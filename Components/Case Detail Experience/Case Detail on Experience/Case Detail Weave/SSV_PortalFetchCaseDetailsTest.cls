/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Description: Apex test Class for SSV_PortalFetchCaseDetails 
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar (Truffle)				Customer Portal development
********************************************************/

@isTest
public class SSV_PortalFetchCaseDetailsTest {

    @testSetup
    static void setup() {
        // Create Account
        Account account = new Account(Name = 'Test Account');
        insert account;

        // Create Contact
        Contact contact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'testcontact@test.com', AccountId = account.Id);
        insert contact;

        // Create Case
        Case caseRecord = new Case(
            ContactId = contact.Id,
            SSV_CaseFormType__c = 'New Workspace'
        );
        insert caseRecord;
    }

    @isTest
    static void testFetchCaseFormType() {
        // Get Case Id
        Case caseRecord = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        String result = SSV_PortalFetchCaseDetails.fetchCaseFormType(caseRecord.Id);
        Test.stopTest();

        System.assertEquals('New Workspace', result,'New Workspace');
    }

    @isTest
    static void testFetchCaseFormTypeCaseNotFound() {
        Contact cont = [Select id from Contact limit 1 ]; 
        Profile p = [SELECT Id FROM Profile WHERE Name='Customer Community Plus Login User']; // Change to an appropriate profile
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            String result = SSV_PortalFetchCaseDetails.fetchCaseFormType(cont.id);
            Test.stopTest();
            System.assertEquals('Case Not Found', result,'Case Not Found');
        }
    }
}