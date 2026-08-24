@isTest
private class TF_EX_MindTouchFileCollectorBatchTest {

    // ── Mock: 200 with single file in response ────────────────────────────────
    private class SingleFileMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"@totalcount":"1","file":{' +
                '"filename":"test-image.png",' +
                '"contents":{"@href":"https://helpme.tebra.com/@api/deki/files/1/test-image.png","@size":"12345"}' +
                '}}'
            );
            return res;
        }
    }

    // ── Mock: 200 with list of files ──────────────────────────────────────────
    private class MultipleFilesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"@totalcount":"2","file":[' +
                '{"filename":"img1.png","contents":{"@href":"https://helpme.tebra.com/@api/deki/files/2/img1.png","@size":"1000"}},' +
                '{"filename":"img2.jpg","contents":{"@href":"https://helpme.tebra.com/@api/deki/files/3/img2.jpg","@size":"2000"}}' +
                ']}'
            );
            return res;
        }
    }

    // ── Mock: 200 — blank filename (should be skipped) ────────────────────────
    private class BlankFilenameMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"@totalcount":"1","file":{"filename":"","contents":{"@href":"","@size":"0"}}}');
            return res;
        }
    }

    // ── Mock: 500 error ───────────────────────────────────────────────────────
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        KnowledgeCategoryMap__c page = new KnowledgeCategoryMap__c(
            Name         = 'Media Repo Page',
            Title__c     = 'Media Repo Page',
            Id__c        = '4000',
            Processed__c = false,
            ArticleType__c = 'topic'
        );
        insert page;
    }

    // ── Test: batch inserts new MindTouchPendingFile__c for single file ───────
    @isTest
    static void testBatchSingleFile() {
        Test.setMock(HttpCalloutMock.class, new SingleFileMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        List<MindTouchPendingFile__c> pending = [
            SELECT FileName__c, Uploaded__c FROM MindTouchPendingFile__c
        ];
        System.assertEquals(1, pending.size(), 'One pending file created');
        System.assertEquals('test-image.png', pending[0].FileName__c);
        System.assertEquals(false, pending[0].Uploaded__c);
    }

    // ── Test: batch inserts multiple files ────────────────────────────────────
    @isTest
    static void testBatchMultipleFiles() {
        Test.setMock(HttpCalloutMock.class, new MultipleFilesMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM MindTouchPendingFile__c];
        System.assertEquals(2, count, 'Two pending files created');
    }

    // ── Test: blank filename is skipped ──────────────────────────────────────
    @isTest
    static void testBatchBlankFilenameSkipped() {
        Test.setMock(HttpCalloutMock.class, new BlankFilenameMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM MindTouchPendingFile__c];
        System.assertEquals(0, count, 'Blank filename skipped');
    }

    // ── Test: API error — no files inserted ───────────────────────────────────
    @isTest
    static void testBatchApiError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM MindTouchPendingFile__c];
        System.assertEquals(0, count, 'No records created on error');
    }

    // ── Test: duplicate URL skipped ───────────────────────────────────────────
    @isTest
    static void testBatchDuplicateSkipped() {
        // Insert an existing pending file with the same URL
        MindTouchPendingFile__c existing = new MindTouchPendingFile__c(
            FileName__c    = 'test-image.png',
            DownloadURL__c = 'https://helpme.tebra.com/@api/deki/files/1/test-image.png',
            PageTitle__c   = 'Existing',
            Uploaded__c    = false
        );
        insert existing;

        Test.setMock(HttpCalloutMock.class, new SingleFileMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        // Should still be only 1 record (duplicate skipped)
        Integer count = [SELECT COUNT() FROM MindTouchPendingFile__c];
        System.assertEquals(1, count, 'Duplicate URL not re-inserted');
    }

    // ── Test: finish() logs summary ───────────────────────────────────────────
    @isTest
    static void testFinish() {
        Test.setMock(HttpCalloutMock.class, new SingleFileMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchFileCollectorBatch(), 200);
        Test.stopTest();

        System.assert(true, 'finish() ran without error');
    }
}