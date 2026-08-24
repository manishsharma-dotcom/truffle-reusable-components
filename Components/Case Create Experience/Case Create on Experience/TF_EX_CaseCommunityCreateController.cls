/**
 * @class       TF_EX_CaseCommunityCreateController
 * @testClass   TF_EX_CaseCommunityCreateControllerTest
 * @description Controller for the TF_EX_CaseCommunityCreate LWC on Experience Cloud.
 *              Handles form initialisation and case creation including file attachments
 *              and collaborator (CaseTeamMember) assignment.
 *              Declared without sharing intentionally — community guest/portal users
 *              do not own records and sharing rules would prevent required data access.
 *
 * @author      Truffle Consulting
 */
public without sharing class TF_EX_CaseCommunityCreateController {

    /**
     * @description Returns all data required to render the case creation form in a
     *              single Apex call: current user details, linked accounts, permitted
     *              case record types, and the Collaborators CaseTeamRole Id.
     *
     * @return      InitialData wrapper containing user, account, record type and role data.
     */
    @AuraEnabled(cacheable=false)
    public static InitialData getInitialData() {
        InitialData data = new InitialData();
        Id currentUserId = UserInfo.getUserId();

        User currentUser = [
            SELECT Id, ContactId, Email, Phone,
                   Contact.Phone, Contact.FirstName, Contact.LastName
            FROM   User
            WHERE  Id = :currentUserId
            LIMIT  1
        ];
        data.currentUserEmail        = currentUser.Email;
        data.currentUserContactPhone = currentUser.Phone;
        data.currentUserContactId    = currentUser.ContactId;

        List<AccountContactRelation> acrs = [
            SELECT AccountId, Account.Name, IsDirect, IsActive
            FROM   AccountContactRelation
            WHERE  ContactId = :currentUser.ContactId AND IsActive=TRUE
            ORDER  BY Account.Name ASC
        ];

        List<AccountOption> accounts      = new List<AccountOption>();
        String              primaryAcctId = null;

        for (AccountContactRelation acr : acrs) {
            accounts.add(new AccountOption(acr.AccountId, acr.Account.Name, acr.IsDirect));
            if (acr.IsDirect) primaryAcctId = String.valueOf(acr.AccountId);
        }

        data.primaryAccountId = primaryAcctId;
        data.accounts         = accounts;
        data.isSingleAccount  = (accounts.size() == 1);

        if (data.isSingleAccount) {
            data.singleAccountId   = String.valueOf(accounts[0].accountId);
            data.singleAccountName = accounts[0].accountName;
        }

        /*
        // COLLAB_SUPPRESSED: CaseTeamRole lookup disabled.
        // Uncomment to re-enable collaborator role resolution.
        List<CaseTeamRole> roles = [
        SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1
        ];
        data.caseTeamRoleId = roles.isEmpty() ? null : String.valueOf(roles[0].Id);
        */

        data.recordTypes = [
            SELECT Id, Name, DeveloperName
            FROM   RecordType
            WHERE  SObjectType = 'Case'
            AND    DeveloperName IN (
                'Customer_Support_New', 'Enrollments_Support',
                'Integration_Request', 'Training','Digital_Marketing_Support', 'Account_Invoice_Support', 'Website_Design_Change'
            )
            ORDER  BY Name ASC
        ];

        return data;
    }

    /**
     * @description Creates a new Case with optional file attachments and collaborators.
     *
     * @param  recordTypeId        Record type Id for the Case.
     * @param  accountId           Account Id to associate with the Case.
     * @param  contactId           Contact Id for the Case.
     * @param  contactPhone        Contact phone number.
     * @param  userEmail           Submitting user email address.
     * @param  category            Contact Code Category picklist value.
     * @param  issue               Contact Code picklist value.
     * @param  issueDetail         Sub Contact Code picklist value.
     * @param  subject             Case subject.
     * @param  description         Case description.
     * @param  collaboratorUserIds List of User Ids to add as CaseTeamMembers.
     * @param  contentDocumentIds  List of ContentDocument Ids to link to the Case.
     * @param  caseTeamRoleId      CaseTeamRole Id to assign to all collaborators.
     *
     * @return CaseResult wrapper containing the new Case Id and CaseNumber.
     */
    @AuraEnabled
    public static CaseResult createCase(
        String       recordTypeId,
        String       accountId,
        String       contactId,
        String       contactPhone,
        String       userEmail,
        String       category,
        String       issue,
        String       issueDetail,
        String       subject,
        String       description,
        List<String> collaboratorUserIds,
        List<String> contentDocumentIds,
        String       caseTeamRoleId
    ) {
        Case newCase                     = new Case();
        newCase.RecordTypeId             = recordTypeId;
        newCase.AccountId                = accountId;
        newCase.ContactId                = contactId;
        newCase.Contact_Code_Category__c = category;
        newCase.Contact_Code__c          = issue;
        newCase.Sub_Contact_Code__c      = issueDetail;
        newCase.Subject                  = subject;
        newCase.Description              = description;
        newCase.TF_EX_Description__c     = description;
        newCase.Status                   = 'New';
        newCase.Origin                   = 'Community';
        insert newCase;

        List<Case> inserted = [SELECT Id, CaseNumber FROM Case WHERE Id = :newCase.Id LIMIT 1];
        if (inserted.isEmpty()) {
            throw new AuraHandledException('Case was created but could not be retrieved.');
        }
        Case createdCase = inserted[0];

        if (contentDocumentIds != null && !contentDocumentIds.isEmpty()) {
            List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
            for (String cdId : contentDocumentIds) {
                if (String.isNotBlank(cdId)) {
                    cdls.add(new ContentDocumentLink(
                        ContentDocumentId = cdId,
                        LinkedEntityId    = createdCase.Id,
                        ShareType         = 'V'
                    ));
                }
            }
            if (!cdls.isEmpty()) insert cdls;
        }

        /*if (collaboratorUserIds != null && !collaboratorUserIds.isEmpty()
                && String.isNotBlank(caseTeamRoleId)) {
            Set<Id> uniqueIds = new Set<Id>();
            for (String uid : collaboratorUserIds) {
                if (String.isNotBlank(uid)) uniqueIds.add((Id) uid);
            }
            List<CaseTeamMember> ctms = new List<CaseTeamMember>();
            for (Id uid : uniqueIds) {
                ctms.add(new CaseTeamMember(
                    ParentId   = createdCase.Id,
                    MemberId   = uid,
                    TeamRoleId = caseTeamRoleId
                ));
            }
            if (!ctms.isEmpty()) insert ctms;
        }*/
        
        /*
        // COLLAB_SUPPRESSED: CaseTeamMember insertion disabled.
        // Uncomment the block below to re-enable collaborator assignment on case create.
        if (collaboratorUserIds != null && !collaboratorUserIds.isEmpty()
        && String.isNotBlank(caseTeamRoleId)) {
        Set<Id> uniqueIds = new Set<Id>();
        for (String uid : collaboratorUserIds) {
            if (String.isNotBlank(uid)) uniqueIds.add((Id) uid);
        }
        Case insertedCase = [SELECT OwnerId FROM Case WHERE Id = :createdCase.Id LIMIT 1];
        uniqueIds.remove(insertedCase.OwnerId);
        if (!uniqueIds.isEmpty()) {
            List<CaseTeamMember> alreadyAdded = [
                SELECT MemberId FROM CaseTeamMember
                WHERE ParentId = :createdCase.Id AND MemberId IN :uniqueIds
            ];
            for (CaseTeamMember existing : alreadyAdded) {
                uniqueIds.remove(existing.MemberId);
            }
        }
        List<CaseTeamMember> ctms = new List<CaseTeamMember>();
        for (Id uid : uniqueIds) {
            ctms.add(new CaseTeamMember(
                ParentId   = createdCase.Id,
                MemberId   = uid,
                TeamRoleId = caseTeamRoleId
            ));
        }
        if (!ctms.isEmpty()) insert ctms;
        }
        END COLLAB_SUPPRESSED */

        return new CaseResult(String.valueOf(createdCase.Id), createdCase.CaseNumber);
    }

    /**
     * @description Returns active community users linked to a given account, excluding
     *              the current user. Used to populate the collaborator picker on the
     *              case creation form.
     *
     * @param  accountId  Id of the Account whose contacts should be searched.
     *
     * @return List of CollaboratorOption wrappers representing eligible users.
     */
    @AuraEnabled(cacheable=false)
    public static List<CollaboratorOption> getCollaborators(String accountId) {
            // COLLAB_SUPPRESSED: method body disabled.
        // Uncomment below to re-enable collaborator loading.
        /*
        if (String.isBlank(accountId)) return new List<CollaboratorOption>();
        Id currentUserId = UserInfo.getUserId();
        List<AccountContactRelation> acrs = [
            SELECT ContactId FROM AccountContactRelation WHERE AccountId = :accountId
        ];
        Set<Id> contactIds = new Set<Id>();
        for (AccountContactRelation acr : acrs) { contactIds.add(acr.ContactId); }
        if (contactIds.isEmpty()) return new List<CollaboratorOption>();
        String customerProfileId      = System.Label.TF_CustomerUserProfileId;
        String customerAdminProfileId = System.Label.TF_CustomerAdminUserProfileId;
        List<User> users = [
            SELECT Id, FirstName, LastName, Email, Username FROM User
            WHERE ContactId IN :contactIds
            AND (ProfileId = :customerProfileId OR ProfileId = :customerAdminProfileId)
            AND IsActive = true AND Id != :currentUserId
            ORDER BY FirstName ASC, LastName ASC
        ];
        List<CollaboratorOption> result = new List<CollaboratorOption>();
        for (User u : users) {
            result.add(new CollaboratorOption(
                String.valueOf(u.Id),
                u.FirstName + ' ' + u.LastName + ' (' + u.Username + ')',
                new List<String>{ accountId }
            ));
        }
        return result;
        */
        return new List<CollaboratorOption>(); // COLLAB_SUPPRESSED: stub return
    }

    // ── Inner Classes ────────────────────────────────────────────────────────

    /** @description Wrapper returned by getInitialData containing all form dependencies. */
    public class InitialData {
        @AuraEnabled public String              currentUserEmail;
        @AuraEnabled public String              currentUserContactPhone;
        @AuraEnabled public String              currentUserContactId;
        @AuraEnabled public Boolean             isSingleAccount;
        @AuraEnabled public String              singleAccountId;
        @AuraEnabled public String              singleAccountName;
        @AuraEnabled public String              primaryAccountId;
        @AuraEnabled public List<AccountOption> accounts;
        @AuraEnabled public List<RecordType>    recordTypes;
        @AuraEnabled public String              caseTeamRoleId;
    }

    /** @description Represents an Account option in the account selection dropdown. */
    public class AccountOption {
        @AuraEnabled public String  accountId;
        @AuraEnabled public String  accountName;
        @AuraEnabled public Boolean isPrimary;

        /**
         * @param id        Account Id.
         * @param name      Account Name.
         * @param isPrimary True if this is the user's direct (primary) account.
         */
        public AccountOption(Id id, String name, Boolean isPrimary) {
            this.accountId   = String.valueOf(id);
            this.accountName = name;
            this.isPrimary   = isPrimary;
        }
    }

    /** @description Represents a selectable collaborator user in the picker. */
    public class CollaboratorOption {
        @AuraEnabled public String       userId;
        @AuraEnabled public String       label;
        @AuraEnabled public List<String> accountIds;

        /**
         * @param userId     Salesforce User Id.
         * @param label      Display name shown in the picker.
         * @param accountIds Account Ids this user is associated with.
         */
        public CollaboratorOption(String userId, String label, List<String> accountIds) {
            this.userId     = userId;
            this.label      = label;
            this.accountIds = accountIds;
        }
    }

    /** @description Returned by createCase containing the new Case Id and CaseNumber. */
    public class CaseResult {
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseNumber;

        /**
         * @param caseId     Salesforce Id of the newly created Case.
         * @param caseNumber Auto-generated CaseNumber of the newly created Case.
         */
        public CaseResult(String caseId, String caseNumber) {
            this.caseId     = caseId;
            this.caseNumber = caseNumber;
        }
    }
}