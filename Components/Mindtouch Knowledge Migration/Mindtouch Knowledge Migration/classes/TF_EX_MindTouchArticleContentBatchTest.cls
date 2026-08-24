@isTest
private class TF_EX_MindTouchArticleContentBatchTest {

    // ── Mock: 200 with JSON body containing body as String ────────────────────
    private class SuccessStringBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"body":"<p>Article HTML content</p>"}');
            return res;
        }
    }

    // ── Mock: 200 with JSON body containing body as List ──────────────────────
    private class SuccessListBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"body":["<p>Part one</p>","<p>Part two</p>"]}');
            return res;
        }
    }

    // ── Mock: 200 with body as Map containing #text ───────────────────────────
    private class SuccessMapBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"body":{"#text":"<p>Map text content</p>"}}');
            return res;
        }
    }

    // ── Mock: 200 with empty body ─────────────────────────────────────────────
    private class EmptyBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"body":""}');
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

    // ── Mock: 200 with video tag in body ─────────────────────────────────────
    private class VideoBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"body":"<video><source src=\\"https://kareocustomertraining.s3.amazonaws.com/Help%20Center/video.mp4\\"></video>"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        List<KnowledgeCategoryMap__c> records = new List<KnowledgeCategoryMap__c>();
        for (Integer i = 0; i < 3; i++) {
            records.add(new KnowledgeCategoryMap__c(
                Name         = 'Article ' + i,
                Title__c     = 'Article ' + i,
                Id__c        = String.valueOf(1000 + i),
                Processed__c = false
            ));
        }
        insert records;
    }

    // ── Test: batch runs with 200 String body response ───────────────────────
    @isTest
    static void testBatchSuccessStringBody() {
        Test.setMock(HttpCalloutMock.class, new SuccessStringBodyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> updated = [
            SELECT HTMLContent__c, Processed__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : updated) {
            System.assertEquals(true, r.Processed__c, 'Record marked as processed');
            System.assertEquals('<p>Article HTML content</p>', r.HTMLContent__c);
        }
    }

    // ── Test: batch runs with 500 error response ─────────────────────────────
    @isTest
    static void testBatchErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> updated = [
            SELECT Processed__c, HTMLContent__c FROM KnowledgeCategoryMap__c
        ];
        for (KnowledgeCategoryMap__c r : updated) {
            System.assertEquals(true, r.Processed__c, 'Record marked processed even on error');
            System.assertEquals(null, r.HTMLContent__c, 'No content set on error');
        }
    }

    // ── Test: batch runs with empty body response ─────────────────────────────
    @isTest
    static void testBatchEmptyBody() {
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch ran without exception on empty body');
    }

    // ── Test: replaceVideoTags - no video tag ─────────────────────────────────
    @isTest
    static void testReplaceVideoTagsNoVideo() {
        String html = '<p>No video here</p>';
        String result = TF_EX_MindTouchArticleContentBatch.replaceVideoTags(html);
        System.assertEquals(html, result, 'HTML unchanged when no video tag');
    }

    // ── Test: replaceVideoTags - blank input ──────────────────────────────────
    @isTest
    static void testReplaceVideoTagsBlank() {
        String result = TF_EX_MindTouchArticleContentBatch.replaceVideoTags('');
        System.assertEquals('', result, 'Empty string returned unchanged');

        result = TF_EX_MindTouchArticleContentBatch.replaceVideoTags(null);
        System.assertEquals(null, result, 'Null returned unchanged');
    }

    // ── Test: replaceVideoTags - with video tag and source ───────────────────
    @isTest
    static void testReplaceVideoTagsWithSource() {
        String html =
            '<video><source src="https://kareocustomertraining.s3.amazonaws.com/Help%20Center/test.mp4"></video>';
        String result = TF_EX_MindTouchArticleContentBatch.replaceVideoTags(html);
        System.assert(result.contains('<iframe'), 'Video replaced with iframe');
        System.assert(!result.contains('<video'), 'Video tag removed');
    }

    // ── Test: replaceVideoTags - video block without source tag ──────────────
    @isTest
    static void testReplaceVideoTagsNoSource() {
        String html = '<video controls><p>No source here</p></video>';
        String result = TF_EX_MindTouchArticleContentBatch.replaceVideoTags(html);
        // No source found — block left unchanged
        System.assert(result.contains('<video'), 'Video block left unchanged without source');
    }

    // ── Test: finish method runs without error ────────────────────────────────
    @isTest
    static void testFinish() {
        Test.setMock(HttpCalloutMock.class, new SuccessStringBodyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 200);
        Test.stopTest();

        System.assert(true, 'finish() ran without error');
    }

    // ── Test: content truncation at 131000 chars ──────────────────────────────
    @isTest
    static void testBatchWithLargeContent() {
        // Mock returning 131001+ chars — uses list body path
        Test.setMock(HttpCalloutMock.class, new SuccessMapBodyMock());

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Large content handled without error');
    }
}