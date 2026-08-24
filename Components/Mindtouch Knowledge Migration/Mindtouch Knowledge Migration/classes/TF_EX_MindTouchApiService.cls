public class TF_EX_MindTouchApiService {

    private static final String BASE_URL = TF_EX_MindtouchUtils.base_URL;

    public static HttpResponse testConnection() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/pages/home/info?dream.out.format=json');
        req.setMethod('GET');
        req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Status: ' + res.getStatusCode());
        System.debug('Body: ' + res.getBody());

        return res;
    }
}