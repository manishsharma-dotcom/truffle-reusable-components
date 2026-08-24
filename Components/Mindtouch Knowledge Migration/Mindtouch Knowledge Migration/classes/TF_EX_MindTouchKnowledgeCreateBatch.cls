public class TF_EX_MindTouchKnowledgeCreateBatch
    implements Database.Batchable<SObject>, Database.Stateful  {

    public Map<String, Id> recordTypeMap;

    // ─── START ────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {

        // Load Record Type Ids once
        recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Knowledge__kav'
            AND DeveloperName IN ('Topic', 'HowTo','Reference','Videos')
        ]) {
            recordTypeMap.put(rt.DeveloperName.tolowercase(), rt.Id);
            System.debug('RecordType loaded: ' + rt.DeveloperName + ' → ' + rt.Id);
        }
        
        return Database.getQueryLocator([
            SELECT Id, Id__c, ArticleType__c, Title__c,Summary__c,
                   HTMLContent__c, Public__c,MindTouchPath__c,TransformedHTMLContent__c,
                   Parent__c,
                   Parent__r.Title__c,
                   Parent__r.Parent__r.Title__c,
                   Parent__r.Parent__r.Parent__r.Title__c,
                   Parent__r.Parent__r.Parent__r.Parent__r.Title__c,
                   Parent__r.Parent__r.Parent__r.Parent__r.Parent__r.Title__c
            FROM KnowledgeCategoryMap__c
            WHERE Processed__c = false
        ]);
        
    }

    // ─── EXECUTE ──────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {
        
        List<Data_Category_Mapping__c> dataCategMap = [select id,Title__c, URL_Name__c, DataCategoryGroup__c,New_Category__c,External_Id__c  from Data_Category_Mapping__c];
        Map<String,Data_Category_Mapping__c> urlNameToDataCategRec = new Map<String,Data_Category_Mapping__c>();
        for(Data_Category_Mapping__c each : dataCategMap){
            urlNameToDataCategRec.put(each.External_Id__c,each);
        }
        // Build used UrlNames to avoid duplicates
        Set<String> usedUrlNames = new Set<String>();
        for (Knowledge__kav existing : [SELECT UrlName FROM Knowledge__kav]) {
            usedUrlNames.add(existing.UrlName.toLowerCase());
        }

        List<Knowledge__kav>  toInsert     = new List<Knowledge__kav>();
        // Track index → immediate parent title for category assignment after insert
        Map<Integer, String>  idxToImmediateParent = new Map<Integer, String>();
        Integer idx = 0;
        system.debug('___recordTypeMap___' + recordTypeMap);
        for (KnowledgeCategoryMap__c rec : scope) {
            system.debug('___ArticleType__' + rec.ArticleType__c);
            // ── Record Type ───────────────────────────────────────────────────
            //String rtName = (rec.ArticleType__c == 'howto') ? 'How_To' : 'Topic';
            Id recordTypeId;
            if(rec.ArticleType__c != null && rec.ArticleType__c.contains('topic')){
               if(recordTypeMap != null && recordTypeMap.containsKey('topic')){
                   recordTypeId = recordTypeMap.get('topic');
               } 
            }else if(rec.ArticleType__c != null && rec.ArticleType__c.contains('howto')){
               if(recordTypeMap != null && recordTypeMap.containsKey('howto')){
                   recordTypeId = recordTypeMap.get('howto');
               } 
            }else if(rec.ArticleType__c != null && rec.ArticleType__c.contains('reference')){
               if(recordTypeMap != null && recordTypeMap.containsKey('reference')){
                   recordTypeId = recordTypeMap.get('reference');
               } 
            }else if(rec.ArticleType__c != null && rec.ArticleType__c.contains('videos')){
               if(recordTypeMap != null && recordTypeMap.containsKey('videos')){
                   recordTypeId = recordTypeMap.get('videos');
               } 
            }
            system.debug('___recordTypeId___' + recordTypeId);

            // ── UrlName ───────────────────────────────────────────────────────
            String urlName = rec.MindTouchPath__c.subStringAfterLast('/');
            if(urlName != null && urlName != ''){
                urlName = urlName;
            }else{
                urlName = rec.MindTouchPath__c;
            }
            urlName = buildUrlName(urlName, usedUrlNames);
            usedUrlNames.add(urlName);

            // ── IsVisibleIncsp driven by data category group ────────────────────────────
            Boolean visibleInCsp = false;
            if(urlNameToDataCategRec != null && !urlNameToDataCategRec.isEmpty() && urlNameToDataCategRec.containsKey(rec.Id__c)){
                String type = urlNameToDataCategRec.get(rec.Id__c).DataCategoryGroup__c;
                if(type == 'Internal'){
                    visibleInCsp = false;
                }else{
                    visibleInCsp = true;
                }
            }
            

            // ── Immediate parent title → used as DataCategoryName ─────────────
            
                

            // ── Build article ─────────────────────────────────────────────────
            if(rec.TransformedHTMLContent__c != null && rec.TransformedHTMLContent__c != ''){
                Knowledge__kav article = new Knowledge__kav(
                    Title               = rec.Title__c.left(255),
                    UrlName             = urlName,
                    summary             = rec.Summary__c,
                    KnowledgeContent__c = rec.TransformedHTMLContent__c,
                    Language            = 'en_US',                
                    IsVisibleInCsp      = visibleInCsp,
                    IsVisibleInPkb      = false,
                    //recordtypeid        = recordTypeId,
                    MindtouchExternalId__c = rec.Id__c
                );
    
                if (recordTypeId != null) {
                    article.RecordTypeId = recordTypeId;
                }
    
                toInsert.add(article);
            }
        }

        if (toInsert.isEmpty()) return;

        // ── Insert articles ───────────────────────────────────────────────────
        Database.SaveResult[] results = Database.insert(toInsert, false);

        // ── Collect successfully inserted Ids ─────────────────────────────────
        List<String> KBIds = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                KBIds.add(String.valueOf(results[i].getId()));
                System.debug('Inserted: ' + toInsert[i].Title
                    + ' → ' + results[i].getId());
            } else {
                System.debug('FAILED: ' + toInsert[i].Title
                    + ' | ' + results[i].getErrors()[0].getMessage());
            }
        }
        List<Knowledge__kav> articles = [SELECT id,MindtouchExternalId__c FROM Knowledge__kav WHERE Id IN :KBIds];
        for(Knowledge__kav each : articles){
            KnowledgeCategoryMap__c temp = new KnowledgeCategoryMap__c(Id__c=each.MindtouchExternalId__c,processed__c = true);
            upsert temp Id__c;
        }
        
    }

    // ─── FINISH ───────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        Integer total = [
            SELECT COUNT() FROM Knowledge__kav
            WHERE PublishStatus = 'Draft'
        ];
        System.debug('=== Knowledge Article Creation Complete ===');
        System.debug('Total draft articles in org: ' + total);
        System.debug('Next step: Run publish batch');
    }
    
    // ─── HELPER: Build clean unique UrlName ───────────────────────────────────
    // Salesforce UrlName: alphanumeric + hyphens only, max 255 chars
    private String buildUrlName(String title, Set<String> usedNames) {
        String slug = TF_EX_MindTouchUtils.buildUrlName(title);

        String  base    = slug;
        Integer counter = 1;
        while (usedNames.contains(slug.toLowerCase())) {
            counter++;
            slug = base + '-' + counter;
        }
        return slug;
    }
}