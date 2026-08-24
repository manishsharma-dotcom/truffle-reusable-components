/**
 * TF_EX_KnowledgeCategoryAssignmentBatch
 * 
 * Assigns Data Categories to Draft Knowledge Articles based on
 * Data_Category_Mapping__c records. Matches articles using both
 * Title and UrlName to handle duplicate titles correctly.
 *
 * HOW TO RUN:
 *   Database.executeBatch(new KnowledgeCategoryAssignmentBatch(), 50);
 *
 * HOW TO RUN WITH SPECIFIC ARTICLE TITLES (optional filter):
 *   Database.executeBatch(new KnowledgeCategoryAssignmentBatch('Training%'), 50);
 */
public class TF_EX_KnowledgeCategoryAssignmentBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Optional LIKE filter on Title to process a subset
    private String titleFilter;

    // Counters for summary logging
    private Integer totalProcessed = 0;
    private Integer totalAssigned  = 0;
    private Integer totalSkipped   = 0;
    private List<String> errors    = new List<String>();

    // ── Constructors ─────────────────────────────────────────────────
    public TF_EX_KnowledgeCategoryAssignmentBatch() {
        this.titleFilter = null;
    }

    public TF_EX_KnowledgeCategoryAssignmentBatch(String titleFilter) {
        this.titleFilter = titleFilter;
    }

    // ── Start: query all Draft Knowledge Articles ─────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query =
            'SELECT Id, Title, UrlName, KnowledgeArticleId,MindtouchExternalId__c ' +
            'FROM Knowledge__kav ' +
            'WHERE PublishStatus = \'Draft\' ' +
            'AND Language = \'en_US\' AND (CreatedBy.name = \'Nipun Garg\' OR CreatedBy.name = \'Veeranch Srivastava\')';
            //CreatedDate = TODAY';

        if (String.isNotBlank(titleFilter)) {
            query += ' AND Title LIKE \'' + String.escapeSingleQuotes(titleFilter) + '\'';
        }

        return Database.getQueryLocator(query);
    }

    // ── Execute: assign categories per batch ──────────────────────────
    public void execute(Database.BatchableContext bc, List<Knowledge__kav> articles) {
        // Build list of category selections to insert
        List<Knowledge__DataCategorySelection> toInsert = new List<Knowledge__DataCategorySelection>();

        List<Data_Category_Mapping__c> dataCategMap = [select id,Title__c, URL_Name__c, DataCategoryGroup__c,New_Category__c,External_Id__c  from Data_Category_Mapping__c];
        Map<String,Data_Category_Mapping__c> externalIdToDataCategRec = new Map<String,Data_Category_Mapping__c>();
        for(Data_Category_Mapping__c each : dataCategMap){
            externalIdToDataCategRec.put(each.External_Id__c,each);
        }
        
        // Build lookup keys from this batch: Title+UrlName -> article
        Map<String, Knowledge__kav> articleByKey = new Map<String, Knowledge__kav>();
        for (Knowledge__kav art : articles) {
            if(externalIdToDataCategRec != null && externalIdToDataCategRec.containsKey(art.MindtouchExternalId__c)){
                Data_Category_Mapping__c dataCateg = externalIdToDataCategRec.get(art.MindtouchExternalId__c);
                String groupName = dataCateg.DataCategoryGroup__c;
                String categName = dataCateg.New_Category__c;
                toInsert.add(new Knowledge__DataCategorySelection(
                    ParentId              = art.id,
                    DataCategoryGroupName = groupName,
                    DataCategoryName      = categName
                ));
            }
        }

        // Insert category selections
        if (!toInsert.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(toInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Database.Error err : results[i].getErrors()) {
                        String msg = 'INSERT ERROR: ' + toInsert[i].DataCategoryGroupName +
                                     '.' + toInsert[i].DataCategoryName +
                                     ' on article Id=' + toInsert[i].ParentId +
                                     ' | ' + err.getMessage();
                        errors.add(msg);
                        System.debug(msg);
                    }
                    totalAssigned--;
                    totalSkipped++;
                }
            }
        }
    }

    // ── Finish: log summary ───────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('======================================');
        System.debug('KnowledgeCategoryAssignmentBatch DONE');
        System.debug('Total articles processed : ' + totalProcessed);
        System.debug('Categories assigned      : ' + totalAssigned);
        System.debug('Skipped (no map/dup/err) : ' + totalSkipped);
        System.debug('Errors                   : ' + errors.size());
        for (String e : errors) {
            System.debug('  ' + e);
        }
        System.debug('======================================');
    }
    
}