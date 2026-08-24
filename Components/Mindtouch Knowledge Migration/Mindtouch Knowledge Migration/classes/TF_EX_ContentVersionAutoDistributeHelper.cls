public class TF_EX_ContentVersionAutoDistributeHelper {

    public static void createPublicLinks(List<ContentVersion> newVersions) {
        List<ContentDistribution> distributionsToInsert = new List<ContentDistribution>();
        List<String> contentVersionIds = new List<String>();

        for (ContentVersion cv : newVersions) {
            // A file upload via the UI creates a new ContentVersion with IsLatest = true
            // We need to ensure we only process the primary upload event and not subsequent updates/versions if that's the intent
            if (cv.IsLatest) { 
                contentVersionIds.add(cv.Id);
            }
        }
        
        // Query the necessary data before creating ContentDistributions
        // The ContentDistribution object requires a ContentVersionId
        List<ContentVersion> versionsWithData = [
            SELECT Id, Title, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id IN :contentVersionIds
        ];

        for (ContentVersion cv : versionsWithData) {
            ContentDistribution cd = new ContentDistribution();
            cd.Name = cv.Title;
            cd.ContentVersionId = cv.Id;
            // Set preferences as needed; these allow viewing/downloading the file
            cd.PreferencesAllowOriginalDownload = true;
            cd.PreferencesAllowPDFDownload = true;
            cd.PreferencesAllowViewInBrowser = true;
            distributionsToInsert.add(cd);
        }

        if (!distributionsToInsert.isEmpty()) {
            try {
                insert distributionsToInsert;
                // After insertion, the DistributionPublicUrl and ContentDownloadUrl fields will be populated automatically
                // You can query these fields back if you need to store the URL elsewhere (e.g., on a custom field of a related object)
                // Example query to get the generated URLs:
                // List<ContentDistribution> insertedCds = [SELECT Id, DistributionPublicUrl, ContentDownloadUrl FROM ContentDistribution WHERE Id IN :distributionsToInsert];
            } catch (DmlException e) {
                System.debug('Error creating ContentDistribution links: ' + e.getMessage());
            }
        }
    }

}