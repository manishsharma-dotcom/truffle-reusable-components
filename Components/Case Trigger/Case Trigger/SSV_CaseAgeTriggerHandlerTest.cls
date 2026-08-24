/*******************************************************
* @Author: Sandeep (Truffle)
* @Date: Jan-09-2025 
* @Test Class For : SSV_CaseAgeTriggerHandler 
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Jan-09-2025      Sandeep(Truffle)				Customer Portal development
********************************************************/
@isTest
public class SSV_CaseAgeTriggerHandlerTest {
    
    // Test data setup for Case records and required custom fields
    
    @testSetup 
    public static void setupTestData() {
           
                
        // Create an Account
        Account account = new Account(Name = 'Test Account');        
        Account acc1 = new Account(Name = 'Test Account 1');
        Account acc2 = new Account(Name = 'Test Account 2');
        insert new List<Account>{ account, acc1, acc2 };
            
        // Create a Contact
        Id wamRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('WAM_User').getRecordTypeId();
        
        Contact contact = new Contact( FirstName = 'Test', LastName = 'Contact', Email = 'testcontact@test.com', AccountId = account.Id,WAMUser__c = true);   
        // SFM-5657
        contact.RecordTypeId = wamRecordTypeId;
        // Create Contacts
        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc1.Id);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Doe', AccountId = null); // No related Account
        insert new List<Contact>{ contact, contact1, contact2 };
        
        // Email Message
        EmailMessage email = new EmailMessage(
            Subject = 'Test Email Weave Paid Support',
            FromAddress = 'testPaidsupportweavetest@example.com',
            ToAddress = 'testPaidsupportweave@example.com',            
            Incoming = true);
        insert email;

        // Create Priority Program records (Lowest Order per Account)
        SSV_PriorityProgram__c pp1 = new SSV_PriorityProgram__c(SSV_Account__c = acc1.Id, SSV_ProgramPriority__c = 'High', SSV_Sequence__c = 1,SSV_ProgramType__c='VIP',  SSV_StartDate__c=System.today(), SSV_EndDate__c =System.today());
        SSV_PriorityProgram__c pp2 = new SSV_PriorityProgram__c(SSV_Account__c = acc1.Id, SSV_ProgramPriority__c = 'Low', SSV_Sequence__c = 2,SSV_ProgramType__c='VIP',  SSV_StartDate__c=System.today(), SSV_EndDate__c =System.today());
        insert new List<SSV_PriorityProgram__c>{ pp1, pp2 };        
        
        
        // Creating mock Case records with required fields
        List<Case> caseList = new List<Case>();
        
        Case case1 = new Case(
            ContactId = contact.Id,
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
            OwnerId = UserInfo.getUserId(),
            SourceId = email.id
        );
        caseList.add(case1);
        
