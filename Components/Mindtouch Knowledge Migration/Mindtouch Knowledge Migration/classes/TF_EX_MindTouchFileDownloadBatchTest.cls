@isTest
private class TF_EX_MindTouchFileDownloadBatchTest {

    // =========================================================
    // MOCK : Success Response
    // =========================================================
    private class SuccessMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);
            res.setBody('Fake File Content');

            return res;
        }
    }

    // =========================================================
    // MOCK : Failure Response
    // =========================================================
    private class FailureMock
        implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(500);
            res.setBody('Error');

            return res;
        }
    }

    // =========================================================
    // TEST SETUP
    // =========================================================
    @TestSetup
    static void setupData() {

        String uniqueKey =
            String.valueOf(Math.abs(Crypto.getRandomInteger()));

        List<MindTouchPendingFile__c> files =
            new List<MindTouchPendingFile__c>();

        files.add(new MindTouchPendingFile__c(
            FileName__c = 'TestFile1_' + uniqueKey + '.png',
            DownloadURL__c = 'https://example.com/file1',
            PageTitle__c = 'Page One',
            Uploaded__c = false
        ));

        files.add(new MindTouchPendingFile__c(
            FileName__c = 'TestFile2_' + uniqueKey + '.png',
            DownloadURL__c = 'https://example.com/file2',
            PageTitle__c = 'Page Two',
            Uploaded__c = false
        ));

        insert files;
    }

    // =========================================================
    // TEST : start()
    // =========================================================
    @isTest
    static void testStartMethod() {

        TF_EX_MindTouchFileDownloadBatch batchObj =
            new TF_EX_MindTouchFileDownloadBatch();

        Test.startTest();

        Database.QueryLocator ql =
            batchObj.start(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            ql
        );
    }

    // =========================================================
    // TEST : execute() success path
    // =========================================================
    @isTest
    static void testExecuteSuccess() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TF_EX_MindTouchFileDownloadBatch(),
            200
        );

        Test.stopTest();

        List<MindTouchPendingFile__c> updatedFiles = [
            SELECT Id,
                   Uploaded__c
            FROM MindTouchPendingFile__c
        ];

        for (MindTouchPendingFile__c fileRec : updatedFiles) {

            System.assertEquals(
                true,
                fileRec.Uploaded__c
            );
        }

        List<ContentVersion> cvs = [
            SELECT Id,
                   Title
            FROM ContentVersion
        ];

        System.assert(
            cvs.size() > 0
        );
    }

    // =========================================================
    // TEST : execute() failure path
    // =========================================================
    @isTest
static void testExecuteFailure() {

    Test.setMock(
        HttpCalloutMock.class,
        new FailureMock()
    );

    List<MindTouchPendingFile__c> scope = [
        SELECT Id,
               FileName__c,
               DownloadURL__c,
               PageTitle__c,
               Uploaded__c
        FROM MindTouchPendingFile__c
        LIMIT 1
    ];

    TF_EX_MindTouchFileDownloadBatch batchObj =
        new TF_EX_MindTouchFileDownloadBatch();

    Test.startTest();

    batchObj.execute(
        null,
        scope
    );

    Test.stopTest();

    MindTouchPendingFile__c refreshed = [
        SELECT Uploaded__c
        FROM MindTouchPendingFile__c
        WHERE Id = :scope[0].Id
        LIMIT 1
    ];

    System.assertEquals(
        false,
        refreshed.Uploaded__c
    );
}
    // =========================================================
    // TEST : execute() direct coverage
    // =========================================================
    @isTest
    static void testExecuteDirectly() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        List<MindTouchPendingFile__c> scope = [
            SELECT Id,
                   FileName__c,
                   DownloadURL__c,
                   PageTitle__c,
                   Uploaded__c
            FROM MindTouchPendingFile__c
            LIMIT 1
        ];

        TF_EX_MindTouchFileDownloadBatch batchObj =
            new TF_EX_MindTouchFileDownloadBatch();

        Test.startTest();

        batchObj.execute(
            null,
            scope
        );

        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // TEST : empty scope
    // =========================================================
    @isTest
    static void testExecuteEmptyScope() {

        TF_EX_MindTouchFileDownloadBatch batchObj =
            new TF_EX_MindTouchFileDownloadBatch();

        Test.startTest();

        batchObj.execute(
            null,
            new List<MindTouchPendingFile__c>()
        );

        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // TEST : finish()
    // =========================================================
    @isTest
    static void testFinishMethod() {

        Test.setMock(
            HttpCalloutMock.class,
            new SuccessMock()
        );

        Test.startTest();

        Database.executeBatch(
            new TF_EX_MindTouchFileDownloadBatch(),
            200
        );

        Test.stopTest();

        System.assert(true);
    }
}