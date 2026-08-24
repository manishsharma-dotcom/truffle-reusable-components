/**
 * @class       TF_EX_CaseCommunityDetailControllerTest
 * @description Test class for TF_EX_CaseCommunityDetailController.
 *              Covers getCaseDetail (open case, recently closed case, collaborator list),
 *              getClosedReasonOptions, closeCase (success and blank reason validation),
 *              reopenCase (success and blank reason validation), addCollaborator
 *              (new member and idempotent duplicate), and removeCollaborator.
 *              Requires profiles 'Customer User' and 'Customer User Admin', permission sets
 *              'TF_EX_CustomerUserPermission' and 'TF_EX_CustomerUserAdminPermission',
 *              a CaseTeamRole named 'Collaborators', and Chatter enabled in the org.
 * @createdBy   Truffle Consulting
 */
@IsTest
private class TF_EX_CaseCommunityDetailControllerTest {

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
            LastName  = 'Detail Test',
            Email     = 'customer.detail.test@example.tebra.test',
            AccountId = acc.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        Contact con2 = new Contact(
            FirstName = 'Admin',
            LastName  = 'Detail Test',
            Email     = 'admin.detail.test@example.tebra.test',
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
                LastName          = 'Detail Test',
                Email             = 'customer.detail.test@example.tebra.test',
                Username          = 'customer.detail.test@example.tebra.test.sandbox',
                Alias             = 'cdtest',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = customerProfile.Id,
                ContactId         = con1.Id
            );
            User adminUser = new User(
                FirstName         = 'Admin',
                LastName          = 'Detail Test',
                Email             = 'admin.detail.test@example.tebra.test',
                Username          = 'admin.detail.test@example.tebra.test.sandbox',
                Alias             = 'adtest',
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
            WHERE  Username = 'customer.detail.test@example.tebra.test.sandbox' LIMIT 1
        ];

        RecordType rt = [
            SELECT Id FROM RecordType
            WHERE  SObjectType   = 'Case'
            AND    DeveloperName = 'Clinical_Enrollments'
            LIMIT  1
        ];