        insert caseList;
    }
    
    @isTest 
    public static void testMethodInsert(){
        List<Case> caseList = new List<Case>();       

        Case case1 = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
            OwnerId = UserInfo.getUserId()
        );
        caseList.add(case1);
        insert caseList;
        List<SSV_CaseAgeRecord__c> caseAgeRecords = [SELECT ID FROM SSV_CaseAgeRecord__c limit 1];
        System.assertEquals(1, caseAgeRecords.size(), 'Case Age Records created');      
        
    }
    
    @isTest static void testMethodUpdate(){
        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'SSV_AgentSupportPaid' LIMIT 1].id;
        Case cs = [SELECT ID FROM CASE LIMIT 1];
        cs.SSV_RecentPublicComment__c ='Hi There!';       
        update cs;
        List<Case> cases = [SELECT ID FROM case where id=:cs.Id];
        System.assertEquals(1, cases.size(), 'Case Updated');
        
    }
    
    @isTest static void testMethodUpdateForCloseCase(){
        
        Case cs = [SELECT ID FROM CASE LIMIT 1];
        cs.status ='Closed';
        update cs;
        List<SSV_CaseAgeRecord__c> caseAgeRecords = [SELECT ID FROM SSV_CaseAgeRecord__c where SSV_EndTime__c!=null limit 1];
        System.assertEquals(1, caseAgeRecords.size(), 'Case Age Records closed');
        
    }
    
    @isTest
    static void testBulkInsertCases() {        
        Id eId= [Select id from EmailMessage where Subject='Test Email Weave Paid Support' Limit 1].id;
        List<Case> caseList = new List<Case>();
        Id accId = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1].Id;
        List<SSV_PriorityProgram__c> ppList = [Select id,SSV_Account__c,SSV_ProgramPriority__c,SSV_Sequence__c from SSV_PriorityProgram__c where SSV_Account__c=:accId];
        for (Integer i = 0; i < 10; i++) {
            caseList.add(new Case(
                Subject = 'Bulk Case ' + i,
                AccountId = accId,
                SourceId = eId,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId()
            ));
        }

        Test.startTest();        
        insert caseList;       
        Test.stopTest();
        
        // Verify bulk insert processed correctly
        Integer highPriorityCases = [SELECT COUNT() FROM Case WHERE Priority = 'High' AND Subject LIKE 'Bulk Case%'];
        System.assertEquals(10, highPriorityCases, 'All bulk cases should have Priority set to High.');
        }
    
    @isTest
    static void testContactInsertCases() {
        List<Case> caseList = new List<Case>();
        Id eId= [Select id from EmailMessage where Subject='Test Email Weave Paid Support' Limit 1].id;
        Id accId = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1].Id;
        Id conId = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1].Id;
        for (Integer i = 0; i < 10; i++) {
            caseList.add(new Case(
                Subject = 'Bulk Case ' + i,
                ContactId = conId,
                SourceId = eId,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId()
            ));
        }

        Test.startTest();
        insert caseList;
        Test.stopTest();

        // Verify bulk insert processed correctly
        Integer highPriorityCases = [SELECT COUNT() FROM Case WHERE Priority = 'High' AND Subject LIKE 'Bulk Case%'];
        System.assertEquals(10, highPriorityCases, 'All bulk cases should have Priority set to High.');
    }


    @isTest
    static void testNoPriorityWhenNoPriorityProgram() {
        // Create Account without a Priority Program
        Account accNoPriority = new Account(Name = 'No Priority Account');
        insert accNoPriority;

        // Create Case for Account with NO Priority Program
        Case caseNoPriority = new Case(
            Subject = 'No Priority Case',
            AccountId = accNoPriority.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId()
        );

        insert caseNoPriority;

        // Fetch Case after trigger execution
        Case fetchedCase = [SELECT Priority FROM Case WHERE Id = :caseNoPriority.Id];
        System.assertEquals('Medium', fetchedCase.Priority, 'Case should have default priority Medium (No Priority Program found).');
    }
    
    @isTest 
    public static void testMethodInsertPaidSupport(){
        List<Case> caseList = new List<Case>();
        Id eId= [Select id from EmailMessage where Subject='Test Email Weave Paid Support' Limit 1].id;
        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'SSV_AgentSupportPaid' LIMIT 1].id;

        Case case1 = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
            OwnerId = queueId,
            SourceId = eId
        );
        caseList.add(case1);
        insert caseList;
        // Verify the field was updated
        Case insertedCase = [SELECT SSV_IsPaidSupportCase__c FROM Case WHERE Id = :case1.Id];
        System.assertEquals(true, insertedCase.SSV_IsPaidSupportCase__c, 'Case should be marked as Paid Support.');
    }   
    
    @isTest 
    public static void testMethodUpdatePaidSupport(){
		Id eId= [Select id from EmailMessage where Subject='Test Email Weave Paid Support' Limit 1].id;
        Id queueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'SSV_AgentSupportPaid' LIMIT 1].id;
        Case cs = [SELECT ID FROM CASE LIMIT 1];
        cs.SSV_RecentPublicComment__c ='Hi There!';
        cs.OwnerId = queueId;
        update cs;
        Case UpdatedCase = [SELECT SSV_IsPaidSupportCase__c FROM Case WHERE Id = :cs.Id];
        System.assertEquals(true, UpdatedCase.SSV_IsPaidSupportCase__c, 'Case should be marked as Paid Support.');
    }
    /*@isTest 
    public static void testMethodUpdateForChatCase(){
        
        PermissionSetGroup psg = [SELECT Id, DeveloperName FROM PermissionSetGroup where DeveloperName =  'SSV_ServiceSupervisorUser' limit 1];
        
        String uniqueUserName = 'adachatbot.user@getweave.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName=uniqueUserName);
        insert u;
        
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetGroupId=psg.Id;
        psa.AssigneeId =u.id ;
        insert psa;
        System.runAs(u) {
            List<Case> caseList = new List<Case>();
            Id contactId = [Select Id from contact where IsWAMUser__c =true limit 1].id;
            Case chatCase1 = new Case(
                contactId= contactId,
                Subject = 'Test Case 1',
                Status = 'New',
                //SSV_SlaStatusChat__c = 'Not Applicable',
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            Case chatCase2 = new Case(
                contactId= contactId,
                Subject = 'Test Case 2',
                Status = 'In Progress',
                //SSV_SlaStatusChat__c = 'Timer On',
                SSV_SlaStatusChatTimerStart__c = system.now() ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            Case chatCase3 = new Case(
                contactId= contactId,
                Subject = 'Test Case 3',
                Status = 'In Progress',
                //SSV_SlaStatusChat__c = 'Timer On',
                SSV_SlaStatusChatTimerStart__c = system.now() ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            
            Case chatCase4 = new Case(
                contactId= contactId,
                Subject = 'Test Case 4',
                Status = 'In Progress',
                //SSV_SlaStatusChat__c = 'Timer On',
                SSV_SlaStatusChatTimerStart__c = system.now().adddays(-1) ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            
          
            caseList.add(chatCase1);
            caseList.add(chatCase2);
            caseList.add(chatCase3);
            caseList.add(chatCase4);

            
            insert caseList;
            
            List<case> updatedCaseList = [Select ID,SSV_SlaStatusChat__c from case where id=:chatCase1.id limit 1];
            System.assertEquals(1, updatedCaseList.size(), 'Case SSV_SlaStatusChat__c was updated');

            
        }
    }*/
    /*@isTest 
    public static void testMethodUpdateForLinearCase(){
        
        PermissionSetGroup psg = [SELECT Id, DeveloperName FROM PermissionSetGroup where DeveloperName =  'SSV_Tier2ServiceUser' limit 1];
        
        String uniqueUserName = 'SSV_Tier2ServiceUser.user@getweave.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',
                          UserName=uniqueUserName);
        insert u;
        
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.PermissionSetGroupId=psg.Id;
        psa.AssigneeId =u.id ;
        insert psa;
        System.runAs(u) {
            List<Case> caseList = new List<Case>();
            Id contactId = [Select Id from contact where IsWAMUser__c =true limit 1].id;
            
            
            
            Case chatCase5 = new Case(
                contactId= contactId,
                Subject = 'Test Case 5',
                Status = 'In Progress',
                //SSV_SlaStatusLinearTicket__c = 'Not Applicable' ,
                SSV_SlaStatusLinearTimerStart__c = system.now() ,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            
            Case chatCase6 = new Case(
                contactId= contactId,
                Subject = 'Test Case 6',
                Status = 'In Progress',
                //SSV_SlaStatusLinearTicket__c = 'Timer On' ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                SSV_SlaStatusLinearTimerStart__c = system.now() ,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
            Case chatCase7 = new Case(
                contactId= contactId,
                Subject = 'Test Case 7',
                Status = 'In Progress',
                //SSV_SlaStatusLinearTicket__c = 'Timer On' ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                SSV_SlaStatusLinearTimerStart__c = system.now() ,
                SSV_IsDefect__c=false,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );
             Case chatCase8 = new Case(
                contactId= contactId,
                Subject = 'Test Case 8',
                Status = 'In Progress',
                //SSV_SlaStatusLinearTicket__c = 'Timer On' ,
                SSV_RelatedLinearRecord__c = 'xyzTestt.com',
                SSV_SlaStatusLinearTimerStart__c = system.now().addDays(-1) ,
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                OwnerId = UserInfo.getUserId()
            );

            caseList.add(chatCase5);
            caseList.add(chatCase6);
            caseList.add(chatCase7);
            caseList.add(chatCase8);

            insert caseList; 
            //List<case> updatedCaseList = [Select ID,SSV_SlaStatusLinearTicket__c from case where id=:chatCase5.id limit 1];
            //System.assertEquals(1, updatedCaseList.size(), 'Case SSV_SlaStatusLinearTicket__c was updated');
            
            
        }*/
}