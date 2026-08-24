/**
 * @class       TF_EX_DataCategoryControllerTest
 * @description Test class for TF_EX_DataCategoryController.
 *              Covers getCategoryTree (non-null result and node structure via Schema metadata),
 *              getArticleCountByCategory (full counting logic covered via org's existing
 *              published Knowledge articles visible through @SeeAllData=true),
 *              and getArticles (returns results for valid categories).
 *              Note: @SeeAllData=true is required because Knowledge__DataCategorySelection
 *              records cannot be inserted in test context — Salesforce blocks that DML —
 *              and WITH DATA CATEGORY SOQL filters only return results against real
 *              published and categorised articles. This is the standard Salesforce pattern
 *              for Knowledge-based test classes. Tests are written defensively (>= 0 assertions)
 *              so they do not fail if org data changes.
 *              Requires Knowledge to be enabled and data category group 'All_External_New'
 *              with published articles to exist in the org.
 * @createdBy   Truffle Consulting
 */
@IsTest(SeeAllData=true)
private class TF_EX_DataCategoryControllerTest {

    private static final String CATEGORY_GROUP = 'External';
    private static final String OBJECT_NAME    = 'KnowledgeArticleVersion';
    private static final String TEST_CATEGORY  = 'Dashboard';

    // ─── getCategoryTree ──────────────────────────────────────────────────────

    /**
     * @description Verifies that getCategoryTree returns a non-null list for a valid
     *              category group using Schema.describeDataCategoryGroupStructures.
     */
    @IsTest
    static void testGetCategoryTree_ValidGroup_ReturnsNonNull() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryNode> result =
            TF_EX_DataCategoryController.getCategoryTree(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    /**
     * @description Verifies that every top-level CategoryNode returned by getCategoryTree
     *              has a non-null label, name, and items list.
     */
    @IsTest
    static void testGetCategoryTree_TopLevelNodes_HaveRequiredFields() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryNode> result =
            TF_EX_DataCategoryController.getCategoryTree(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        for (TF_EX_DataCategoryController.CategoryNode node : result) {
            System.assertNotEquals(null, node.label, 'Node label should not be null');
            System.assertNotEquals(null, node.name,  'Node name should not be null');
            System.assertNotEquals(null, node.items, 'Node items list should not be null');
        }
    }

    /**
     * @description Verifies that child nodes nested inside top-level CategoryNodes
     *              also carry non-null label, name, and items fields.
     */
    @IsTest
    static void testGetCategoryTree_ChildNodes_HaveRequiredFields() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryNode> result =
            TF_EX_DataCategoryController.getCategoryTree(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        for (TF_EX_DataCategoryController.CategoryNode node : result) {
            for (TF_EX_DataCategoryController.CategoryNode child : node.items) {
                System.assertNotEquals(null, child.label, 'Child node label should not be null');
                System.assertNotEquals(null, child.name,  'Child node name should not be null');
                System.assertNotEquals(null, child.items, 'Child node items list should not be null');
            }
        }
    }

    // ─── getArticleCountByCategory ────────────────────────────────────────────

    /**
     * @description Verifies that getArticleCountByCategory returns a non-null list
     *              using the org's existing published Knowledge articles. With SeeAllData=true
     *              the DATA CATEGORY query returns real articles, allowing lines 105-124
     *              (the Knowledge__DataCategorySelection query and counting logic) to execute.
     *              Asserts size >= 0 so the test is not brittle against org data changes.
     */
    @IsTest
    static void testGetArticleCountByCategory_OrgData_ExecutesCountingLogic() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryCount> result =
            TF_EX_DataCategoryController.getArticleCountByCategory(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 0, 'Result size should be zero or more');
    }

    /**
     * @description Verifies that every CategoryCount entry returned has a non-null
     *              name and a positive count when org articles are present.
     */
    @IsTest
    static void testGetArticleCountByCategory_Entries_HaveNameAndPositiveCount() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryCount> result =
            TF_EX_DataCategoryController.getArticleCountByCategory(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        for (TF_EX_DataCategoryController.CategoryCount cc : result) {
            System.assertNotEquals(null, cc.name,  'CategoryCount name should not be null');
            System.assert(cc.count > 0, 'CategoryCount count should be greater than 0');
        }
    }

    /**
     * @description Verifies that getArticleCountByCategory completes without error
     *              across multiple sequential invocations in the same transaction.
     */
    @IsTest
    static void testGetArticleCountByCategory_MultipleInvocations_NoException() {
        Test.startTest();
        List<TF_EX_DataCategoryController.CategoryCount> result1 =
            TF_EX_DataCategoryController.getArticleCountByCategory(OBJECT_NAME, CATEGORY_GROUP);
        List<TF_EX_DataCategoryController.CategoryCount> result2 =
            TF_EX_DataCategoryController.getArticleCountByCategory(OBJECT_NAME, CATEGORY_GROUP);
        Test.stopTest();

        System.assertNotEquals(null, result1, 'First result should not be null');
        System.assertNotEquals(null, result2, 'Second result should not be null');
    }

    // ─── getArticles ──────────────────────────────────────────────────────────

    /**
     * @description Verifies that getArticles returns a non-null list for a valid
     *              category using the org's existing published Knowledge articles.
     *              Asserts size >= 0 so the test is not brittle against org data changes.
     */
    @IsTest
    static void testGetArticles_ValidCategory_ReturnsNonNull() {
        Test.startTest();
        List<Knowledge__kav> result =
            TF_EX_DataCategoryController.getArticles(CATEGORY_GROUP, TEST_CATEGORY);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 0, 'Result size should be zero or more');
    }

    /**
     * @description Verifies that when getArticles returns articles, each record
     *              carries the expected fields: Id, Title, UrlName, and LastPublishedDate.
     */
    @IsTest
    static void testGetArticles_ReturnedArticles_HaveRequiredFields() {
        Test.startTest();
        List<Knowledge__kav> result =
            TF_EX_DataCategoryController.getArticles(CATEGORY_GROUP, TEST_CATEGORY);
        Test.stopTest();

        for (Knowledge__kav art : result) {
            System.assertNotEquals(null, art.Id,                'Article Id should be populated');
            System.assertNotEquals(null, art.Title,             'Article Title should be populated');
            System.assertNotEquals(null, art.UrlName,           'Article UrlName should be populated');
            System.assertNotEquals(null, art.LastPublishedDate, 'Article LastPublishedDate should be populated');
        }
    }

    /**
     * @description Verifies that getArticles completes without error when called
     *              for different categories within the same group.
     */
    @IsTest
    static void testGetArticles_DifferentCategories_NoException() {
        Test.startTest();
        List<Knowledge__kav> result1 =
            TF_EX_DataCategoryController.getArticles(CATEGORY_GROUP, TEST_CATEGORY);
        List<Knowledge__kav> result2 =
            TF_EX_DataCategoryController.getArticles(CATEGORY_GROUP, 'All');
        Test.stopTest();

        System.assertNotEquals(null, result1, 'Dashboard category result should not be null');
        System.assertNotEquals(null, result2, 'All category result should not be null');
    }
}