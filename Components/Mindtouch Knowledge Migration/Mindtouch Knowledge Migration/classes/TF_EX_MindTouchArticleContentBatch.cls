public class TF_EX_MindTouchArticleContentBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private static final String BASE_URL = TF_EX_MindtouchUtils.base_URL;

    // ── S3 base prefix to strip from <source src="..."> URL ─────────────────
    // Everything after this becomes the path appended to the iframe base URL
    private static final String S3_BASE =
    	'https://kareocustomertraining.s3.amazonaws.com/';

    // ── iframe base URL — stored in Custom Metadata ──────────────────────────
    // Record: TF_EX_MigrationConfig__mdt with DeveloperName = 'Video_Base_URL'
    // and a text field Video_Base_URL__c containing:
    // https://patientpop--scully.sandbox.my.site.com/CustomerCommunity/apex/tf_ex_videopage?path=Help%20Center/
    private static final String IFRAME_BASE = getIframeBase();

    private static String getIframeBase() {
        List<MindTouch_Config__mdt> configs = [
            SELECT TF_EX_VideoBaseURL__c
            FROM   MindTouch_Config__mdt
            WHERE  DeveloperName = 'VideoBaseURL'
            LIMIT  1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].TF_EX_VideoBaseURL__c)) {
            return configs[0].TF_EX_VideoBaseURL__c;
        }
        // Fallback — update custom metadata to avoid hardcoding
        return 'https://patientpop--scully.sandbox.my.site.com/CustomerCommunity/apex/tf_ex_videopage?path=';
    }

    // ─── START ───────────────────────────────────────────────────────────────
    // Only filter: Processed__c = false
    // No article type or parent title filters — every unprocessed record
    // gets fetched regardless of type (how-to, topic, videos, etc.)
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        return Database.getQueryLocator([
            SELECT Id, Id__c, ArticleType__c, Title__c,
                   Parent__c, Parent__r.Title__c,
                   HTMLContent__c, Processed__c, TransformedHTMLContent__c
            FROM   KnowledgeCategoryMap__c
            WHERE  Processed__c = false
        ]);
        
    }

    // ─── EXECUTE ─────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {

        List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();

        for (KnowledgeCategoryMap__c record : scope) {

            System.debug('Fetching content for: ' + record.Title__c
                + ' | Id__c: ' + record.Id__c);

            String htmlContent = fetchArticleContent(record.Id__c);

            if (htmlContent != null) {

                // ── Replace <video> tags with <iframe> before storing ─────────
                htmlContent = replaceVideoTags(htmlContent);

                // HTMLContent__c is Rich Text Area(131072) - enforce limit
                if (htmlContent.length() > 131000) {
                    htmlContent = htmlContent.left(131000)
                        + '<p><strong>[Content truncated during migration]</strong></p>';
                }

                record.HTMLContent__c             = htmlContent;
                record.TransformedHTMLContent__c  = htmlContent;
            }

            // Mark processed regardless — even if content was empty/null
            record.Processed__c = true;
            toUpdate.add(record);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('Updated ' + toUpdate.size() + ' records with HTML content');
        }
    }

    // ─── FINISH ──────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('TF_EX_MindTouchArticleContentBatch complete.');
    }

    // ─── HELPER: Replace <video>...</video> blocks with <iframe> ─────────────
    //
    // Finds every <video ...>...</video> block in the HTML regardless of
    // whether it sits inside a topic article or a dedicated video article.
    //
    // Steps:
    //   1. Locate <source src="..."> inside the video block → get S3 URL
    //   2. Strip S3_BASE prefix → keep only the path segment
    //   3. Build iframe src = IFRAME_BASE + path segment
    //   4. Replace entire <video...>...</video> with the iframe tag
    //
    // The (?is) flags make the pattern case-insensitive and DOTALL
    // (so . matches newlines inside multi-line video blocks).
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible
    public static String replaceVideoTags(String html) {
        if (String.isBlank(html) || !html.containsIgnoreCase('<video')) {
            return html;
        }

        Pattern videoPattern  = Pattern.compile('(?is)<video\\b[^>]*>.*?</video>');
        Pattern sourcePattern = Pattern.compile('(?i)<source[^>]+src="([^"]+)"');

        Matcher videoMatcher = videoPattern.matcher(html);

        // Collect all match positions and their replacements first.
        // Then apply in reverse order so earlier indices stay valid.
        List<Integer> starts       = new List<Integer>();
        List<Integer> ends         = new List<Integer>();
        List<String>  replacements = new List<String>();

        while (videoMatcher.find()) {
            String videoBlock  = videoMatcher.group(0);
            String replacement = videoBlock; // default: leave unchanged

            Matcher sourceMatcher = sourcePattern.matcher(videoBlock);
            if (sourceMatcher.find()) {
                String s3Url      = sourceMatcher.group(1);
                String pathSegment = s3Url;
                if (pathSegment.startsWith(S3_BASE)) {
                    pathSegment = pathSegment.substring(S3_BASE.length());
                }
                String iframeSrc = IFRAME_BASE + pathSegment;
                replacement =
                    '<iframe width="500" height="500" frameborder="1"' +
                    ' scrolling="auto" src="' + iframeSrc + '"></iframe>';
                System.debug('Video replaced: ' + s3Url + ' -> ' + iframeSrc);
            } else {
                System.debug('Video block — no <source src> found, left unchanged.');
            }

            starts.add(videoMatcher.start());
            ends.add(videoMatcher.end());
            replacements.add(replacement);
        }

        // Apply in reverse so positions remain valid after each substitution
        for (Integer i = starts.size() - 1; i >= 0; i--) {
            html = html.substring(0, starts[i])
                 + replacements[i]
                 + html.substring(ends[i]);
        }

        return html;
    }

    // ─── HELPER: Fetch HTML content from MindTouch API ───────────────────────
    private String fetchArticleContent(String mindTouchPageId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                BASE_URL + '/pages/' + mindTouchPageId
                + '/contents?dream.out.format=json'
            );
            req.setMethod('GET');
            req.setHeader('X-Deki-Token', TF_EX_MindTouchTokenHelper.buildToken());
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);

            System.debug('Response status for page '
                + mindTouchPageId + ': ' + res.getStatusCode());

            if (res.getStatusCode() != 200) {
                System.debug('Non-200 response for page ' + mindTouchPageId
                    + ': ' + res.getBody());
                return null;
            }

            // Parse response
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            Object bodyRaw = body.get('body');
            String htmlContent = '';

            if (bodyRaw instanceof String) {
                htmlContent = (String) bodyRaw;

            } else if (bodyRaw instanceof List<Object>) {
                List<Object> bodyParts = (List<Object>) bodyRaw;
                for (Object part : bodyParts) {
                    if (part instanceof String) {
                        htmlContent += (String) part;
                    } else if (part instanceof Map<String, Object>) {
                        Map<String, Object> partMap = (Map<String, Object>) part;
                        if (partMap.containsKey('#text')) {
                            htmlContent += String.valueOf(partMap.get('#text'));
                        }
                    }
                }

            } else if (bodyRaw instanceof Map<String, Object>) {
                Map<String, Object> bodyMap = (Map<String, Object>) bodyRaw;
                if (bodyMap.containsKey('#text')) {
                    htmlContent = String.valueOf(bodyMap.get('#text'));
                }
            }

            if (String.isBlank(htmlContent)) {
                System.debug('Empty content returned for page: ' + mindTouchPageId);
                return null;
            }

            return htmlContent;

        } catch (Exception e) {
            System.debug('Exception fetching content for page '
                + mindTouchPageId + ': ' + e.getMessage());
            return null;
        }
    }
}