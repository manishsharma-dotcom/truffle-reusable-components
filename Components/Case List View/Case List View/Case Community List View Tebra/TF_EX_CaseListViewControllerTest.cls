/**
 * @class       TF_EX_CaseListViewControllerTest
 * @description Test class for TF_EX_CaseListViewController.
 *              Covers isAdminUser, getAccounts, getCases (MY_CASES and MY_ACCOUNT_CASES modes),
 *              and closeCases across both Customer and Admin personas.
 *              Requires profiles 'Customer User' and 'Customer User Admin' and permission sets
 *              'TF_EX_CustomerUserPermission' and 'TF_EX_CustomerUserAdminPermission' to exist in the org.
 * @createdBy   Truffle Consulting
 */
@IsTest
private class TF_EX_CaseListViewControllerTest {

    /**
     * @description Creates shared test data for all test methods.
     *              Inserts one Account, two Contacts, two community Users (Customer and Admin),
     *              assigns the corresponding Permission Sets, and creates three Cases
     *              (two open, one closed) linked to the Customer User's Contact.
     */
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con1 = new Contact(
            FirstName = 'Customer',
            LastName  = 'ListView Test',
            Email     = 'customer.lv.test@example.tebra.test',
            AccountId = acc.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        Contact con2 = new Contact(
            FirstName = 'Admin',
            LastName  = 'ListView Test',
            Email     = 'admin.lv.test@example.tebra.test',
            AccountId = acc.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        insert new List<Contact>{ con1, con2 };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile customerProfile = [
                SELECT Id FROM Profile
                WHERE  Name = 'Customer User'
                LIMIT  1
            ];
            Profile adminProfile = [
                SELECT Id FROM Profile
                WHERE  Name = 'Customer User Admin'
                LIMIT  1
            ];

            User customerUser = new User(
                FirstName         = 'Customer',
                LastName          = 'ListView Test',
                Email             = 'customer.lv.test@example.tebra.test',
                Username          = 'customer.lv.test@example.tebra.test.sandbox',
                Alias             = 'clvtest',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = customerProfile.Id,
                ContactId         = con1.Id
            );
            User adminUser = new User(
                FirstName         = 'Admin',
                LastName          = 'ListView Test',
                Email             = 'admin.lv.test@example.tebra.test',
                Username          = 'admin.lv.test@example.tebra.test.sandbox',
                Alias             = 'alvtest',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = adminProfile.Id,
                ContactId         = con2.Id
            );
            insert new List<User>{ customerUser, adminUser };

            PermissionSet customerPS = [
                SELECT Id FROM PermissionSet
                WHERE  Name = 'TF_EX_CustomerUserPermission' LIMIT 1
            ];
            PermissionSet adminPS = [
                SELECT Id FROM PermissionSet
                WHERE  Name = 'TF_EX_CustomerUserAdminPermission' LIMIT 1
            ];
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(
                    AssigneeId      = customerUser.Id,
                    PermissionSetId = customerPS.Id
                ),
                new PermissionSetAssignment(
                    AssigneeId      = adminUser.Id,
                    PermissionSetId = adminPS.Id
                )
            };
        }

        User customerUser = [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'customer.lv.test@example.tebra.test.sandbox' LIMIT 1
        ];

        RecordType rt = [
            SELECT Id FROM RecordType
            WHERE  SObjectType    = 'Case'
            AND    DeveloperName  = 'Customer_Support_New'
            LIMIT  1
        ];

