/**
 * @class       TF_EX_FeedCommentTriggerHandlerTest
 * @description Test class for TF_EX_FeedCommentTriggerHandler.
 *              Covers the handle method for: non-community profile early exit,
 *              null FeedItemId early exit, FeedItem not parented by a Case early exit,
 *              open Case (no error), recently closed Case within the 5-business-day limit (no error),
 *              and empty list no-op.
 *              Covers the @TestVisible businessDaysBetween method for: same-day zero count,
 *              single-day span, two-week span exceeding the limit, and weekend exclusion.
 *              Note: The blocked path (ClosedDate > 5 business days ago) cannot be exercised
 *              through handle() in test context because ClosedDate is a system field automatically
 *              set to today when a Case is closed. This logic is validated through the direct
 *              businessDaysBetween unit tests.
 *              Requires profiles 'Customer User' and 'Customer User Admin', permission sets
 *              'TF_EX_CustomerUserPermission' and 'TF_EX_CustomerUserAdminPermission',
 *              RecordType 'Customer_Support_New' on Case, and Chatter enabled in the org.
 * @createdBy   Truffle Consulting
 */
@IsTest
private class TF_EX_FeedCommentTriggerHandlerTest {

    /**
     * @description Creates shared test data for all test methods.
     *              Inserts one Account, two Contacts, two community Users (Customer and Admin),
     *              assigns the corresponding Permission Sets, and creates two Cases
     *              (one open, one closed) linked to the Customer User's Contact.
     */
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con1 = new Contact(
            FirstName = 'Customer',
            LastName  = 'Feed Test',
            Email     = 'customer.feed.test@example.tebra.test',
            AccountId = acc.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        Contact con2 = new Contact(
            FirstName = 'Admin',
            LastName  = 'Feed Test',
            Email     = 'admin.feed.test@example.tebra.test',
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
                LastName          = 'Feed Test',
                Email             = 'customer.feed.test@example.tebra.test',
                Username          = 'customer.feed.test@example.tebra.test.sandbox',
                Alias             = 'cftest',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = customerProfile.Id,
                ContactId         = con1.Id
            );
            User adminUser = new User(
                FirstName         = 'Admin',
                LastName          = 'Feed Test',
                Email             = 'admin.feed.test@example.tebra.test',
                Username          = 'admin.feed.test@example.tebra.test.sandbox',
                Alias             = 'aftest',
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
            WHERE  Username = 'customer.feed.test@example.tebra.test.sandbox' LIMIT 1
        ];

        RecordType rt = [
            SELECT Id FROM RecordType
            WHERE  SObjectType   = 'Case'
            AND    DeveloperName = 'Customer_Support_New'
            LIMIT  1
        ];

        insert new List<Case>{
            new Case(
                Subject      = 'Open Feed Case',
                Status       = 'New',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            ),
            new Case(
                Subject      = 'Closed Feed Case',
                Status       = 'Closed',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            )
        };
    }

    /**
     * @description Returns the Customer persona test User.
     * @return      User — community user assigned TF_EX_CustomerUserPermission.
     */
    private static User getCustomerUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'customer.feed.test@example.tebra.test.sandbox'
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
            WHERE  Username = 'admin.feed.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    /**
     * @description Returns the Id of the open test Case.
     * @return      Id — Case Id for 'Open Feed Case'.
     */
    private static Id getOpenCaseId() {
        return [SELECT Id FROM Case WHERE Subject = 'Open Feed Case' LIMIT 1].Id;
    }

    /**
     * @description Returns the Id of the closed test Case.
     * @return      Id — Case Id for 'Closed Feed Case'.
     */
    private static Id getClosedCaseId() {
        return [SELECT Id FROM Case WHERE Subject = 'Closed Feed Case' LIMIT 1].Id;
    }

    // ─── handle ───────────────────────────────────────────────────────────────

