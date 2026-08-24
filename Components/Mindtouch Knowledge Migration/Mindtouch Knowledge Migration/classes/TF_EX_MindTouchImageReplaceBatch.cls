public class TF_EX_MindTouchImageReplaceBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    // ── CHANGED: no longer build map in constructor
    // Map is built lazily on first execute() call inside the batch transaction
    // Database.Stateful keeps it across all execute() calls — built only once
    private Map<String, String> urlMap;

    public TF_EX_MindTouchImageReplaceBatch() {
        // Constructor is intentionally empty — map built in execute()
        // This avoids hitting CPU limit in the Anonymous Apex context
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        
       return Database.getQueryLocator([
            SELECT Id,Id__c, Title__c, HTMLContent__c, TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            WHERE processed__c = false
        ]);
        
    }

    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {

        // Build map once on first execute() — runs inside batch (60s CPU limit, not 10s)
        // Database.Stateful keeps it populated for all subsequent execute() calls
        
        if (urlMap == null) {
            urlMap = TF_EX_MindTouchImageUrlReplacer.buildFilenameToPublicUrlMap();
            System.debug('Map built with ' + urlMap.size() + ' images');
        }

        List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();

        for (KnowledgeCategoryMap__c record : scope) {
            record.processed__c = true;
            if (String.isBlank(record.TransformedHTMLContent__c)) {
                System.debug('Skipping (no content): ' + record.Title__c);
                continue;
            }
            if (!record.TransformedHTMLContent__c.contains('@api/deki/files/')) {
                System.debug('Skipping (no MindTouch URLs): ' + record.Title__c);
                continue;
            }

            String original = record.TransformedHTMLContent__c;
            String updated  = TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                original, urlMap
            );

            if (updated != original) {
                record.TransformedHTMLContent__c = updated;
                toUpdate.add(record);
                System.debug('Updated: ' + record.Title__c);
            } else {
                System.debug('No changes: ' + record.Title__c);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('Saved ' + toUpdate.size() + ' records');
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        
        List<KnowledgeCategoryMap__c> all = [
            SELECT Id, Title__c, HTMLContent__c, TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            WHERE ArticleType__c != 'topic-category'
            AND   ArticleType__c != 'topic-guide'
        ];
        Integer replaced  = 0;
        Integer remaining = 0;
        Integer noContent = 0;
        for (KnowledgeCategoryMap__c r : all) {
            if (String.isBlank(r.HTMLContent__c)) {
                noContent++;
            } else if (!String.isBlank(r.TransformedHTMLContent__c)
                       && r.TransformedHTMLContent__c.contains('@api/deki/files/')) {
                remaining++;
                System.debug('Still has MindTouch URL: ' + r.Title__c);
            } else {
                replaced++;
            }
        }
        System.debug('=== Image Replacement Complete ===');
        System.debug('Successfully replaced:     ' + replaced);
        System.debug('Still have MindTouch URLs: ' + remaining);
        System.debug('No content (skipped):      ' + noContent);
        if (remaining > 0) {
            System.debug('ACTION: Upload missing images then re-run');
        } else {
            System.debug('All MindTouch image URLs replaced successfully');
        }
        
    }
}