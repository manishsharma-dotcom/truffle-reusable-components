public class TF_EX_MindTouchMissingImageBatch
    implements Database.Batchable<SObject> {

    private static final String MINDTOUCH_IMG_BASE = 'https://helpme.tebra.com/@api/deki/files/';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Title__c, TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            WHERE Processed__c = false
        ]);
    }

    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {

        // Load already-queued download URLs to avoid duplicates
        Set<String> alreadyQueued = new Set<String>();
        for (MindTouchPendingFile__c pf : [
            SELECT DownloadURL__c FROM MindTouchPendingFile__c
        ]) {
            if (String.isNotBlank(pf.DownloadURL__c)) {
                alreadyQueued.add(pf.DownloadURL__c.toLowerCase());
            }
        }

        // Load already-uploaded filenames to skip
        Set<String> alreadyUploaded = new Set<String>();
        for (ContentVersion cv : [
            SELECT Title, FileExtension FROM ContentVersion WHERE IsLatest = true
        ]) {
            alreadyUploaded.add((cv.Title + '.' + cv.FileExtension).toLowerCase());
        }

        List<MindTouchPendingFile__c> toInsert = new List<MindTouchPendingFile__c>();
        String markerLower = ('src="' + MINDTOUCH_IMG_BASE).toLowerCase();

        for (KnowledgeCategoryMap__c rec : scope) {
            String html = rec.TransformedHTMLContent__c;
            if (String.isBlank(html)) continue;

            String htmlLower  = html.toLowerCase();
            Integer searchFrom = 0;

            while (searchFrom < html.length()) {
                Integer found = htmlLower.indexOf(markerLower, searchFrom);
                if (found == -1) break;

                // Move past src="
                Integer urlStart = found + 5;
                Integer urlEnd   = html.indexOf('"', urlStart);
                if (urlEnd == -1) { searchFrom = found + 1; continue; }

                String rawUrl = html.substring(urlStart, urlEnd);

                // Decode HTML-encoded ampersands
                rawUrl = rawUrl.replace('&amp;', '&');

                // DownloadURL__c = URL before query string
                String downloadUrl = rawUrl.contains('?')
                    ? rawUrl.substringBefore('?')
                    : rawUrl;

                // FileName__c = segment after last / (before ?)
                String fileName = downloadUrl.substringAfterLast('/');

                if (String.isBlank(fileName) || String.isBlank(downloadUrl)) {
                    searchFrom = found + 1;
                    continue;
                }
                if (alreadyQueued.contains(downloadUrl.toLowerCase())) {
                    searchFrom = found + 1;
                    continue;
                }
                if (alreadyUploaded.contains(fileName.toLowerCase())) {
                    searchFrom = found + 1;
                    continue;
                }

                toInsert.add(new MindTouchPendingFile__c(
                    FileName__c    = fileName,
                    DownloadURL__c = downloadUrl,
                    PageTitle__c   = rec.Title__c,
                    Uploaded__c    = false
                ));
                alreadyQueued.add(downloadUrl.toLowerCase());

                System.debug('Queued missing image: ' + fileName
                    + ' | URL: ' + downloadUrl
                    + ' | Page: ' + rec.Title__c);

                searchFrom = found + 1;
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            System.debug('Inserted ' + toInsert.size() + ' missing image records');
        }
    }

    public void finish(Database.BatchableContext bc) {
        Integer pending = [
            SELECT COUNT() FROM MindTouchPendingFile__c WHERE Uploaded__c = false
        ];
        System.debug('=== Missing Image Collection Complete ===');
        System.debug('Total pending for download: ' + pending);
        System.debug('Next step: Database.executeBatch(new TF_EX_MindTouchFileDownloadBatch(), 1)');
    }
}