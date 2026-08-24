/**
* TF_EX_MindTouchHTMLCleanupBatch
*
* Cleans two MindTouch artefacts from TransformedHTMLContent__c on
* KnowledgeCategoryMap__c records:
*
*  1. Updated/Views header
*     Removes the metadata line that MindTouch prepended to every article,
*     e.g.  "Updated: 04/09/2026<span>…</span>Views: 16"
*           "Updated: 01/20/2021<br>Views: 2062"
*           "<br>Updated: 03/27/2026<br>"   (mid-content variant near end)
*     Pattern: optional leading <br>, then "Updated:" + date + any HTML + optional
*     "Views: digits", terminated by a newline or next HTML tag.
*
*  2. Trailing auto-generated TOC <ol>
*     MindTouch appends a nested <ol> of anchor links after the last </div>.
*     Safe to remove ONLY when every <a href in that trailing <ol> uses a
*     #hash anchor (pure in-page TOC). If any href points to an external URL
*     or relative path, the <ol> is preserved — it contains real related links.
*
* No chaining required: 1,421 records / batch size 20 = ~71 execute() calls.
* No Processed__c flag required: operation is idempotent.
*
* Usage:
*   Database.executeBatch(new TF_EX_MindTouchHTMLCleanupBatch(), 20);
*/
public class TF_EX_MindTouchHTMLCleanupBatch
implements Database.Batchable<SObject>, Database.Stateful {
    
    // ── Counters (Database.Stateful so they accumulate across execute() calls) ──
    public Integer totalProcessed       = 0;
    public Integer updatedViewsRemoved  = 0;
    public Integer trailingOlRemoved    = 0;
    public Integer trailingOlSkipped    = 0; // had external hrefs — left untouched
    public Integer noChangeCount        = 0;
    
    // ── Query ─────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        
        return Database.getQueryLocator([
            SELECT Id, TransformedHTMLContent__c
            FROM   KnowledgeCategoryMap__c where Processed__c= False
        ]);
        
        /*
return Database.getQueryLocator([
SELECT Id, KnowledgeContent__c
FROM   Knowledge__kav where id='ka2Em0000007w7JIAQ'
]);
*/
        
    }
    
    // ── Process ───────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc,
                        List<KnowledgeCategoryMap__c> records) {
                            
                            
                            List<KnowledgeCategoryMap__c> toUpdate = new List<KnowledgeCategoryMap__c>();
                            
                            for (KnowledgeCategoryMap__c rec : records) {
                                rec.processed__c = true;
                                totalProcessed++;
                                
                                if (String.isBlank(rec.TransformedHTMLContent__c)) {
                                    noChangeCount++;
                                    continue;
                                }
                                
                                String original = rec.TransformedHTMLContent__c;
                                String cleaned  = original;
                                
                                // ── Step 1: Remove Updated/Views header ───────────────────────────
                                String afterStep1 = removeUpdatedViewsHeader(cleaned);
                                if (afterStep1 != cleaned) {
                                    updatedViewsRemoved++;
                                    cleaned = afterStep1;
                                }
                                
                                // ── Step 2: Remove trailing TOC <ol> (only if all hrefs are #hash) ─
                                String afterStep2 = removeTrailingTocOl(cleaned);
                                if (afterStep2 == null) {
                                    // null signals "external hrefs found — leave untouched"
                                    trailingOlSkipped++;
                                } else if (afterStep2 != cleaned) {
                                    trailingOlRemoved++;
                                    cleaned = afterStep2;
                                }
                                
                                // ── Only DML if something actually changed ────────────────────────
                                if (cleaned != original) {
                                    rec.TransformedHTMLContent__c = cleaned;
                                    toUpdate.add(rec);
                                } else {
                                    noChangeCount++;
                                }
                                
                            }
                            
                            if (!toUpdate.isEmpty()) {
                                update toUpdate;
                            }
                            update records;
                        }
    
    // ── Finish ────────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        String summary =
            'TF_EX_MindTouchHTMLCleanupBatch complete.\n' +
            'Total records processed : ' + totalProcessed       + '\n' +
            'Updated/Views removed   : ' + updatedViewsRemoved  + '\n' +
            'Trailing OL removed     : ' + trailingOlRemoved    + '\n' +
            'Trailing OL skipped     : ' + trailingOlSkipped    + ' (had external hrefs)\n' +
            'No change needed        : ' + noChangeCount;
        
        System.debug(LoggingLevel.INFO, summary);
        
        // Send summary email to running user
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
            mail.setSubject('MindTouch HTML Cleanup Batch — Complete');
            mail.setPlainTextBody(summary);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                         'Could not send summary email: ' + e.getMessage());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
