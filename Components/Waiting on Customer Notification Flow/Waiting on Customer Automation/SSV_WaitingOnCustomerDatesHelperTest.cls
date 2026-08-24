/*******************************************************
* @Author: Sandeep Kumar (Truffle)
* @Date: Aug 13 2025
* @Description: Apex Helper for SSV_WaitingOnCustomerDatesHelper : SSV-1411
* @Test Class For: SSV_WaitingOnCustomerDatesHelper
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.             Code Reviewer       Modification
*================================================================================================
* 1.0       Aug 13 2025      Sandeep Kumar(Truffle)				Customer Portal development
********************************************************/

/**
 * @description SSV_WaitingOnCustomerDatesHelperTest is the test class for SSV_WaitingOnCustomerDatesHelper
 */
@IsTest
private class SSV_WaitingOnCustomerDatesHelperTest {
    
    static Account sharedAccount;
    
    /** 
    * @description Test setup method to create test Account.
    * This method runs before each test method in the class.
    */
    @testSetup
    static void setupData() {
        sharedAccount = new Account(Name = 'Test Account');
        insert sharedAccount;
    }    
    
    /** 
    * @description This method returns datetime after calculating difference in hours.
    * @params Takes number of hours difference
    * @return Datetime
    */
    private static DateTime getBusinessDateTimeHoursAgo(Integer hoursAgo) {
        DateTime target = System.now().addHours(-hoursAgo);
        target = DateTime.newInstance(target.year(), target.month(), target.day(), 9, 0, 0);
        while (target.format('E') == 'Sat' || target.format('E') == 'Sun') {
            target = target.addDays(-1);
        }
        return target;
    }
    
    /** 
    * @description This method returns wrapper SSV_WaitingOnCustomerCaseDetailsInput .
    * @params Takes case id, waiting time and last reminder
    * @return SSV_WaitingOnCustomerCaseDetailsInput
    */
    private static SSV_WaitingOnCustomerCaseDetailsInput buildCaseDetail(
        String caseId, DateTime waitingDate, DateTime lastReminder
    ) {
        SSV_WaitingOnCustomerCaseDetailsInput detail = new SSV_WaitingOnCustomerCaseDetailsInput();
        detail.caseId = caseId;
        detail.waitingOnCustomerDate = waitingDate;
        detail.waitingOnCustomerLastReminder = lastReminder;
        return detail;
    }
    
    /** 
    * @description This method handles first day scenario .
    * @params NA.
    * @return NA.
    */
    @IsTest
    static void testFirstReminderScenario() {
        Account sharedAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Case c = new Case(
            AccountId = sharedAccount.Id,
            Status = 'Waiting On Customer',            
            SSV_WaitingOnCustomerDate__c = getBusinessDateTimeHoursAgo(30),
            SSV_WaitingOnCustomerLastReminder__c = null
        );
        insert c;
        
        SSV_WaitingOnCustomerDatesHelper.IdListWrapper wrapper = new SSV_WaitingOnCustomerDatesHelper.IdListWrapper();
        wrapper.caseDetails = new List<SSV_WaitingOnCustomerCaseDetailsInput>{
            buildCaseDetail(c.Id, c.SSV_WaitingOnCustomerDate__c, c.SSV_WaitingOnCustomerLastReminder__c)
        };
        
        Test.startTest();
        List<SSV_WaitingOnCustomerDatesHelper.ReminderOutputWrapper> result =
            SSV_WaitingOnCustomerDatesHelper.getDates(
                new List<SSV_WaitingOnCustomerDatesHelper.IdListWrapper>{ wrapper }
            );
        Test.stopTest();
        
        System.assertEquals(1, result[0].results.size());        
    }
    
