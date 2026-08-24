public class TF_EX_MindTouchImageUrlReplacer {

    // ─── Verify mapping - run from Anonymous Apex first ──────────────────────
    public static void verifyMapping() {
        Map<String, String> urlMap = buildFilenameToPublicUrlMap();
        System.debug('Total images mapped: ' + urlMap.size());
        for (String key : urlMap.keySet()) {
            System.debug('Normalized: ' + key + ' → ' + urlMap.get(key));
        }
    }

    // ─── Build map: SF title (lowercase) → ContentDownloadUrl ────────────────
    public static Map<String, String> buildFilenameToPublicUrlMap() {
        Map<String, String> result = new Map<String, String>();
        Id TruffleAdminId1;
        Id TruffleAdminId2;
        List<User> users = [Select Id,Name from User where Name = 'Nipun Garg' OR Name = 'Veeranch Srivastava'];
        for(User u : users){
            if(u.name == 'Nipun Garg'){
                TruffleAdminId1 = u.id;
            }
            if(u.name == 'Veeranch Srivastava'){
                TruffleAdminId2 = u.id;
            }
        }
        
        List<ContentDistribution> dists = [
            SELECT Id,
                   ContentDownloadUrl,
                   DistributionPublicUrl,
                   ContentVersionId,
                   Name
            FROM ContentDistribution where (createdById=:TruffleAdminId1 OR createdById=:TruffleAdminId2)
        ];

        if (dists.isEmpty()) {
            System.debug('No ContentDistribution records found');
            return result;
        }

        Set<Id> cvIds = new Set<Id>();
        for (ContentDistribution cd : dists) {
            cvIds.add(cd.ContentVersionId);
        }

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
            SELECT Id, Title, FileExtension
            FROM ContentVersion
            WHERE Id IN :cvIds
        ]);

        for (ContentDistribution cd : dists) {
            ContentVersion cv = cvMap.get(cd.ContentVersionId);
            if (cv == null) continue;

            String urlToUse = '';
            if (!String.isBlank(cd.ContentDownloadUrl)) {
                urlToUse = cd.ContentDownloadUrl;
            }
            else {
                System.debug('WARNING - No URL for: ' + cv.Title);
                continue;
            }

            // ── CHANGED: just lowercase — preserve underscores/hyphens ───────
            // "Billing_PatientCollections_Access" → "billing_patientcollections_access"
            String normalizedTitle = cv.Title.toLowerCase();

            result.put(normalizedTitle, urlToUse);
            System.debug('Mapped: ' + cv.Title + ' → ' + normalizedTitle);
        }

        return result;
    }

    // ─── Extract all MindTouch image URLs from HTML ───────────────────────────
    /*public static List<String> extractMindTouchImageUrls(String html) {
        List<String> urls = new List<String>();
        if (String.isBlank(html)) return urls;

        String searchToken = '@api/deki/files/';
        Integer cursor = 0;

        while (cursor < html.length()) {
            Integer tokenPos = html.indexOf(searchToken, cursor);
            if (tokenPos == -1) break;

            Integer openQuote = -1;
            for (Integer i = tokenPos; i >= Math.max(0, tokenPos - 200); i--) {
                String ch = html.substring(i, i + 1);
                if (ch == '"' || ch == '\'') {
                    openQuote = i;
                    break;
                }
            }

            Integer closeQuote = -1;
            if (openQuote != -1) {
                String q = html.substring(openQuote, openQuote + 1);
                closeQuote = html.indexOf(q, tokenPos);
            }

            if (openQuote != -1 && closeQuote != -1 && closeQuote > openQuote) {
                String fullUrl = html.substring(openQuote + 1, closeQuote);
                if (!urls.contains(fullUrl)) {
                    urls.add(fullUrl);
                    System.debug('Found MindTouch URL: ' + fullUrl);
                }
                cursor = closeQuote + 1;
            } else {
                cursor = tokenPos + searchToken.length();
            }
        }

        return urls;
    }*/

    // ─── Normalize a MindTouch full URL to match SF title ────────────────────
    // Input:  "https://.../@api/deki/files/7/Billing_PatientCollections_Access.png?revision=1"
    // Output: "billing_patientcollections_access"
    public static String normalizeMindTouchUrl(String fullUrl) {
        if (String.isBlank(fullUrl)) return '';

        String filename = fullUrl;

        // Strip query string
        if (filename.contains('?')) {
            filename = filename.substringBefore('?');
        }

        // Get filename after last /
        if (filename.contains('/')) {
            filename = filename.substringAfterLast('/');
        }

        // Strip file extension
        if (filename.contains('.')) {
            filename = filename.substringBeforeLast('.');
        }

        // ── CHANGED: just lowercase — preserve underscores/hyphens ───────────
        // "Billing_PatientCollections_Access" → "billing_patientcollections_access"
        return filename.toLowerCase();
    }

     // ─── Replace all MindTouch image URLs in HTML ─────────────────────────────
    // Uses compiled regex Pattern/Matcher instead of character-by-character loop
    // Same approach as ArticleLinkRewriteBatch — avoids CPU timeout on large articles
    public static String replaceImageUrls(
        String html,
        Map<String, String> urlMap
    ) {
        if (String.isBlank(html)) return html;
        if (!html.contains('@api/deki/files/')) return html;

        // Compiled once per call — matches full MindTouch file URLs in src/href attributes
        // Captures the full URL between quotes e.g. src="https://.../@api/deki/files/7/file.png?revision=1"
        Pattern urlPattern = Pattern.compile(
            '(["\'])([^"\']*@api/deki/files/[^"\']+)\\1'
        );
        Matcher matcher = urlPattern.matcher(html);

        // Collect all unique MindTouch URLs found in this HTML
        List<String> mindTouchUrls = new List<String>();
        Set<String> seen = new Set<String>();
        while (matcher.find()) {
            String url = matcher.group(2);
            if (!seen.contains(url)) {
                seen.add(url);
                mindTouchUrls.add(url);
            }
        }

        System.debug('MindTouch image URLs found: ' + mindTouchUrls.size());

        String updatedHtml = html;
        Integer replaced = 0;

        for (String oldUrl : mindTouchUrls) {
            String normalizedKey = normalizeMindTouchUrl(oldUrl);

            if (urlMap.containsKey(normalizedKey)) {
                String newUrl = urlMap.get(normalizedKey);
                updatedHtml = updatedHtml.replace(oldUrl, newUrl);
                replaced++;
            } else {
                System.debug('WARNING - No SF match for: '
                    + oldUrl.substringAfterLast('/').left(60)
                    + ' | key: ' + normalizedKey);
            }
        }

        System.debug('Replaced ' + replaced + ' of ' + mindTouchUrls.size() + ' URLs');
        return updatedHtml;
    }
}