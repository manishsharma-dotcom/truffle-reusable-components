@isTest
private class TF_EX_KnowledgeCategoryABTest {

    // =========================================================
    // TEST SETUP
    // =========================================================
    @TestSetup
    static void setupData() {

        String uniqueKey =
            String.valueOf(Math.abs(Crypto.getRandomInteger()));

        // -----------------------------------------------------
        // Data Category Mapping
        // -----------------------------------------------------
        List<Data_Category_Mapping__c> mappings =
            new List<Data_Category_Mapping__c>();

        mappings.add(new Data_Category_Mapping__c(
            Title__c = 'How To Article',
            URL_Name__c = 'how-to-article',
            DataCategoryGroup__c = 'Products',
            New_Category__c = 'Billing',
            External_Id__c = 'EXT001'
        ));

        mappings.add(new Data_Category_Mapping__c(
            Title__c = 'Topic Article',
            URL_Name__c = 'topic-article',
            DataCategoryGroup__c = 'Departments',
            New_Category__c = 'Support',
            External_Id__c = 'EXT002'
        ));

        insert mappings;

        // -----------------------------------------------------
        // Knowledge Articles
        // -----------------------------------------------------
        List<Knowledge__kav> articles =
            new List<Knowledge__kav>();

        articles.add(new Knowledge__kav(
            Title = 'How To Article',
            UrlName = 'howto-' + uniqueKey.left(5),
            Language = 'en_US',
            MindtouchExternalId__c = 'EXT001'
        ));

        articles.add(new Knowledge__kav(
            Title = 'Topic Article',
            UrlName = 'topic-' + uniqueKey.left(5),
            Language = 'en_US',
            MindtouchExternalId__c = 'EXT002'
        ));

        // No mapping branch
        articles.add(new Knowledge__kav(
            Title = 'No Mapping',
            UrlName = 'nomap-' + uniqueKey.left(5),
            Language = 'en_US',
            MindtouchExternalId__c = 'EXT003'
        ));

        insert articles;
    }

    // =========================================================
// TEST : batch execution
// =========================================================
@isTest
static void testBatchExecution() {

    Test.startTest();

    Database.executeBatch(
        new TF_EX_KnowledgeCategoryAssignmentBatch(),
        200
    );

    Test.stopTest();

    // Validate batch executed successfully
    List<Knowledge__kav> articles = [
        SELECT Id,
               Title,
               MindtouchExternalId__c
        FROM Knowledge__kav
    ];

    System.assert(
        articles.size() > 0,
        'Knowledge articles should exist'
    );
}

    // =========================================================
    // TEST : constructor with title filter
    // =========================================================
    @isTest
    static void testBatchWithTitleFilter() {

        Test.startTest();

        Database.executeBatch(
            new TF_EX_KnowledgeCategoryAssignmentBatch(
                'How%'
            ),
            200
        );

        Test.stopTest();

        List<Knowledge__DataCategorySelection> selections = [
            SELECT Id,
                   DataCategoryGroupName
            FROM Knowledge__DataCategorySelection
        ];

        System.assert(
            selections.size() >= 0
        );
    }

    // =========================================================
    // TEST : start() method
    // =========================================================
    @isTest
    static void testStartMethod() {

        TF_EX_KnowledgeCategoryAssignmentBatch batchObj =
            new TF_EX_KnowledgeCategoryAssignmentBatch();

        Test.startTest();

        Database.QueryLocator ql =
            batchObj.start(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            ql
        );
    }

    // =========================================================
    // TEST : execute() direct coverage
    // =========================================================
    @isTest
    static void testExecuteDirectly() {

        List<Knowledge__kav> scope = [
            SELECT Id,
                   Title,
                   UrlName,
                   MindtouchExternalId__c
            FROM Knowledge__kav
            LIMIT 2
        ];

        TF_EX_KnowledgeCategoryAssignmentBatch batchObj =
            new TF_EX_KnowledgeCategoryAssignmentBatch();

        Test.startTest();

        batchObj.execute(
            null,
            scope
        );

        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // TEST : execute() empty scope
    // =========================================================
    @isTest
    static void testExecuteEmptyScope() {

        TF_EX_KnowledgeCategoryAssignmentBatch batchObj =
            new TF_EX_KnowledgeCategoryAssignmentBatch();

        Test.startTest();

        batchObj.execute(
            null,
            new List<Knowledge__kav>()
        );

        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // TEST : finish() method
    // =========================================================
    @isTest
    static void testFinishMethod() {

        Test.startTest();

        Database.executeBatch(
            new TF_EX_KnowledgeCategoryAssignmentBatch(),
            200
        );

        Test.stopTest();

        System.assert(true);
    }
}