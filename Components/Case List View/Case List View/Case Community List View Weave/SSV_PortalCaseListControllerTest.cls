/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: July 23 2024
* @Description: Apex controller for LWC sSV_caselist 
* @Test Class For : SSV_PortalCaseListController
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jul-23-2024      Sandeep Kumar(Truffle)				Customer Portal development
********************************************************/
@isTest
public class SSV_PortalCaseListControllerTest {
    
    @testSetup
    static void setup() {
        // Create Account
        Account account = new Account(Name = 'Test Account');
        insert account;
        
        // Create Contact 
        Contact contact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'testcontact@test.com', AccountId = account.Id);
        insert contact;        
        
        // Create Cases
        List<Case> cases = new List<Case>();        
        cases.add(new Case(ContactId = contact.Id, Subject = 'Test Case 1 ', Status='Open', SSV_CaseFormType__c = 'New Workspace'));
        cases.add(new Case(ContactId = contact.Id, Subject = 'Test Case 2 ',Status='Open', SSV_CaseFormType__c = 'New Workspace'));
        cases.add(new Case(ContactId = contact.Id, Subject = 'Test Case 3', Status='Closed Cancelled', SSV_CaseFormType__c = 'New Workspace'));        
        insert cases;         
    }
    
    @isTest
    static void testGetCaseListMyOpenReq() {
        Contact cont = [Select id from Contact limit 1 ]; 
        
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser']; // Change to an appropriate profile
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('', 'My Open Cases',1,1000);
            SSV_PortalCaseListController.getCaseCount('', 'My Open Cases');
            Test.stopTest();
            
            System.assertNotEquals(null, result,'No Data');
            System.assertNotEquals(null, result.caseData,'No Data');
            System.assertNotEquals(null, result.columns,'No Data');
        }
    }
    @isTest
    static void testGetCaseListMyClosedReq() {
        Contact cont = [Select id from Contact limit 1 ]; 
        
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser']; // Change to an appropriate profile
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('', 'My Closed Cases',1,1000);
            SSV_PortalCaseListController.getCaseCount('', 'My Closed Cases');
            Test.stopTest();            
            System.assertNotEquals(null, result,'No Data');
            System.assertNotEquals(null, result.caseData,'No Data');
            System.assertNotEquals(null, result.columns,'No Data');
        }
    }
    @isTest
    static void testGetCaseListMyCompanyCase() {
        Contact cont = [Select id from Contact limit 1 ]; 
        
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser']; // Change to an appropriate profile
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('', 'My Company Cases - Open',1,1000);
            SSV_PortalCaseListController.getCaseCount('', 'My Company Cases - Open');
            Test.stopTest();            
            System.assertNotEquals(null, result,'No Data');
            System.assertNotEquals(null, result.caseData,'No Data');
            System.assertNotEquals(null, result.columns,'No Data');
        }
    }
    @isTest
    static void testGetSFCaseListMyCompanyCase() {
        Contact cont = [Select id from Contact limit 1 ]; 
        
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser'];
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('', 'My Company Cases - Closed',1,1000);
            SSV_PortalCaseListController.getCaseCount('', 'My Company Cases - Closed');            
            System.assertNotEquals(null, result,'No Data');
            System.assertNotEquals(null, result.caseData,'No Data');
            System.assertNotEquals(null, result.columns,'No Data');
        }
    }
    
    @isTest
    static void testGetCaseListWithSearchText() {
        Contact cont = [Select id from Contact limit 1 ]; 
        
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser']; // Change to an appropriate profile
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('Test Case 1', 'My Open Cases',1,1000);
            SSV_PortalCaseListController.getCaseCount('Test Case 1', 'My Open Cases');            
            Test.stopTest();            
            System.assertNotEquals(null, result,'No Data');
        }
    }
    
    @isTest
    static void testGetCaseListWithInvalidView() { 
        Contact cont = [Select id from Contact limit 1 ];         
        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name='SSV_HelpCenterUser'];
        User user = new User(Alias = 'standt', Email='PortalCaseListController@test.com', EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles', UserName='PortalCaseListController@test.com', ContactId = cont.Id);
        insert user;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetId = [Select ID from PermissionSet where name ='SSV_HelpCenterCasePS'].Id;
        psa.AssigneeId =user.id;
        insert psa;
        System.runAs(user) {
            Test.startTest();
            SSV_PortalCaseListController.Wrapper result = SSV_PortalCaseListController.getCaseList('', 'Invalid View',0,1000);
            SSV_PortalCaseListController.getCaseCount('', 'Invalid View');
            Test.stopTest();            
            System.assertEquals(null, result, 'Expected null result for invalid view');
        }
    }
}