@isTest
private class TF_EX_MindTouchCategorySyncTest {

    // =========================================================
    // MOCK : Success LIST response
    // =========================================================
    private class SuccessListMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{' +
                '"page.subpage": [' +
                    '{' +
                        '"@id":"1001",' +
                        '"title":"How To Article",' +
                        '"article":"howto",' +
                        '"path":{"#text":"/help/howto"},' +
                        '"security":{' +
                            '"permissions.page":{' +
                                '"restriction":{"#text":"Public"}' +
                            '}' +
                        '}' +
                    '},' +
                    '{' +
                        '"@id":"1002",' +
                        '"title":"Topic Article",' +
                        '"article":"topic",' +
                        '"path":{"#text":"/help/topic"},' +
                        '"security":{' +
                            '"permissions.page":{' +
                                '"restriction":{"#text":"Private"}' +
                            '}' +
                        '}' +
                    '}' +
                ']' +
                '}'
            );

            return res;
        }
    }

    // =========================================================
    // MOCK : Single object response
    // =========================================================
    private class SuccessSingleMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{' +
                    '"page.subpage": {' +
                        '"@id":"2001",' +
                        '"title":"Reference Article",' +
                        '"article":"reference",' +
                        '"path":{"#text":"/help/reference"},' +
                        '"security":{' +
                            '"permissions.page":{' +
                                '"restriction":{"#text":"Public"}' +
                            '}' +
                        '}' +
                    '}' +
                '}'
            );

            return res;
        }
    }

    // =========================================================
    // MOCK : Failure response
    // =========================================================
    private class FailureMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(500);
            res.setBody('Server Error');

            return res;
        }
    }

    // =========================================================
    // MOCK : malformed security response
    // =========================================================
    private class MalformedSecurityMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setBody(
                '{' +
                    '"page.subpage": {' +
                        '"@id":"3001",' +
                        '"title":"Broken Security",' +
                        '"article":"topic",' +
                        '"path":{"#text":"/help/broken"}' +
                    '}' +
                '}'
            );

            return res;
        }
    }

    // =========================================================
    // TEST : LIST response
    // =========================================================
    @isTest
    static void testSyncTopLevelCategories_ListResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessListMock()
        );

        Test.startTest();

        TF_EX_MindTouchCategorySync.syncTopLevelCategories();

        Test.stopTest();

        List<KnowledgeCategoryMap__c> records = [
            SELECT Id,
                   Id__c,
                   Title__c,
                   Public__c,
                   MindTouchPath__c
            FROM KnowledgeCategoryMap__c
            WHERE Id__c IN ('1001', '1002')
        ];

        System.assertEquals(
            2,
            records.size()
        );

        Boolean foundPublic = false;
        Boolean foundPrivate = false;

        for (KnowledgeCategoryMap__c rec : records) {

            if (rec.Id__c == '1001') {

                foundPublic = true;

                System.assertEquals(
                    true,
                    rec.Public__c
                );
            }

            if (rec.Id__c == '1002') {

                foundPrivate = true;

                System.assertEquals(
                    false,
                    rec.Public__c
                );
            }
        }

        System.assert(foundPublic);
        System.assert(foundPrivate);
    }

    // =========================================================
    // TEST : Single object response
    // =========================================================
    @isTest
    static void testSyncTopLevelCategories_SingleObject() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessSingleMock()
        );

        Test.startTest();

        TF_EX_MindTouchCategorySync.syncTopLevelCategories();

        Test.stopTest();

        List<KnowledgeCategoryMap__c> records = [
            SELECT Id,
                   Id__c,
                   Title__c
            FROM KnowledgeCategoryMap__c
            WHERE Id__c = '2001'
        ];

        System.assertEquals(
            1,
            records.size()
        );

        System.assertEquals(
            'Reference Article',
            records[0].Title__c
        );
    }

    // =========================================================
    // TEST : Failure response
    // =========================================================
    @isTest
    static void testSyncTopLevelCategories_FailureResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new FailureMock()
        );

        Test.startTest();

        TF_EX_MindTouchCategorySync.syncTopLevelCategories();

        Test.stopTest();

        List<KnowledgeCategoryMap__c> records = [
            SELECT Id
            FROM KnowledgeCategoryMap__c
            WHERE Id__c IN ('1001', '1002', '2001')
        ];

        System.assertEquals(
            0,
            records.size()
        );
    }

    // =========================================================
    // TEST : malformed security branch
    // =========================================================
    @isTest
    static void testMalformedSecurityHandling() {

        Test.setMock(
            HttpCalloutMock.class,
            new MalformedSecurityMock()
        );

        Test.startTest();

        TF_EX_MindTouchCategorySync.syncTopLevelCategories();

        Test.stopTest();

        List<KnowledgeCategoryMap__c> records = [
            SELECT Id,
                   Public__c
            FROM KnowledgeCategoryMap__c
            WHERE Id__c = '3001'
        ];

        System.assertEquals(
            1,
            records.size()
        );

        System.assertEquals(
            false,
            records[0].Public__c
        );
    }
}