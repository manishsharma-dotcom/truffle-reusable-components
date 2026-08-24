/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: Aug 13 2025
* @Description: Apex Helper for SSV_WaitingOnCustomerDatesHelper : SSV-1411
* @Test Class : SSV_WaitingOnCustomerDatesHelperTest
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Aug 13 2025      Sandeep Kumar (Truffle)				Customer Portal development
********************************************************/
global without sharing class SSV_WaitingOnCustomerCaseDetailsInput {
    
    @AuraEnabled @InvocableVariable(required=true)
    public String caseId;
    @AuraEnabled  @InvocableVariable(required=true)
    public DateTime waitingOnCustomerDate;
    @AuraEnabled  @InvocableVariable(required=true)
    public DateTime waitingOnCustomerLastReminder;
}