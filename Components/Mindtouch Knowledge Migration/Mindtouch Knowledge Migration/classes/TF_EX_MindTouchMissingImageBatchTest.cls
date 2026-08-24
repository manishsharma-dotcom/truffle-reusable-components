@isTest
private class TF_EX_MindTouchMissingImageBatchTest {
    
    @TestSetup
    static void setupData() {
        //List<MindTouchPendingFile__c> pendingFiles = new List<MindTouchPendingFile__c>();
        MindTouchPendingFile__c temp = new MindTouchPendingFile__c(
            downloadURL__c = 'https://helpme.tebra.com/@api/deki/files/1234'
        );
        insert temp;
        // Create KnowledgeCategoryMap__c records (unprocessed)
        List<KnowledgeCategoryMap__c> records = new List<KnowledgeCategoryMap__c>();

        // Record with HTML content containing helpme.tebra.com link
        KnowledgeCategoryMap__c rec1 = new KnowledgeCategoryMap__c(
            Name                    = 'Test Article 1',
            Title__c                = 'Test Article 1',
            Processed__c            = false,
            TransformedHTMLContent__c =
                '<p>See <img src="https://helpme.tebra.com/@api/deki/files/1873?version"></img></p>'
        );
        records.add(rec1);

        // Record with blank HTML content
        KnowledgeCategoryMap__c rec2 = new KnowledgeCategoryMap__c(
            Name                    = 'Test Article 2',
            Title__c                = 'Test Article 2',
            Processed__c            = false,
            TransformedHTMLContent__c = ''
        );
        records.add(rec2);

        // Record with HTML content but no helpme.tebra.com links
        KnowledgeCategoryMap__c rec3 = new KnowledgeCategoryMap__c(
            Name                    = 'Test Article 3',
            Title__c                = 'Test Article 3',
            Processed__c            = false,
            TransformedHTMLContent__c = '<p>Regular content with no special links.</p>'
        );
        records.add(rec3);

        insert records;
    }
    
    @isTest
    static void insertMissingFilesTest() {
        TF_EX_MindTouchMissingImageBatch batch =
            new TF_EX_MindTouchMissingImageBatch();

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}