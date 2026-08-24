@isTest
private class TF_EX_KnowledgeCategAssignmentBatchTest {
    
    @TestSetup
    static void setupData() {
        // Create KnowledgeCategoryMap__c records (unprocessed)
        List<Knowledge__kav> records = new List<Knowledge__kav>();
        List<Data_Category_Mapping__c> categMapList = new List<Data_Category_Mapping__c>();

        // Record with HTML content containing helpme.tebra.com link
        Knowledge__kav rec1 = new Knowledge__kav(
            urlName                 = 'test-Article-1',
            Title                   = 'Test Article 1',
            KnowledgeContent__c    = 'Content of Article 1',
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
        
        Data_Category_Mapping__c categMap = new Data_Category_Mapping__c(
            External_Id__c = '001',
            DataCategoryGroup__c = 'External',
            New_Category__c = 'All'
        );
        categMapList.add(categMap);
        
        Data_Category_Mapping__c categMap1 = new Data_Category_Mapping__c(
            External_Id__c = '002',
            DataCategoryGroup__c = 'External',
            New_Category__c = 'All'
        );
        categMapList.add(categMap1);
        
        insert records;
        insert categMapList;
    }
    @isTest
    static void testDataCategAssignment() {
        TF_EX_KnowledgeCategoryAssignmentBatch batch =
            new TF_EX_KnowledgeCategoryAssignmentBatch();

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
    @isTest
    static void testDataCategAssignmentWithTitle() {
        TF_EX_KnowledgeCategoryAssignmentBatch batch =
            new TF_EX_KnowledgeCategoryAssignmentBatch('Article');

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}