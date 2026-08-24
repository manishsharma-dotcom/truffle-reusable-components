/**
 * @description Test class for TF_EX_CaseCommunityCreateController.
 *              Covers getInitialData, createCase, and getCollaborators
 *              across Customer User and Customer Admin User personas. *              
 *
 * @author      Truffle Consulting
 */
@IsTest
private class TF_EX_CaseCommunityCreateControllerTest {

    // ── Test Data Setup ───────────────────────────────────────────────────────

    /**
     * @description Creates all test data shared across test methods:
     *              two Accounts, three Contacts, three community Users
     *              (Customer, Admin, Collaborator), permission set assignments,
     *              and AccountContactRelations including a secondary indirect account
     *              to support multi-account test scenarios.
     */
    @TestSetup
    static void setupData() {
        Account acc1 = new Account(Name = 'Primary Account');
        Account acc2 = new Account(Name = 'Secondary Account');
        insert new List<Account>{ acc1, acc2 };

        Contact con1 = new Contact(
            FirstName = 'Customer',   LastName = 'CC Test',
            Email     = 'customer.cc.test@example.tebra.test',  AccountId = acc1.Id , Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        Contact con2 = new Contact(
            FirstName = 'Admin',      LastName = 'CC Test',
            Email     = 'admin.cc.test@example.tebra.test',     AccountId = acc1.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        Contact con3 = new Contact(
            FirstName = 'Collaborator', LastName = 'CC Test',
            Email     = 'collaborator.cc.test@example.tebra.test', AccountId = acc1.Id, Specialty_NEW__c = 'Other' , MailingPostalCode = '31905'
        );
        insert new List<Contact>{ con1, con2, con3 };

        List<CaseTeamRole> roles = [
            SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1
        ];
        if (roles.isEmpty()) {
            insert new CaseTeamRole(Name = 'Collaborators', AccessLevel = 'Edit');
        }

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile customerProfile = [
                SELECT Id FROM Profile WHERE Name = 'Customer User' LIMIT 1
            ];
            Profile adminProfile = [
                SELECT Id FROM Profile WHERE Name = 'Customer User Admin' LIMIT 1
            ];

            User customerUser = new User(
                FirstName = 'Customer', LastName = 'CC Test',
                Email     = 'customer.cc.test@example.tebra.test',
                Username  = 'customer.cc.test@example.tebra.test.sandbox',
                Alias     = 'cctest',  TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US', ProfileId = customerProfile.Id,
                ContactId = con1.Id
            );
            User adminUser = new User(
                FirstName = 'Admin', LastName = 'CC Test',
                Email     = 'admin.cc.test@example.tebra.test',
                Username  = 'admin.cc.test@example.tebra.test.sandbox',
                Alias     = 'acctest', TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US', ProfileId = adminProfile.Id,
                ContactId = con2.Id
            );
            User collaboratorUser = new User(
                FirstName = 'Collaborator', LastName = 'CC Test',
                Email     = 'collaborator.cc.test@example.tebra.test',
                Username  = 'collaborator.cc.test@example.tebra.test.sandbox',
                Alias     = 'coltest', TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US', ProfileId = customerProfile.Id,
                ContactId = con3.Id
            );
            insert new List<User>{ customerUser, adminUser, collaboratorUser };

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
                    AssigneeId = customerUser.Id,    PermissionSetId = customerPS.Id),
                new PermissionSetAssignment(
                    AssigneeId = adminUser.Id,       PermissionSetId = adminPS.Id),
                new PermissionSetAssignment(
                    AssigneeId = collaboratorUser.Id, PermissionSetId = customerPS.Id)
            };
        }

