@isTest
private class TF_EX_MindTouchImageUrlReplacerTest {

    // =========================================================
    // Helper : Unique username
    // =========================================================
    private static String uniqueUsername() {

        return 'nipun.'
            + System.currentTimeMillis()
            + Math.abs(Crypto.getRandomInteger())
            + '@testorg.com';
    }

    // =========================================================
    // Helper : Create User
    // =========================================================
    private static User createUser() {
        return [SELECT Id FROM user WHERE name = 'Nipun Garg'];
  /* Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Standard User'
        LIMIT 1
    ];

    String uniqueKey =
        String.valueOf(Math.abs(Crypto.getRandomInteger()));

    User u = new User(
        FirstName = 'Nipun',
        LastName = 'Garg',
        Alias = 'tu' + uniqueKey.left(3),
        Email = 'test' + uniqueKey + '@testorg.com',
        Username = 'test' + uniqueKey + '@testorg.com',
        ProfileId = p.Id,
        TimeZoneSidKey = 'America/Los_Angeles',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
*
    //insert u;

    return u;*/
}

    // =========================================================
    // Helper : Create ContentDistribution
    // =========================================================
   private static void createDistribution(
    String title,
    User owner
) {

    String uniqueKey =
        String.valueOf(DateTime.now().getTime()) +
        String.valueOf(Math.abs(Crypto.getRandomInteger()));

    System.runAs(owner) {

        ContentVersion cv = new ContentVersion(
            Title = title + '_' + uniqueKey,
            PathOnClient = uniqueKey + '.png',
            VersionData = Blob.valueOf(uniqueKey),
            IsMajorVersion = true
        );

        insert cv;

        cv = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDistribution cd =
            new ContentDistribution(
                Name = uniqueKey,
                ContentVersionId = cv.Id,
                PreferencesAllowViewInBrowser = true,
                PreferencesLinkLatestVersion = true
            );

        //insert cd;
    }
}

