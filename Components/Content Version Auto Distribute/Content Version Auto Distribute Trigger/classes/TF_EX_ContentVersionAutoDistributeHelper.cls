public class TF_EX_ContentVersionAutoDistributeHelper {

    public static void createPublicLinks(List<ContentVersion> newVersions) {

        // ── 1. Filter to latest versions only ────────────────────────────────
        List<Id> contentVersionIds = new List<Id>();
        for (ContentVersion cv : newVersions) {
            if (cv.IsLatest) {
                contentVersionIds.add(cv.Id);
            }
        }
        if (contentVersionIds.isEmpty()) return;

        // ── 2. Query Title (needed for ContentDistribution.Name) ──────────────
        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
            SELECT Id, Title
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ]);

        // ── 3. Skip versions that already have a ContentDistribution ──────────
        // Prevents duplicate distributions if trigger fires more than once
        Set<Id> alreadyDistributed = new Set<Id>();
        for (ContentDistribution existing : [
            SELECT ContentVersionId
            FROM ContentDistribution
            WHERE ContentVersionId IN :contentVersionIds
        ]) {
            alreadyDistributed.add(existing.ContentVersionId);
        }

        // ── 4. Build ContentDistribution records ──────────────────────────────
        List<ContentDistribution> toInsert = new List<ContentDistribution>();
        for (Id cvId : contentVersionIds) {
            if (alreadyDistributed.contains(cvId)) continue;
            ContentVersion cv = cvMap.get(cvId);
            if (cv == null) continue;

            ContentDistribution cd = new ContentDistribution();
            cd.Name                              = cv.Title;
            cd.ContentVersionId                  = cvId;
            cd.PreferencesAllowOriginalDownload  = true;
            cd.PreferencesAllowPDFDownload       = true;
            cd.PreferencesAllowViewInBrowser     = true;
            toInsert.add(cd);
        }

        if (toInsert.isEmpty()) return;

        // ── 5. Insert ContentDistributions ────────────────────────────────────
        try {
            insert toInsert;
        } catch (DmlException e) {
            System.debug('Error creating ContentDistribution: ' + e.getMessage());
            return;
        }

        // ── 6. Collect inserted ContentDistribution IDs ───────────────────────
        // ContentDownloadUrl is NOT immediately available after insert —
        // Salesforce populates it after the transaction commits.
        // We pass the IDs to a @future method to query and write back.
        List<Id> distributionIds = new List<Id>();
        for (ContentDistribution cd : toInsert) {
            distributionIds.add(cd.Id);
        }

        writeDownloadUrlsAsync(distributionIds);
    }

    // ── @future: runs after current transaction commits ───────────────────────
    // At this point ContentDownloadUrl is populated by Salesforce.
    // We query it and write it back to ContentVersion.KnowledgeReferenceURL__c
    @future
    private static void writeDownloadUrlsAsync(List<Id> distributionIds) {

        // Query distributions — ContentDownloadUrl is now populated
        List<ContentDistribution> distributions = [
            SELECT Id, ContentVersionId, ContentDownloadUrl
            FROM ContentDistribution
            WHERE Id IN :distributionIds
        ];
        
        if (distributions.isEmpty()) return;

        // Build ContentVersion update list
        List<ContentVersion> toUpdate = new List<ContentVersion>();
        for (ContentDistribution cd : distributions) {
            if (String.isBlank(cd.ContentDownloadUrl)) continue;
            toUpdate.add(new ContentVersion(
                Id                       = cd.ContentVersionId,
                KnowledgeReferenceURL__c = cd.ContentDownloadUrl
            ));
        }

        if (toUpdate.isEmpty()) return;

        try {
            update toUpdate;
        } catch (DmlException e) {
            System.debug('Error writing KnowledgeReferenceURL__c: ' + e.getMessage());
        }
    }
}