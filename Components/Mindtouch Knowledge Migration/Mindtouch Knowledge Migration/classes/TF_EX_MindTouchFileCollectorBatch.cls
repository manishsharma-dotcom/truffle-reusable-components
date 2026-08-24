public class TF_EX_MindTouchFileCollectorBatch
implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    private static final String BASE_URL = TF_EX_MindTouchUtils.base_URL;
    private static final Integer PAGE_SIZE = 100;
    
    // ─── START ────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // No callouts in start() — just query
        return Database.getQueryLocator([
            SELECT Id, Id__c, Title__c
            FROM KnowledgeCategoryMap__c
            WHERE (
                Parent__r.Title__c = 'Media Repo'
                OR Parent__r.Parent__r.Title__c = 'Media Repo'
                OR Parent__r.Parent__r.Parent__r.Title__c = 'Media Repo'
                OR Processed__c = false
            )
        ]);
    }
    
    // ─── EXECUTE ──────────────────────────────────────────────────────────────
    // Batch size = 1 → each execute handles one image page
    // Max callouts per execute = ceil(totalFiles / 100)
    // Worst case: 1112 files = 12 callouts → well within 100 limit
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {
                            
                            // Already-queued filenames to avoid duplicates
                            Set<String> alreadyQueued = new Set<String>();
                            for (MindTouchPendingFile__c pf : [
                                SELECT DownloadURL__c FROM MindTouchPendingFile__c
                            ]) {
                                alreadyQueued.add(pf.DownloadURL__c.toLowerCase());
                            }
                            
                            // Already-uploaded filenames to skip
                            Set<String> alreadyUploaded = new Set<String>();
                            for (ContentVersion cv : [
                                SELECT Title, FileExtension FROM ContentVersion WHERE IsLatest = true
                            ]) {
                                alreadyUploaded.add((cv.Title + '.' + cv.FileExtension).toLowerCase());
                            }
                            
                            List<MindTouchPendingFile__c> toInsert = new List<MindTouchPendingFile__c>();
                            
                            for (KnowledgeCategoryMap__c page : scope) {
                                System.debug('Collecting files for: ' + page.Title__c
                                             + ' | MindTouch ID: ' + page.Id__c);
                                
                                Integer offset     = 0;
                                Integer totalCount = null;
                                Integer fetched    = 0;
                                
                                // Paginate through ALL files on this page
                                do {
                                    HttpRequest req = new HttpRequest();
                                    req.setEndpoint(
                                        BASE_URL + '/pages/' + page.Id__c
                                        + '/files?dream.out.format=json'
                                        + '&limit=' + PAGE_SIZE
                                        + '&offset=' + offset
                                    );
                                    req.setMethod('GET');
                                    req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
                                    req.setHeader('Accept', 'application/json');
                                    req.setTimeout(30000);
                                    
                                    HttpResponse res = new Http().send(req);
                                    
                                    if (res.getStatusCode() != 200) {
                                        System.debug('File list failed for page ' + page.Id__c
                                                     + ' offset=' + offset + ': ' + res.getStatusCode());
                                        break;
                                    }
                                    
                                    Map<String, Object> body =
                                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                                    
                                    // Read total count on first call
                                    if (totalCount == null) {
                                        totalCount = Integer.valueOf(
                                            String.valueOf(body.get('@totalcount'))
                                        );
                                        System.debug('Page ' + page.Title__c
                                                     + ' has ' + totalCount + ' total files');
                                    }
                                    
                                    // Parse file list
                                    Object filesRaw = body.get('file');
                                    List<Object> fileList = new List<Object>();
                                    if (filesRaw instanceof List<Object>) {
                                        fileList = (List<Object>) filesRaw;
                                    } else if (filesRaw instanceof Map<String, Object>) {
                                        fileList.add(filesRaw);
                                    }
                                    
                                    for (Object f : fileList) {
                                        Map<String, Object> file = (Map<String, Object>) f;
                                        String downloadUrl = '';
                                        Double fileSize = 0;
                                        Object contentsRaw = file.get('contents');
                                        if (contentsRaw instanceof Map<String, Object>) {
                                            downloadUrl = String.valueOf(
                                                ((Map<String, Object>) contentsRaw).get('@href')
                                            );
                                            fileSize = Double.valueOf(
                                                ((Map<String, Object>) contentsRaw).get('@size')
                                            );
                                        }
                                        
                                        // Extract filename from URL: between last '/' and '?' (or end of string)
                                        String filename = '';
                                        if (String.isNotBlank(downloadUrl)) {
                                            String afterSlash = downloadUrl.substringAfterLast('/');
                                            filename = afterSlash.contains('?')
                                                ? afterSlash.substringBefore('?')
                                                : afterSlash;
                                        }
                                        
                                        if (String.isBlank(filename) || String.isBlank(downloadUrl)) continue;
                                        if (alreadyQueued.contains(downloadUrl.toLowerCase())) continue;
                                        if (alreadyUploaded.contains(filename.toLowerCase()))  continue;
                                        
                                        toInsert.add(new MindTouchPendingFile__c(
                                            FileName__c    = filename,
                                            DownloadURL__c = downloadUrl,
                                            PageTitle__c   = page.Title__c,
                                            Uploaded__c    = false,
                                            File_Size__c = fileSize
                                        ));
                                        alreadyQueued.add(downloadUrl.toLowerCase());
                                        fetched++;
                                    }
                                    
                                    offset += PAGE_SIZE;
                                    
                                } while (totalCount != null && offset < totalCount);
                                
                                System.debug('Queued ' + fetched + ' new files from: ' + page.Title__c);
                            }
                            
                            if (!toInsert.isEmpty()) {
                                insert toInsert;
                                System.debug('Inserted ' + toInsert.size() + ' pending file records');
                            }
                        }
    
    // ─── FINISH ───────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        Integer pending  = [SELECT COUNT() FROM MindTouchPendingFile__c WHERE Uploaded__c = false];
        Integer uploaded = [SELECT COUNT() FROM MindTouchPendingFile__c WHERE Uploaded__c = true];
        System.debug('=== File Collection Complete ===');
        System.debug('Pending download: ' + pending);
        System.debug('Already uploaded: ' + uploaded);
        System.debug('Next step: Database.executeBatch(new MindTouchFileDownloadBatch(), 1)');
    }
}