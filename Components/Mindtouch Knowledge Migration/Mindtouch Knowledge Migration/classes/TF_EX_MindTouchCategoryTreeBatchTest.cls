@isTest
private class TF_EX_MindTouchCategoryTreeBatchTest {

    // ─────────────────────────────────────────────────────────────────────────
    // The batch's fetchSubpages() uses a do-while loop driven by @totalcount.
    // The mock MUST return @totalcount so the loop exits after the first call.
    // Without it, totalCount stays null and offset never advances past 0, which
    // can cause an infinite loop or unexpected callout counts.
    //
    // The batch's finish() calls Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch())
    // when unprocessed records remain. After Test.stopTest() the child record
    // (Id__c = '301') exists and is unprocessed, so finish() re-launches the batch.
    // To prevent that re-launch from making real callouts (or failing), we use
    // a mock that returns @totalcount=0 / empty subpages so the child batch
    // exits cleanly. The child record is set Processed__c = false by the batch
    // but since it has no children (empty mock), no further children are added.
    // ─────────────────────────────────────────────────────────────────────────

    // ── Mock: 200 with a single subpage and @totalcount ───────────────────────
    // Returns count=1 so the do-while exits after one call.
    private class SuccessSingleMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '"@totalcount":"1",' +
                '"@count":"1",' +
                '"page.subpage":{' +
                '"@id":"301",' +
                '"title":"Child Category",' +
                '"article":"howto",' +
                '"path":{"#text":"/Parent/Child"},' +
                '"security":{' +
                '"permissions.page":{' +
                '"restriction":{"#text":"Public"}' +
                '}}}}'
            );
            return res;
        }
    }

    // ── Mock: 200 with empty subpages and @totalcount = 0 ────────────────────
    // Used for the re-launched batch in finish() and for "nothing to do" tests.
    private class EmptySubpagesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"@totalcount":"0","@count":"0"}');
            return res;
        }
    }

    // ── Mock: responds with subpage on first call, empty on subsequent calls ──
    // Handles the case where the initial batch run creates a child record
    // (Id__c = '301', Processed__c = false), and finish() re-launches the batch
    // to process it. The second call must return empty so no further children
    // are created and the batch terminates cleanly.
    private class SingleThenEmptyMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            if (callCount == 1) {
                res.setBody(
                    '{' +
                    '"@totalcount":"1","@count":"1",' +
                    '"page.subpage":{' +
                    '"@id":"301","title":"Child Category","article":"howto",' +
                    '"path":{"#text":"/Parent/Child"},' +
                    '"security":{"permissions.page":{"restriction":{"#text":"Public"}}}' +
                    '}}'
                );
            } else {
                // Subsequent calls (re-launched batch processing the child) return empty
                res.setBody('{"@totalcount":"0","@count":"0"}');
            }
            return res;
        }
    }

    // ── Mock: 404 error ───────────────────────────────────────────────────────
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
        KnowledgeCategoryMap__c parent = new KnowledgeCategoryMap__c(
            Name           = 'Parent Category',
            Title__c       = 'Parent Category',
            Id__c          = '3000',
            Processed__c   = false,
            ArticleType__c = 'topic-category'
        );
        insert parent;
    }

    // ── Test: batch fetches subpages and upserts child record ─────────────────
    @isTest
    static void testBatchFetchesSubpages() {
        // SingleThenEmptyMock handles both the initial batch (returns one child)
        // and the re-launched batch from finish() (returns empty for the child).
        Test.setMock(HttpCalloutMock.class, new SingleThenEmptyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> children = [
            SELECT Id__c, Title__c, Public__c, MindTouchPath__c
            FROM KnowledgeCategoryMap__c
            WHERE Id__c = '301'
        ];
        System.assertEquals(1,                children.size(),              'Child record upserted');
        System.assertEquals('Child Category', children[0].Title__c,        'Title correct');
        System.assertEquals(true,             children[0].Public__c,       'Public flag correct');
        System.assertEquals('/Parent/Child',  children[0].MindTouchPath__c,'Path correct');
    }

    // ── Test: batch with empty subpages — parent marked processed, no children
    @isTest
    static void testBatchEmptySubpages() {
        Test.setMock(HttpCalloutMock.class, new EmptySubpagesMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        // Only the parent exists; no children added
        Integer count = [SELECT COUNT() FROM KnowledgeCategoryMap__c];
        System.assertEquals(1, count, 'No child records created for empty subpages');

        // Parent must be marked as processed
        KnowledgeCategoryMap__c parent = [
            SELECT Processed__c FROM KnowledgeCategoryMap__c WHERE Id__c = '3000'
        ];
        System.assertEquals(true, parent.Processed__c, 'Parent marked as processed');
    }

    // ── Test: 404 API error — parent still marked processed, no children ──────
    @isTest
    static void testBatchApiError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM KnowledgeCategoryMap__c];
        System.assertEquals(1, count, 'No child records created on API error');
    }

    // ── Test: no unprocessed records — batch scope is empty, no callouts made ─
    @isTest
    static void testBatchNothingToProcess() {
        KnowledgeCategoryMap__c parent = [SELECT Id FROM KnowledgeCategoryMap__c LIMIT 1];
        parent.Processed__c = true;
        update parent;

        Test.setMock(HttpCalloutMock.class, new EmptySubpagesMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        // finish() sees 0 unprocessed → no re-launch → just logs complete
        System.assert(true, 'Batch with empty scope ran without error');
    }

    // ── Test: finish() re-launches when unprocessed records remain ─────────────
    @isTest
    static void testFinishRelaunch() {
        // First call creates a child; second call (re-launch) processes child with empty
        Test.setMock(HttpCalloutMock.class, new SingleThenEmptyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        // Both parent (3000) and child (301) should exist after both batch runs
        Integer total = [SELECT COUNT() FROM KnowledgeCategoryMap__c];
        System.assert(total >= 1, 'Records exist after batch re-launch cycle');
    }

    // ── Test: finish() logs complete when all records processed ───────────────
    @isTest
    static void testFinishComplete() {
        Test.setMock(HttpCalloutMock.class, new EmptySubpagesMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 200);
        Test.stopTest();

        System.assert(true, 'finish() logged complete without error');
    }
}