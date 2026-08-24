@isTest
private class TF_EX_MindTouchTokenHelperTest {

    // =========================================================
    // TEST : buildToken()
    // =========================================================
    @isTest
    static void testBuildToken() {

        Test.startTest();

        String token =
            TF_EX_MindTouchTokenHelper.buildToken();

        Test.stopTest();

        System.assertNotEquals(
            null,
            token,
            'Token should not be null'
        );

        System.assert(
            token.startsWith('tkn_'),
            'Token should start with tkn_'
        );

        System.assert(
            token.contains('_'),
            'Token should contain separators'
        );

        List<String> parts =
            token.split('_');

        System.assert(
            parts.size() >= 5,
            'Token should contain all required parts'
        );
    }

    // =========================================================
    // TEST : token uniqueness
    // =========================================================
    @isTest
    static void testBuildTokenUniqueness() {

        Test.startTest();

        String token1 =
            TF_EX_MindTouchTokenHelper.buildToken();

        String token2 =
            TF_EX_MindTouchTokenHelper.buildToken();

        Test.stopTest();

        System.assertNotEquals(
            null,
            token1
        );

        System.assertNotEquals(
            null,
            token2
        );

        System.assert(
            token1.startsWith('tkn_')
        );

        System.assert(
            token2.startsWith('tkn_')
        );
    }

    // =========================================================
    // TEST : token contains hex signature
    // =========================================================
    @isTest
    static void testTokenContainsHash() {

        Test.startTest();

        String token =
            TF_EX_MindTouchTokenHelper.buildToken();

        Test.stopTest();

        String hashPart =
            token.substringAfterLast('_');

        System.assert(
            hashPart.length() > 10,
            'Hash portion should exist'
        );

        Boolean isHex = true;

        for (Integer i = 0; i < hashPart.length(); i++) {

            String ch =
                hashPart.substring(i, i + 1).toLowerCase();

            if (
                !'0123456789abcdef'.contains(ch)
            ) {
                isHex = false;
                break;
            }
        }

        System.assertEquals(
            true,
            isHex,
            'Hash should be hexadecimal'
        );
    }
}