    /** 
    * @description This method handles third day scenario .
    * @params NA.
    * @return NA.
    */
    @IsTest
    static void testThirdReminderScenario() {
        Account sharedAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Case c = new Case(
            AccountId = sharedAccount.Id,
            Status = 'Waiting On Customer',            
            SSV_WaitingOnCustomerDate__c = getBusinessDateTimeHoursAgo(145),            
            SSV_WaitingOnCustomerLastReminder__c = getBusinessDateTimeHoursAgo(50)
        );
        insert c;
        
        SSV_WaitingOnCustomerDatesHelper.IdListWrapper wrapper = new SSV_WaitingOnCustomerDatesHelper.IdListWrapper();
        wrapper.caseDetails = new List<SSV_WaitingOnCustomerCaseDetailsInput>{
            buildCaseDetail(c.Id, c.SSV_WaitingOnCustomerDate__c, c.SSV_WaitingOnCustomerLastReminder__c)
        };
        
        Test.startTest();
        List<SSV_WaitingOnCustomerDatesHelper.ReminderOutputWrapper> result =
            SSV_WaitingOnCustomerDatesHelper.getDates(
                new List<SSV_WaitingOnCustomerDatesHelper.IdListWrapper>{ wrapper }
            );
        Test.stopTest();
        
        System.assertEquals(1, result[0].results.size());       
    }
    
    /** 
    * @description This method handles 4th day scenario .
    * @params NA.
    * @return NA.
    */
    @IsTest
    static void testFourthClosureScenario() {
        Account sharedAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Case c = new Case(
            AccountId = sharedAccount.Id,
            Status = 'Waiting On Customer',            
            SSV_WaitingOnCustomerDate__c = getBusinessDateTimeHoursAgo(169),            
            SSV_WaitingOnCustomerLastReminder__c = getBusinessDateTimeHoursAgo(85)
        );
        insert c;
        
        SSV_WaitingOnCustomerDatesHelper.IdListWrapper wrapper = new SSV_WaitingOnCustomerDatesHelper.IdListWrapper();
        wrapper.caseDetails = new List<SSV_WaitingOnCustomerCaseDetailsInput>{
            buildCaseDetail(c.Id, c.SSV_WaitingOnCustomerDate__c, c.SSV_WaitingOnCustomerLastReminder__c)
        };
        
        Test.startTest();
        List<SSV_WaitingOnCustomerDatesHelper.ReminderOutputWrapper> result =
            SSV_WaitingOnCustomerDatesHelper.getDates(
                new List<SSV_WaitingOnCustomerDatesHelper.IdListWrapper>{ wrapper }
            );
        Test.stopTest();
        
        System.assertEquals(1, result[0].results.size());       
    }
    
    /** 
    * @description This method handles No scenario .
    * @params NA.
    * @return NA.
    */
    @IsTest
    static void testNoReminderScenario() {
        Account sharedAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Case c = new Case(
            AccountId = sharedAccount.Id,
            Status = 'Waiting On Customer',
            SSV_WaitingOnCustomerDate__c = DateTime.now().addHours(-5),
            SSV_WaitingOnCustomerLastReminder__c = DateTime.now().addHours(-1)
        );
        insert c;
        
        SSV_WaitingOnCustomerDatesHelper.IdListWrapper wrapper = new SSV_WaitingOnCustomerDatesHelper.IdListWrapper();
        wrapper.caseDetails = new List<SSV_WaitingOnCustomerCaseDetailsInput>{
            buildCaseDetail(c.Id, c.SSV_WaitingOnCustomerDate__c, c.SSV_WaitingOnCustomerLastReminder__c)
        };
        
        Test.startTest();
        List<SSV_WaitingOnCustomerDatesHelper.ReminderOutputWrapper> result =
            SSV_WaitingOnCustomerDatesHelper.getDates(
                new List<SSV_WaitingOnCustomerDatesHelper.IdListWrapper>{ wrapper }
            );
        Test.stopTest();
        
        System.assertEquals(1, result[0].results.size());
        System.assertEquals(null, result[0].results[0].firstReminderDate);
        System.assertEquals(null, result[0].results[0].thirdReminderDate);
        System.assertEquals(null, result[0].results[0].fourthClosureDate);
    }
}