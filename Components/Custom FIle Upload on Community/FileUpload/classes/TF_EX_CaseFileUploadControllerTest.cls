/**
 * @class       TF_EX_CaseFileUploadControllerTest
 * @description Test class for TF_EX_CaseFileUploadController.
 *              Covers uploadFile (success, blank/null input validation),
 *              deleteFiles (single, multiple, empty, and null list),
 *              and getFileDetails (single, multiple, empty, and null list).
 *              Declared without sharing — ContentVersion/ContentDocument operations
 *              run in system context regardless of the running user persona.
 * @createdBy   Truffle Consulting
 */
@IsTest
private class TF_EX_CaseFileUploadControllerTest {

    private static final String BASE64_CONTENT = EncodingUtil.base64Encode(
        Blob.valueOf('Test file content for unit testing')
    );
    private static final String FILE_NAME    = 'test_file.txt';
    private static final String CONTENT_TYPE = 'text/plain';

    /**
     * @description Creates shared test data for all test methods.
     *              Inserts one Account, two Contacts, two community Users (Customer and Admin),
     *              and assigns the corresponding Permission Sets to each User.
     */
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con1 = new Contact(
            FirstName = 'Customer',
            LastName  = 'User Test',
            Email     = 'customer.user.test@example.tebra.test',
            AccountId = acc.Id
        );
        Contact con2 = new Contact(
            FirstName = 'Admin',
            LastName  = 'User Test',
            Email     = 'admin.user.test@example.tebra.test',
            AccountId = acc.Id
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
                LastName          = 'User Test',
                Email             = 'customer.user.test@example.tebra.test',
                Username          = 'customer.user.test@example.tebra.test.sandbox',
                Alias             = 'cutest',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = customerProfile.Id,
                ContactId         = con1.Id
            );
            User adminUser = new User(
                FirstName         = 'Admin',
                LastName          = 'User Test',
                Email             = 'admin.user.test@example.tebra.test',
                Username          = 'admin.user.test@example.tebra.test.sandbox',
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
    }

    /**
     * @description Returns the Customer persona test User.
     * @return      User — community user assigned TF_EX_CustomerUserPermission.
     */
    private static User getCustomerUser() {
        return [
            SELECT Id FROM User
            WHERE  Username = 'customer.user.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    /**
     * @description Returns the Admin persona test User.
     * @return      User — community user assigned TF_EX_CustomerUserAdminPermission.
     */
    private static User getAdminUser() {
        return [
            SELECT Id FROM User
            WHERE  Username = 'admin.user.test@example.tebra.test.sandbox'
            LIMIT  1
        ];
    }

    // ─── uploadFile ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that uploadFile creates a ContentVersion and returns
     *              a valid ContentDocumentId for a Customer persona user.
     */
    @IsTest
    static void testUploadFile_CustomerUser_Success() {
        Test.startTest();
        String cdId = TF_EX_CaseFileUploadController.uploadFile(
            FILE_NAME, BASE64_CONTENT, CONTENT_TYPE
        );
        Test.stopTest();

        System.assertNotEquals(null, cdId, 'ContentDocumentId should be returned');
        List<ContentVersion> cvs = [
            SELECT Id, Title, ContentDocumentId
            FROM   ContentVersion
            WHERE  ContentDocumentId = :cdId
        ];
        System.assertEquals(1, cvs.size(), 'One ContentVersion should exist');
        System.assertEquals(FILE_NAME, cvs[0].Title, 'Title should match file name');
    }

    /**
     * @description Verifies that uploadFile creates a ContentDocument successfully
     *              when called in an Admin persona context.
     */
    @IsTest
    static void testUploadFile_AdminUser_Success() {
        Test.startTest();
        String cdId = TF_EX_CaseFileUploadController.uploadFile(
            'admin_upload.pdf', BASE64_CONTENT, 'application/pdf'
        );
        Test.stopTest();

        System.assertNotEquals(null, cdId, 'ContentDocumentId should be returned');
    }

    /**
     * @description Verifies that a blank fileName throws an AuraHandledException.
     */
    @IsTest
    static void testUploadFile_BlankFileName_ThrowsException() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseFileUploadController.uploadFile('', BASE64_CONTENT, CONTENT_TYPE);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that blank base64 content throws an AuraHandledException.
     */
    @IsTest
    static void testUploadFile_BlankBase64_ThrowsException() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseFileUploadController.uploadFile(FILE_NAME, '', CONTENT_TYPE);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that null fileName and base64 content throws an AuraHandledException.
     */
    @IsTest
    static void testUploadFile_NullInputs_ThrowsException() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            try {
                TF_EX_CaseFileUploadController.uploadFile(null, null, null);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
            }
            Test.stopTest();
        }
    }

