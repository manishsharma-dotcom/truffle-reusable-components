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
public without sharing class SSV_WaitingOnCustomerDatesHelper {
    
	/**
     * @description Handles Input Parameter defined in SSV_WaitingOnCustomerCaseDetailsInput.
     * @param caseMap List of cases and details for evaluation.
     * @return NA
     */
    public class IdListWrapper {
        @InvocableVariable(required=true)
        public List<SSV_WaitingOnCustomerCaseDetailsInput> caseDetails;
    }
   
    /**
     * @description Called from Flow SSV_WaitingOnCustomerReminderEmails
     * @param List of wrapper IdListWrapper with cases details for evaluation.
     * @return List of ReminderOutputWrapper.
     */
     @InvocableMethod(label='Calculate Reminder Dates for Cases')
    public static List<ReminderOutputWrapper> getDates(List<IdListWrapper> requests) {
        WaitingReminderHours reminderHours = SSV_WaitingOnCustomerDatesHelper.getReminderHours();
        Integer h24 = reminderHours.twentyFourHours;
        Integer h72 = reminderHours.SeventyTwoHours;
        Integer h96 = reminderHours.NinetySixHours;
        system.debug(reminderHours + '24' + reminderHours.twentyFourHours +'72' + reminderHours.SeventyTwoHours + '96' + reminderHours.NinetySixHours);
        ReminderOutputWrapper outputWrapper = new ReminderOutputWrapper();
        outputWrapper.results = new List<SSV_ReminderDatesOuput>();
        List<SSV_WaitingOnCustomerCaseDetailsInput> caseDetails = requests[0].caseDetails;
        for(SSV_WaitingOnCustomerCaseDetailsInput cd: caseDetails){ 
            DateTime statusSetDate = cd.waitingOnCustomerDate;
            DateTime lastReminderDate = cd.waitingOnCustomerLastReminder;
            DateTime nowDT = System.now();
            SSV_ReminderDatesOuput result = new SSV_ReminderDatesOuput();
            Long hoursSinceWaitingStatus = getBusinessHoursBetween(statusSetDate, nowDT);
            
            Long hoursSinceLastReminder = lastReminderDate != null ? getBusinessHoursBetween(statusSetDate,lastReminderDate) : null;
             result.caseId = cd.caseId;            
            
            // 4th Closure (first priority) — 4 business days since waiting date
            if (lastReminderDate != null && hoursSinceWaitingStatus >= h96 && hoursSinceLastReminder < h96) {
                result.fourthClosureDate = nowDT.date();
                system.debug(result);
            }
            // Third Reminder — 2 business days since last reminder
            else if (lastReminderDate != null && hoursSinceWaitingStatus >= h72 && hoursSinceLastReminder < h72) {
                result.thirdReminderDate = nowDT.date();
                system.debug(result);
            }
            // First Reminder — 1 business day since waiting date, no last reminder yet
            else if (lastReminderDate == null && hoursSinceWaitingStatus >= h24 && (hoursSinceLastReminder < h24 ||hoursSinceLastReminder == null)) {
                result.firstReminderDate = nowDT.date();
                system.debug(result);
            }
            outputWrapper.results.add(result);
            
        }     
  		system.debug(outputWrapper.results);
        return new List<ReminderOutputWrapper>{outputWrapper};
            
    }
    
    /**
     * @description Called from other methods in this class
     * @param Start Datetime and End Datetime.
     * @return Time difference in hours.
     */
    private static Long getBusinessHoursBetween(DateTime startDT, DateTime endDT) {
        if (startDT == null || endDT == null || endDT <= startDT) return 0;
        
        Long totalHours = 0;
        DateTime temp = startDT;
        
        while (temp < endDT) {
            String dayName = temp.format('E');
            if (dayName != 'Sat' && dayName != 'Sun') {
                DateTime nextHour = temp.addHours(1);
                if (nextHour <= endDT) {
                    totalHours++;
                }
            }
            temp = temp.addHours(1);
        }
        return totalHours;
    }
    
    /**
     * @description Called from other methods in this class to call SSV_ReminderDatesOuput for Output
     * @param NA
     * @return NA
     */
    public class ReminderOutputWrapper {
        @InvocableVariable
        public List<SSV_ReminderDatesOuput> results;
    }
    
    /**
     * @description to store hours values from custom metadata
     * @param NA
     * @return NA
     */
    public class WaitingReminderHours {
    public Integer twentyFourHours;
    public Integer SeventyTwoHours;
    public Integer NinetySixHours;
	}
    
    /**
     * @description returns WaitingReminderHours wrapper
     * @param NA
     * @return NA
     */
    public static WaitingReminderHours getReminderHours() {
        SSV_ServiceSetting__mdt settings =  SSV_ServiceSetting__mdt.getInstance('SSV_WaitingOnCustomerReminderHours');
        return (WaitingReminderHours) JSON.deserialize(settings.SSV_WaitingOnCustomerHours__c, WaitingReminderHours.class);
    }
}