/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Description: Apex controller for LWC SSV_CaseSSV_CollaboratorCC , ssv_AgentCaseCollaboratorComponent
* @Test Class : SSV_PortalCaseCollaboratorControllerTest
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar (Truffle)				Customer Portal development
********************************************************/

public with sharing class SSV_PortalCaseCollaboratorController {
    
    /** 
    * @description -  On load sSV_CaseSSV_CollaboratorCC brings the existing collaborator details.
    */
    @AuraEnabled
    public  static List<Wrapper> getData(Id recordId) {
        Case caseRecord = [SELECT Id, SSV_Collaborator1__c, SSV_Collaborator2__c, SSV_Collaborator3__c, SSV_Collaborator4__c, SSV_Collaborator5__c 
                           FROM Case 
                           WHERE Id = :recordId WITH SECURITY_ENFORCED];
        
        List<Wrapper> wrap = new List<Wrapper>();
        
        wrap.add(new Wrapper(caseRecord.SSV_Collaborator1__c,1)); 
        wrap.add(new Wrapper(caseRecord.SSV_Collaborator2__c,2));
        wrap.add(new Wrapper(caseRecord.SSV_Collaborator3__c,3));
        wrap.add(new Wrapper(caseRecord.SSV_Collaborator4__c,4));
        wrap.add(new Wrapper(caseRecord.SSV_Collaborator5__c,5));
        
        return wrap;
  
    }
    /** 
    * @description -  Method to remove case collaborator on user action using given email. Collaborator must be a contact
    */
    @AuraEnabled
    public  static List<Wrapper> removeColabFromCase(Id recordId, String fieldNumber) {

        
        List<Wrapper> wrap = new List<Wrapper>();
        
        Case csRecord = [select id ,contact.accountid, SSV_Collaborator1__c,SSV_Collaborator2__c,SSV_Collaborator3__c,SSV_Collaborator4__c,
                         SSV_Collaborator5__c from case where id=:recordId WITH SECURITY_ENFORCED];

        
            String collaboratorEmail;
        
             try{  
                 collaboratorEmail = String.valueof(csRecord.get('SSV_Collaborator'+FieldNumber+'__c'));
                 csRecord.put('SSV_Collaborator'+FieldNumber+'__c',null);
                 if (Schema.sObjectType.Case.isUpdateable() ) {
                 update csRecord;
                 }else{throw new SSV_ServiceUtil.SecurityException('Missing update permissions on Case');  }
             }catch(Exception ex){
                System.debug(LoggingLevel.DEBUG, ex.getMessage()); 
                 
             }
        wrap.add(new Wrapper(csRecord.SSV_Collaborator1__c,1));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator2__c,2));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator3__c,3));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator4__c,4));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator5__c,5));
        
        deletecollaborator(collaboratorEmail,csRecord);
        
        return wrap;
        
    }

      /** 
    * @description -  Helper method called from removeColabFromCase 
    */
    private static void deletecollaborator(String collaboratorEmail, Case csRec){
        
        List<CaseTeamRole> watcherRole = [SELECT Id, Name FROM CaseTeamRole WHERE Name = 'Collaborator' WITH SECURITY_ENFORCED];
        if(watcherRole.isEmpty()){return; } 
        SSV_CollabHelperClass.DeleteCaseTeamMembers(csRec,watcherRole[0].Id,collaboratorEmail);
        
    }

     /** 
* @description -  Method to add contact as a case collaborator using emailon user action 
*/
    @AuraEnabled
    public  static List<Wrapper> addColabOnCase(Id recordId,String email) {
        List<Wrapper> wrap = new List<Wrapper>();
        
        Case csRecord = [SELECT id ,contact.accountid ,SSV_Collaborator1__c,SSV_Collaborator2__c,SSV_Collaborator3__c,SSV_Collaborator4__c,SSV_Collaborator5__c 
                         FROM CASE 
                         WHERE id=:recordId WITH SECURITY_ENFORCED];
        
        
        if(csRecord.SSV_Collaborator1__c==null){
            csRecord.put('SSV_Collaborator1__c',Email);
            
        }else if(csRecord.SSV_Collaborator2__c==null){
            csRecord.put('SSV_Collaborator2__c',Email);
            
        }else if(csRecord.SSV_Collaborator3__c==null){
            csRecord.put('SSV_Collaborator3__c',Email);
            
        }else if(csRecord.SSV_Collaborator4__c==null){
            csRecord.put('SSV_Collaborator4__c',Email);
            
        }else if(csRecord.SSV_Collaborator5__c==null){
            csRecord.put('SSV_Collaborator5__c',Email);
        }
        try{
            if (Schema.sObjectType.Case.isUpdateable() ) {
                update csRecord;
            }else{throw new SSV_ServiceUtil.SecurityException('Missing create permissions on Case Team');}
        }catch(Exception ex){System.debug(LoggingLevel.DEBUG, ex.getMessage()); }
        
        
        wrap.add(new Wrapper(csRecord.SSV_Collaborator1__c,1));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator2__c,2));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator3__c,3));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator4__c,4));
        wrap.add(new Wrapper(csRecord.SSV_Collaborator5__c,5));
        
        updateCaseWatchers(csRecord,Email);
        
        return wrap;
  
    }
    
       /** 
    * @description -  Helper method called from addColabOnCase
    */
    private static void updateCaseWatchers(Case csRec, String email){

        List<CaseTeamRole> watcherRole = [SELECT Id, Name FROM CaseTeamRole WHERE Name = 'Collaborator' WITH SECURITY_ENFORCED];
        if(watcherRole.isEmpty()){return; } 
        SSV_CollabHelperClass.InsertCaseTeamMembers(csRec,watcherRole[0].Id,email);
     
    }
    

 
    public class Wrapper{

        @AuraEnabled
        public String index;
        @AuraEnabled  
        public String email;

        public Wrapper(String email, Integer index){
            this.email = email;
            this.index = String.valueof(index);
        }
     }
}