@isTest
private class TF_EX_MindTouchApiServiceTest {

    // ── Mock: 200 OK response ─────────────────────────────────────────────────
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"@id":"home","title":"Home"}');
            return res;
        }
    }

    // ── Mock: 401 Unauthorized response ──────────────────────────────────────
    private class UnauthorizedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('Unauthorized');
            return res;
        }
    }

    // ── Mock: 500 Server Error response ──────────────────────────────────────
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // ── Test: successful connection (200) ─────────────────────────────────────
    @isTest
    static void testConnectionSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        HttpResponse res = TF_EX_MindTouchApiService.testConnection();
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode(), 'Expected 200 OK');
        System.assert(res.getBody().contains('home'), 'Body contains expected content');
    }

    // ── Test: unauthorized response (401) ─────────────────────────────────────
    @isTest
    static void testConnectionUnauthorized() {
        Test.setMock(HttpCalloutMock.class, new UnauthorizedMock());

        Test.startTest();
        HttpResponse res = TF_EX_MindTouchApiService.testConnection();
        Test.stopTest();

        System.assertEquals(401, res.getStatusCode(), 'Expected 401 Unauthorized');
    }

    // ── Test: server error response (500) ─────────────────────────────────────
    @isTest
    static void testConnectionServerError() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        HttpResponse res = TF_EX_MindTouchApiService.testConnection();
        Test.stopTest();

        System.assertEquals(500, res.getStatusCode(), 'Expected 500 Server Error');
    }
}