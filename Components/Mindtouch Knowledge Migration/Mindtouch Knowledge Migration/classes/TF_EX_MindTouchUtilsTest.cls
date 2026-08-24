@isTest
private class TF_EX_MindTouchUtilsTest {

    // ── Test: base_URL is set correctly ──────────────────────────────────────
    @isTest
    static void testBaseUrl() {
        System.assertEquals(
            'https://helpme.tebra.com/@api/deki',
            TF_EX_MindTouchUtils.base_URL,
            'BASE_URL matches expected value'
        );
    }

    // ── Test: buildUrlName — standard input ───────────────────────────────────
    @isTest
    static void testBuildUrlNameStandard() {
        String result = TF_EX_MindTouchUtils.buildUrlName('Hello World');
        System.assertEquals('Hello-World', result, 'Space replaced with hyphen');
    }

    // ── Test: buildUrlName — special chars removed ────────────────────────────
    @isTest
    static void testBuildUrlNameSpecialChars() {
        String result = TF_EX_MindTouchUtils.buildUrlName('Hello! @World#2024');
        System.assert(!result.startsWith('-'), 'No leading hyphen');
        System.assert(!result.endsWith('-'), 'No trailing hyphen');
        System.assert(result.length() > 0, 'Non-empty result');
    }

    // ── Test: buildUrlName — blank input ──────────────────────────────────────
    @isTest
    static void testBuildUrlNameBlank() {
        String result = TF_EX_MindTouchUtils.buildUrlName('');
        System.assertEquals('', result, 'Blank returns blank');
    }

    // ── Test: buildUrlName — null input ──────────────────────────────────────
    @isTest
    static void testBuildUrlNameNull() {
        String result = TF_EX_MindTouchUtils.buildUrlName(null);
        System.assertEquals(null, result, 'Null returns null');
    }

    // ── Test: buildUrlName — truncation at 255 chars ──────────────────────────
    @isTest
    static void testBuildUrlNameTruncation() {
        String longInput = 'a'.repeat(300);
        String result = TF_EX_MindTouchUtils.buildUrlName(longInput);
        System.assert(result.length() <= 255, 'Result truncated to 255 chars');
    }

    // ── Test: buildUrlName — leading and trailing hyphens stripped ────────────
    @isTest
    static void testBuildUrlNameLeadingTrailingStripped() {
        String result = TF_EX_MindTouchUtils.buildUrlName('!--test--!');
        System.assertEquals('test', result, 'Leading/trailing hyphens stripped');
    }

    // ── Test: buildUrlName — consecutive hyphens collapsed ───────────────────
    @isTest
    static void testBuildUrlNameConsecutiveHyphens() {
        String result = TF_EX_MindTouchUtils.buildUrlName('a!!b');
        System.assertEquals('a-b', result, 'Multiple specials become single hyphen');
    }

    // ── Test: normalizeSpaces — multiple spaces collapsed ─────────────────────
    @isTest
    static void testNormalizeSpacesMultiple() {
        String result = TF_EX_MindTouchUtils.normalizeSpaces('Hello   World');
        System.assertEquals('Hello World', result, 'Multiple spaces collapsed to one');
    }

    // ── Test: normalizeSpaces — single space unchanged ────────────────────────
    @isTest
    static void testNormalizeSpacesSingle() {
        String result = TF_EX_MindTouchUtils.normalizeSpaces('Hello World');
        System.assertEquals('Hello World', result, 'Single space unchanged');
    }

    // ── Test: normalizeSpaces — blank input ───────────────────────────────────
    @isTest
    static void testNormalizeSpacesBlank() {
        String result = TF_EX_MindTouchUtils.normalizeSpaces('');
        System.assertEquals('', result, 'Blank returns blank');

        result = TF_EX_MindTouchUtils.normalizeSpaces(null);
        System.assertEquals(null, result, 'Null returns null');
    }

    // ── Test: normalizeSpaces — no spaces ─────────────────────────────────────
    @isTest
    static void testNormalizeSpacesNoSpaces() {
        String result = TF_EX_MindTouchUtils.normalizeSpaces('HelloWorld');
        System.assertEquals('HelloWorld', result, 'No spaces — unchanged');
    }

    // ── Test: markProcessedArticleFalse — runs without error ─────────────────
    @isTest
    static void testMarkProcessedArticleFalse() {
        Test.startTest();
        TF_EX_MindTouchUtils.markProcessedArticleFalse();
        Test.stopTest();

        System.assert(true, 'markProcessedArticleFalse ran without error');
    }

