public class TF_EX_MindTouchArticleSummaryBatch
implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    private static final String BASE_URL = TF_EX_MindTouchUtils.base_URL;
    
    // ─── START ───────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Same article set as MindTouchArticleContentBatch
        return Database.getQueryLocator([
            SELECT Id, Id__c, Title__c
            FROM KnowledgeCategoryMap__c
            WHERE Processed__c = false
        ]);
    }
    
    // ─── EXECUTE ─────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {
                            
                            List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();
                            
                            for (KnowledgeCategoryMap__c record : scope) {
                                System.debug('Fetching summary for: ' + record.Title__c
                                             + ' | Id__c: ' + record.Id__c);
                                
                                String summary = fetchPageSummary(record.Id__c);
                                
                                if (!String.isBlank(summary)) {
                                    record.Summary__c = summary;
                                    System.debug('Summary found: ' + summary.left(100));
                                } else {
                                    System.debug('No summary for: ' + record.Title__c);
                                }
                                
                                record.Processed__c = true;
                                toUpdate.add(record);
                            }
                            
                            if (!toUpdate.isEmpty()) {
                                update toUpdate;
                                System.debug('Updated ' + toUpdate.size() + ' records');
                            }
                        }
    
    // ─── FINISH ──────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        Integer total = [
            SELECT COUNT() FROM KnowledgeCategoryMap__c
            WHERE ArticleType__c != 'topic-category'
            AND   ArticleType__c != 'topic-guide'
        ];
        Integer processed = [
            SELECT COUNT() FROM KnowledgeCategoryMap__c
            WHERE ArticleType__c != 'topic-category'
            AND   ArticleType__c != 'topic-guide'
            AND   Processed__c = true
        ];
        
        System.debug('=== Summary Fetch Complete ===');
        System.debug('Total articles:     ' + total);
        System.debug('Processed:          ' + processed);
        System.debug('Skipped/remaining:  ' + (total - processed));
    }
    
    // ─── HELPER: Fetch page summary from MindTouch properties endpoint ───────
    private String fetchPageSummary(String mindTouchPageId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                BASE_URL + '/pages/' + mindTouchPageId
                + '/properties?dream.out.format=json'
            );
            req.setMethod('GET');
            req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            HttpResponse res = new Http().send(req);
            
            if (res.getStatusCode() != 200) {
                System.debug('Properties fetch failed for page ' + mindTouchPageId
                             + ': ' + res.getStatusCode());
                return null;
            }
            
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            // Response can be a single property (Map) or multiple (List)
            // Find the one with @name = 'mindtouch.page#overview'
            Object propertyRaw = body.get('property');
            
            List<Object> propertyList = new List<Object>();
            if (propertyRaw instanceof List<Object>) {
                propertyList = (List<Object>) propertyRaw;
            } else if (propertyRaw instanceof Map<String, Object>) {
                // Single property returned as Map
                propertyList.add(propertyRaw);
            }
            
            for (Object p : propertyList) {
                Map<String, Object> prop = (Map<String, Object>) p;
                String propName = String.valueOf(prop.get('@name'));
                
                if (propName == 'mindtouch.page#overview') {
                    Object contentsRaw = prop.get('contents');
                    if (contentsRaw instanceof Map<String, Object>) {
                        Map<String, Object> contents =
                            (Map<String, Object>) contentsRaw;
                        String summaryText = String.valueOf(contents.get('#text'));
                        if (!String.isBlank(summaryText)
                            && summaryText != 'null') {
                                return summaryText;
                            }
                    }
                }
            }
            
            // No overview property found for this page
            return null;
            
        } catch (Exception e) {
            System.debug('Exception fetching summary for page '
                         + mindTouchPageId + ': ' + e.getMessage());
            return null;
        }
    }
}