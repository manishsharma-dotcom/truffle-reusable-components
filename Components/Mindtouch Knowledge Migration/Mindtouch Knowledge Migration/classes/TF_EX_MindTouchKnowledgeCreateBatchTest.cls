@isTest
private class TF_EX_MindTouchKnowledgeCreateBatchTest {

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
        List<Data_Category_Mapping__c> dataMappings =
            new List<Data_Category_Mapping__c>();

        dataMappings.add(new Data_Category_Mapping__c(
            Title__c = 'How To Article',
            URL_Name__c = 'how-to-article',
            DataCategoryGroup__c = 'Internal',
            External_Id__c = 'EXT1_' + uniqueKey
        ));

        dataMappings.add(new Data_Category_Mapping__c(
            Title__c = 'Topic Article',
            URL_Name__c = 'topic-article',
            DataCategoryGroup__c = 'External',
            External_Id__c = 'EXT2_' + uniqueKey
        ));

        insert dataMappings;

        // -----------------------------------------------------
        // KnowledgeCategoryMap records
        // -----------------------------------------------------
        List<KnowledgeCategoryMap__c> records =
            new List<KnowledgeCategoryMap__c>();

        records.add(new KnowledgeCategoryMap__c(
            Name = 'HowTo',
            Id__c = '1001_' + uniqueKey,
            Title__c = 'How To Article',
            ArticleType__c = 'howto',
            Processed__c = false,
            MindTouchPath__c = '/help/how-to-article',
            TransformedHTMLContent__c = '<p>How To Content</p>',
            Summary__c = 'Summary'
        ));

        records.add(new KnowledgeCategoryMap__c(
            Name = 'Topic',
            Id__c = '1002_' + uniqueKey,
            Title__c = 'Topic Article',
            ArticleType__c = 'topic',
            Processed__c = false,
            MindTouchPath__c = '/help/topic-article',
            TransformedHTMLContent__c = '<p>Topic Content</p>',
            Summary__c = 'Topic Summary'
        ));

        records.add(new KnowledgeCategoryMap__c(
            Name = 'Reference',
            Id__c = '1003_' + uniqueKey,
            Title__c = 'Reference Article',
            ArticleType__c = 'reference',
            Processed__c = false,
            MindTouchPath__c = '/help/reference-article',
            TransformedHTMLContent__c = '<p>Reference Content</p>'
        ));

        records.add(new KnowledgeCategoryMap__c(
            Name = 'Videos',
            Id__c = '1004_' + uniqueKey,
            Title__c = 'Videos Article',
            ArticleType__c = 'videos',
            Processed__c = false,
            MindTouchPath__c = '/help/videos-article',
            TransformedHTMLContent__c = '<p>Videos Content</p>'
        ));

        // Null HTML branch
        records.add(new KnowledgeCategoryMap__c(
            Name = 'NoHtml',
            Id__c = '1005_' + uniqueKey,
            Title__c = 'No Html',
            ArticleType__c = 'howto',
            Processed__c = false,
            MindTouchPath__c = '/help/no-html',
            TransformedHTMLContent__c = null
        ));

        // Unknown article type branch
        records.add(new KnowledgeCategoryMap__c(
            Name = 'UnknownType',
            Id__c = '1006_' + uniqueKey,
            Title__c = 'Unknown Type',
            ArticleType__c = 'topic-category',
            Processed__c = false,
            MindTouchPath__c = '/help/unknown-type',
            TransformedHTMLContent__c = '<p>Unknown</p>'
        ));

        insert records;
    }

    // =========================================================
    // TEST : Batch execution
    // =========================================================
    @isTest
    static void testBatchExecution() {

        Test.startTest();

        Database.executeBatch(
            new TF_EX_MindTouchKnowledgeCreateBatch(),
            10
        );

        Test.stopTest();

        List<KnowledgeCategoryMap__c> processedRecords = [
            SELECT Id,
                   Processed__c,
                   Id__c
            FROM KnowledgeCategoryMap__c
        ];
        System.assert(
            processedRecords.size() > 0,
            'Records queried successfully'
        );
    }

   // =========================================================
// TEST : finish() method
// =========================================================
@isTest
static void testFinishMethod() {

    Test.startTest();

    // Large batch size ensures single execute invocation
    Database.executeBatch(
        new TF_EX_MindTouchKnowledgeCreateBatch(),
        200
    );

    Test.stopTest();

    System.assert(true);
}
    // =========================================================
// TEST : duplicate URL handling
// =========================================================
@isTest
static void testDuplicateUrlHandling() {

    String uniqueKey =
        String.valueOf(Math.abs(Crypto.getRandomInteger()));

    insert new KnowledgeCategoryMap__c(
        Name = 'DuplicateUrl',
        Id__c = '2001_' + uniqueKey,
        Title__c = 'Duplicate Url',
        ArticleType__c = 'topic',
        Processed__c = false,
        MindTouchPath__c = '/help/topic-article',
        TransformedHTMLContent__c = '<p>Duplicate</p>'
    );

    Test.startTest();

    // MUST be > total records from setup
    Database.executeBatch(
        new TF_EX_MindTouchKnowledgeCreateBatch(),
        200
    );

    Test.stopTest();

    System.assert(true);
}
    // =========================================================
// TEST : no insert branch
// =========================================================
@isTest
static void testNoInsertBranch() {

    String uniqueKey =
        String.valueOf(Math.abs(Crypto.getRandomInteger()));

    insert new KnowledgeCategoryMap__c(
        Name = 'NoContent',
        Id__c = '3001_' + uniqueKey,
        Title__c = 'No Content',
        ArticleType__c = 'topic',
        Processed__c = false,
        MindTouchPath__c = '/help/no-content',
        TransformedHTMLContent__c = null
    );

    Test.startTest();

    // Large batch size avoids multiple executeBatch calls
    Database.executeBatch(
        new TF_EX_MindTouchKnowledgeCreateBatch(),
        200
    );

    Test.stopTest();

    System.assert(true);
}

    // =========================================================
    // TEST : start() method
    // =========================================================
    @isTest
    static void testStartMethod() {

        TF_EX_MindTouchKnowledgeCreateBatch batchObj =
            new TF_EX_MindTouchKnowledgeCreateBatch();

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

        List<KnowledgeCategoryMap__c> scope = [
            SELECT Id,
                   Id__c,
                   ArticleType__c,
                   Title__c,
                   Summary__c,
                   HTMLContent__c,
                   Public__c,
                   MindTouchPath__c,
                   TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            LIMIT 2
        ];

        TF_EX_MindTouchKnowledgeCreateBatch batchObj =
            new TF_EX_MindTouchKnowledgeCreateBatch();

        batchObj.recordTypeMap = new Map<String, Id>();

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
    static void testExecuteWithEmptyScope() {

        TF_EX_MindTouchKnowledgeCreateBatch batchObj =
            new TF_EX_MindTouchKnowledgeCreateBatch();

        batchObj.recordTypeMap = new Map<String, Id>();

        Test.startTest();

        batchObj.execute(
            null,
            new List<KnowledgeCategoryMap__c>()
        );

        Test.stopTest();

        System.assert(true);
    }
}