/**
 * @class       TF_EX_DataCategoryController
 * @testClass   TF_EX_DataCategoryControllerTest
 * @createdBy   Truffle Consulting
 * @description Apex controller for data category navigation LWCs used in Experience Cloud.
 *              Provides three read operations against Salesforce Knowledge:
 *                - Full category tree retrieval via Schema.describeDataCategoryGroupStructures
 *                - Article count per category using two bulk SOQLs (no per-category queries)
 *                - Article list for a selected category using the BELOW scope operator
 *              Declared without sharing to allow community users to access Knowledge
 *              category metadata regardless of record-level access.
 */
public with sharing class TF_EX_DataCategoryController {

    /**
     * @description Retrieves the full category tree for the given object and category group
     *              using Schema.describeDataCategoryGroupStructures. The root 'All' node is
     *              skipped — its direct children are returned as the top-level nodes so the
     *              LWC does not render a redundant root entry.
     * @param       objectName     API name of the SObject (e.g. 'KnowledgeArticleVersion').
     * @param       categoryGroup  API name of the data category group (e.g. 'All_External_New').
     * @return      List<CategoryNode> — recursive tree of label, name, and child items.
     */
    @AuraEnabled(cacheable=true)
    public static List<CategoryNode> getCategoryTree(String objectName, String categoryGroup) {
        List<CategoryNode> results = new List<CategoryNode>();

        List<DataCategoryGroupSobjectTypePair> pairs = new List<DataCategoryGroupSobjectTypePair>();
        DataCategoryGroupSobjectTypePair pair = new DataCategoryGroupSobjectTypePair();
        pair.setSobject(objectName);
        pair.setDataCategoryGroupName(categoryGroup);
        pairs.add(pair);

        List<Schema.DescribeDataCategoryGroupStructureResult> listResults =
            Schema.describeDataCategoryGroupStructures(pairs, false);

        for (Schema.DescribeDataCategoryGroupStructureResult each : listResults) {
            for (DataCategory node : each.getTopCategories()) {
                if (node.getName().equalsIgnoreCase('All')) {
                    for (DataCategory child : node.getChildCategories()) {
                        results.add(buildNode(child));
                    }
                } else {
                    results.add(buildNode(node));
                }
            }
        }
        return results;
    }

    /**
     * @description Recursively builds a CategoryNode from a DataCategory,
     *              populating label, name, and nested child items.
     * @param       dc  The DataCategory instance to convert.
     * @return      CategoryNode — populated node with all descendants.
     */
    private static CategoryNode buildNode(DataCategory dc) {
        CategoryNode node = new CategoryNode();
        node.label = dc.getLabel();
        node.name  = dc.getName();
        node.items = new List<CategoryNode>();
        for (DataCategory child : dc.getChildCategories()) {
            node.items.add(buildNode(child));
        }
        return node;
    }

    /**
     * @description Returns the article count per data category for all published Knowledge
     *              articles in the given category group. Uses exactly two SOQLs regardless
     *              of the number of categories: one to retrieve all matching article IDs
     *              using BELOW All__c scope, and one to fetch their DataCategorySelection
     *              records. Counts are tallied in memory from the selection records.
     * @param       objectName     API name of the SObject (unused in query but kept for
     *                             interface consistency with getCategoryTree).
     * @param       categoryGroup  API name of the data category group (e.g. 'All_External_New').
     *                             Appended with '__c' to form the SOQL DATA CATEGORY group name.
     * @return      List<CategoryCount> — each entry contains a category API name and its article count.
     *                                    Returns an empty list if no published articles are found.
     */
    @AuraEnabled(cacheable=true)
    public static List<CategoryCount> getArticleCountByCategory(
        String objectName,
        String categoryGroup
    ) {
        String grpSuffix = categoryGroup + '__c';
        String allCat    = 'All__c';

        List<Knowledge__kav> articles = Database.query(
            'SELECT Id FROM Knowledge__kav ' +
            'WHERE PublishStatus = \'Online\' ' +            
            'WITH DATA CATEGORY ' + grpSuffix + ' BELOW ' + allCat
        );

        Set<Id> articleIds = new Set<Id>();
        for (Knowledge__kav art : articles) {
            articleIds.add(art.Id);
        }

        if (articleIds.isEmpty()) {
            return new List<CategoryCount>();
        }

        List<Knowledge__DataCategorySelection> selections = [
            SELECT ParentId, DataCategoryName
            FROM Knowledge__DataCategorySelection
            WHERE ParentId IN :articleIds
        ];

        Map<String, Integer> countMap = new Map<String, Integer>();
        for (Knowledge__DataCategorySelection sel : selections) {
            String catName = sel.DataCategoryName;
            countMap.put(catName, (countMap.get(catName) ?? 0) + 1);
        }

        List<CategoryCount> results = new List<CategoryCount>();
        for (String name : countMap.keySet()) {
            CategoryCount cc = new CategoryCount();
            cc.name  = name;
            cc.count = countMap.get(name);
            results.add(cc);
        }
        return results;
    }

    /**
     * @description Returns all published Knowledge articles assigned to the given category
     *              or any of its descendants (BELOW scope). Results are ordered by Title ascending.
     * @param       groupName   API name of the data category group (e.g. 'All_External_New').
     *                          Appended with '__c' to form the SOQL DATA CATEGORY group name.
     * @param       categName   API name of the data category (e.g. 'Dashboard').
     *                          Appended with '__c' to form the SOQL DATA CATEGORY value.
     * @return      List<Knowledge__kav> — published articles with Id, Title, UrlName,
     *                                     Summary, and LastPublishedDate.
     */
    @AuraEnabled
    public static List<Knowledge__kav> getArticles(String groupName, String categName) {
        String grp = groupName + '__c';
        String cat = categName + '__c';
        String query =
            'SELECT Id, Title, UrlName, Summary, LastPublishedDate ' +
            'FROM Knowledge__kav ' +
            'WHERE PublishStatus = \'Online\' ' +            
            'WITH DATA CATEGORY ' + grp + ' BELOW ' + cat +
            ' ORDER BY Title ASC';
        return Database.query(query);
    }

    /**
     * @description Recursive tree node returned by getCategoryTree.
     *              Represents a single data category with its display label,
     *              API name, and ordered list of child nodes.
     */
    public class CategoryNode {
        @AuraEnabled public String             label;
        @AuraEnabled public String             name;
        @AuraEnabled public List<CategoryNode> items;
    }

    /**
     * @description Result entry returned by getArticleCountByCategory.
     *              Contains the data category API name and the number of
     *              published articles assigned to that category.
     */
    public class CategoryCount {
        @AuraEnabled public String  name;
        @AuraEnabled public Integer count;
    }
}