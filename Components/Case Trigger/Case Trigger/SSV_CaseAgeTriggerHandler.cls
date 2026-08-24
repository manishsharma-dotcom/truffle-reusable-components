/*******************************************************
* @Author: Suriya Soundrapandian
* @Date: July 23 2024
* @Description: Trigger handler for Case to update CaseAge records
* @Test Class : CaseAgeTriggerHandlerTest
* @Code Reviewed By : 
*================================================================================================
* Ver.      Date.               Author.                    Code Reviewer           Modification
*================================================================================================
* 1.0       Jul-23-2024         Suriya Soundrapandian			 		    	   Initial Service development
********************************************************/
public with sharing class SSV_CaseAgeTriggerHandler extends TriggerHandler{
    
    /*****************
     * @description framework method implementation.
     * @param context trigger context input
     */
    public override void afterInsert(TriggerContext context){
        
        if(this.hasRun()) {return;}

        this.markRun();
        caseAfterInsertTriggerHandler(getServiceCases((List<Case>)(context.newList)));        
    }
            
    /** 
    * @description framework method implementation.
    * @param context trigger context input
    */
    public override void beforeUpdate(TriggerContext context){
        if(Test.isRunningTest())
        {
            this.resetHasRun();
        }
        
        if(this.hasRun())
        {
            System.debug(LoggingLevel.DEBUG, 'No execution needed');
            return;
        } 
        
        this.markRun();            
        caseBeforeUpdateTriggerHandler(getServiceCases((Map<Id,Case>)context.newMap), (Map<Id,Case>)context.oldMap);
        updatePaidSupportFlag((List<Case>)context.newList,(Map<Id,Case>)context.oldMap);
    }
    
    /**
     * @description Flag to check and avoid multiple after update processing.
     */
    private Boolean isAfterUpdateRan = false; 

    /** 
     * @description framework method implementation.
     * @param context trigger context input
     */
    public override void afterUpdate(TriggerContext context){
        if(Test.isRunningTest())
        {
            isAfterUpdateRan = false;
        }

        if(isAfterUpdateRan) 
        {
            System.debug(LoggingLevel.DEBUG, 'No execution needed');
            return;
        } 
            
        isAfterUpdateRan = true;
        caseAfterUpdateTriggerHandler(getServiceCases((Map<Id,Case>)context.newMap), (Map<Id,Case>)context.oldMap);
    }
    
    
     /*****************
     * @description framework method implementation.
     * @param context trigger context input
     */
    public override void beforeInsert(TriggerContext context){
        
       
        caseBeforeInsertTriggerHandler((List<Case>)(context.newList)); 
        updatePaidSupportFlag((List<Case>)context.newList,null);
    }

    /**
     * @description Filter service cases so the logic wont apply to other case record types.
     * @param caseMap List of cases for evaluation
     * @return Map of service cases
     */
    public static Map<Id, Case> getServiceCases(Map<Id, Case> caseMap)
    {
        Id supportRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId();
        Id emergencySupportCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupportEmergencyAfterHours').getRecordTypeId();

        Map<Id, Case> serviceCases = new Map<Id, Case>();

        for(Case caseObj : caseMap.values()){
            if(caseObj.RecordTypeId == supportRecordTypeId || caseObj.RecordTypeId == emergencySupportCaseRecordTypeId){
                serviceCases.put(caseObj.Id, caseObj);
            }
        }

        return serviceCases;
    }

    /**
     * @description Filter service cases so the logic wont apply to other case record types.
     * @param cases List of cases for evaluation
     * @return List of service cases.
     */
    public static List<Case> getServiceCases(List<Case> cases)
    {
        Map<Id, Case> serviceCases = getServiceCases(new Map<Id, Case>(cases));
        return new List<Case>(serviceCases.values());
    }      
    /** 
     * @description upon new case record initial new age record will be created by this method.
     * @param newCases List of case to handle
     */
    private static void caseAfterInsertTriggerHandler(List<Case> newCases){
        if(newCases.isEmpty()) return;

       /* if(Test.isRunningTest()) 
        {
            createNewAgeRecords(newCases);
            processSlaTimerLogic(newCases);
            return;
        }*/
        
        List<Id> caseIds = new List<Id>();

        for(Case currCase : newCases)
        {
            caseIds.add(currCase.Id);
        }

        handleAfterInsertAsync(caseIds);
    }
    
    @testvisible
    @future
    private static void handleAfterInsertAsync(List<Id> caseIds)
    {
        List<Case> newCases = [SELECT Id, Status, OwnerId FROM Case WHERE Id IN :caseIds];
        createNewAgeRecords(newCases);
        //processSlaTimerLogic(newCases);
    }

    /** 
     * @description upon case update this method updates the case SSV_RecentPublicComment__c and remove the HTML tags from records.
     * @param newCaseMap updated record list
     * @param oldCaseMap record prior to update
     */
    private static void caseBeforeUpdateTriggerHandler(Map<Id, Case> newCaseMap, Map<Id, Case> oldCaseMap){
        if(newCaseMap.isEmpty()) return;
        for(Id caseId : newCaseMap.keySet())
        {
            Case newCase = newCaseMap.get(caseId);
            if(newCase.SSV_RecentPublicComment__c!=null &&
               newCase.SSV_RecentPublicComment__c != oldCaseMap.get(newCase.Id).SSV_RecentPublicComment__c
              ){
                String recentComment = newCase.SSV_RecentPublicComment__c;
                recentComment = recentComment.replaceall('</p>','=n=');
                recentComment = recentComment.replaceall('<br/>','=n=');
                recentComment = recentComment.stripHtmlTags();
                recentComment = recentComment.replaceall('=n=','\\\n');
                newCase.SSV_RecentPublicComment__c = recentComment;
            }
        }
		
       
    }

    
    /** 
     * @description upon case update this method checks the status or owner ship update and accordingly create or closes caseage records.
     * @param newCaseMap updated record list
     * @param oldCaseMap record prior to update
     */
    private static void caseAfterUpdateTriggerHandler(Map<Id, Case> newCaseMap, Map<Id, Case> oldCaseMap){
        if(newCaseMap.isEmpty()) return;

        //processSlaTimerLogic(new List<Case>(newCaseMap.values()));

        List<Case> interestedCases = new List<Case>();

        for(Id caseId : newCaseMap.keySet())
        {
            Case newCase = newCaseMap.get(caseId);
            Case prevCase = oldCaseMap.get(caseId);

            if(newCase.Status != prevCase.Status || newCase.OwnerId != prevCase.OwnerId)
            {
                interestedCases.add(newCase);
            }
        }

        if(interestedCases.isEmpty()) {
            return;
        }

        closeOldAgeRecords(interestedCases);
        createNewAgeRecords(interestedCases);
    }

    private static Set<String> closedStatuses = new Set<String>();

    /** 
     * @description This method provides whether the status is defined as Case closed status or not.
     * This method is backed by closedStatuses cache and hence it is safe to call it many times even from loop.
     * @param status status to check.
     * @return true if status is defined as closed status.
     */
    private static boolean isClosedStatus(String status)
    {
        if(closedStatuses.isEmpty())
        {
            for(CaseStatus currStatus : [SELECT Id, MasterLabel FROM CaseStatus WHERE IsClosed = true WITH SECURITY_ENFORCED])
            {
                closedStatuses.add(currStatus.MasterLabel);
            }
        }

        return closedStatuses.contains(status);
    }

    /** 
     * @description - Since case owner can be user or queue, this method based on the owner provides the name looking up both User and Queue objects.
     * @param idToNameMap map whose key is lookedup and name is populated to value
     */
    private static void resolveIdToName(Map<Id, String> idToNameMap)
    {
        for(User currUser : [SELECT Id, Name FROM User WHERE Id IN :idToNameMap.keySet() WITH SECURITY_ENFORCED])
        {
            idToNameMap.put(currUser.Id, currUser.Name);
        }

        for(Group currGroup : [SELECT Id, Name FROM Group WHERE Id IN :idToNameMap.keySet() WITH SECURITY_ENFORCED])
        {
            idToNameMap.put(currGroup.Id, currGroup.Name);
        }
    }

    /** 
     * @description - If the status is not closed, change in ownership or status will result in new Case Age record. 
     * @param newCases cases for which Age records should be created.
     */
    @testvisible
    private static void createNewAgeRecords(List<Case> newCases)
    {
        List<SSV_CaseAgeRecord__c> recordsToCreate = new List<SSV_CaseAgeRecord__c>();
        Map<Id, String> ownerIdToNameMap = new Map<Id, String>();

        for(Case currCase : newCases) {
            SSV_CaseAgeRecord__c ageRecord = new SSV_CaseAgeRecord__c();
            ageRecord.SSV_Case__C = currCase.Id;
            ageRecord.SSV_StartTime__c = Datetime.now();
            ageRecord.SSV_Status__c = currCase.Status;
            ageRecord.SSV_OwnerId__c = currCase.ownerId;
            ownerIdToNameMap.put(currCase.OwnerId, null);
            if(isClosedStatus(currCase.Status))
            {
                ageRecord.SSV_EndTime__c = Datetime.now();
            }

            recordsToCreate.add(ageRecord);
        }

        if(ownerIdToNameMap.size() > 0)
        {
            if(UserInfo.getUserType() != 'Guest')
            {
                resolveIdToName(ownerIdToNameMap);
            }
            else
            {
                SSV_CollabHelperClass.resolveIdToName(ownerIdToNameMap);
            }

            for(SSV_CaseAgeRecord__c currRec : recordsToCreate)
            {
                if(String.isBlank(currRec.SSV_OwnerId__c)) { continue; }

                currRec.SSV_OwnerName__c = ownerIdToNameMap.get(currRec.SSV_OwnerId__c);
            }
        }

        //adding the function to skip case age records for 'Weave IT User Record' 
        //for SSV-1127
        List<SSV_CaseAgeRecord__c> finalRecordsToCreate = new List<SSV_CaseAgeRecord__c>();
        for(SSV_CaseAgeRecord__c eachR : recordsToCreate){
            if(eachR.SSV_OwnerName__c != 'dev'){
                finalRecordsToCreate.add(eachR);
            }
        }

        if(finalRecordsToCreate.size() > 0) {
            
            if(UserInfo.getUserType() != 'Guest'){
                
                if (!Schema.sObjectType.SSV_CaseAgeRecord__c.isCreateable() ) {throw new SSV_ServiceUtil.SecurityException('Missing create permissions on CaseAgeRecord');}
                insert finalRecordsToCreate;

            }
            else
            {
                SSV_CollabHelperClass.insertCaseAgeRecords(finalRecordsToCreate);
            }
        }
    }

    /** 
     * @description - When the status or ownership changes previous state record will be closed using this method. 
     * @param cases cases for which old Age records should be closed/endtime should be populated.
     */
    private static void closeOldAgeRecords(List<Case> cases)
    {
        List<SSV_CaseAgeRecord__c> recordsToUpdate = new List<SSV_CaseAgeRecord__c>();

        for(SSV_CaseAgeRecord__c currRec : [SELECT Id FROM SSV_CaseAgeRecord__c WHERE SSV_Case__c IN :cases AND SSV_EndTime__c = null WITH SECURITY_ENFORCED])
        {            
            currRec.SSV_EndTime__c = Datetime.now();
            recordsToUpdate.add(currRec);
        }

        if(recordsToUpdate.size() > 0) {
            if (!Schema.sObjectType.SSV_CaseAgeRecord__c.isUpdateable() ) {
                throw new SSV_ServiceUtil.SecurityException('Missing update permissions on CaseAgeRecord');
            }
            update recordsToUpdate;
        }
    }

    
     /**
	  * @description Assiging Priority to Cases before Insert
      * @param cases List of cases
      * @return NA
      */       
    public static void caseBeforeInsertTriggerHandler(List<Case> newCases) {
        
        Set<Id> validRecordTypeIds = getValidRecordTypeIds();        
        Set<Id> accountIds = new Set<Id>();
        Map<Id, Id> caseToAccountMap = new Map<Id, Id>();
        Map<Id, Id> caseToContactMapWithoutAccount = new Map<Id, Id>();
        List<Case> validRecordTypesCases = new List<Case>();
        
        for (Case c : newCases) {
            
            if (!validRecordTypeIds.contains(c.RecordTypeId)) {
                continue; 
            }
        	           
            if (c.AccountId != null) {               
                accountIds.add(c.AccountId);
                caseToAccountMap.put(c.Id, c.AccountId);
                validRecordTypesCases.add(c);                
            }
            else if (c.ContactId != null) {                      		
                caseToContactMapWithoutAccount.put(c.ContactId, c.Id);                 
                validRecordTypesCases.add(c);
            }
        }
        
        if (validRecordTypesCases.isEmpty()){
            return;
        }
        
        // Fetch Account Ids for Cases where only ContactId is present    
        if (!caseToContactMapWithoutAccount.isEmpty()) {
            Map<Id, Contact> contacts = new Map<Id, Contact>(
                [SELECT Id, AccountId FROM Contact WHERE Id IN :caseToContactMapWithoutAccount.keySet()]
            );            
            for (Id contactId : caseToContactMapWithoutAccount.keySet()) {
                if (contacts.containsKey(contactId) && contacts.get(contactId).AccountId != null) {
                    Id caseId = caseToContactMapWithoutAccount.get(contactId);
                    caseToAccountMap.put(caseId, contacts.get(contactId).AccountId);
                    accountIds.add(contacts.get(contactId).AccountId);
                }
            }
        }
        
        List<Case> validCasesWithAccount = new List<Case>();
        for (Case c : validRecordTypesCases) {
            if (caseToAccountMap.containsKey(c.Id)) {
                validCasesWithAccount.add(c);
            }
        }        
        
        if (validCasesWithAccount.isEmpty()) {
            return;
        } 
        
        // Fetch lowest order Priority Program for each Account
        Map<Id, SSV_PriorityProgram__c> accountToPriorityProgramMap = new Map<Id, SSV_PriorityProgram__c>();
        
        List<SSV_PriorityProgram__c> priorityPrograms =  SSV_CollabHelperClass.getPriorityProgram(accountIds);
        for (SSV_PriorityProgram__c pp : priorityPrograms) {
            // Store only the first (lowest priority) record per account
            if (!accountToPriorityProgramMap.containsKey(pp.SSV_Account__c)) {
                accountToPriorityProgramMap.put(pp.SSV_Account__c, pp);
            }
        }       
        
        for (Case c : validCasesWithAccount) {
            Id accId = caseToAccountMap.get(c.Id);
            if (accountToPriorityProgramMap.containsKey(accId)) {
                SSV_PriorityProgram__c priorityProgram = accountToPriorityProgramMap.get(accId);
                c.Priority = priorityProgram.SSV_ProgramPriority__c;
                c.SSV_PriorityProgram__c = priorityProgram.Id;  // Assigning Lookup field
            }
        }
    }
    
    /**
	* @description Fetching SSV Record Types
	* @param NA
	* @return NA
	*/   
    private static Set<Id> getValidRecordTypeIds() {
        return new Set<Id>{
                Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupport').getRecordTypeId(),
                Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupportEmergencyAfterHours').getRecordTypeId()};
   }
    
     /**
	* @description Fetching Case Source
	* @param NA
	* @return NA
	*/   

    private static String getCaseSource(Case c) {
        if (userinfo.getUserid() == Label.SSV_WeaveDefaultUserId || (c.SourceId != null && String.valueOf(c.SourceId).startsWith('02s'))) {
            return 'Email';
        }
        if (c.CreatedBy.Username != null && c.CreatedBy.Username.contains('adachatbot.user@getweave.com')) {
            return 'Chat';
        }
        
        String userType = userinfo.getUserType();
        if (userType == 'PowerCustomerSuccess' || 
            userType == 'CsnOnly' || 
            userType == 'Guest') {
                return 'Web';
            }
        return 'Voice'; // Default case
    }
    
   
 	/**
	* @description To Update Paid Support Cases
	* @param New Cases and Old Cases
	* @return NA
	*/  
    public static void updatePaidSupportFlag(List<Case> newCases, Map<Id, Case> oldCases) {
        // cannot run in usermode due to guest user access. The case gets created through web (guest mode) and we cannot give access of group to guest user 
        List<Group> queuePaid = SSV_CollabHelperClass.getPaidSupportQueue();
        Set<Id> validRecordTypeIds = getValidRecordTypeIds();        

        if (queuePaid.isEmpty()) {
            return; 
        }     
    
        for (Case c : newCases) {
            if (!validRecordTypeIds.contains(c.RecordTypeId)) {
                continue; 
            }
            String caseSource = getCaseSource(c);
            if (caseSource != 'Email') { 
            	continue;
        	}  
            Boolean isNewAssignmentToQueueABC = false;
            
            // For insert: Check if the case is assigned to Paid Queue
            if (oldCases == null && c.OwnerId == queuePaid[0].Id) {
                isNewAssignmentToQueueABC = true;
            }
            // For update: Check if Owner has changed to Paid Queue
            else if (oldCases != null) {
                Case oldCase = oldCases.get(c.Id);
                if (oldCase != null && oldCase.OwnerId != c.OwnerId && c.OwnerId == queuePaid[0].Id) {
                    isNewAssignmentToQueueABC = true;
                }
            }
            
            if (isNewAssignmentToQueueABC) {                
                c.SSV_IsPaidSupportCase__c = true;               
            }
        }
    }
    
    
    /**
     * @description Starting SLA timers.
     * @param cases list of cases for evaluation
     */
   /* private static void processSlaTimerLogic(List<Case> cases)
    {
        List<Case> caseList = null;
                
        if(Auth.CommunitiesUtil.isGuestUser())
        {
            caseList = SSV_CollabHelperClass.getCasesForSlaLogic(cases);
        }
        else
        {
            caseList = [SELECT Id, CreatedDate, Origin, Status, RecordTypeId, OwnerId, SSV_Source__c, SSV_RelatedLinearRecord__c, SSV_IsDefect__c, SSV_SlaStatusChat__c, SSV_SlaStatusChatTimerStart__c, SSV_SlaStatusEmail__c, SSV_SlaStatusEmailTimerStart__c, SSV_SlaStatusEmergency__c, SSV_SlaStatusEmergencyTimerStart__c, SSV_SlaStatusLinearTicket__c, SSV_SlaStatusLinearTimerStart__c FROM Case WHERE Id IN :cases WITH SECURITY_ENFORCED];
        }
        
        Map<Id, Case> updatedCases = new Map<Id, Case>();

          //removed as part of SSV-1101
          //updatedCases.putAll(processEmailSlaTimerLogic(caseList));
        updatedCases.putAll(processChatSlaTimerLogic(caseList));
        updatedCases.putAll(processLinearSlaTimerLogic(caseList));
          //removed as part of SSV-1101
          //updatedCases.putAll(processEmergencySlaTimerLogic(caseList));

        if(updatedCases.size() > 0)
        {
            if (Auth.CommunitiesUtil.isGuestUser())
            {
                SSV_CollabHelperClass.updateCases(updatedCases.values());
            }
            else
            {
                if(!Schema.sObjectType.Case.isUpdateable() ) {
                    throw new SSV_ServiceUtil.SecurityException('Missing update permissions on Case');
                }

                update updatedCases.values();
            }
        }
    }*/

    //removed as part of SSV-1101 -- Start    
    /**
     * @description Email SLA timer start and stop logic.
     * @param caseList list of cases to evaluate
     * @return affected casemap
     */    
   /* private static Map<Id, Case> processEmailSlaTimerLogic(List<Case> caseList)
    {
        Integer slaMinutes = (Integer) SSV_ServiceSetting__mdt.getInstance('Global').SSV_SlaEmailDurationInMins__c;

        Map<Id, Case> updatedCases = new Map<Id, Case>();

        List<Id> toStartTimer = new List<Id>();

        for(Case currCase : caseList)
        {
            if(currCase.SSV_Source__c != 'Email') { continue; }

            if(currCase.Status == 'New' && currCase.SSV_SlaStatusEmail__c == 'Not Applicable')
            {
                toStartTimer.add(currCase.Id);
                currCase.SSV_SlaStatusEmail__c = 'Timer On';
                currCase.SSV_SlaStatusEmailTimerStart__c = Datetime.now();
                updatedCases.put(currCase.Id, currCase);
            }
            else if(currCase.Status != 'New' && currCase.SSV_SlaStatusEmail__c == 'Timer On')
            {
                DateTime createdDate = currCase.SSV_SlaStatusEmailTimerStart__c;
                if(createdDate.addMinutes(slaMinutes).getTime() > DateTime.now().getTime() )
                {
                    currCase.SSV_SlaStatusEmail__c = 'Met';
                }
                else
                {
                    currCase.SSV_SlaStatusEmail__c = 'Violated';
                }
                updatedCases.put(currCase.Id, currCase);
            }
        }

        return updatedCases;
    }*/
    //removed as part of SSV-1101 -- END    

    /**
     * @description Chat SLA timer start and stop logic.
     * @param caseList list of cases to evaluate
     * @return affected casemap
     */   
    /*@testvisible
    private static Map<Id, Case> processChatSlaTimerLogic(List<Case> caseList)
    {
        Integer slaMinutes = (Integer) SSV_ServiceSetting__mdt.getInstance('Global').SSV_SlaChatDurationInMins__c;

        Map<Id, Case> updatedCases = new Map<Id, Case>();

        List<Id> toStartTimer = new List<Id>();

        for(Case currCase : caseList)
        {
            if(currCase.SSV_Source__c != 'Chat') { continue; }

            if(currCase.Status == 'New' && currCase.SSV_SlaStatusChat__c == 'Not Applicable')
            {
                toStartTimer.add(currCase.Id);
                currCase.SSV_SlaStatusChat__c = 'Timer On';
                currCase.SSV_SlaStatusChatTimerStart__c = Datetime.now();
                updatedCases.put(currCase.Id, currCase);
            }
            else if(currCase.Status != 'New' && currCase.SSV_SlaStatusChat__c == 'Timer On')
            {
                DateTime createdDate = currCase.SSV_SlaStatusChatTimerStart__c;
                if(createdDate.addMinutes(slaMinutes).getTime() > DateTime.now().getTime() )
                {
                    currCase.SSV_SlaStatusChat__c = 'Met';
                }
                else
                {
                    currCase.SSV_SlaStatusChat__c = 'Violated';
                }
                updatedCases.put(currCase.Id, currCase);
            }
        }

        return updatedCases;
    }*/


 //removed as part of SSV-1101 -- Start    
     /**
     * @description Emergency SLA timer start and stop logic.
     * @param caseList list of cases to evaluate
     * @return affected casemap
     */    
     /*private static Map<Id, Case> processEmergencySlaTimerLogic(List<Case> caseList)
    {
        Id emergencySupportCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('SSV_CustomerSupportEmergencyAfterHours').getRecordTypeId();

        Integer slaMinutes = (Integer) SSV_ServiceSetting__mdt.getInstance('Global').SSV_SlaEmergencyDurationInMins__c;

        Map<Id, Case> updatedCases = new Map<Id, Case>();

        List<Id> toStartTimer = new List<Id>();

        for(Case currCase : caseList)
        {
            if(currCase.RecordTypeId != emergencySupportCaseRecordTypeId) { continue; }

            if(currCase.Status == 'New' && currCase.SSV_SlaStatusEmergency__c == 'Not Applicable')
            {
                toStartTimer.add(currCase.Id);
                currCase.SSV_SlaStatusEmergency__c = 'Timer On';
                currCase.SSV_SlaStatusEmergencyTimerStart__c = Datetime.now();
                updatedCases.put(currCase.Id, currCase);
            }
            else if(currCase.Status != 'New' && currCase.SSV_SlaStatusEmergency__c == 'Timer On')
            {
                DateTime createdDate = currCase.SSV_SlaStatusEmergencyTimerStart__c;
                if(createdDate.addMinutes(slaMinutes).getTime() > DateTime.now().getTime() )
                {
                    currCase.SSV_SlaStatusEmergency__c = 'Met';
                }
                else
                {
                    currCase.SSV_SlaStatusEmergency__c = 'Violated';
                }
                updatedCases.put(currCase.Id, currCase);
            }
        }

        return updatedCases;
    }*/
    //removed as part of SSV-1101 -- END    

        /**
     * @description Linear URL SLA timer start and stop logic.
     * @param caseList list of cases to evaluate
     * @return affected casemap
     */    
    /*private static Map<Id, Case> processLinearSlaTimerLogic(List<Case> caseList)
    {
        Integer slaMinutes = (Integer) SSV_ServiceSetting__mdt.getInstance('Global').SSV_SlaLinearTicketDurationInMins__c;

        Set<Id> tier2Users = getTier2Users(caseList);

        Map<Id, Case> updatedCases = new Map<Id, Case>();

        List<Id> toStartTimer = new List<Id>();

        for(Case currCase : caseList)
        {
           
            
            if(currCase.SSV_IsDefect__c == false)             
            {
                if(currCase.SSV_SlaStatusLinearTicket__c != 'Not Applicable')
                {
                    currCase.SSV_SlaStatusLinearTicket__c = 'Not Applicable';
                    currCase.SSV_SlaStatusLinearTimerStart__c = Datetime.now();
                    updatedCases.put(currCase.Id, currCase);
                }
                continue;
            }

            if(!tier2Users.contains(currCase.OwnerId)) { continue; }

            if(String.isEmpty(currCase.SSV_RelatedLinearRecord__c) && currCase.SSV_SlaStatusLinearTicket__c == 'Not Applicable')
            {
                toStartTimer.add(currCase.Id);
                currCase.SSV_SlaStatusLinearTicket__c = 'Timer On';
                currCase.SSV_SlaStatusLinearTimerStart__c = Datetime.now();
                updatedCases.put(currCase.Id, currCase);
            }
            else if(!String.isEmpty(currCase.SSV_RelatedLinearRecord__c) && currCase.SSV_SlaStatusLinearTicket__c == 'Timer On')
            {
                DateTime createdDate = currCase.SSV_SlaStatusLinearTimerStart__c;
                if(createdDate.addMinutes(slaMinutes).getTime() > DateTime.now().getTime() )
                {
                    currCase.SSV_SlaStatusLinearTicket__c = 'Met';
                }
                else
                {
                    currCase.SSV_SlaStatusLinearTicket__c = 'Violated';
                }
                updatedCases.put(currCase.Id, currCase);
            }
        }

        return updatedCases;
    }*/

    /**
     * @description get the Tier2 user for the case.
     * @param caseList Input cases
     * @return List of case owners who are Tier2 users.
     */
    /*private static Set<Id> getTier2Users(List<Case> caseList)
    {
        Set<Id> userIds = new Set<Id>();

        for(Case currCase : caseList)
        {
            userIds.add(currCase.OwnerId);
        }

        Set<Id> ret = new Set<Id>();
        for(PermissionSetAssignment currAssignment : [SELECT AssigneeId FROM PermissionSetAssignment WHERE AssigneeId IN :userIds AND PermissionSetGroup.DeveloperName = 'SSV_Tier2ServiceUser'])
        {
            ret.add(currAssignment.AssigneeId);
        }

        return ret;
    }*/
    
    
}