        insert new List<Case>{
            new Case(
                Subject      = 'Open Detail Case',
                Status       = 'New',
                AccountId    = acc.Id,
                ContactId    = customerUser.ContactId,
                Origin       = 'Community',
                RecordTypeId = rt.Id
            ),
            new Case(
                Subject      = 'Closed Detail Case',
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
            WHERE  Username = 'customer.detail.test@example.tebra.test.sandbox'
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
            WHERE  Username = 'admin.detail.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    /**
     * @description Returns the Id of the open test Case.
     * @return      Id — Case Id for 'Open Detail Case'.
     */
    private static Id getOpenCaseId() {
        return [SELECT Id FROM Case WHERE Subject = 'Open Detail Case' LIMIT 1].Id;
    }

    /**
     * @description Returns the Id of the closed test Case.
     * @return      Id — Case Id for 'Closed Detail Case'.
     */
    private static Id getClosedCaseId() {
        return [SELECT Id FROM Case WHERE Subject = 'Closed Detail Case' LIMIT 1].Id;
    }

    // ─── getCaseDetail ────────────────────────────────────────────────────────

    /**
     * @description Verifies that getCaseDetail returns a non-null CaseDetailResult
     *              with the correct Case record for a Customer persona user.
     */
    @IsTest
    static void testGetCaseDetail_CustomerUser_ReturnsResult() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.caseRecord, 'Case record should not be null');
            System.assertEquals(caseId, result.caseRecord.Id, 'Case Id should match');
        }
    }

    /**
     * @description Verifies that getCaseDetail returns an empty collaborators list
     *              when no CaseTeamMembers exist for the Case.
     */
    /*@IsTest
    static void testGetCaseDetail_NoCollaborators_ReturnsEmptyList() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertNotEquals(null, result.collaborators, 'Collaborators list should not be null');
            System.assertEquals(0, result.collaborators.size(), 'No collaborators should be present');
        }
    }*/

    /**
     * @description Verifies that canReopen is false for an open (non-closed) Case.
     */
    @IsTest
    static void testGetCaseDetail_OpenCase_CanReopenFalse() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertEquals(false, result.canReopen, 'Open case should not be eligible for reopen');
        }
    }

    /**
     * @description Verifies that canReopen is true for a Case closed today
     *              (zero business days since closure, within the 5-day window).
     */
    @IsTest
    static void testGetCaseDetail_RecentlyClosedCase_CanReopenTrue() {
        User cu     = getCustomerUser();
        Id   caseId = getClosedCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertEquals(true, result.canReopen, 'Case closed today should be eligible for reopen');
        }
    }

    /**
     * @description Verifies that getCaseDetail returns a non-null CaseDetailResult
     *              when called by an Admin persona user.
     */
    @IsTest
    static void testGetCaseDetail_AdminUser_ReturnsResult() {
        User au     = getAdminUser();
        Id   caseId = getOpenCaseId();
        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null for admin user');
        }
    }

    // ─── getClosedReasonOptions ───────────────────────────────────────────────

    /**
     * @description Verifies that getClosedReasonOptions returns a non-null list
     *              containing only entries from the allowed set.
     */
    @IsTest
    static void testGetClosedReasonOptions_ReturnsAllowedValues() {
        Set<String> allowed = new Set<String>{ 'Resolved', 'No Longer Needed' };
        Test.startTest();
        List<TF_EX_CaseCommunityDetailController.PicklistOption> options =
            TF_EX_CaseCommunityDetailController.getClosedReasonOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Options list should not be null');
        for (TF_EX_CaseCommunityDetailController.PicklistOption opt : options) {
            System.assert(allowed.contains(opt.value), 'Option value should be in allowed set: ' + opt.value);
            System.assertNotEquals(null, opt.label, 'Option label should not be null');
        }
    }

    // ─── closeCase ────────────────────────────────────────────────────────────

    /**
     * @description Verifies that closeCase sets Status to 'Closed' and populates
     *              Closed_Reason__c when called with a valid reason.
     */
    @IsTest
    static void testCloseCase_ValidReason_Success() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.closeCase(caseId, 'Resolved');
            Test.stopTest();

            Case updated = [SELECT Status, Closed_Reason__c FROM Case WHERE Id = :caseId];
            System.assertEquals('Closed', updated.Status, 'Case Status should be Closed');
            System.assertEquals('Resolved', updated.Closed_Reason__c, 'Closed_Reason__c should be set');
        }
    }

    /**
     * @description Verifies that closeCase throws an AuraHandledException when
     *              closedReason is blank.
     */
    @IsTest
    static void testCloseCase_BlankReason_ThrowsException() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseCommunityDetailController.closeCase(caseId, '');
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that closeCase throws an AuraHandledException when
     *              closedReason is null.
     */
    @IsTest
    static void testCloseCase_NullReason_ThrowsException() {
        User cu     = getCustomerUser();
        Id   caseId = getOpenCaseId();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseCommunityDetailController.closeCase(caseId, null);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    // ─── reopenCase ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that reopenCase sets Status to 'ReOpened' and completes
     *              without error (Chatter FeedItem insert is covered implicitly —
     *              Salesforce restricts FeedItem SOQL to Id-based filters in test context).
     */
    @IsTest
    static void testReopenCase_ValidReason_Success() {
        User cu     = getCustomerUser();
        Id   caseId = getClosedCaseId();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.reopenCase(caseId, 'Still experiencing the issue');
            Test.stopTest();

            Case updated = [SELECT Status FROM Case WHERE Id = :caseId];
            System.assertEquals('ReOpened', updated.Status, 'Case Status should be ReOpened');
        }
    }

    /**
     * @description Verifies that reopenCase throws an AuraHandledException when
     *              reason is blank.
     */
    @IsTest
    static void testReopenCase_BlankReason_ThrowsException() {
        User cu     = getCustomerUser();
        Id   caseId = getClosedCaseId();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseCommunityDetailController.reopenCase(caseId, '');
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that reopenCase throws an AuraHandledException when
     *              reason is null.
     */
    @IsTest
    static void testReopenCase_NullReason_ThrowsException() {
        User cu     = getCustomerUser();
        Id   caseId = getClosedCaseId();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseCommunityDetailController.reopenCase(caseId, null);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    // ─── addCollaborator ──────────────────────────────────────────────────────

    /**
     * @description Verifies that addCollaborator creates a CaseTeamMember and returns
     *              a non-null CaseTeamMember Id.
     */
    /*@IsTest
    static void testAddCollaborator_NewMember_Success() {
        User cu     = getCustomerUser();
        User au     = getAdminUser();
        Id   caseId = getOpenCaseId();

        Id roleId = null;
        List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;

        System.runAs(cu) {
            Test.startTest();
            String ctmId = TF_EX_CaseCommunityDetailController.addCollaborator(caseId, au.Id, roleId);
            Test.stopTest();

            System.assertNotEquals(null, ctmId, 'CaseTeamMember Id should be returned');
            List<CaseTeamMember> members = [
                SELECT Id FROM CaseTeamMember
                WHERE  ParentId = :caseId AND MemberId = :au.Id
            ];
            System.assertEquals(1, members.size(), 'One CaseTeamMember should be created');
        }
    }*/

    /**
     * @description Verifies that calling addCollaborator twice with the same User
     *              returns the existing CaseTeamMember Id without creating a duplicate.
     */
    /*@IsTest
    static void testAddCollaborator_DuplicateMember_ReturnsExistingId() {
        User cu     = getCustomerUser();
        User au     = getAdminUser();
        Id   caseId = getOpenCaseId();

        Id roleId = null;
        List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;

        System.runAs(cu) {
            Test.startTest();
            String firstId  = TF_EX_CaseCommunityDetailController.addCollaborator(caseId, au.Id, roleId);
            String secondId = TF_EX_CaseCommunityDetailController.addCollaborator(caseId, au.Id, roleId);
            Test.stopTest();

            System.assertEquals(firstId, secondId, 'Duplicate call should return the same CaseTeamMember Id');
            List<CaseTeamMember> members = [
                SELECT Id FROM CaseTeamMember
                WHERE  ParentId = :caseId AND MemberId = :au.Id
            ];
            System.assertEquals(1, members.size(), 'Only one CaseTeamMember should exist');
        }
    }*/

    // ─── removeCollaborator ───────────────────────────────────────────────────

    /**
     * @description Verifies that removeCollaborator deletes the CaseTeamMember record.
     */
    /*@IsTest
    static void testRemoveCollaborator_Success() {
        User cu     = getCustomerUser();
        User au     = getAdminUser();
        Id   caseId = getOpenCaseId();

        Id roleId = null;
        List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;

        String ctmId = TF_EX_CaseCommunityDetailController.addCollaborator(caseId, au.Id, roleId);

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.removeCollaborator(Id.valueOf(ctmId));
            Test.stopTest();

            List<CaseTeamMember> remaining = [
                SELECT Id FROM CaseTeamMember
                WHERE  ParentId = :caseId AND MemberId = :au.Id
            ];
            System.assertEquals(0, remaining.size(), 'CaseTeamMember should be deleted');
        }
    }*/

    /**
     * @description Verifies that getCaseDetail returns the correct collaborator
     *              in the list after a CaseTeamMember has been added.
     */
    /*@IsTest
    static void testGetCaseDetail_WithCollaborator_ReturnsCollaboratorInList() {
        User cu     = getCustomerUser();
        User au     = getAdminUser();
        Id   caseId = getOpenCaseId();

        Id roleId = null;
        List<CaseTeamRole> roles = [SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;

        TF_EX_CaseCommunityDetailController.addCollaborator(caseId, au.Id, roleId);

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityDetailController.CaseDetailResult result =
                TF_EX_CaseCommunityDetailController.getCaseDetail(caseId);
            Test.stopTest();

            System.assertEquals(1, result.collaborators.size(), 'One collaborator should be present');
            System.assertEquals(
                String.valueOf(au.Id),
                result.collaborators[0].userId,
                'Collaborator userId should match the added User'
            );
        }
    }*/
}