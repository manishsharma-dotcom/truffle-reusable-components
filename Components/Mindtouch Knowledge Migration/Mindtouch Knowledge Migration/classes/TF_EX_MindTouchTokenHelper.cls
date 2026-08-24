public class TF_EX_MindTouchTokenHelper {

    public static String buildToken() {
        MindTouch_Config__mdt config = [
            SELECT API_Key__c, API_Secret__c, API_User__c
            FROM MindTouch_Config__mdt where API_Key__c != NULL
            LIMIT 1
        ];

        String apiKey    = config.API_Key__c;
        String apiSecret = config.API_Secret__c;
        String apiUser   = config.API_User__c; // e.g. '=admin'

        // Current epoch timestamp in seconds
        Long epoch = DateTime.now().getTime() / 1000;
        String epochStr = String.valueOf(epoch);

        // Message to sign: {key}_{epoch}_{user}
        String message = apiKey + '_' + epochStr + '_' + apiUser;

        // HMAC-SHA256 signature
        Blob hmacHash = Crypto.generateMac(
            'hmacSHA256',
            Blob.valueOf(message),
            Blob.valueOf(apiSecret)
        );

        // Convert to lowercase hex string
        String hashHex = EncodingUtil.convertToHex(hmacHash);

        // Final token: tkn_{key}_{epoch}_{user}_{hash}
        system.debug('tooken---'+'tkn_' + apiKey + '_' + epochStr + '_' + apiUser + '_' + hashHex);
        return 'tkn_' + apiKey + '_' + epochStr + '_' + apiUser + '_' + hashHex;
    }
}