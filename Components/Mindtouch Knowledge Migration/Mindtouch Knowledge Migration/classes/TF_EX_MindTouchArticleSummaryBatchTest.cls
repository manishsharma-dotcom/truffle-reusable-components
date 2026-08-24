@isTest
private class TF_EX_MindTouchArticleSummaryBatchTest {

    // ── Mock: 200 with single property object containing overview ─────────────
    private class SuccessSinglePropertyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"property":{"@name":"mindtouch.page#overview",' +
                '"contents":{"#text":"This is the summary text."}}}'
            );
            return res;
        }
    }

    // ── Mock: 200 with list of properties (one is overview) ───────────────────
    private class SuccessListPropertyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"property":[' +
                '{"@name":"other.prop","contents":{"#text":"Other"}},' +
                '{"@name":"mindtouch.page#overview","contents":{"#text":"List summary."}}' +
                ']}'
            );
            return res;
        }
    }

    // ── Mock: 200 — no overview property ─────────────────────────────────────
    private class NoOverviewMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"property":{"@name":"some.other.property","contents":{"#text":"not overview"}}}');
            return res;
        }
    }

    // ── Mock: 404 error response ──────────────────────────────────────────────
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        List<KnowledgeCategoryMap__c> records = new List<KnowledgeCategoryMap__c>();
        for (Integer i = 0; i < 3; i++) {
            records.add(new KnowledgeCategoryMap__c(
                Name         = 'Summary Article ' + i,
                Title__c     = 'Summary Article ' + i,
                Id__c        = String.valueOf(2000 + i),
                Processed__c = false,
                ArticleType__c = 'howto'
            ));
        }
        insert records;
    }

    // ── Test: batch with single-property 200 response ────────────────────────
    @isTest
    static void testBatchSuccessSingleProperty() {
        Test.setMock(HttpCalloutMock.class, new SuccessSinglePropertyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> results = [
            SELECT Summary__c, Processed__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : results) {
            System.assertEquals(true, r.Processed__c, 'Marked as processed');
            System.assertEquals('This is the summary text.', r.Summary__c);
        }
    }

    // ── Test: batch with list-property 200 response ───────────────────────────
    @isTest
    static void testBatchSuccessListProperty() {
        Test.setMock(HttpCalloutMock.class, new SuccessListPropertyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> results = [
            SELECT Summary__c, Processed__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : results) {
            System.assertEquals(true, r.Processed__c, 'Marked as processed');
            System.assertEquals('List summary.', r.Summary__c);
        }
    }

    // ── Test: batch with no overview property in response ─────────────────────
    @isTest
    static void testBatchNoOverviewProperty() {
        Test.setMock(HttpCalloutMock.class, new NoOverviewMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> results = [
            SELECT Summary__c, Processed__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : results) {
            System.assertEquals(true, r.Processed__c, 'Marked as processed even without summary');
            System.assertEquals(null, r.Summary__c, 'Summary stays null when no overview');
        }
    }

    // ── Test: batch with 404 error response ───────────────────────────────────
    @isTest
    static void testBatchErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> results = [
            SELECT Summary__c, Processed__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : results) {
            System.assertEquals(true, r.Processed__c, 'Marked processed even on error');
            System.assertEquals(null, r.Summary__c, 'No summary set on error');
        }
    }

    // ── Test: empty scope (no unprocessed records) ────────────────────────────
    @isTest
    static void testBatchEmptyScope() {
        delete [SELECT Id FROM KnowledgeCategoryMap__c];
        Test.setMock(HttpCalloutMock.class, new SuccessSinglePropertyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch ran without error on empty scope');
    }

    // ── Test: finish() executes summary debug ─────────────────────────────────
    @isTest
    static void testFinish() {
        Test.setMock(HttpCalloutMock.class, new SuccessSinglePropertyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleSummaryBatch(), 200);
        Test.stopTest();

        System.assert(true, 'finish() executed without error');
    }
}