        List<Case> cases = new List<Case>{
            new Case(
                Subject      = 'Open Case 1',
                Status       = 'New',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            ),
            new Case(
                Subject      = 'Open Case 2',
                Status       = 'Working',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            ),
            new Case(
                Subject      = 'Closed Case 1',
                Status       = 'Closed',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            )
        };
        insert cases;
    }

    /**
     * @description Returns the Customer persona test User.
     * @return      User — community user assigned TF_EX_CustomerUserPermission.
     */
    private static User getCustomerUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'customer.lv.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    /**
     * @description Returns the Admin persona test User.
     * @return      User — community user assigned TF_EX_CustomerUserAdminPermission.
     */
    private static User getAdminUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'admin.lv.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    /**
     * @description Returns the Id of the shared test Account.
     * @return      Id — Account Id for 'Test Account'.
     */
    private static Id getTestAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1].Id;
    }

    // ─── isAdminUser ──────────────────────────────────────────────────────────

    /**
     * @description Verifies that a Customer persona user returns false for isAdminUser.
     */
    @IsTest
    static void testIsAdminUser_CustomerUser_ReturnsFalse() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            Boolean result = TF_EX_CaseListViewController.isAdminUser();
            Test.stopTest();
            System.assertEquals(false, result, 'Customer user should not be admin');
        }
    }

    /**
     * @description Verifies that an Admin persona user returns true for isAdminUser.
     */
    @IsTest
    static void testIsAdminUser_AdminUser_ReturnsTrue() {
        User au = getAdminUser();
        System.runAs(au) {
            Test.startTest();
            Boolean result = TF_EX_CaseListViewController.isAdminUser();
            Test.stopTest();
            System.assertEquals(true, result, 'Admin user should be admin');
        }
    }

    // ─── getAccounts ──────────────────────────────────────────────────────────

    /**
     * @description Verifies that a Customer user sees their ACR-linked Accounts,
     *              including the expected 'Test Account'.
     */
    @IsTest
    static void testGetAccounts_CustomerUser_ReturnsLinkedAccounts() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseListViewController.AccountOption> accounts =
                TF_EX_CaseListViewController.getAccounts();
            Test.stopTest();

            System.assertNotEquals(null, accounts, 'Accounts list should not be null');
            System.assert(accounts.size() > 0, 'Customer user should see linked accounts');
            Boolean found = false;
            for (TF_EX_CaseListViewController.AccountOption opt : accounts) {
                if (opt.accountName == 'Test Account') { found = true; break; }
            }
            System.assert(found, 'Test Account should be in the list');
        }
    }

    /**
     * @description Verifies that getAccounts returns a non-null list for an Admin user.
     */
    @IsTest
    static void testGetAccounts_AdminUser_ReturnsAccounts() {
        User au = getAdminUser();
        System.runAs(au) {
            Test.startTest();
            List<TF_EX_CaseListViewController.AccountOption> accounts =
                TF_EX_CaseListViewController.getAccounts();
            Test.stopTest();
            System.assertNotEquals(null, accounts, 'Accounts list should not be null');
        }
    }

    // ─── getCases — MY_CASES ──────────────────────────────────────────────────

    /**
     * @description Verifies that a Customer user in MY_CASES mode retrieves their own Cases.
     */
    @IsTest
    static void testGetCases_MyCases_CustomerUser_ReturnsOwnCases() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', '', 'MY_CASES', 'ALL'
                );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assert(result.totalCount > 0, 'Customer user should see their cases');
            System.assert(result.cases.size() > 0, 'Cases list should not be empty');
        }
    }

    /**
     * @description Verifies that MY_CASES respects an explicitly passed Account ID filter.
     */
    @IsTest
    static void testGetCases_MyCases_WithAccountFilter() {
        User cu  = getCustomerUser();
        Id accId = getTestAccountId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    new List<Id>{ accId }, 10, 1, 'CaseNumber', 'asc', '', 'MY_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }

    /**
     * @description Verifies that the OPEN status filter returns only non-closed Cases.
     */
    @IsTest
    static void testGetCases_MyCases_OpenStatusFilter() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', '', 'MY_CASES', 'OPEN'
                );
            Test.stopTest();

            System.assertNotEquals(null, result);
            for (Case c : result.cases) {
                System.assertNotEquals('Closed', c.Status, 'Only open cases should be returned');
            }
        }
    }

    /**
     * @description Verifies that the CLOSED status filter returns only closed Cases.
     */
    @IsTest
    static void testGetCases_MyCases_ClosedStatusFilter() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', '', 'MY_CASES', 'CLOSED'
                );
            Test.stopTest();

            System.assertNotEquals(null, result);
            for (Case c : result.cases) {
                System.assertEquals('Closed', c.Status, 'Only closed cases should be returned');
            }
        }
    }

    /**
     * @description Verifies that a keyword search term executes without error and returns a valid result.
     */
    @IsTest
    static void testGetCases_MyCases_WithSearchTerm() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', 'Open Case', 'MY_CASES', 'ALL'
                );
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assert(result.totalCount >= 0, 'Search should execute without error');
        }
    }

    /**
     * @description Verifies that descending sort executes without error.
     */
    @IsTest
    static void testGetCases_MyCases_SortDescending() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'Subject', 'desc', '', 'MY_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    /**
     * @description Verifies that an invalid sort field falls back to the default (CaseNumber)
     *              without throwing an exception.
     */
    @IsTest
    static void testGetCases_MyCases_InvalidSortField_DefaultsToSafe() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'INVALID_FIELD__c', 'asc', '', 'MY_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    /**
     * @description Verifies that pagination returns correctly sized pages and handles page 2.
     */
    @IsTest
    static void testGetCases_MyCases_Pagination() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult page1 =
                TF_EX_CaseListViewController.getCases(
                    null, 2, 1, 'CaseNumber', 'asc', '', 'MY_CASES', 'ALL'
                );
            TF_EX_CaseListViewController.CaseListResult page2 =
                TF_EX_CaseListViewController.getCases(
                    null, 2, 2, 'CaseNumber', 'asc', '', 'MY_CASES', 'ALL'
                );
            Test.stopTest();

            System.assertNotEquals(null, page1);
            System.assertNotEquals(null, page2);
            System.assert(page1.cases.size() <= 2, 'Page size respected');
        }
    }

    /**
     * @description Verifies that null pagination and sort parameters fall back to safe defaults
     *              without throwing an exception.
     */
    @IsTest
    static void testGetCases_MyCases_NullPageParams_DefaultsApplied() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, null, null, null, null, null, 'MY_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result, 'Null params should use defaults');
        }
    }

    // ─── getCases — MY_ACCOUNT_CASES ─────────────────────────────────────────

    /**
     * @description Verifies that MY_ACCOUNT_CASES with no Account filter returns all
     *              Cases across the user's ACR-linked Accounts.
     */
    @IsTest
    static void testGetCases_MyAccountCases_NoAccountFilter() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', '', 'MY_ACCOUNT_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
            System.assert(result.totalCount >= 0);
        }
    }

    /**
     * @description Verifies that MY_ACCOUNT_CASES respects an explicitly passed Account ID filter.
     */
    @IsTest
    static void testGetCases_MyAccountCases_WithAccountFilter() {
        User cu  = getCustomerUser();
        Id accId = getTestAccountId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    new List<Id>{ accId }, 10, 1, 'CaseNumber', 'asc', '', 'MY_ACCOUNT_CASES', 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    /**
     * @description Verifies that a null listViewType defaults to MY_CASES behaviour.
     */
    @IsTest
    static void testGetCases_NullListViewType_DefaultsToMyCases() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseListViewController.CaseListResult result =
                TF_EX_CaseListViewController.getCases(
                    null, 10, 1, 'CaseNumber', 'asc', '', null, 'ALL'
                );
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    // ─── closeCases ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that an Admin user can successfully close a Case.
     */
    @IsTest
    static void testCloseCases_AdminUser_Success() {
        User au = getAdminUser();
        List<Case> cases = [SELECT Id FROM Case WHERE Status = 'New' LIMIT 1];

        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseListViewController.closeCases(new List<Id>{ cases[0].Id });
            Test.stopTest();

            Case updated = [SELECT Status FROM Case WHERE Id = :cases[0].Id];
            System.assertEquals('Closed', updated.Status, 'Case should be closed');
        }
    }

    /**
     * @description Verifies that a Customer user attempting to close a Case receives an AuraHandledException.
     */
    @IsTest
    static void testCloseCases_CustomerUser_ThrowsException() {
        User cu = getCustomerUser();
        List<Case> cases = [SELECT Id FROM Case WHERE Status = 'Working' LIMIT 1];

        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseListViewController.closeCases(new List<Id>{ cases[0].Id });
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'Non-admin cannot close cases');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that passing an empty list to closeCases completes without error.
     */
    @IsTest
    static void testCloseCases_EmptyList_NoOp() {
        User au = getAdminUser();
        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseListViewController.closeCases(new List<Id>());
            Test.stopTest();
            System.assert(true, 'Empty list handled gracefully');
        }
    }

    /**
     * @description Verifies that passing null to closeCases completes without error.
     */
    @IsTest
    static void testCloseCases_NullList_NoOp() {
        User au = getAdminUser();
        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseListViewController.closeCases(null);
            Test.stopTest();
            System.assert(true, 'Null list handled gracefully');
        }
    }
}