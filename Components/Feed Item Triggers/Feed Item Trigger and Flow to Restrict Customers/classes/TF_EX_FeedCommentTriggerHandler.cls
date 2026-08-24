/**
 * @class       TF_EX_FeedCommentTriggerHandler
 * @testClass   TF_EX_FeedCommentTriggerHandlerTest
 * @createdBy   Truffle Consulting
 * @description Trigger handler for the FeedComment object.
 *              Prevents community users from adding or updating comments on Cases
 *              that have been closed for more than 5 business days.
 *              Only enforced for users on the 'Customer User' and 'Customer User Admin' profiles.
 *              Intended to be called from a FeedComment before-insert and before-update trigger.
 */
public with sharing class TF_EX_FeedCommentTriggerHandler {

    private static final Set<String> ALLOWED_PROFILES = new Set<String>{
        'Customer User', 'Customer User Admin'
    };
    private static final Integer BUSINESS_DAYS_LIMIT = 5;
    private static final String ERROR_MSG =
        'You Cannot Add or Update Comment on Closed Case, Please Create a new Case';

    /**
     * @description Entry point called by the FeedComment trigger.
     *              Applies the closed-case comment restriction to the provided list of FeedComments.
     *              Exits early if the running user's profile is not in the allowed set,
     *              if no FeedItem IDs are present, if none of the FeedItems are parented by a Case,
     *              or if none of the related Cases exceed the business day closure limit.
     * @param       newComments  List of FeedComment records from Trigger.new.
     */
    public static void handle(List<FeedComment> newComments) {
        String profileName = getCurrentProfileName();
        if (!ALLOWED_PROFILES.contains(profileName)) return;

        Set<Id> feedItemIds = new Set<Id>();
        for (FeedComment fc : newComments) {
            if (fc.FeedItemId != null) feedItemIds.add(fc.FeedItemId);
        }
        if (feedItemIds.isEmpty()) return;

        Map<Id, Id> feedItemToCaseId = new Map<Id, Id>();
        for (FeedItem fi : [
            SELECT Id, ParentId FROM FeedItem
            WHERE Id IN :feedItemIds AND ParentId != null
        ]) {
            if (((String) fi.ParentId).startsWith('500')) {
                feedItemToCaseId.put(fi.Id, fi.ParentId);
            }
        }
        if (feedItemToCaseId.isEmpty()) return;

        Set<Id> caseIds = new Set<Id>(feedItemToCaseId.values());
        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id, IsClosed, ClosedDate FROM Case
            WHERE Id IN :caseIds AND IsClosed = TRUE AND ClosedDate != NULL
        ]);

        Date today = Date.today();
        Set<Id> blockedCaseIds = new Set<Id>();
        for (Case c : caseMap.values()) {
            if (businessDaysBetween(c.ClosedDate.date(), today) > BUSINESS_DAYS_LIMIT) {
                blockedCaseIds.add(c.Id);
            }
        }
        if (blockedCaseIds.isEmpty()) return;

        for (FeedComment fc : newComments) {
            if (fc.FeedItemId == null) continue;
            Id caseId = feedItemToCaseId.get(fc.FeedItemId);
            if (caseId != null && blockedCaseIds.contains(caseId)) {
                fc.addError(ERROR_MSG);
            }
        }
    }

    /**
     * @description Queries and returns the Profile Name of the currently running user.
     * @return      String — Profile Name of the running user.
     */
    private static String getCurrentProfileName() {
        return [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
    }

    /**
     * @description Counts the number of business days (Monday–Friday) between a start datetime
     *              and an end date. The start date is exclusive and the end date is inclusive.
     *              Uses DateTime.format('E') to determine the day of the week.
     * @param       startDatetime  Datetime to count from (exclusive — first day counted is startDate + 1).
     * @param       endDate        Date to count to (inclusive).
     * @return      Integer — number of weekdays between the two dates.
     */
    @TestVisible
    private static Integer businessDaysBetween(Datetime startDatetime, Date endDate) {
        Date startDate = startDatetime.date();
        Integer count = 0;
        Date d = startDate.addDays(1);
        while (d <= endDate) {
            DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
            String day = dt.format('E');
            if (day != 'Sat' && day != 'Sun') count++;
            d = d.addDays(1);
        }
        return count;
    }
}