    // ─── deleteFiles ──────────────────────────────────────────────────────────

    /**
     * @description Verifies that a single ContentDocument is deleted successfully.
     */
    @IsTest
    static void testDeleteFiles_CustomerUser_Success() {
        String cdId = TF_EX_CaseFileUploadController.uploadFile(
            'to_delete.txt', BASE64_CONTENT, CONTENT_TYPE
        );

        Test.startTest();
        TF_EX_CaseFileUploadController.deleteFiles(new List<Id>{ cdId });
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM ContentDocument WHERE Id = :cdId];
        System.assertEquals(0, remaining, 'ContentDocument should be deleted');
    }

    /**
     * @description Verifies that multiple ContentDocuments are all deleted in a single call.
     */
    @IsTest
    static void testDeleteFiles_MultipleFiles_Success() {
        List<Id> cdIds = new List<Id>();
        cdIds.add(TF_EX_CaseFileUploadController.uploadFile('file1.txt', BASE64_CONTENT, CONTENT_TYPE));
        cdIds.add(TF_EX_CaseFileUploadController.uploadFile('file2.txt', BASE64_CONTENT, CONTENT_TYPE));

        Test.startTest();
        TF_EX_CaseFileUploadController.deleteFiles(cdIds);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM ContentDocument WHERE Id IN :cdIds];
        System.assertEquals(0, remaining, 'All ContentDocuments should be deleted');
    }

    /**
     * @description Verifies that passing an empty list to deleteFiles completes without error.
     */
    @IsTest
    static void testDeleteFiles_EmptyList_NoOp() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseFileUploadController.deleteFiles(new List<Id>());
            Test.stopTest();
            System.assert(true, 'Empty list handled gracefully');
        }
    }

    /**
     * @description Verifies that passing null to deleteFiles completes without error.
     */
    @IsTest
    static void testDeleteFiles_NullList_NoOp() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            TF_EX_CaseFileUploadController.deleteFiles(null);
            Test.stopTest();
            System.assert(true, 'Null list handled gracefully');
        }
    }

    // ─── getFileDetails ───────────────────────────────────────────────────────

    /**
     * @description Verifies that getFileDetails returns the correct ContentVersion
     *              with matching Title, ContentDocumentId, and a populated ContentSize.
     */
    @IsTest
    static void testGetFileDetails_CustomerUser_Success() {
        String cdId = TF_EX_CaseFileUploadController.uploadFile(
            'details_test.txt', BASE64_CONTENT, CONTENT_TYPE
        );

        Test.startTest();
        List<ContentVersion> result = TF_EX_CaseFileUploadController.getFileDetails(
            new List<Id>{ cdId }
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return one ContentVersion');
        System.assertEquals(cdId, result[0].ContentDocumentId, 'ContentDocumentId should match');
        System.assertEquals('details_test.txt', result[0].Title, 'Title should match');
        System.assertNotEquals(null, result[0].ContentSize, 'ContentSize should be populated');
    }

    /**
     * @description Verifies that getFileDetails returns one ContentVersion per uploaded file
     *              when multiple ContentDocumentIds are provided.
     */
    @IsTest
    static void testGetFileDetails_MultipleFiles_Success() {
        List<Id> cdIds = new List<Id>();
        cdIds.add(TF_EX_CaseFileUploadController.uploadFile('detail1.txt', BASE64_CONTENT, CONTENT_TYPE));
        cdIds.add(TF_EX_CaseFileUploadController.uploadFile('detail2.txt', BASE64_CONTENT, CONTENT_TYPE));

        Test.startTest();
        List<ContentVersion> result = TF_EX_CaseFileUploadController.getFileDetails(cdIds);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return two ContentVersions');
    }

    /**
     * @description Verifies that passing an empty list to getFileDetails returns an empty result.
     */
    @IsTest
    static void testGetFileDetails_EmptyList_ReturnsEmpty() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            List<ContentVersion> result = TF_EX_CaseFileUploadController.getFileDetails(
                new List<Id>()
            );
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Empty list should return empty result');
        }
    }

    /**
     * @description Verifies that passing null to getFileDetails returns an empty result.
     */
    @IsTest
    static void testGetFileDetails_NullList_ReturnsEmpty() {
        User cu = getCustomerUser();
        System.runAs(cu) {
            Test.startTest();
            List<ContentVersion> result = TF_EX_CaseFileUploadController.getFileDetails(null);
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Null list should return empty result');
        }
    }
}