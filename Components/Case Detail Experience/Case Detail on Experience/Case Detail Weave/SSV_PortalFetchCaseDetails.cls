/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Description: Apex controller for LWC sSV_CaseDetail 
* @Test Class : SSV_PortalFetchCaseDetailsTest
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar (Truffle)				Customer Portal development
********************************************************/

public with sharing class SSV_PortalFetchCaseDetails {
    
	 /** 
    * @description -  On load of sSV_CaseDetail, the method returns the Case Details.
    */
	@AuraEnabled
    public static String fetchCaseFormType(String recordId){
        List<Case> csList = [select id , SSV_CaseFormType__c from case where id=:recordId WITH SECURITY_ENFORCED ];
        if(!csList.isEmpty()){
            return csList[0].SSV_CaseFormType__c;
        }else{
            return 'Case Not Found';
        }
        
    }
}