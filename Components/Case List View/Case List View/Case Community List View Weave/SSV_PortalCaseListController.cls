/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Description: Apex controller for LWC sSV_caselist 
* @Test Class : SSV_PortalCaseListControllerTest
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar (Truffle)			Customer Portal development
********************************************************/
public with sharing class SSV_PortalCaseListController {
    
    /** 
    * @description - On loading sSV_caselist, the method brings the existing cases that are visible to user.
    *                details. The fields to return is configurable from metadata SSV_HelpCenterCaseList__mdt
    *                The listview, SearchText and CurrentSize helps in filtering and perform pagination.
    */
    @AuraEnabled
    public static Wrapper getCaseList(String searchText , String listView ,  Integer offsetVal, Integer limitSize) {
        
        List<String> caseFields = new List<String>();
        List<Column> columns = new List<Column>();
        for(SSV_HelpCenterCaseList__mdt mdt:[SELECT ID ,label,SSV_FieldAPIName__c , SSV_FieldType__c, SSV_order__c 
                                             FROM  SSV_HelpCenterCaseList__mdt  WITH SECURITY_ENFORCED 
                                             ORDER BY SSV_order__c ASC ]) {
            TypeAttribute tatt ;
            String fieldName = mdt.SSV_FieldAPIName__c;
            if(mdt.SSV_FieldAPIName__c.equalsIgnoreCase('casenumber')) {
                tatt = new TypeAttribute();
                tatt.label = new FieldLabel(mdt.SSV_FieldAPIName__c);
                tatt.target ='_blank';
                fieldName = 'caseNumberURL';
            }
            columns.add(new Column(mdt.label, fieldName, mdt.SSV_FieldType__c, tatt, true));
            caseFields.add(mdt.SSV_FieldAPIName__c);
        }

        Set<String> allowedRecordType = new Set<String>{'SSV_CustomerSupport','SSV_CustomerSupportEmergencyAfterHours','SSV_OwnershipTransfer'};
        
        String casefield = String.join(caseFields, ',');
        String query = 'SELECT Id,' + string.escapeSingleQuotes(casefield) + ' FROM Case WHERE recordtype.developername IN :allowedRecordType';
        
        if(!String.isBlank(searchText)) {
            searchText = String.escapeSingleQuotes(searchText);
            query += ' AND (CaseNumber LIKE \'' + '%' + searchText + '%' + '\' OR Subject LIKE \'' + '%' + searchText + '%' + '\')';
        }

        String contactId;
        if(UserInfo.getUserId() != null) {
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
            if(!users.isEmpty()) {
                contactId = users[0].ContactId;
            }
        }

        if(String.isBlank(contactId)) {
            contactId = UserInfo.getUserId();
        }

        contactId= string.escapeSingleQuotes(contactId);

        if(listView == 'My Open Cases') {
            query += ' AND ContactId = :contactId AND IsClosed = false';
        } else if(listView == 'My Closed Cases') {
            query += ' AND ContactId = :contactId AND IsClosed = true';
        } else if(listView == 'My Company Cases - Open') {
            query += ' AND ContactId != :contactId AND IsClosed = false';
        } else if(listView == 'My Company Cases - Closed') {
            query += ' AND ContactId != :contactId AND IsClosed = true';
        } else {
            return null;
        }

        query += ' AND CreatedDate = LAST_N_DAYS:30 ORDER BY LastModifiedDate DESC, Id DESC';
        
        Integer safeLimit = (limitSize != null && limitSize > 0) ? limitSize : 1000;
        Integer safeOffset = (offsetVal != null && offsetVal >= 0) ? offsetVal : 0;
        String safeLimitStr = String.valueof(safeLimit) ;
        String safeOffsetStr = String.valueof(safeOffset) ;
 
        query += ' LIMIT ' + String.escapeSingleQuotes(safeLimitStr) + ' OFFSET ' + String.escapeSingleQuotes(safeOffsetStr);         

        Wrapper wrapperData = new Wrapper();
        wrapperData.caseData = Database.query(query);
        wrapperData.columns = columns;
        return wrapperData;
    }   

    /**
    * @description - Returns the total number of Cases based on filters (search text and list view)
    */
    @AuraEnabled
    public static Integer getCaseCount(String searchText , String listView) {
        Set<String> allowedRecordType = new Set<String>{'SSV_CustomerSupport','SSV_CustomerSupportEmergencyAfterHours'};
        String countQuery = 'SELECT Count() FROM Case WHERE recordtype.developername IN :allowedRecordType';

        if(!String.isBlank(searchText)) {
            searchText = String.escapeSingleQuotes(searchText);
            countQuery += ' AND (CaseNumber LIKE \'' + '%' + searchText + '%' + '\' OR Subject LIKE \'' + '%' + searchText + '%' + '\')';
        }

        String contactId;
        if(UserInfo.getUserId() != null) {
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
            if(!users.isEmpty()) {
                contactId = users[0].ContactId;
            }
        }

        if(String.isBlank(contactId)) {
            contactId = UserInfo.getUserId();
        }

        if(listView == 'My Open Cases') {
            countQuery += ' AND ContactId = :contactId AND IsClosed = false';
        } else if(listView == 'My Closed Cases') {
            countQuery += ' AND ContactId = :contactId AND IsClosed = true';
        } else if(listView == 'My Company Cases - Open') {
            countQuery += ' AND ContactId != :contactId AND IsClosed = false';
        } else if(listView == 'My Company Cases - Closed') {
            countQuery += ' AND ContactId != :contactId AND IsClosed = true';
        } else {
            return 0;
        }

        countQuery += ' AND CreatedDate = LAST_N_DAYS:30';

        return Database.countQuery(countQuery);
    }

    public class Wrapper{
        @AuraEnabled public List<Case> caseData;
        @AuraEnabled public List<Column> columns;
        public Wrapper(){
            caseData  = new List<Case>();
            columns = new List<Column>();
        }
    }

    public class Column{
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type; 
        @AuraEnabled public TypeAttribute typeAttributes;
        @AuraEnabled public Boolean sortable;

        public Column(String label, String fieldName , String type , TypeAttribute typeAttributes, Boolean sortable){
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
            this.typeAttributes = typeAttributes;
            this.sortable = sortable;
        }
    }

    public class TypeAttribute{
        @AuraEnabled public FieldLabel label;
        @AuraEnabled public String target;
    }

    public class FieldLabel{
        @AuraEnabled public String fieldName;
        public FieldLabel(String fieldName){
            this.fieldName = fieldName;
        }
    }
}