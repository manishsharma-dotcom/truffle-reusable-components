/**
 * @class       TF_EX_CaseCommunityDetailController
 * @testClass   TF_EX_CaseCommunityDetailControllerTest
 * @createdBy   Truffle Consulting
 * @description Apex controller for the TF_EX_CaseCommunityDetail LWC used in Experience Cloud.
 *              Handles Case detail retrieval, closure, reopening, and collaborator management
 *              via CaseTeamMember records. Declared without sharing to allow community users
 *              to perform Case operations regardless of record-level access.
 */
public without sharing class TF_EX_CaseCommunityDetailController {

    public class CollaboratorInfoComparator implements Comparator<CollaboratorInfo> {
        public Integer compare(CollaboratorInfo a, CollaboratorInfo b) {
            return a.userName.compareTo(b.userName);
        }
    }

    /**
     * @description Retrieves Case fields, existing CaseTeamMember collaborators,
     *              the CaseTeamRole Id for the 'Collaborators' role, and a flag
     *              indicating whether the Case is eligible to be reopened
     *              (closed within the last 5 business days).
     * @param       caseId  Id of the Case record to retrieve.
     * @return      CaseDetailResult — contains the Case record, collaborator list,
     *              CaseTeamRole Id, and canReopen flag.
     */
    @AuraEnabled(cacheable=false)
    public static CaseDetailResult getCaseDetail(Id caseId) {
        Case c = [
            SELECT Id, CaseNumber, Status, IsClosed, Subject,
                   TF_EX_Description__c, ContactPhone, IsEscalated,
                   AccountId, ContactId, ClosedDate
            FROM   Case
            WHERE  Id = :caseId
            LIMIT  1
        ];

                /*
        // COLLAB_SUPPRESSED: CaseTeamMember query and collaborator list building disabled.
        // Uncomment below to re-enable collaborator display on case detail.
        List<CaseTeamMember> ctmList = [
            SELECT Id, MemberId FROM CaseTeamMember WHERE ParentId = :caseId
        ];
        Set<Id> memberIds = new Set<Id>();
        for (CaseTeamMember ctm : ctmList) memberIds.add(ctm.MemberId);
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, FirstName, LastName, Username FROM User WHERE Id IN :memberIds
        ]);
        List<CollaboratorInfo> collabs = new List<CollaboratorInfo>();
        for (CaseTeamMember ctm : ctmList) {
            User u = userMap.get(ctm.MemberId);
            String displayName = u != null
                ? u.FirstName + ' ' + u.LastName + ' (' + u.Username + ')'
                : String.valueOf(ctm.MemberId);
            collabs.add(new CollaboratorInfo(ctm.Id, ctm.MemberId, displayName));
        }
        collabs.sort(new CollaboratorInfoComparator());
        Id roleId = null;
        List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;
        END COLLAB_SUPPRESSED */

        Boolean canReopen = false;
        if (c.IsClosed && c.ClosedDate != null) {
            Date closedDate = c.ClosedDate.date();
            Date today      = Date.today();
            Integer bizDays = businessDaysBetween(closedDate, today);
            canReopen = (bizDays <= 5);
        }

        CaseDetailResult result    = new CaseDetailResult();
        result.caseRecord          = c;
        result.collaborators  = new List<CollaboratorInfo>(); // COLLAB_SUPPRESSED: empty list
        result.caseTeamRoleId = '';                           // COLLAB_SUPPRESSED: blank
        result.canReopen           = canReopen;
        return result;
    }

    /**
     * @description Returns the active Closed_Reason__c picklist values filtered
     *              to the allowed set ('Resolved', 'No Longer Needed').
     *              Retrieved via Schema describe to avoid hardcoding labels.
     * @return      List<PicklistOption> — value/label pairs for the allowed picklist entries.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getClosedReasonOptions() {
        Set<String> allowed = new Set<String>{ 'Resolved', 'No Longer Needed' };
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry :
             Case.Closed_Reason__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && allowed.contains(entry.getValue())) {
                options.add(new PicklistOption(entry.getValue(), entry.getLabel()));
            }
        }
        return options;
    }

    /**
     * @description Sets the Case Status to 'Closed' and populates Closed_Reason__c.
     *              Throws AuraHandledException if closedReason is blank.
     * @param       caseId        Id of the Case to close.
     * @param       closedReason  Value for the Closed_Reason__c picklist field.
     */
    @AuraEnabled
    public static void closeCase(Id caseId, String closedReason) {
        if (String.isBlank(closedReason)) {
            throw new AuraHandledException('A Closed Reason is required to close the case.');
        }
        update new Case(
            Id               = caseId,
            Status           = 'Closed',
            Closed_Reason__c = closedReason
        );
    }

    /**
     * @description Reopens a Case by posting the provided reason as a rich-text
     *              Chatter FeedItem and updating the Status to 'ReOpened'.
     *              The reason is recorded in Chatter only and not stored on the Case record.
     *              Throws AuraHandledException if reason is blank.
     * @param       caseId  Id of the Case to reopen.
     * @param       reason  Reopen reason posted to the Case Chatter feed.
     */
    @AuraEnabled
    public static void reopenCase(Id caseId, String reason) {
        if (String.isBlank(reason)) {
            throw new AuraHandledException('A reason is required to reopen the case.');
        }

        FeedItem fi = new FeedItem();
        fi.ParentId   = caseId;
        fi.Body       = '<b>Reopen Reason:</b><p>&nbsp;</p>' + reason;
        fi.Type       = 'TextPost';
        fi.IsRichText = true;
        fi.Visibility = 'AllUsers';
        insert fi;

        update new Case(Id = caseId, Status = 'ReOpened');
    }

    /**
     * @description Creates a CaseTeamMember linking the given User to the Case
     *              with the specified CaseTeamRole. Returns the existing CaseTeamMember Id
     *              without creating a duplicate if the User is already a team member.
     * @param       caseId      Id of the Case to add the collaborator to.
     * @param       userId      Id of the User to add as a collaborator.
     * @param       teamRoleId  Id of the CaseTeamRole to assign to the new member.
     * @return      String — Id of the new or existing CaseTeamMember record.
     */
    @AuraEnabled
    public static String addCollaborator(Id caseId, Id userId, Id teamRoleId) {
            // COLLAB_SUPPRESSED: method body disabled.
        // Uncomment below to re-enable:
        /*
        List<CaseTeamMember> existing = [
            SELECT Id FROM CaseTeamMember WHERE ParentId = :caseId AND MemberId = :userId LIMIT 1
        ];
        if (!existing.isEmpty()) return String.valueOf(existing[0].Id);
        CaseTeamMember ctm = new CaseTeamMember(
            ParentId = caseId, MemberId = userId, TeamRoleId = teamRoleId
        );
        insert ctm;
        return String.valueOf(ctm.Id);
        */
        return ''; // COLLAB_SUPPRESSED: stub return
    }

    /**
     * @description Removes a CaseTeamMember record by its Id,
     *              unlinking the collaborator from the Case.
     * @param       caseTeamMemberId  Id of the CaseTeamMember record to delete.
     */
    @AuraEnabled
    public static void removeCollaborator(Id caseTeamMemberId) {
        // COLLAB_SUPPRESSED: method body disabled.
        // Uncomment below to re-enable:
        // delete new CaseTeamMember(Id = caseTeamMemberId);
    }

    /**
     * @description Returns true if the given Date falls on a weekday (Monday–Friday).
     *              Uses Date.toStartOfWeek() which returns the Sunday of the week,
     *              giving offsets 0 (Sunday) through 6 (Saturday).
     * @param       d  The Date to evaluate.
     * @return      Boolean — true if the date is a weekday, false if weekend.
     */
    private static Boolean isWeekday(Date d) {
        Integer offset = d.toStartOfWeek().daysBetween(d);
        return offset >= 1 && offset <= 5;
    }

    /**
     * @description Counts the number of business days (Monday–Friday) between
     *              two dates, inclusive of both endpoints.
     *              Intended for small ranges only — called exclusively for spans
     *              of up to approximately 10 calendar days.
     * @param       startDate  Start of the date range.
     * @param       endDate    End of the date range.
     * @return      Integer — number of weekdays in the range.
     */
    private static Integer businessDaysBetween(Date startDate, Date endDate) {
        Integer count = 0;
        Date    d     = startDate;
        while (d <= endDate) {
            if (isWeekday(d)) count++;
            d = d.addDays(1);
        }
        return count;
    }

    /**
     * @description Result wrapper returned by getCaseDetail.
     *              Carries the Case record, sorted collaborator list,
     *              CaseTeamRole Id for new member inserts, and the canReopen eligibility flag.
     */
    public class CaseDetailResult {
        @AuraEnabled public Case                   caseRecord;
        @AuraEnabled public List<CollaboratorInfo> collaborators;
        @AuraEnabled public String                 caseTeamRoleId;
        @AuraEnabled public Boolean                canReopen;
    }

    /**
     * @description Lightweight collaborator wrapper returned inside CaseDetailResult.
     *              Carries the CaseTeamMember Id, the User Id, and a formatted display name.
     */
    public class CollaboratorInfo {
        @AuraEnabled public String caseTeamMemberId;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        public CollaboratorInfo(Id ctmId, Id uid, String name) {
            this.caseTeamMemberId = String.valueOf(ctmId);
            this.userId           = String.valueOf(uid);
            this.userName         = name;
        }
    }

    /**
     * @description Picklist value/label pair returned by getClosedReasonOptions
     *              for use in the LWC combobox.
     */
    public class PicklistOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        public PicklistOption(String v, String l) {
            this.value = v;
            this.label = l;
        }
    }
}