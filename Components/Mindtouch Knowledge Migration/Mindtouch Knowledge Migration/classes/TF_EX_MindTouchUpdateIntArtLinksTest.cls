@isTest
private class TF_EX_MindTouchUpdateIntArtLinksTest {
    
    @TestSetup
    static void setupData() {
        MindTouch_Config__mdt metadataRecord = [SELECT id, SiteURL__c FROM MindTouch_Config__mdt WHERE SiteURL__c !=null Limit 1];
        // Create Knowledge__kav records (unprocessed)
        List<Knowledge__kav> records = new List<Knowledge__kav>();
        List<Data_Category_Mapping__c> categMapList = new List<Data_Category_Mapping__c>();

        // Record with HTML content containing helpme.tebra.com link
        Knowledge__kav rec1 = new Knowledge__kav(
            urlName                 = 'test-Article-1',
            Title                   = 'Test Article 1',
            KnowledgeContent__c    = '<a href="' + metadataRecord.siteURL__c + '/test-article-2">Test Link</a>',
            MindtouchExternalId__c  = '001'
        );
        records.add(rec1);

        // Record with blank HTML content
        Knowledge__kav rec2 = new Knowledge__kav(
            urlName                 = 'test-Article-2',
            Title                   = 'Test Article 2',
            KnowledgeContent__c    = 'Content of Article 2',
            MindtouchExternalId__c  = '002'
        );
        records.add(rec2);

        insert records;
    }

    @isTest
    static void rewriteInternalLinkTest() {
        TF_EX_MindTouchUpdateInternalArtLinks batch =
            new TF_EX_MindTouchUpdateInternalArtLinks();

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}