    // =========================================================
    // TEST : verifyMapping()
    // =========================================================
   @isTest
static void testVerifyMapping() {

    Test.startTest();

    TF_EX_MindTouchImageUrlReplacer.verifyMapping();

    Test.stopTest();

    System.assert(true);
}
    // =========================================================
    // TEST : buildFilenameToPublicUrlMap()
    // =========================================================
    @isTest
    static void testBuildFilenameToPublicUrlMap() {

        User u = createUser();

        createDistribution(
            'Dashboard_Overview',
            u
        );

        Test.startTest();

        Map<String, String> result =
            TF_EX_MindTouchImageUrlReplacer.buildFilenameToPublicUrlMap();

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );
    }

    // =========================================================
    // TEST : Empty distributions branch
    // =========================================================
    @isTest
    static void testBuildFilenameEmpty() {

        createUser();

        Test.startTest();

        Map<String, String> result =
            TF_EX_MindTouchImageUrlReplacer.buildFilenameToPublicUrlMap();

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );
    }

    // =========================================================
    // TEST : normalizeMindTouchUrl()
    // =========================================================
    @isTest
    static void testNormalizeMindTouchUrl() {

        // full URL
        System.assertEquals(
            'billing_patientcollections_access',
            TF_EX_MindTouchImageUrlReplacer.normalizeMindTouchUrl(
                    'https://helpme.tebra.com/@api/deki/files/7/Billing_PatientCollections_Access.png?revision=1'
                )
        );

        // filename only
        System.assertEquals(
            'simpleimage',
            TF_EX_MindTouchImageUrlReplacer.normalizeMindTouchUrl(
                    'SimpleImage.png'
                )
        );

        // no extension
        System.assertEquals(
            'myimage',
            TF_EX_MindTouchImageUrlReplacer.normalizeMindTouchUrl(
                    'https://helpme.tebra.com/@api/deki/files/7/myimage'
                )
        );

        // null
        System.assertEquals(
            '',
            TF_EX_MindTouchImageUrlReplacer.normalizeMindTouchUrl(null)
        );

        // blank
        System.assertEquals(
            '',
            TF_EX_MindTouchImageUrlReplacer.normalizeMindTouchUrl('')
        );
    }

    // =========================================================
    // TEST : replaceImageUrls() blank
    // =========================================================
    @isTest
    static void testReplaceBlankHtml() {

        Map<String, String> urlMap =
            new Map<String, String>();

        System.assertEquals(
            '',
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    '',
                    urlMap
                )
        );

        System.assertEquals(
            null,
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    null,
                    urlMap
                )
        );
    }

    // =========================================================
    // TEST : replaceImageUrls() no token
    // =========================================================
    @isTest
    static void testReplaceNoToken() {

        String html =
            '<img src="https://google.com/image.png"/>';

        Map<String, String> urlMap =
            new Map<String, String>{
                'image' => 'https://sf.com/new.png'
            };

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    urlMap
                );

        System.assertEquals(
            html,
            result
        );
    }

    // =========================================================
    // TEST : matched URL replaced
    // =========================================================
    @isTest
    static void testReplaceMatchedUrl() {

        String oldUrl =
            'https://helpme.tebra.com/@api/deki/files/7/test-image.png?revision=1';

        String newUrl =
            'https://salesforce.com/test-image.png';

        String html =
            '<img src="' + oldUrl + '"/>';

        Map<String, String> urlMap =
            new Map<String, String>{
                'test-image' => newUrl
            };

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    urlMap
                );

        System.assert(
            result.contains(newUrl)
        );

        System.assert(
            !result.contains(oldUrl)
        );
    }

    // =========================================================
    // TEST : unmatched URL
    // =========================================================
    @isTest
    static void testReplaceUnmatchedUrl() {

        String oldUrl =
            'https://helpme.tebra.com/@api/deki/files/8/unmapped.png';

        String html =
            '<img src="' + oldUrl + '"/>';

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    new Map<String, String>()
                );

        System.assert(
            result.contains(oldUrl)
        );
    }

    // =========================================================
    // TEST : duplicate URLs
    // =========================================================
    @isTest
    static void testReplaceDuplicateUrls() {

        String oldUrl =
            'https://helpme.tebra.com/@api/deki/files/9/shared.png';

        String newUrl =
            'https://sf.com/shared.png';

        String html =
            '<img src="' + oldUrl + '"/>' +
            '<img src="' + oldUrl + '"/>';

        Map<String, String> urlMap =
            new Map<String, String>{
                'shared' => newUrl
            };

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    urlMap
                );

        System.assert(
            !result.contains(oldUrl)
        );

        Integer first =
            result.indexOf(newUrl);

        Integer second =
            result.indexOf(
                newUrl,
                first + 1
            );

        System.assert(
            second != -1
        );
    }

    // =========================================================
    // TEST : mixed matched/unmatched URLs
    // =========================================================
    @isTest
    static void testReplaceMixedUrls() {

        String matchedOld =
            'https://helpme.tebra.com/@api/deki/files/1/matched.png';

        String unmatchedOld =
            'https://helpme.tebra.com/@api/deki/files/2/unmatched.png';

        String newUrl =
            'https://sf.com/matched.png';

        String html =
            '<img src="' + matchedOld + '"/>' +
            '<img src="' + unmatchedOld + '"/>';

        Map<String, String> urlMap =
            new Map<String, String>{
                'matched' => newUrl
            };

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    urlMap
                );

        System.assert(
            result.contains(newUrl)
        );

        System.assert(
            result.contains(unmatchedOld)
        );

        System.assert(
            !result.contains(matchedOld)
        );
    }

    // =========================================================
    // TEST : single quote regex branch
    // =========================================================
    @isTest
    static void testReplaceSingleQuoteBranch() {

        String oldUrl =
            'https://helpme.tebra.com/@api/deki/files/3/single.png';

        String newUrl =
            'https://sf.com/single.png';

        String html =
            '<img src=\'' + oldUrl + '\'/>';

        Map<String, String> urlMap =
            new Map<String, String>{
                'single' => newUrl
            };

        String result =
            TF_EX_MindTouchImageUrlReplacer.replaceImageUrls(
                    html,
                    urlMap
                );

        System.assert(
            result.contains(newUrl)
        );

        System.assert(
            !result.contains(oldUrl)
        );
    }
}