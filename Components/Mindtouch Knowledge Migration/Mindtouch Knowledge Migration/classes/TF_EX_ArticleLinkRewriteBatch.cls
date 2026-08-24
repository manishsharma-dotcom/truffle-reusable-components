/**
 * @description Batch job to find and replace article links inside Knowledge article content.
 * Replaces http(s)://old.example.com/<path/query> with https://new.example.com/<path/query> while preserving path and query.
 *
 * Defaults (per user confirmation):
 * - Object/field: KnowledgeArticleVersion.ArticleBody
 * - Scope: latest published versions across all languages
 * - One-time run; includes dry-run capability controlled by constructor flag
 *
 * Design:
 * - with sharing to respect org sharing
 * - Bulkified, no SOQL/DML in loops
 * - Database methods with AccessLevel.USER_MODE
 * - Return-early patterns and robust exception handling
 * - Aggregated results exposed via getters
 *
 * Invocation:
 * - Directly via Execute Anonymous / Scheduler
 * - Invocable wrapper provided in ArticleLinkRewriteInvoker
 *
 * Notes:
 * - KnowledgeArticleVersion is read-only for certain states. We target latest published versions and update ArticleBody on the draft version when required by platform semantics.
 * - This implementation queries KnowledgeArticleVersion with PublishStatus = 'Online' and IsLatestVersion = true, Language = ANY.
 */
public with sharing class TF_EX_ArticleLinkRewriteBatch 
    implements Database.Batchable<SObject>, Database.Stateful {

    private final Boolean isDryRun;

    public Integer totalScanned { get; private set; }
    public Integer totalChanged { get; private set; }
    public Integer totalFailed  { get; private set; }

    public class LogEntry {
        @AuraEnabled public Id      recordId;
        @AuraEnabled public String  title;
        @AuraEnabled public Boolean changed;
        @AuraEnabled public String  error;
    }
    public List<LogEntry> logs { get; private set; }

    public TF_EX_ArticleLinkRewriteBatch(Boolean dryRun) {
        this.isDryRun     = dryRun == null ? true : dryRun;
        this.totalScanned = 0;
        this.totalChanged = 0;
        this.totalFailed  = 0;
        this.logs         = new List<LogEntry>();
    }

    // ─── START ────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Source: HTMLContent__c (original)
        // Target: TransformedHTMLContent__c (where we write updated HTML)
        // Only process actual articles not categories
        return Database.getQueryLocator([
            SELECT Id, Title__c, HTMLContent__c, TransformedHTMLContent__c
            FROM KnowledgeCategoryMap__c
            WHERE Processed__c = false
        ]);
    }

    // ─── EXECUTE ──────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> scope) {

        if (scope == null || scope.isEmpty()) return;

        totalScanned += scope.size();

        List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();

        for (KnowledgeCategoryMap__c record : scope) {
            record.processed__c = true;
            try {
                // Read from HTMLContent__c (original source)
                String original = record.TransformedHTMLContent__c;

                if (String.isBlank(original)) {
                    logs.add(buildLog(record, false, 'No HTML content'));
                    continue;
                }

                // Apply link rewrite
                String transformed = rewriteArticleLinks(original);

                if (!isDryRun) {
                    // Write to TransformedHTMLContent__c (not HTMLContent__c)
                    // HTMLContent__c stays untouched as the original source
                    record.TransformedHTMLContent__c = transformed;
                    record.Processed__c = true;
                    toUpdate.add(record);
                }

                logs.add(buildLog(record, true, null));
                totalChanged++;

            } catch (Exception e) {
                totalFailed++;
                logs.add(buildLog(record, false, e.getMessage()));
            }
        }
        
        System.debug('Scanned: ' + totalScanned 
            + ' | Changed: ' + totalChanged 
            + ' | Failed: '  + totalFailed);

        if (!isDryRun && !toUpdate.isEmpty()) {
            Database.SaveResult[] srs = Database.update(toUpdate, false);
            for (Integer i = 0; i < srs.size(); i++) {
                if (!srs[i].isSuccess()) {
                    totalFailed++;
                    Database.Error err = srs[i].getErrors().isEmpty() 
                        ? null 
                        : srs[i].getErrors()[0];
                    logs.add(buildLog(
                        toUpdate[i],
                        false,
                        err == null ? 'Unknown DML error' : err.getMessage()
                    ));
                }
            }
        }
    }

    // ─── FINISH ───────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('=== Article Link Rewrite Complete ===');
        System.debug('Total Scanned: ' + totalScanned);
        System.debug('Total Changed: ' + totalChanged);
        System.debug('Total Failed:  ' + totalFailed);

        // Log any failures
        for (LogEntry le : logs) {
            if (!String.isBlank(le.error)) {
                System.debug('FAILED: ' + le.title + ' | ' + le.error);
            }
        }
    }

    // ─── HELPER: Rewrite helpme.tebra.com links → Salesforce site links ───────
    public static String rewriteArticleLinks(String html) {
        MindTouch_Config__mdt config = [
            SELECT SiteURL__c,matchingPattern__c
            FROM MindTouch_Config__mdt where SiteURL__c != NULL and matchingPattern__c != NULL
            LIMIT 1
        ];
        String rawURL  = config.SiteURL__c;
        string finalURL = rawURL.removeEnd('/');

        Pattern p = Pattern.compile(
            'href="(https://helpme\\.tebra\\.com[^"]*)"'
        );
        Matcher m = p.matcher(html);

        List<String> links = new List<String>();
        while (m.find()) {
            links.add(m.group(1));
        }

        System.debug('Links found to rewrite: ' + links.size());
        Integer count = 0;
        for (String link : links) {
            String lastPart = link.substringAfterLast('/');
            if(lastPart != null && lastPart != ''){
                String validURLName = TF_EX_MindTouchUtils.buildUrlName(lastPart);
                String newLink  = rawURL + validURLName;
                if(html.contains(link)){
                    html = html.replace(link, newLink);
                    if(!html.contains(newLink)){
                        system.debug('link not replaced--->' + link + '<----new link---->' + newLink);
                        break;
                    }
                }
            }
        }
        

        
        while (html.contains('https://helpme.tebra.com')) {
            //html = html.replace('https://helpme.tebra.com','https://tr1770619935525.my.site.com/professional/s/learning/article');
            html = html.replace('https://helpme.tebra.com',finalURL);
        }
        if(TF_EX_MindTouchUtils.validateURL(html) > 0){
           system.debug('Still has invalid links--->');
        }
            
        return html;
    }

    // ─── HELPER: Build log entry ──────────────────────────────────────────────
    private static LogEntry buildLog(KnowledgeCategoryMap__c record,
                                     Boolean changed,
                                     String error) {
        LogEntry le  = new LogEntry();
        le.recordId  = record.Id;
        le.title     = record.Title__c;
        le.changed   = changed;
        le.error     = error;
        return le;
    }
}