        User customerUser = [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'customer.cc.test@example.tebra.test.sandbox' LIMIT 1
        ];
        insert new AccountContactRelation(
            AccountId = acc2.Id,
            ContactId = customerUser.ContactId,
            IsActive  = true
        );
    }

    // ── Helper Methods ────────────────────────────────────────────────────────

    /** @description Retrieves the Customer community test User. */
    private static User getCustomerUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'customer.cc.test@example.tebra.test.sandbox' LIMIT 1
        ];
    }

    /** @description Retrieves the Customer Admin community test User. */
    private static User getAdminUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'admin.cc.test@example.tebra.test.sandbox' LIMIT 1
        ];
    }

    /** @description Retrieves the Collaborator community test User. */
    private static User getCollaboratorUser() {
        return [
            SELECT Id, ContactId FROM User
            WHERE  Username = 'collaborator.cc.test@example.tebra.test.sandbox' LIMIT 1
        ];
    }

    /**
     * @description Returns the Id of a Case RecordType by DeveloperName.
     * @param  developerName DeveloperName of the RecordType.
     * @return RecordType Id, or null if not found.
     */
    private static Id getRecordTypeId(String developerName) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Case' AND DeveloperName = :developerName LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /** @description Returns the Id of the Primary Account test record. */
    private static Id getPrimaryAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Primary Account' LIMIT 1].Id;
    }

    /** @description Returns the Id of the Collaborators CaseTeamRole, or null if absent. */
    private static String getCaseTeamRoleId() {
        List<CaseTeamRole> roles = [
            SELECT Id FROM CaseTeamRole WHERE Name = 'Collaborators' LIMIT 1
        ];
        return roles.isEmpty() ? null : String.valueOf(roles[0].Id);
    }

    // ── getInitialData ────────────────────────────────────────────────────────

    /**
     * @description Verifies that getInitialData returns a populated result
     *              for a standard Customer User.
     */
    @IsTest
    static void testGetInitialData_CustomerUser_Success() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            System.assertNotEquals(null, data, 'InitialData should not be null');
            System.assertNotEquals(null, data.currentUserEmail, 'Email should be populated');
            System.assertEquals(
                'customer.cc.test@example.tebra.test', data.currentUserEmail,
                'Email should match the running user');
            System.assertNotEquals(null, data.currentUserContactId, 'ContactId should be set');
            System.assertNotEquals(null, data.accounts, 'Accounts list should not be null');
            System.assert(data.accounts.size() > 0, 'Should have at least one linked account');
            System.assertNotEquals(null, data.recordTypes, 'Record types should not be null');
            System.assert(data.recordTypes.size() > 0, 'Should have at least one record type');
        }
    }

    /**
     * @description Verifies that isSingleAccount is false when the user is linked
     *              to more than one account via AccountContactRelation.
     */
    @IsTest
    static void testGetInitialData_MultipleAccounts_NotSingleAccount() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            System.assertEquals(false, data.isSingleAccount,
                'isSingleAccount should be false when multiple ACRs exist');
            System.assert(data.accounts.size() >= 2,
                'Both linked accounts should be returned');
        }
    }

    /**
     * @description Verifies that isSingleAccount is true and singleAccountId/Name
     *              are populated when the user has exactly one linked account.
     */
    @IsTest
    static void testGetInitialData_SingleAccount_IsSingleAccountTrue() {
        User au = getAdminUser();
        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            System.assertNotEquals(null, data);
            System.assertEquals(true, data.isSingleAccount,
                'isSingleAccount should be true for a user with one linked account');
            System.assertNotEquals(null, data.singleAccountId,
                'singleAccountId should be populated');
            System.assertNotEquals(null, data.singleAccountName,
                'singleAccountName should be populated');
        }
    }

    /**
     * @description Verifies that primaryAccountId is set to the account where
     *              IsDirect = true on the AccountContactRelation.
     */
    @IsTest
    static void testGetInitialData_PrimaryAccountId_IsDirectAccount() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            System.assertNotEquals(null, data.primaryAccountId,
                'primaryAccountId should be set for a direct ACR');
            System.assertEquals(
                getPrimaryAccountId(), (Id) data.primaryAccountId,
                'primaryAccountId should match the direct-relationship account');
        }
    }

    /**
     * @description Verifies that the permitted Case record types include
     *              Customer_Support_New in the returned list.
     */
    @IsTest
    static void testGetInitialData_RecordTypes_ContainsExpectedTypes() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            Set<String> rtNames = new Set<String>();
            for (RecordType rt : data.recordTypes) rtNames.add(rt.DeveloperName);

            System.assert(rtNames.contains('Customer_Support_New'),
                'Customer_Support_New record type should be present');
        }
    }

    /**
     * @description Verifies that caseTeamRoleId is populated when the
     *              Collaborators CaseTeamRole exists in the org.
     */
    /*@IsTest
    static void testGetInitialData_CaseTeamRoleId_Populated() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.InitialData data =
                TF_EX_CaseCommunityCreateController.getInitialData();
            Test.stopTest();

            System.assertNotEquals(null, data.caseTeamRoleId,
                'caseTeamRoleId should be populated when the Collaborators role exists');
        }
    }*/

    // ── createCase ────────────────────────────────────────────────────────────

    /**
     * @description Verifies that a basic Case is created successfully by a
     *              Customer User with no attachments or collaborators, and that
     *              core fields are persisted correctly.
     */
    @IsTest
    static void testCreateCase_CustomerUser_BasicCase_Success() {
        User cu    = getCustomerUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    '5551234567', 'customer.cc.test@example.tebra.test',
                    'Platform', 'Dashboard', 'Navigation',
                    'Test Subject', 'Test Description',
                    new List<String>(), new List<String>(), null
                );
            Test.stopTest();

            System.assertNotEquals(null, result,           'Result should not be null');
            System.assertNotEquals(null, result.caseId,    'Case Id should be returned');
            System.assertNotEquals(null, result.caseNumber,'Case Number should be returned');

            Case inserted = [
                SELECT Subject, Status, Origin, Description
                FROM   Case WHERE Id = :result.caseId LIMIT 1
            ];
            System.assertEquals('Test Subject',     inserted.Subject,     'Subject should match');
            System.assertEquals('Community',        inserted.Origin,      'Origin should be Community');
            System.assertEquals('Test Description', inserted.Description, 'Description should match');
        }
    }

    /**
     * @description Verifies that a basic Case is created successfully by a
     *              Customer Admin User.
     */
    @IsTest
    static void testCreateCase_AdminUser_BasicCase_Success() {
        User au    = getAdminUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();

        System.runAs(au) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(au.ContactId),
                    null, 'admin.cc.test@example.tebra.test',
                    'Billing', 'Invoice', null,
                    'Admin Test Subject', 'Admin Test Description',
                    new List<String>(), new List<String>(), null
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            System.assertNotEquals(null, result.caseNumber);
        }
    }

    /**
     * @description Verifies that ContentDocumentLinks are created when valid
     *              ContentDocument Ids are passed to createCase.
     */
    @IsTest
    static void testCreateCase_WithContentDocumentLinks_Success() {
        User cu    = getCustomerUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();

        ContentVersion cv = new ContentVersion(
            Title          = 'test_attachment.txt',
            PathOnClient   = 'test_attachment.txt',
            VersionData    = Blob.valueOf('Test attachment content'),
            IsMajorVersion = true
        );
        insert cv;
        String cdId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
        ].ContentDocumentId;

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', 'Dashboard', null,
                    'Subject with Attachment', 'Description with Attachment',
                    new List<String>(), new List<String>{ cdId }, null
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            List<ContentDocumentLink> cdls = [
                SELECT Id FROM ContentDocumentLink
                WHERE  LinkedEntityId = :result.caseId AND ContentDocumentId = :cdId
            ];
            System.assertEquals(1, cdls.size(), 'One ContentDocumentLink should be created');
        }
    }

    /**
     * @description Verifies that CaseTeamMember records are created when
     *              collaborator User Ids and a valid role Id are provided.
     */
    /*@IsTest
    static void testCreateCase_WithCollaborators_Success() {
        User cu           = getCustomerUser();
        User collaborator = getCollaboratorUser();
        Id   rtId         = getRecordTypeId('Clinical_Enrollments');
        Id   accId        = getPrimaryAccountId();
        String roleId     = getCaseTeamRoleId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', 'Dashboard', null,
                    'Subject with Collaborator', 'Description with Collaborator',
                    new List<String>{ String.valueOf(collaborator.Id) },
                    new List<String>(), roleId
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            if (String.isNotBlank(roleId)) {
                List<CaseTeamMember> ctms = [
                    SELECT Id FROM CaseTeamMember
                    WHERE  ParentId = :result.caseId AND MemberId = :collaborator.Id
                ];
                System.assertEquals(1, ctms.size(), 'One CaseTeamMember should be created');
            }
        }
    }*/

    /**
     * @description Verifies that passing null for contentDocumentIds does not
     *              cause an error and results in no ContentDocumentLinks.
     */
    @IsTest
    static void testCreateCase_NullContentDocumentIds_NoLinksCreated() {
        User cu    = getCustomerUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', null, null,
                    'Null Files Subject', 'Null Files Description',
                    null, null, null
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId, 'Case should still be created');
            List<ContentDocumentLink> cdls = [
                SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :result.caseId
            ];
            System.assertEquals(0, cdls.size(), 'No ContentDocumentLinks should exist');
        }
    }

    /**
     * @description Verifies that passing an empty collaborator list results in
     *              no CaseTeamMember records being created.
     */
    @IsTest
    static void testCreateCase_EmptyCollaboratorIds_NoCaseTeamMembers() {
        User cu    = getCustomerUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();
        String roleId = getCaseTeamRoleId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', null, null,
                    'No Collab Subject', 'No Collab Description',
                    new List<String>(), new List<String>(), roleId
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            List<CaseTeamMember> ctms = [
                SELECT Id FROM CaseTeamMember WHERE ParentId = :result.caseId
            ];
            System.assertEquals(0, ctms.size(), 'No CaseTeamMembers should be created');
        }
    }

    /**
     * @description Verifies that passing the same collaborator User Id multiple times
     *              results in only one CaseTeamMember being created (deduplication).
     */
    /*@IsTest
    static void testCreateCase_DuplicateCollaboratorIds_DeduplicatedInsert() {
        User cu           = getCustomerUser();
        User collaborator = getCollaboratorUser();
        Id   rtId         = getRecordTypeId('Clinical_Enrollments');
        Id   accId        = getPrimaryAccountId();
        String roleId     = getCaseTeamRoleId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', null, null,
                    'Dupe Collab Subject', 'Dupe Collab Description',
                    new List<String>{
                        String.valueOf(collaborator.Id),
                        String.valueOf(collaborator.Id)
                    },
                    new List<String>(), roleId
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            if (String.isNotBlank(roleId)) {
                List<CaseTeamMember> ctms = [
                    SELECT Id FROM CaseTeamMember
                    WHERE  ParentId = :result.caseId AND MemberId = :collaborator.Id
                ];
                System.assertEquals(1, ctms.size(),
                    'Duplicate collaborator Id should produce only one CaseTeamMember');
            }
        }
    }*/

    /**
     * @description Verifies that blank or null entries in the contentDocumentIds
     *              list are safely skipped without causing errors.
     */
    @IsTest
    static void testCreateCase_BlankContentDocumentIdInList_Skipped() {
        User cu    = getCustomerUser();
        Id   rtId  = getRecordTypeId('Clinical_Enrollments');
        Id   accId = getPrimaryAccountId();

        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseCommunityCreateController.CaseResult result =
                TF_EX_CaseCommunityCreateController.createCase(
                    rtId, String.valueOf(accId), String.valueOf(cu.ContactId),
                    null, 'customer.cc.test@example.tebra.test',
                    'Platform', null, null,
                    'Blank CDId Subject', 'Blank CDId Description',
                    new List<String>(), new List<String>{ '', null }, null
                );
            Test.stopTest();

            System.assertNotEquals(null, result.caseId);
            List<ContentDocumentLink> cdls = [
                SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :result.caseId
            ];
            System.assertEquals(0, cdls.size(), 'Blank or null CDIds should be skipped');
        }
    }

    // ── getCollaborators ──────────────────────────────────────────────────────

    /**
     * @description Verifies that passing a blank accountId returns an empty list.
     */
    @IsTest
    static void testGetCollaborators_BlankAccountId_ReturnsEmpty() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseCommunityCreateController.CollaboratorOption> result =
                TF_EX_CaseCommunityCreateController.getCollaborators('');
            Test.stopTest();

            System.assertEquals(0, result.size(),
                'Blank accountId should return an empty list');
        }
    }

    /**
     * @description Verifies that passing a null accountId returns an empty list.
     */
    @IsTest
    static void testGetCollaborators_NullAccountId_ReturnsEmpty() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseCommunityCreateController.CollaboratorOption> result =
                TF_EX_CaseCommunityCreateController.getCollaborators(null);
            Test.stopTest();

            System.assertEquals(0, result.size(),
                'Null accountId should return an empty list');
        }
    }

    /**
     * @description Verifies that the currently running user is excluded from
     *              the collaborator list even when linked to the queried account.
     */
    @IsTest
    static void testGetCollaborators_ValidAccount_ExcludesCurrentUser() {
        User cu    = getCustomerUser();
        Id   accId = getPrimaryAccountId();

        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseCommunityCreateController.CollaboratorOption> result =
                TF_EX_CaseCommunityCreateController.getCollaborators(String.valueOf(accId));
            Test.stopTest();

            for (TF_EX_CaseCommunityCreateController.CollaboratorOption opt : result) {
                System.assertNotEquals(String.valueOf(cu.Id), opt.userId,
                    'The running user should be excluded from the collaborator list');
            }
        }
    }

    /**
     * @description Verifies that an account with no linked contacts returns
     *              an empty collaborator list without errors.
     */
    @IsTest
    static void testGetCollaborators_AccountWithNoContacts_ReturnsEmpty() {
        User cu = getCustomerUser();
        Account emptyAcc = new Account(Name = 'Empty Account');
        insert emptyAcc;

        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseCommunityCreateController.CollaboratorOption> result =
                TF_EX_CaseCommunityCreateController.getCollaborators(
                    String.valueOf(emptyAcc.Id));
            Test.stopTest();

            System.assertEquals(0, result.size(),
                'An account with no contacts should return an empty collaborator list');
        }
    }

    /**
     * @description Verifies that each CollaboratorOption returned has all fields
     *              correctly populated, including userId, label, and accountIds.
     */
    @IsTest
    static void testGetCollaborators_OptionFields_PopulatedCorrectly() {
        User cu    = getCustomerUser();
        Id   accId = getPrimaryAccountId();

        System.runAs(cu) {
            Test.startTest();
            List<TF_EX_CaseCommunityCreateController.CollaboratorOption> result =
                TF_EX_CaseCommunityCreateController.getCollaborators(String.valueOf(accId));
            Test.stopTest();

            for (TF_EX_CaseCommunityCreateController.CollaboratorOption opt : result) {
                System.assertNotEquals(null, opt.userId,     'userId should be populated');
                System.assertNotEquals(null, opt.label,      'label should be populated');
                System.assertNotEquals(null, opt.accountIds, 'accountIds should be populated');
                System.assertEquals(1, opt.accountIds.size(),
                    'accountIds should contain exactly one entry');
                System.assertEquals(String.valueOf(accId), opt.accountIds[0],
                    'accountId in the option should match the queried account');
            }
        }
    }
}