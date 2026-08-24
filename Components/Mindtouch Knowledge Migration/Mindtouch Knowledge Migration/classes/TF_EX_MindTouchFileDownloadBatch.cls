public class TF_EX_MindTouchFileDownloadBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // ─── START ────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, FileName__c, DownloadURL__c, PageTitle__c
            FROM MindTouchPendingFile__c
            WHERE Uploaded__c = false
            ORDER BY PageTitle__c ASC
        ]);
    }

    // ─── EXECUTE ──────────────────────────────────────────────────────────────
    // Batch size = 1 → exactly 1 callout per transaction
    public void execute(Database.BatchableContext bc,
                        List<MindTouchPendingFile__c> scope) {

        List<MindTouchPendingFile__c> toUpdate = new List<MindTouchPendingFile__c>();

        for (MindTouchPendingFile__c pending : scope) {
            System.debug('Downloading: ' + pending.FileName__c
                + ' | Page: ' + pending.PageTitle__c);

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(pending.DownloadURL__c);
                req.setMethod('GET');
                req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
                req.setTimeout(30000);
                
                String username = 'veeranch.srivastava@trufflecorp.com';
				String password = 'lYzHiB1V';
				String credentials = username + ':' + password;
				Blob headerValue = Blob.valueOf(credentials);
				String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                

				req.setHeader('Authorization', authorizationHeader);
                req.setHeader('Content-Type','application/json');

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 200) {
                    Blob fileBlob  = res.getBodyAsBlob();
                    String filename = pending.FileName__c;

                    // Insert ContentVersion
                    // ContentVersionAutoDistribute trigger fires automatically
                    ContentVersion cv = new ContentVersion(
                        Title          = filename.substringBeforeLast('.'),
                        PathOnClient   = filename,
                        VersionData    = fileBlob,
                        IsMajorVersion = true
                    );
                    insert cv;

                    pending.Uploaded__c = true;
                    toUpdate.add(pending);

                    System.debug('Uploaded: ' + filename
                        + ' (' + fileBlob.size() + ' bytes)');
                } else {
                    System.debug('Download failed: ' + pending.FileName__c
                        + ' | Status: ' + res.getStatusCode());
                }
            } catch (Exception e) {
                System.debug('Exception: ' + pending.FileName__c
                    + ' | ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    // ─── FINISH ───────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        Integer uploaded  = [SELECT COUNT() FROM MindTouchPendingFile__c WHERE Uploaded__c = true];
        Integer remaining = [SELECT COUNT() FROM MindTouchPendingFile__c WHERE Uploaded__c = false];
        Integer totalCVs  = [SELECT COUNT() FROM ContentVersion WHERE IsLatest = true];
        Integer totalDist = [SELECT COUNT() FROM ContentDistribution];

        System.debug('=== Download Complete ===');
        System.debug('Files uploaded this run: ' + uploaded);
        System.debug('Files still pending:     ' + remaining);
        System.debug('Total ContentVersions:   ' + totalCVs);
        System.debug('Total Distributions:     ' + totalDist);

        if (remaining > 0) {
            System.debug('Re-running for remaining files...');
            Database.executeBatch(new TF_EX_MindTouchFileDownloadBatch(), 1);
        } else {
            System.debug('All files downloaded successfully.');
        }
    }
}