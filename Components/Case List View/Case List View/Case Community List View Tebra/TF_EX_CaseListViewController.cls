/**
 * @class       TF_EX_CaseListViewController
 * @testClass   TF_EX_CaseListViewControllerTest
 * @createdBy   Truffle Consulting
 * @description Apex controller for the caseListView LWC used in Experience Cloud.
 *              Supports two personas:
 *                - Admin    : users with Custom Permission "TF_EX_CaseAdminAccess" — see all Accounts and Cases.
 *                - Customer : community users linked to a Contact — see ACR-linked Accounts and their own Cases.
 *              Provides account dropdown population, paginated/filtered/sorted case retrieval, and admin-only case closure.
 *              Requires Multi-Account Contact Relationships enabled in the org.
 */
public with sharing class TF_EX_CaseListViewController {

    private static final Set<String> VALID_SORT_FIELDS = new Set<String>{
        'CaseNumber', 'Subject', 'Contact.Name', 'Account.Name', 'Status'
    };

    /**
     * @description Checks whether the running user holds the "TF_EX_CaseAdminAccess" custom permission.
     *              Called once on component load to establish the user's persona.
     * @return      Boolean — true if the user is an Admin, false otherwise.
     */
    @AuraEnabled(cacheable=false)
    public static Boolean isAdminUser() {
        return FeatureManagement.checkPermission('TF_EX_CaseAdminAccess');
    }

    /**
     * @description Returns the list of Accounts to populate the Account filter dropdown.
     *              Retrieves Accounts linked to the running user's Contact via AccountContactRelation.
     * @return      List<AccountOption> — account ID, name, and primary flag for each related Account.
     */
    @AuraEnabled(cacheable=false)
    public static List<AccountOption> getAccounts() {
        Boolean isAdmin = FeatureManagement.checkPermission('TF_EX_CaseAdminAccess');
        List<AccountOption> options = new List<AccountOption>();

        Id userId = UserInfo.getUserId();
        User currentUser = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];

        if (currentUser.ContactId != null) {
            Id contactId = currentUser.ContactId;
            for (AccountContactRelation acr : [
                SELECT AccountId, Account.Name, IsDirect , IsActive
                FROM AccountContactRelation
                WHERE ContactId = :contactId AND IsActive=True
                ORDER BY Account.Name ASC
            ]) {
                options.add(new AccountOption(acr.AccountId, acr.Account.Name, acr.IsDirect));
            }
        }

        return options;
    }

    /**
     * @description Returns a paginated, filtered, and sorted list of Cases along with the total matching record count.
     *              Supports two list view modes:
     *                - MY_CASES          : Cases where the ContactId matches the running user's Contact.
     *                - MY_ACCOUNT_CASES  : Cases belonging to Accounts linked to the user via AccountContactRelation.
     *              Sort fields are whitelisted to prevent SOQL injection.
     *              Search term is sanitised via String.escapeSingleQuotes before use in dynamic SOQL.
     * @param       accountIds    List of Account IDs to filter by; empty list means no Account filter.
     * @param       pageSize      Number of records per page (1–200); defaults to 10 if null or out of range.
     * @param       pageNumber    1-based page number; defaults to 1 if null or invalid.
     * @param       sortField     API field name to sort by; must be in VALID_SORT_FIELDS, defaults to CaseNumber.
     * @param       sortDirection Sort direction — 'asc' or 'desc'; defaults to DESC if unrecognised.
     * @param       searchTerm    Partial-match keyword applied across CaseNumber, Subject, Status, Account.Name, and Contact.Name.
     * @param       listViewType  View mode — 'MY_CASES' or 'MY_ACCOUNT_CASES'; defaults to MY_CASES if null.
     * @param       statusFilter  Case status scope — 'OPEN', 'CLOSED', or null for all statuses.
     * @return      CaseListResult — contains the Case records for the requested page and the total matching count.
     */
    @AuraEnabled(cacheable=false)
    public static CaseListResult getCases(
        List<Id>  accountIds,
        Integer   pageSize,
        Integer   pageNumber,
        String    sortField,
        String    sortDirection,
        String    searchTerm,
        String    listViewType,
        String    statusFilter
    ) {
        Boolean isAdmin = FeatureManagement.checkPermission('TF_EX_CaseAdminAccess');

        Integer safePageSize = (pageSize  != null && pageSize  > 0 && pageSize  <= 200) ? pageSize  : 10;
        Integer safePage     = (pageNumber != null && pageNumber > 0)                   ? pageNumber : 1;
        String  safeField    = VALID_SORT_FIELDS.contains(sortField) ? sortField : 'CaseNumber';
        String  safeDir      = 'asc'.equalsIgnoreCase(sortDirection) ? 'ASC' : 'DESC';

        List<String> conditions = new List<String>();

        Id userId = UserInfo.getUserId();
        User u    = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];

        if (listViewType == null || listViewType == 'MY_CASES') {

    if (u.ContactId != null) {
        conditions.add('ContactId = \'' + String.valueOf(u.ContactId) + '\'');

        // Get all active AccountContactRelation Accounts for this Contact
        Set<Id> activeAccountIds = new Set<Id>();
        for (AccountContactRelation acr : [
            SELECT AccountId
            FROM AccountContactRelation
            WHERE ContactId = :u.ContactId
            AND IsActive = TRUE
        ]) {
            activeAccountIds.add(acr.AccountId);
        }

        // If user has selected Accounts, intersect them with active Accounts
        if (accountIds != null && !accountIds.isEmpty()) {
            activeAccountIds.retainAll(new Set<Id>(accountIds));
        }

        // Only show Cases for active Account relationships
        if (!activeAccountIds.isEmpty()) {
            List<String> quoted = new List<String>();
            for (Id aid : activeAccountIds) {
                quoted.add('\'' + String.valueOf(aid) + '\'');
            }
            conditions.add('AccountId IN (' + String.join(quoted, ', ') + ')');
        } else {
            // Prevent returning Cases from inactive Account relationships
            conditions.add('AccountId = null');
        }
    }
} else if (listViewType == 'MY_ACCOUNT_CASES') {
            List<Id> effectiveAccountIds = new List<Id>();

            if (accountIds != null && !accountIds.isEmpty()) {
                effectiveAccountIds = accountIds;
            } else if (u.ContactId != null) {
                for (AccountContactRelation acr : [
                    SELECT AccountId,IsActive
                    FROM AccountContactRelation
                    WHERE ContactId = :u.ContactId AND IsActive=TRUE
                ]) {
                    effectiveAccountIds.add(acr.AccountId);
                }
            }

            if (!effectiveAccountIds.isEmpty()) {
                List<String> quoted = new List<String>();
                for (Id aid : effectiveAccountIds) {
                    quoted.add('\'' + String.valueOf(aid) + '\'');
                }
                conditions.add('AccountId IN (' + String.join(quoted, ', ') + ')');
            } else {
                conditions.add('AccountId = null');
            }
        }

        if ('OPEN'.equals(statusFilter)) {
            conditions.add('IsClosed = false');
        } else if ('CLOSED'.equals(statusFilter)) {
            conditions.add('IsClosed = true');
        }

        if (String.isNotBlank(searchTerm)) {
            String escaped = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            conditions.add(
                '(CaseNumber LIKE \'' + escaped + '\' OR Subject LIKE \'' + escaped + '\' OR Status LIKE \'' + escaped + '\' OR Account.Name LIKE \'' + escaped + '\' OR Contact.Name LIKE \'' + escaped + '\' )'
            );
        }

        String rtFilter = 'RecordType.DeveloperName IN (\'Customer_Support_New\', \'Enrollments_Support\', \'Integration_Request\', \'Training\', \'Digital_Marketing_Support\', \'Website_Design_Change\')';
        
        String whereClause = conditions.isEmpty()
            ? ' WHERE ' + rtFilter
            : ' WHERE ' + String.join(conditions, ' AND ') + ' AND ' + rtFilter;

        String  orderClause = ' ORDER BY ' + safeField + ' ' + safeDir + ' NULLS LAST';
        Integer offsetVal   = (safePage - 1) * safePageSize;

        String dataQuery =
            'SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, '
            + 'Account.Name, Owner.Name, Contact.Name, RecordType.Name '
            + 'FROM Case'
            + whereClause
            + ' WITH USER_MODE '
            + orderClause
            + ' LIMIT '  + safePageSize
            + ' OFFSET ' + offsetVal;

        String countQuery = 'SELECT COUNT() FROM Case' + whereClause;

        CaseListResult res = new CaseListResult();
        res.cases      = Database.query(dataQuery);
        res.totalCount = Database.countQuery(countQuery);
        return res;
    }

    /**
     * @description Sets the Status to 'Closed' for the provided Case IDs.
     *              Restricted to Admin users — throws AuraHandledException for non-admins.
     * @param       caseIds   List of Case IDs to close.
     */
    @AuraEnabled
    public static void closeCases(List<Id> caseIds) {
        if (!FeatureManagement.checkPermission('TF_EX_CaseAdminAccess')) {
            throw new AuraHandledException('You do not have permission to close cases.');
        }
        if (caseIds == null || caseIds.isEmpty()) return;

        List<Case> toUpdate = new List<Case>();
        for (Id cid : caseIds) {
            toUpdate.add(new Case(Id = cid, Status = 'Closed'));
        }
        update toUpdate;
    }

    /**
     * @description Lightweight Account wrapper returned to the LWC Account filter dropdown.
     *              Exposes the Account ID, display name, and whether it is the Contact's primary Account.
     */
    public class AccountOption {
        @AuraEnabled public String  accountId;
        @AuraEnabled public String  accountName;
        @AuraEnabled public Boolean isPrimary;

        public AccountOption(Id id, String name, Boolean isPrimary) {
            this.accountId   = String.valueOf(id);
            this.accountName = name;
            this.isPrimary   = isPrimary;
        }
    }

    /**
     * @description Result wrapper returned by getCases.
     *              Carries the Case records for the current page and the total matching record count for pagination.
     */
    public class CaseListResult {
        @AuraEnabled public List<Case> cases;
        @AuraEnabled public Integer    totalCount;
    }
}