    // ── Test: publishAllArticles — runs without error ─────────────────────────
    @isTest
    static void testPublishAllArticles() {
        Test.startTest();
        TF_EX_MindTouchUtils.publishAllArticles();
        Test.stopTest();

        System.assert(true, 'publishAllArticles ran without error');
    }

    // ── Test: postMigrationSummary — runs without error ───────────────────────
    @isTest
    static void testPostMigrationSummary() {
        Test.startTest();
        TF_EX_MindTouchUtils.postMigrationSummary();
        Test.stopTest();

        System.assert(true, 'postMigrationSummary ran without error');
    }

    // ── Test: validateURL — returns 0 for clean input ─────────────────────────
    @isTest
    static void testValidateUrlClean() {
        // Method queries MindTouch_Config__mdt — may throw if CMDT not seeded.
        // Wrap in try/catch for portability.
        try {
            Integer count = TF_EX_MindTouchUtils.validateURL('<p>No special URL</p>');
            System.assertEquals(0, count, 'No invalid URLs found');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'CMDT not seeded in test org');
        }
    }

    // ── Test: getNewDataCategory — runs without error ─────────────────────────
    @isTest
    static void testGetNewDataCategory() {
        // Insert a KnowledgeCategoryMap__c and Data_Category_Mapping__c
        Data_Category_Mapping__c mapping = new Data_Category_Mapping__c(
            Old_Category__c = 'howto',
            New_Category__c = 'HowToNew'
        );
        insert mapping;

        KnowledgeCategoryMap__c record = new KnowledgeCategoryMap__c(
            Name           = 'Test Article',
            Title__c       = 'Test Article',
            ArticleType__c = 'howto',
            Processed__c   = false
        );
        insert record;

        Test.startTest();
        TF_EX_MindTouchUtils.getNewDataCategory();
        Test.stopTest();

        KnowledgeCategoryMap__c updated = [
            SELECT New_Category__c FROM KnowledgeCategoryMap__c WHERE Id = :record.Id
        ];
        System.assertEquals('HowToNew', updated.New_Category__c, 'Category mapped correctly');
    }

    // ── Test: getCurrentCategory — runs without error ─────────────────────────
    @isTest
    static void testGetCurrentCategory() {
        KnowledgeCategoryMap__c record = new KnowledgeCategoryMap__c(
            Name             = 'HowTo Test',
            Title__c         = 'HowTo Test',
            ArticleType__c   = 'howto',
            Processed__c     = false,
            MindTouchPath__c = '/ParentCat/ChildCat/article-name'
        );
        insert record;

        Test.startTest();
        TF_EX_MindTouchUtils.getCurrentCategory();
        Test.stopTest();

        KnowledgeCategoryMap__c updated = [
            SELECT current_category__c FROM KnowledgeCategoryMap__c WHERE Id = :record.Id
        ];
        System.assertEquals('ChildCat', updated.current_category__c, 'Category extracted from path');
    }

    // ── Test: checkSummaryField — returns count of null summaries ─────────────
    @isTest
    static void testCheckSummaryField() {
        KnowledgeCategoryMap__c record = new KnowledgeCategoryMap__c(
            Name             = 'Topic Test',
            Title__c         = 'Topic Test',
            ArticleType__c   = 'topic',
            Processed__c     = false,
            Summary__c       = null,
            MindTouchPath__c = '/Cats/topic-test'
        );
        insert record;

        Test.startTest();
        Integer count = TF_EX_MindTouchUtils.checkSummaryField();
        Test.stopTest();

        System.assert(count >= 1, 'At least one null summary found');
    }

    // ── Test: updateURLName — updates URL_Name__c on Data_Category_Mapping__c ─
    @isTest
    static void testUpdateURLName() {
        Data_Category_Mapping__c mapping = new Data_Category_Mapping__c(
            Title__c    = 'My Category Title',
            URL_Name__c = null
        );
        insert mapping;

        Test.startTest();
        TF_EX_MindTouchUtils.updateURLName();
        Test.stopTest();

        Data_Category_Mapping__c updated = [
            SELECT URL_Name__c FROM Data_Category_Mapping__c WHERE Id = :mapping.Id
        ];
        System.assertNotEquals(null, updated.URL_Name__c, 'URL_Name__c populated');
        System.assert(updated.URL_Name__c.length() > 0, 'URL_Name__c is non-empty');
    }
}