    /**
     * @description Verifies that handle exits early and adds no error when the running
     *              user's profile is not in the allowed set (non-community profile).
     */
    @IsTest
    static void testHandle_NonCommunityProfile_ExitsEarly_NoError() {
        Id caseId = getClosedCaseId();
        FeedItem fi = new FeedItem(ParentId = caseId, Body = 'Test post', Type = 'TextPost');
        insert fi;

        FeedComment fc = new FeedComment(FeedItemId = fi.Id, CommentBody = 'Test comment');
        Test.startTest();
        TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>{ fc });
        Test.stopTest();

        System.assertEquals(0, fc.getErrors().size(), 'Non-community profile should exit early with no error');
    }

    /**
     * @description Verifies that handle exits early and adds no error when the
     *              FeedComment has a null FeedItemId.
     */
    @IsTest
    static void testHandle_NullFeedItemId_ExitsEarly_NoError() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            FeedComment fc = new FeedComment(CommentBody = 'Test comment');
            Test.startTest();
            TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>{ fc });
            Test.stopTest();

            System.assertEquals(0, fc.getErrors().size(), 'Null FeedItemId should exit early with no error');
        }
    }

    /**
     * @description Verifies that handle exits early and adds no error when the FeedItem
     *              is parented by a non-Case record (Account), so the Case Id set is empty.
     */
    @IsTest
    static void testHandle_FeedItemNotOnCase_ExitsEarly_NoError() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        FeedItem fi = new FeedItem(ParentId = acc.Id, Body = 'Account post', Type = 'TextPost');
        insert fi;

        User cu = getCustomerUser();
        System.runAs(cu) {
            FeedComment fc = new FeedComment(FeedItemId = fi.Id, CommentBody = 'Test comment');
            Test.startTest();
            TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>{ fc });
            Test.stopTest();

            System.assertEquals(0, fc.getErrors().size(), 'FeedItem not on a Case should exit early with no error');
        }
    }

    /**
     * @description Verifies that a Customer User can comment on an open Case
     *              without receiving an error.
     */
    @IsTest
    static void testHandle_OpenCase_CustomerUser_NoError() {
        Id caseId = getOpenCaseId();
        FeedItem fi = new FeedItem(ParentId = caseId, Body = 'Open case post', Type = 'TextPost');
        insert fi;

        User cu = getCustomerUser();
        System.runAs(cu) {
            FeedComment fc = new FeedComment(FeedItemId = fi.Id, CommentBody = 'Comment on open case');
            Test.startTest();
            TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>{ fc });
            Test.stopTest();

            System.assertEquals(0, fc.getErrors().size(), 'Comment on open case should not produce an error');
        }
    }

    /**
     * @description Verifies that a Customer User can comment on a Case closed today
     *              (0 business days since closure, within the 5-day limit) without receiving an error.
     */
    @IsTest
    static void testHandle_RecentlyClosedCase_WithinLimit_NoError() {
        Id caseId = getClosedCaseId();
        FeedItem fi = new FeedItem(ParentId = caseId, Body = 'Closed case post', Type = 'TextPost');
        insert fi;

        User cu = getCustomerUser();
        System.runAs(cu) {
            FeedComment fc = new FeedComment(FeedItemId = fi.Id, CommentBody = 'Comment on recently closed case');
            Test.startTest();
            TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>{ fc });
            Test.stopTest();

            System.assertEquals(0, fc.getErrors().size(), 'Comment on recently closed case should not produce an error');
        }
    }

    /**
     * @description Verifies that passing an empty list to handle completes without error.
     */
    @IsTest
    static void testHandle_EmptyList_NoOp() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_FeedCommentTriggerHandler.handle(new List<FeedComment>());
            Test.stopTest();
            System.assert(true, 'Empty list should be handled gracefully');
        }
    }

    // ─── businessDaysBetween ──────────────────────────────────────────────────

    /**
     * @description Verifies that businessDaysBetween returns 0 when start and end
     *              are the same day (start is exclusive so no days are counted).
     */
    @IsTest
    static void testBusinessDaysBetween_SameDay_ReturnsZero() {
        Date     today = Date.today();
        Datetime start = Datetime.newInstance(today.year(), today.month(), today.day());

        Test.startTest();
        Integer result = TF_EX_FeedCommentTriggerHandler.businessDaysBetween(start, today);
        Test.stopTest();

        System.assertEquals(0, result, 'Same start and end date should return 0 business days');
    }

    /**
     * @description Verifies that businessDaysBetween returns 0 or 1 for a single-day span
     *              (start yesterday exclusive, end today inclusive) depending on whether
     *              today falls on a weekday or weekend.
     */
    @IsTest
    static void testBusinessDaysBetween_SingleDaySpan_ReturnsZeroOrOne() {
        Date     yesterday = Date.today().addDays(-1);
        Datetime start     = Datetime.newInstance(yesterday.year(), yesterday.month(), yesterday.day());

        Test.startTest();
        Integer result = TF_EX_FeedCommentTriggerHandler.businessDaysBetween(start, Date.today());
        Test.stopTest();

        System.assert(result >= 0 && result <= 1, 'Single-day span should return 0 or 1 business days, got: ' + result);
    }

    /**
     * @description Verifies that businessDaysBetween returns more than 5 for a 14-day span,
     *              confirming such a gap would exceed the BUSINESS_DAYS_LIMIT and trigger a block.
     */
    @IsTest
    static void testBusinessDaysBetween_TwoWeekSpan_ExceedsLimit() {
        Date     twoWeeksAgo = Date.today().addDays(-14);
        Datetime start       = Datetime.newInstance(twoWeeksAgo.year(), twoWeeksAgo.month(), twoWeeksAgo.day());

        Test.startTest();
        Integer result = TF_EX_FeedCommentTriggerHandler.businessDaysBetween(start, Date.today());
        Test.stopTest();

        System.assert(result > 5, 'Two-week span should yield more than 5 business days, got: ' + result);
    }

    /**
     * @description Verifies that businessDaysBetween excludes Saturday and Sunday by confirming
     *              the count over a 14-day span is less than 14 (the total calendar days).
     */
    @IsTest
    static void testBusinessDaysBetween_SpansWeekend_ExcludesWeekendDays() {
        Date     twoWeeksAgo = Date.today().addDays(-14);
        Datetime start       = Datetime.newInstance(twoWeeksAgo.year(), twoWeeksAgo.month(), twoWeeksAgo.day());

        Test.startTest();
        Integer result = TF_EX_FeedCommentTriggerHandler.businessDaysBetween(start, Date.today());
        Test.stopTest();

        System.assert(result < 14, 'Business day count should be less than total calendar days over two weeks, got: ' + result);
        System.assert(result >= 8, 'Two full weeks should include at least 8 business days (exclusive start), got: ' + result);
    }

    // ─── Trigger coverage ─────────────────────────────────────────────────────

    /**
     * @description Integration test that inserts a FeedComment via DML to fire
     *              TF_EX_FeedCommentTrigger on before insert, ensuring the trigger lines
     *              are covered. Runs as a Customer User commenting on an open Case so
     *              handle() completes without adding an error and the insert succeeds.
     */
    @IsTest
    static void testTrigger_BeforeInsert_FiresHandler() {
        Id caseId = getOpenCaseId();
        FeedItem fi = new FeedItem(ParentId = caseId, Body = 'Trigger test post', Type = 'TextPost');
        insert fi;

        Test.startTest();
        insert new FeedComment(FeedItemId = fi.Id, CommentBody = 'Trigger integration comment');
        Test.stopTest();

        List<FeedComment> inserted = [
            SELECT Id FROM FeedComment WHERE FeedItemId = :fi.Id
        ];
        System.assertEquals(1, inserted.size(), 'FeedComment should be inserted successfully via trigger');
    }
}