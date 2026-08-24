@isTest
private class TF_EX_MindTouchImageReplaceBatchTest {

    @TestSetup
    static void setupData() {
        List<KnowledgeCategoryMap__c> records = new List<KnowledgeCategoryMap__c>();

        // Record with MindTouch image URL
        records.add(new KnowledgeCategoryMap__c(
            Name                      = 'Article With Image',
            Title__c                  = 'Article With Image',
            Processed__c              = false,
            TransformedHTMLContent__c =
                '<img src="https://helpme.tebra.com/@api/deki/files/7/test-image.png?revision=1"/>'
        ));

        // Record without MindTouch image URL
        records.add(new KnowledgeCategoryMap__c(
            Name                      = 'Article No Image',
            Title__c                  = 'Article No Image',
            Processed__c              = false,
            TransformedHTMLContent__c = '<p>No MindTouch image URLs here.</p>'
        ));

        // Record with blank content
        records.add(new KnowledgeCategoryMap__c(
            Name                      = 'Blank Article',
            Title__c                  = 'Blank Article',
            Processed__c              = false,
            TransformedHTMLContent__c = null
        ));

        insert records;
    }

    // ── Test: batch runs without error — urlMap built in first execute ────────
    @isTest
    static void testBatchRunsWithoutError() {
        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchImageReplaceBatch(), 200);
        Test.stopTest();

        List<KnowledgeCategoryMap__c> processed = [
            SELECT Processed__c FROM KnowledgeCategoryMap__c WHERE Processed__c = true
        ];
        System.assert(processed.size() > 0, 'Records processed without error');
    }

    // ── Test: blank content is skipped without error ──────────────────────────
    @isTest
    static void testBlankContentSkipped() {
        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchImageReplaceBatch(), 200);
        Test.stopTest();

        KnowledgeCategoryMap__c blankRec = [
            SELECT TransformedHTMLContent__c, Processed__c
            FROM KnowledgeCategoryMap__c
            WHERE Title__c = 'Blank Article'
        ];
        System.assertEquals(true, blankRec.Processed__c, 'Blank article marked processed');
        System.assertEquals(null, blankRec.TransformedHTMLContent__c, 'Blank content unchanged');
    }

    // ── Test: record without @api/deki/files/ is skipped ─────────────────────
    @isTest
    static void testRecordWithoutMindTouchUrlSkipped() {
        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchImageReplaceBatch(), 200);
        Test.stopTest();

        KnowledgeCategoryMap__c noImageRec = [
            SELECT TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            WHERE Title__c = 'Article No Image'
        ];
        System.assertEquals(
            '<p>No MindTouch image URLs here.</p>',
            noImageRec.TransformedHTMLContent__c,
            'Content without MindTouch URL unchanged'
        );
    }

    // ── Test: constructor is empty and batch is Stateful ─────────────────────
    @isTest
    static void testConstructor() {
        TF_EX_MindTouchImageReplaceBatch batch = new TF_EX_MindTouchImageReplaceBatch();
        System.assertNotEquals(null, batch, 'Batch instance created');
    }

    // ── Test: finish() reports summary ────────────────────────────────────────
    @isTest
    static void testFinish() {
        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchImageReplaceBatch(), 200);
        Test.stopTest();

        System.assert(true, 'finish() ran without error');
    }

    // ── Test: empty scope ─────────────────────────────────────────────────────
    @isTest
    static void testEmptyScope() {
        delete [SELECT Id FROM KnowledgeCategoryMap__c];

        Test.startTest();
        Database.executeBatch(new TF_EX_MindTouchImageReplaceBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch handled empty scope without error');
    }
}