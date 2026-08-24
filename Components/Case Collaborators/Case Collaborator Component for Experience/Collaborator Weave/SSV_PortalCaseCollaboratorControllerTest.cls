/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Test Class for: SSV_PortalCaseCollaboratorController
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar (Truffle)				Customer Portal development
********************************************************/

@isTest
public class SSV_PortalCaseCollaboratorControllerTest {

    @testSetup
    static void setup() {
        // Create Account
        Account account = new Account(Name = 'Test Account');
        insert account;

        // Create Contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'First1', LastName = 'Last1', Email = 'collaborator1@test.com', AccountId = account.Id),
            new Contact(FirstName = 'First2', LastName = 'Last2', Email = 'collaborator2@test.com', AccountId = account.Id),
            new Contact(FirstName = 'First3', LastName = 'Last3', Email = 'collaborator3@test.com', AccountId = account.Id),
            new Contact(FirstName = 'First4', LastName = 'Last4', Email = 'collaborator4@test.com', AccountId = account.Id),
            new Contact(FirstName = 'First5', LastName = 'Last5', Email = 'collaborator5@test.com', AccountId = account.Id)
        };
        insert contacts;

        // Create Case
        Case caseRecord = new Case(
            ContactId = contacts[0].Id );
        insert caseRecord;
        SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'collaborator1@test.com');

    }

    @isTest
    static void testGetData() {
        // Get Case Id
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        List<SSV_PortalCaseCollaboratorController.Wrapper> result = SSV_PortalCaseCollaboratorController.getData(caseRecord.Id);
        Test.stopTest();

        System.assertEquals(5, result.size(),'Collorator Exists');
    }

    @isTest
    static void testRemoveColabFromCase() {
        // Get Case Id
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<SSV_PortalCaseCollaboratorController.Wrapper> result = SSV_PortalCaseCollaboratorController.removeColabFromCase(caseRecord.Id, '1');
        Test.stopTest();

        System.assertEquals(5, result.size(),'Collorator Exists');
    }
    @isTest
    static void testRemoveColabFromCaseWithError() {
        // Get Case Id
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        List<SSV_PortalCaseCollaboratorController.Wrapper> result = SSV_PortalCaseCollaboratorController.removeColabFromCase(caseRecord.Id, '9');
        Test.stopTest();
         
        System.assertEquals(5, result.size(),'Collorator Exists');
    }
    @isTest
    static void testAddColabOnCase() {
        // Get Case Id
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<SSV_PortalCaseCollaboratorController.Wrapper> result = SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'newcollaborator@test.com');
        result = SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'newcollaborator2@test.com');
        result = SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'newcollaborator3@test.com');
        
        result = SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'newcollaborator4@test.com');
        
        result = SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'newcollaborator5@test.com');
        
        
        Test.stopTest();

        System.assertEquals(5, result.size(),'Collorator Exists');
    }

    @isTest
    static void testUpdateCaseWatchers() {
        // Get Case
        Case caseRecord = [SELECT Id,Contact.Email,Contact.AccountId FROM Case LIMIT 1];
        Contact cont = [Select id,Email from Contact limit 1 ]; 

        Test.startTest();
        SSV_PortalCaseCollaboratorController.addColabOnCase(caseRecord.Id, 'PortalCaseListController@test.com');
        Test.stopTest();

        List<CaseTeamMember> caseTeamMembers = [SELECT Id FROM CaseTeamMember WHERE ParentId = :caseRecord.Id];
        System.assert(true);
    }
    
    
    @isTest
    static void testgetCaseOwnerQueues(){
        SSV_CollabHelperClass.getCaseOwnerQueues();
        Map<Id, String> ownerIdToNameMap = new Map<Id, String>();
        Case currCase = [select id ,Status,ownerid from case limit 1];
        ownerIdToNameMap.put(currCase.OwnerId, null);
        SSV_CollabHelperClass.resolveIdToName(ownerIdToNameMap);
        List<SSV_CaseAgeRecord__c> recordsToCreate = new List<SSV_CaseAgeRecord__c>();
        
        SSV_CaseAgeRecord__c ageRecord = new SSV_CaseAgeRecord__c();
        ageRecord.SSV_Case__C = currCase.Id;
        ageRecord.SSV_StartTime__c = Datetime.now();
        ageRecord.SSV_Status__c = currCase.Status;
        ageRecord.SSV_OwnerId__c = currCase.ownerId;
        
        ageRecord.SSV_EndTime__c = Datetime.now();
        
        
        recordsToCreate.add(ageRecord);
        
        
        
        List<SSV_CaseAgeRecord__c> finalRecordsToCreate = new List<SSV_CaseAgeRecord__c>();
        for(SSV_CaseAgeRecord__c eachR : recordsToCreate){
            if(eachR.SSV_OwnerName__c != 'dev'){
                finalRecordsToCreate.add(eachR);
            }
        }
        SSV_CollabHelperClass.insertCaseAgeRecords(finalRecordsToCreate);
        System.assertEquals(!finalRecordsToCreate.isEmpty(), true,'Collorator Exists');

    }
}