* Removes the MindTouch "Updated: …Views: N" metadata line.
*
* Handles all observed variants:
*   A) True start of content:
*      "Updated: 04/09/2026<span>…</span>Views: 16\n\n<p>…"
*      "Updated: 01/20/2021<br>Views: 2062\n\n<p>…"
*
*   B) Mid-content (4 articles): appended inside a table cell near end,
*      always preceded by "<br>" and followed by "<br>" or "</div>":
*      "\n\n<br>Updated: 03/27/2026<br></div>"
*      "\n\n<br>Updated: 12/04/2025<br><p> </p>\n</div>"
*
*   C) Wrapped in mt-contentreuse-widget div (4 articles):
*      '<div class="mt-contentreuse-widget">\n<div class="mt-include" …>
*       Updated: 12/19/2025<span>…</span>Views: 36902\n\n<p>…'
*      → remove only the "Updated:…Views:N" token, leave the wrapper divs
*
* Returns the cleaned string (unchanged if pattern not found).
*/
    @TestVisible
    private static String removeUpdatedViewsHeader(String html) {
        if (String.isBlank(html)) return html;
        
        String lower = html.toLowerCase();
        Integer updatedIdx = lower.indexOf('updated:');
        if (updatedIdx == -1) return html;
        
        // ── Walk back from 'updated:' to consume any leading <br> + whitespace ──
        String beforeUpdated = html.substring(0, updatedIdx);
        String trimmedBefore = beforeUpdated.replaceAll('(?i)(<br\\s*/?>)?\\s*$', '');
        Integer removeFrom   = trimmedBefore.length();
        
        // ── Find end of the header ────────────────────────────────────────────
        // Look for "views:" within 500 chars of "updated:" — consume through
        // end of the digit string after it using replaceFirst on that slice
        Integer viewsIdx = lower.indexOf('views:', updatedIdx);
        Integer removeTo;
        
        if (viewsIdx != -1 && viewsIdx < updatedIdx + 500) {
            // Grab from views: onward and strip the number + trailing whitespace
            String fromViews = html.substring(viewsIdx);
            // Remove "views:" + optional spaces + digits + trailing whitespace
            String afterViewsStripped = fromViews.replaceFirst(
                '(?i)views:\\s*\\d+\\s*', ''
            );
            removeTo = html.length() - afterViewsStripped.length();
        } else {
            // No views: found — cut to the next tag after the date portion
            Integer nextTag = html.indexOf('<', updatedIdx + 10);
            removeTo = (nextTag != -1) ? nextTag : html.length();
        }
        
        String result = html.substring(0, removeFrom) + html.substring(removeTo);
        
        // Collapse any leading blank lines left behind
        result = result.replaceAll('^[\\s\\n\\r]+', '');
        
        return String.isBlank(result) ? html : result;
    }
    
    /**
* Removes the trailing auto-generated TOC <ol> IF AND ONLY IF every
* <a href="..."> inside it uses a #hash anchor.
*
* Returns:
*   - cleaned string   → trailing OL was hash-only and was removed
*   - same string      → no trailing OL found (nothing to do)
*   - null             → trailing OL found but contains external hrefs — caller skips
*/
    @TestVisible
    private static String removeTrailingTocOl(String html) {
        if (String.isBlank(html)) return html;
        
        String htmlLower = html.toLowerCase();
        
        // ── Find the last </ol> in the document ──────────────────────────────────
        Integer lastOlClose = htmlLower.lastIndexOf('</ol>');
        if (lastOlClose == -1) return html;
        
        // ── Verify nothing but whitespace follows it ──────────────────────────────
        String afterOl = html.substring(lastOlClose + 5).trim();
        if (String.isNotBlank(afterOl)) return html; // not trailing — leave alone
        
        // ── Walk backwards to find the matching opening <ol ───────────────────────
        // Going backwards: each </ol> we pass means another nested level to skip;
        // each <ol we pass at depth 0 is our match.
        Integer depth     = 0;
        Integer searchPos = lastOlClose - 1;
        Integer olStart   = -1;
        
        while (searchPos >= 0) {
            Integer prevClose = htmlLower.lastIndexOf('</ol>', searchPos);
            Integer prevOpen  = htmlLower.lastIndexOf('<ol',   searchPos);
            
            if (prevClose == -1 && prevOpen == -1) break;
            
            // Whichever tag has the higher index is the one we hit first going back
            if (prevClose != -1 && (prevOpen == -1 || prevClose > prevOpen)) {
                // Found a nested </ol> — need to skip its matching <ol> too
                depth++;
                searchPos = prevClose - 1;
            } else {
                // Found a <ol (with or without attributes)
                if (depth == 0) {
                    olStart = prevOpen;
                    break;
                }
                depth--;
                searchPos = prevOpen - 1;
            }
        }
        
        if (olStart == -1) return html;
        
        // ── Check every href in the block — only remove if all are #hash ──────────
        String olBlock = html.substring(olStart, lastOlClose + 5);
        Pattern hrefPat = Pattern.compile('href="([^"]*)"');
        Matcher m = hrefPat.matcher(olBlock);
        while (m.find()) {
            String href = m.group(1);
            if (!href.startsWith('#')) {
                return null; // external href found — signal caller to skip
            }
        }
        
        // ── Safe to remove ────────────────────────────────────────────────────────
        String beforeOl = html.substring(0, olStart).replaceAll('\\s+$', '');
        return beforeOl;
    }
}