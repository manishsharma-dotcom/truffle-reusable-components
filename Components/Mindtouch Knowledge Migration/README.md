# MindTouch (CXone Expert) → Salesforce Knowledge Migration Guide

> **Purpose:** End-to-end reference for migrating knowledge articles from MindTouch (NICE CXone Expert) to Salesforce Knowledge via Apex and REST APIs.  
> **Audience:** Salesforce developers implementing this migration for any client.  
> **Last Updated:** June 2026

---

## Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [Prerequisites & Setup](#2-prerequisites--setup)
3. [Authentication — MindTouch Token Helper](#3-authentication--mindtouch-token-helper)
4. [Custom Object — KnowledgeCategoryMap__c](#4-custom-object--knowledgecategorymap__c)
5. [Phase 1 — Sync Category Tree](#5-phase-1--sync-category-tree)
6. [Phase 2 — Fetch Article HTML Content](#6-phase-2--fetch-article-html-content)
7. [Phase 3 — Image Download Pipeline](#7-phase-3--image-download-pipeline)
8. [Phase 4 — Image URL Replacement](#8-phase-4--image-url-replacement)
9. [Phase 5 — HTML Cleanup](#9-phase-5--html-cleanup)
10. [Phase 6 — Article Link Rewrite](#10-phase-6--article-link-rewrite)
11. [Phase 7 — Create Salesforce Knowledge Articles](#11-phase-7--create-salesforce-knowledge-articles)
12. [Phase 8 — Data Categories (Taxonomy) Deployment](#12-phase-8--data-categories-taxonomy-deployment)
13. [Phase 9 — Assign Data Categories to Articles](#13-phase-9--assign-data-categories-to-articles)
14. [Utility Classes Reference](#14-utility-classes-reference)
15. [Execution Order & Runbook](#15-execution-order--runbook)
16. [Known Limitations & Gotchas](#16-known-limitations--gotchas)
17. [Troubleshooting Reference](#17-troubleshooting-reference)

---

## 1. Overview & Architecture

### What This Migration Does

MindTouch organizes content as a **hierarchical page tree** (Home → Category → Subcategory → Article). Salesforce Knowledge organizes content as **flat articles** tagged with **Data Categories**. This migration:

1. Walks the MindTouch page tree and mirrors it into a staging custom object (`KnowledgeCategoryMap__c`)
2. Fetches HTML content for each page
3. Downloads all images referenced in the HTML into Salesforce Files (ContentVersion)
4. Replaces MindTouch image URLs in HTML with Salesforce CDN public URLs
5. Cleans up MindTouch-specific HTML artifacts
6. Creates Salesforce Knowledge articles from the staged data
7. Deploys matching Data Category taxonomy
8. Assigns categories to articles

### High-Level Architecture

```
MindTouch REST API
        │
        ▼
┌────────────────────────────┐
│  KnowledgeCategoryMap__c   │  ← Staging object (mirrors MT page tree)
│  (Custom Object)           │
└────────────────┬───────────┘
                 │
    ┌────────────┼─────────────┐
    ▼            ▼             ▼
ContentVersion  HTML        Knowledge__kav
(Images/Files)  Cleanup     (Articles)
    │                          │
    ▼                          ▼
ContentDistribution      DataCategorySelection
(Public CDN URLs)        (Taxonomy tagging)
```

### MindTouch API Base URL Pattern

```
https://<your-tenant>.cxoneexpert.ai/@api/deki/
```

Key endpoints used:

| Endpoint | Purpose |
|---|---|
| `/pages/home/subpages?dream.out.format=json` | Top-level pages |
| `/pages/{id}/subpages?dream.out.format=json` | Children of a page |
| `/pages/{id}/contents?dream.out.format=json` | Page HTML content |
| `/pages/{id}/files?dream.out.format=json` | Files attached to a page |
| `/files/{id}` | Download a specific file |

---

## 2. Prerequisites & Setup

### MindTouch Side

1. Log in to MindTouch Admin panel
2. Navigate to **Admin → Integrations / API Keys**
3. Generate an **API Key** and **Shared Secret** — store these securely
4. Note your tenant base URL (e.g. `https://yourcompany.cxoneexpert.ai`)

### Salesforce Side

#### Remote Site Setting
```
Setup → Security → Remote Site Settings → New
Name: MindTouchAPI
Remote Site URL: https://<your-tenant>.cxoneexpert.ai
Active: ✓
```

#### Custom Metadata Type — `TF_EX_MigrationConfig__mdt`
Used to store configuration values without hardcoding.

| Field API Name | Type | Purpose |
|---|---|---|
| `TF_EX_BaseURL__c` | Text | MindTouch API base URL |
| `TF_EX_APIKey__c` | Text | MindTouch API Key |
| `TF_EX_APISecret__c` | Text | MindTouch Shared Secret |
| `TF_EX_Username__c` | Text | MindTouch admin username |
| `TF_EX_VideoBaseURL__c` | Text | Base URL for embedded video iframes |

#### Salesforce Knowledge Setup
- Ensure Knowledge is enabled in the org
- Create required **Record Types** on `Knowledge__kav`:
  - `How_To` — for `topic-task` and `topic-howto` article types
  - `Topic` — for everything else (`topic-concept`, `topic-guide`, `topic-reference`)
- Create a custom field `MindtouchExternalId__c` (Text, External ID, Unique) on `Knowledge__kav`
- Create a custom field `KnowledgeContent__c` (Long Text Area or Rich Text Area) on `Knowledge__kav`

> **Important:** Rich Text Area on Knowledge Articles supports iframes (for embedded videos). Long Text Area on the staging custom object also preserves iframes correctly. Use Rich Text Area on `Knowledge__kav` if video embedding is required.

---

## 3. Authentication — MindTouch Token Helper

### How MindTouch Authentication Works

MindTouch uses a signed token in the `X-Deki-Token` header. The token format is:

```
tkn_{apiKey}_{epochSeconds}_{username}_{hmacSignature}
```

The HMAC-SHA256 signature is computed over: `{apiKey}_{epochSeconds}_{username}` using the Shared Secret.

### Class: `TF_EX_MindtouchUtils` (or `MindTouchTokenHelper`)

```apex
public class TF_EX_MindtouchUtils {

    public static final String BASE_URL;
    private static final String API_KEY;
    private static final String API_SECRET;
    private static final String USERNAME;

    static {
        TF_EX_MigrationConfig__mdt config = [
            SELECT TF_EX_BaseURL__c, TF_EX_APIKey__c, 
                   TF_EX_APISecret__c, TF_EX_Username__c
            FROM TF_EX_MigrationConfig__mdt
            LIMIT 1
        ];
        BASE_URL   = config.TF_EX_BaseURL__c;
        API_KEY    = config.TF_EX_APIKey__c;
        API_SECRET = config.TF_EX_APISecret__c;
        USERNAME   = config.TF_EX_Username__c;
    }

    public static String buildToken() {
        Long epoch = DateTime.now().getTime() / 1000;
        String message = API_KEY + '_' + epoch + '_' + USERNAME;
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(message),
            Blob.valueOf(API_SECRET)
        );
        String signature = EncodingUtil.convertToHex(hmac);
        return 'tkn_' + API_KEY + '_' + epoch + '_' + USERNAME + '_' + signature;
    }
}
```

### Testing Authentication

Run in Anonymous Apex to confirm a 200 response:

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint(TF_EX_MindtouchUtils.BASE_URL + '/pages/home/subpages?dream.out.format=json');
req.setMethod('GET');
req.setHeader('X-Deki-Token', TF_EX_MindtouchUtils.buildToken());
req.setHeader('Accept', 'application/json');
req.setTimeout(30000);
HttpResponse res = new Http().send(req);
System.debug(res.getStatusCode());
System.debug(res.getBody());
```

---

## 4. Custom Object — `KnowledgeCategoryMap__c`

This is the **central staging object**. Every MindTouch page (category or article) gets a record here before anything is pushed to Knowledge.

### Fields

| Field API Name | Type | Notes |
|---|---|---|
| `MindTouchId__c` | Text(255), **External ID**, Unique | MindTouch numeric page ID |
| `Title__c` | Text(255) | Page title |
| `MindTouchPath__c` | Long Text Area | Full path e.g. `Platform/Dashboard/Navigate Dashboard` |
| `ParentMindTouchId__c` | Text(255) | Parent page's MindTouch ID |
| `HTMLContent__c` | Long Text Area | Raw HTML from MindTouch API |
| `TransformedHTMLContent__c` | Long Text Area | HTML after all transformations (image URL replace, cleanup, etc.) |
| `ArticleType__c` | Text(255) | MindTouch page type: `topic-task`, `topic-concept`, `topic-guide`, `topic-reference`, `topic-howto` |
| `Public__c` | Checkbox | True if MindTouch `Restriction` = Public |
| `Summary__c` | Long Text Area | Page summary/description from MindTouch |
| `Processed__c` | Checkbox | Flag used by batches to track progress |
| `Id__c` | Text(255), External ID | Alternative external ID (use `MindTouchId__c` as primary) |

> **Note:** Long Text Area fields **cannot be used in SOQL WHERE clauses**. This affects `MindTouchPath__c`, `Summary__c`, `HTMLContent__c`, and `TransformedHTMLContent__c`. Filter on other fields and process content in Apex.

---

## 5. Phase 1 — Sync Category Tree

### Goal
Walk the MindTouch page hierarchy and create `KnowledgeCategoryMap__c` records for every page found, up to 5 levels deep.

### Step 1a — Sync Top-Level Categories (Anonymous Apex / One-off)

Run `MindTouchCategorySync.syncTopLevelCategories()` to pull the first level (direct children of Home).

### Step 1b — Full Tree Batch: `TF_EX_MindTouchCategoryTreeBatch`

This batch processes each L1 record and recursively fetches all descendants.

**Key design decisions:**
- Implements `Database.Batchable<SObject>` and `Database.AllowsCallouts`
- `start()` queries all existing L1 `KnowledgeCategoryMap__c` records
- `execute()` calls `fetchSubpages()` recursively up to 5 levels
- Uses `upsert` with `MindTouchId__c` as external ID to avoid duplicates

**Critical — Pagination:**
MindTouch API returns a maximum of 100 subpages per call. Pages with more than 100 children require offset pagination:

```apex
private static List<Map<String, Object>> fetchSubpages(String pageId, String parentId) {
    List<Map<String, Object>> allPages = new List<Map<String, Object>>();
    Integer offset = 0;
    Integer limit  = 100;
    Boolean hasMore = true;

    while (hasMore) {
        String url = TF_EX_MindtouchUtils.BASE_URL
            + '/pages/' + pageId
            + '/subpages?dream.out.format=json&limit=' + limit + '&offset=' + offset;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('X-Deki-Token', TF_EX_MindtouchUtils.buildToken());
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) break;

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Integer totalCount = Integer.valueOf(body.get('@totalcount'));
        Integer count      = Integer.valueOf(body.get('@count'));

        // MindTouch returns a Map when 1 child, List when multiple — normalize:
        Object pagesRaw = body.get('page.subpage');
        List<Object> pagesList = new List<Object>();
        if (pagesRaw instanceof List<Object>) {
            pagesList = (List<Object>) pagesRaw;
        } else if (pagesRaw instanceof Map<String, Object>) {
            pagesList.add(pagesRaw);
        }

        for (Object p : pagesList) {
            Map<String, Object> page = (Map<String, Object>) p;
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('id',          String.valueOf(page.get('@id')));
            entry.put('title',       String.valueOf(page.get('@title')));
            entry.put('articleType', String.valueOf(page.get('@type')));
            // Extract path from uri.ui field
            String uriUi = String.valueOf(((Map<String,Object>)page.get('uri')).get('@ui'));
            entry.put('path', uriUi);
            allPages.add(entry);
        }

        offset += count;
        hasMore = (offset < totalCount);
    }
    return allPages;
}
```

> **Gotcha — Single child response:** When a page has exactly 1 subpage, MindTouch returns a `Map` instead of a `List`. Always normalize before iterating.

**Running the batch:**
```apex
Database.executeBatch(new TF_EX_MindTouchCategoryTreeBatch(), 1);
// Batch size 1: each record = 1 parent page + all its recursive callouts
```

---

## 6. Phase 2 — Fetch Article HTML Content

### Goal
For every `KnowledgeCategoryMap__c` record that represents an actual article (not just a container category), fetch the HTML content from MindTouch and store it.

### Batch: `TF_EX_MindTouchArticleContentBatch`

**Query (start):**
```apex
SELECT Id, MindTouchId__c, Title__c, ArticleType__c
FROM KnowledgeCategoryMap__c
WHERE HTMLContent__c = null
AND Processed__c = false
```

**execute() logic per record:**
1. Call `/pages/{MindTouchId__c}/contents?dream.out.format=json`
2. Extract the `body` field from the response JSON
3. Store raw HTML in `HTMLContent__c`
4. Copy to `TransformedHTMLContent__c` (all subsequent transformations operate on this field)
5. Replace `<video>` tags with `<iframe>` (see below)
6. Set `Processed__c = true`

**Video tag replacement:**
MindTouch stores videos as `<video><source src="?path=..."></video>`. Salesforce Knowledge Rich Text Area supports `<iframe>` but not `<video>`. Replacement:

```apex
// Apex-safe regex replacement (no StringBuffer/appendReplacement — those are Java only)
String videoBaseUrl = [SELECT TF_EX_VideoBaseURL__c FROM TF_EX_MigrationConfig__mdt LIMIT 1].TF_EX_VideoBaseURL__c;
Pattern videoPattern = Pattern.compile('<video[^>]*>.*?<source[^>]+src="([^"]+)"[^>]*>.*?</video>');
Matcher m = videoPattern.matcher(html);
while (m.find()) {
    String srcAttr = m.group(1);
    String iframeTag = '<iframe src="' + videoBaseUrl + srcAttr + '" frameborder="0" allowfullscreen></iframe>';
    html = html.replace(m.group(0), iframeTag);
}
```

> **Apex limitation:** Do NOT use `StringBuffer`, `m.appendReplacement()`, or `m.appendTail()` — these are Java methods and do not exist in Apex. Use `html.replace(m.group(0), replacement)` inside the `while` loop instead.

**Running the batch:**
```apex
Database.executeBatch(new TF_EX_MindTouchArticleContentBatch(), 5);
```

---

## 7. Phase 3 — Image Download Pipeline

### Goal
Download all image/file attachments from MindTouch into Salesforce as `ContentVersion` records and generate public CDN URLs for each.

### Custom Object — `TF_EX_MindTouchPendingFile__c`

| Field | Type | Purpose |
|---|---|---|
| `FileName__c` | Text(255) | File name (e.g. `Dashboard_Overview.png`) |
| `SourceURL__c` | Long Text Area | Full MindTouch download URL |
| `PageId__c` | Text(255) | MindTouch page ID the file belongs to |
| `Uploaded__c` | Checkbox | Set to true once downloaded to Salesforce |
| `DownloadURL__c` | Long Text Area | Salesforce public CDN URL (after ContentDistribution) |

### Step 1 — Collect File Metadata: `TF_EX_MindTouchFileCollectorBatch`

Hits `/pages/{id}/files?dream.out.format=json` for every page and creates `TF_EX_MindTouchPendingFile__c` records.

**Critical deduplication — use full URL as key, not filename:**

```apex
// WRONG — causes missed files when two pages have a file with the same name:
Set<String> alreadyQueued = new Set<String>();
alreadyQueued.add(filename);

// CORRECT — use the full source URL as the unique key:
Set<String> alreadyQueued = new Set<String>();
alreadyQueued.add(sourceUrl);
```

**File API pagination:**
Same as subpages — MindTouch caps at 100 per call. Use `&limit=100&offset=N` loop until `offset >= @totalcount`.

**Expected result:** Total file count should exactly match `@totalcount` from MindTouch (e.g. 7,716 files). If counts differ, the deduplication key is likely the issue.

### Step 2 — Download Files: `TF_EX_MindTouchFileDownloadBatch`

Processes `TF_EX_MindTouchPendingFile__c` records where `Uploaded__c = false`.

```apex
// For each pending file:
HttpRequest req = new HttpRequest();
req.setEndpoint(record.SourceURL__c);
req.setMethod('GET');
req.setHeader('X-Deki-Token', TF_EX_MindtouchUtils.buildToken());
req.setTimeout(120000);
HttpResponse res = new Http().send(req);

if (res.getStatusCode() == 200) {
    ContentVersion cv = new ContentVersion();
    cv.Title           = record.FileName__c;
    cv.PathOnClient    = record.FileName__c;
    cv.VersionData     = res.getBodyAsBlob();
    cv.IsMajorVersion  = true;
    insert cv;
    record.Uploaded__c = true;
    update record;
}
```

> **Storage limit warning:** 200 MB default file storage fills quickly. Monitor via Setup → Storage Usage. Delete test files and re-run if limit is hit. With ~7,700 images the org will likely need storage increased or files managed carefully.

### Step 3 — Auto-Generate Public URLs: `ContentVersionAutoDistribute` Trigger

When a `ContentVersion` is inserted, automatically create a `ContentDistribution` to generate a public CDN URL:

```apex
trigger ContentVersionAutoDistribute on ContentVersion (after insert) {
    List<ContentDistribution> dists = new List<ContentDistribution>();
    for (ContentVersion cv : Trigger.new) {
        if (cv.Title != null && cv.Title.endsWith('.png') /* or other image types */) {
            dists.add(new ContentDistribution(
                Name              = cv.Title,
                ContentVersionId  = cv.Id,
                PreferencesAllowViewInBrowser   = true,
                PreferencesLinkLatestVersion    = true,
                PreferencesNotifyOnVisit        = false,
                PreferencesPasswordRequired     = false,
                PreferencesAllowOriginalDownload = true
            ));
        }
    }
    if (!dists.isEmpty()) insert dists;
}
```

> **Note:** `ContentDocumentId` is NOT populated on `Trigger.new` for `ContentVersion`. Use `ContentVersionId` (the record's own `Id` from `Trigger.new`).

After trigger fires, query `ContentDistribution` to get the `DistributionPublicUrl` and store it back on the `TF_EX_MindTouchPendingFile__c.DownloadURL__c` field.

---

## 8. Phase 4 — Image URL Replacement

### Goal
Replace all MindTouch image `src` URLs in `TransformedHTMLContent__c` with Salesforce CDN public URLs.

### Utility Class: `TF_EX_MindTouchImageUrlReplacer`

This is a pure utility with no SOQL — accepts HTML string + URL map, returns transformed HTML.

**Key method:**
```apex
public static String replaceImageUrls(String html, Map<String, String> urlMap) {
    // urlMap: { mindtouchFileName → salesforceCdnUrl }
    Pattern imgPattern = Pattern.compile('<img[^>]+src="([^"]+)"');
    Matcher m = imgPattern.matcher(html);
    while (m.find()) {
        String srcUrl = m.group(1);
        // Extract filename from URL
        String filename = srcUrl.substringAfterLast('/');
        if (filename.contains('?')) {
            filename = filename.substringBefore('?');
        }
        if (urlMap.containsKey(filename)) {
            String newSrc = srcUrl.replace(m.group(1), urlMap.get(filename));
            html = html.replace('src="' + srcUrl + '"', 'src="' + urlMap.get(filename) + '"');
        }
    }
    return html;
}
```

> **Critical bug to avoid:** Do NOT walk back a fixed number of characters to find the `src=` attribute. Always extract the URL from the regex match group directly. Walking back N chars breaks when attributes have variable lengths.

### Batch: `TF_EX_MindTouchImageReplaceBatch`

```apex
// start() — build URL map from ContentDistribution records
// ContentDownloadUrl is NOT filterable — query all and filter in Apex:
Map<String, String> urlMap = new Map<String, String>();
for (ContentDistribution cd : [
    SELECT ContentVersion.Title, DistributionPublicUrl
    FROM ContentDistribution
]) {
    urlMap.put(cd.ContentVersion.Title, cd.DistributionPublicUrl);
}
```

**Query for records to process:**
```apex
// HTMLContent__c and TransformedHTMLContent__c are Long Text Area — NOT filterable
// Use Processed__c or other indexed fields instead:
SELECT Id, TransformedHTMLContent__c
FROM KnowledgeCategoryMap__c
WHERE Processed__c = true
AND MindTouchId__c != null
```

> **Warning on `finish()` self-chaining:** If `finish()` re-chains the batch to handle failures, ensure the re-chain condition won't loop infinitely (e.g. only chain if `Uploaded__c` was actually set to `true` for new records since last run).

---

## 9. Phase 5 — HTML Cleanup

### Goal
Remove MindTouch-specific HTML artifacts from `TransformedHTMLContent__c`:
1. **Updated/Views header** — `Updated: MM/DD/YYYY | Views: N` block at the top of content
2. **Trailing TOC `<ol>`** — table of contents with hash anchor links appended at the bottom

### Batch: `TF_EX_MindTouchHTMLCleanupBatch`

**Remove Updated/Views header:**

```apex
// Pattern: <span...>Updated: </span><span...>DATE</span>...<span...>Views: N</span>
// Use containsIgnoreCase to detect, then strip:
private static String removeUpdatedViewsHeader(String html) {
    if (!html.containsIgnoreCase('Updated:')) return html;
    // Find opening tag of the header block and closing </p> or </div>
    Integer startIdx = html.toLowerCase().indexOf('updated:');
    // Walk back to find the opening tag
    Integer tagStart = html.lastIndexOf('<', startIdx);
    // Walk forward to find the end of the block
    Integer endIdx = html.indexOf('</p>', startIdx);
    if (endIdx == -1) endIdx = html.indexOf('</div>', startIdx);
    if (tagStart > -1 && endIdx > -1) {
        html = html.substring(0, tagStart) + html.substring(endIdx + 4);
    }
    return html;
}
```

> **Gotcha — hardcoded chars:** Do NOT use hardcoded character values (e.g. char code 160 for `&nbsp;`). Use `replaceAll('\\s+$', '')` instead of `stripTrailing()` (which doesn't exist in Apex).

**Remove trailing TOC `<ol>`:**

```apex
// The trailing TOC always appears AFTER the last meaningful content block.
// It contains anchor links like <a href="#section-title">
// Find the last <ol> that only contains internal # links:
private static String removeTrailingTocOl(String html) {
    Integer lastOlStart = html.lastIndexOf('<ol>');
    if (lastOlStart == -1) return html;
    // Verify it's a TOC ol (contains only href="#" links)
    String olContent = html.substring(lastOlStart);
    if (olContent.containsIgnoreCase('href="#')) {
        html = html.substring(0, lastOlStart).replaceAll('\\s+$', '');
    }
    return html;
}
```

> **Gotcha — content ending in `</table>` or `</div>`:** The method must handle blocks ending in either tag. Using `lastIndexOf('</div>')` will miss articles whose last meaningful element is a table.

---

## 10. Phase 6 — Article Link Rewrite

### Goal
MindTouch internal links (`<a href="https://yourcompany.cxoneexpert.ai/...">`) need to be rewritten to point to the corresponding Salesforce Knowledge article URL.

### Batch: `TF_EX_ArticleLinkRewriteBatch`

**Logic:**
1. Build a map of `{ MindTouchPath → Salesforce Knowledge URL }` from existing `Knowledge__kav` records
2. For each `KnowledgeCategoryMap__c`, find all `<a href="...mindtouch...">` links in `TransformedHTMLContent__c`
3. Look up the corresponding Salesforce URL and replace

```apex
Pattern linkPattern = Pattern.compile('<a[^>]+href="(https?://[^"]*cxoneexpert[^"]*)"');
Matcher m = linkPattern.matcher(html);
while (m.find()) {
    String mtUrl = m.group(1);
    String path  = mtUrl.substringAfter('.ai/').substringBefore('?');
    if (sfUrlMap.containsKey(path)) {
        html = html.replace(m.group(1), sfUrlMap.get(path));
    }
}
```

---

## 11. Phase 7 — Create Salesforce Knowledge Articles

### Goal
Create `Knowledge__kav` records from `KnowledgeCategoryMap__c` records that have `HTMLContent__c` populated.

> **Production limit:** Salesforce production orgs default to **50 published articles** in Knowledge. Coordinate with the client's Salesforce AE to increase this before running at scale. In sandboxes there is no such limit.

### Article Type → Record Type Mapping

| `ArticleType__c` value | Record Type DeveloperName |
|---|---|
| `topic-task` | `How_To` |
| `topic-howto` | `How_To` |
| `topic-concept` | `Topic` |
| `topic-guide` | `Topic` |
| `topic-reference` | `Topic` |
| *(anything else)* | `Topic` (default fallback) |

### Batch / Script: `MindTouchKnowledgeCreateBatch`

```apex
// Load record type map:
Map<String, Id> recordTypeMap = new Map<String, Id>();
for (RecordType rt : [
    SELECT Id, DeveloperName FROM RecordType
    WHERE SObjectType = 'Knowledge__kav'
    AND DeveloperName IN ('How_To', 'Topic')
]) {
    recordTypeMap.put(rt.DeveloperName, rt.Id);
}

// For each KnowledgeCategoryMap__c record:
Knowledge__kav article = new Knowledge__kav();
article.Title                  = rec.Title__c;
article.KnowledgeContent__c    = rec.TransformedHTMLContent__c;
article.MindtouchExternalId__c = rec.MindTouchId__c;
article.IsVisibleInPkb         = rec.Public__c; // Public knowledge base

// URL name — must be unique, URL-safe:
article.UrlName = rec.Title__c
    .replaceAll('[^a-zA-Z0-9\\s-]', '')
    .replaceAll('\\s+', '-')
    .toLowerCase()
    .left(255);

// Record type:
String rtName = ARTICLE_TYPE_TO_RECORD_TYPE.get(rec.ArticleType__c);
if (String.isBlank(rtName)) rtName = 'Topic';
article.RecordTypeId = recordTypeMap.get(rtName);

insert article;
```

> **Verify DeveloperNames before running:**
> ```apex
> for (RecordType rt : [SELECT Id, DeveloperName, Name FROM RecordType WHERE SObjectType = 'Knowledge__kav'])
>     System.debug(rt.DeveloperName + ' | ' + rt.Name);
> ```

---

## 12. Phase 8 — Data Categories (Taxonomy) Deployment

### Goal
Deploy a Salesforce Data Category Group that mirrors the MindTouch page hierarchy so Knowledge articles can be tagged/filtered by category.

### Salesforce Data Category Rules

| Rule | Constraint |
|---|---|
| Max categories per group | **100** (can be increased via Salesforce Support) |
| API name max length | **40 characters** |
| API name pattern | Must start with a **letter**, contain only letters/numbers/underscores |
| No duplicate API names | Within the same group tree |
| Label max length | **40 characters** |
| XML tag for API name | `<name>` (NOT `<n>`) |
| XML tag for display label | `<label>` |
| `&` in labels | Must be escaped as `&amp;` in XML |

### XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<DataCategoryGroups xmlns="http://soap.sforce.com/2006/04/metadata">
    <dataCategory>
        <label>All</label>
        <name>All</name>
        <dataCategory>
            <label>Platform</label>
            <name>Platform</name>
            <dataCategory>
                <label>Dashboard</label>
                <name>Dashboard</name>
            </dataCategory>
        </dataCategory>
        <dataCategory>
            <label>Clinical</label>
            <name>Clinical</name>
        </dataCategory>
    </dataCategory>
</DataCategoryGroups>
```

Pair with a metadata definition file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<DataCategoryGroup xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Knowledge article categories</description>
    <label>Product</label>
    <name>Product</name>
    <objectUsage>
        <object>KnowledgeArticleVersion</object>
    </objectUsage>
</DataCategoryGroup>
```

### Common Fixes for XML Errors

| Error | Cause | Fix |
|---|---|---|
| `Invalid developer name` | API name starts with digit | Prefix with `N_` (e.g. `21st_Century` → `N_21st_Century`) |
| `Invalid developer name` | Contains special char | Replace with `_` |
| `Value too long for label field` | Label > 40 chars | Truncate to 40 |
| `Value too long for name field` | API name > 40 chars | Truncate to 40 |
| `Duplicate developer name` | Two categories with same API name | Prefix child with parent name (e.g. `Reports` → `Billing_Reports`) |
| `Element n invalid` | Used `<n>` instead of `<name>` | Replace all `<n>` and `</n>` with `<name>` and `</name>` |
| `Exceeded maximum limit` | > 100 categories in group | Contact Salesforce Support to increase limit |

### Deploy via Salesforce CLI

```bash
sf project deploy start --source-dir force-app/main/default/datacategorygroups
```

---

## 13. Phase 9 — Assign Data Categories to Articles

### Goal
Tag each `Knowledge__kav` with its corresponding Data Category based on the MindTouch path hierarchy.

### How It Works

```apex
// Query the group and category API names first:
List<KnowledgeArticleVersion> arts = [
    SELECT Id, KnowledgeArticleId
    FROM KnowledgeArticleVersion
    WHERE PublishStatus = 'Draft'
    AND Language = 'en_US'
    LIMIT 1
];

// Assign category:
Knowledge__DataCategorySelection sel = new Knowledge__DataCategorySelection();
sel.ParentId                  = arts[0].Id;
sel.DataCategoryGroupName     = 'Product';   // Group API name
sel.DataCategoryName          = 'Dashboard'; // Category API name
insert sel;
```

> **Verify exact API names before running at scale:**
> ```apex
> // Get group API name:
> List<Schema.DataCategoryGroupSobjectTypePair> pairs =
>     Schema.describeDataCategoryGroups(new List<String>{'Knowledge'});
> for (Schema.DataCategoryGroupSobjectTypePair p : pairs)
>     System.debug(p.getName());
> ```

**Path → Category mapping logic:**
Use `MindTouchPath__c` on the `KnowledgeCategoryMap__c` record to determine which category to assign. Split the path on `/` and map each segment to the corresponding Data Category API name.

---

## 14. Utility Classes Reference

### Summary of All Classes

| Class Name | Type | Purpose |
|---|---|---|
| `TF_EX_MindtouchUtils` | Utility | Auth token generation, base URL, shared config |
| `MindTouchCategorySync` | Utility/Runnable | Sync top-level categories (run once) |
| `TF_EX_MindTouchCategoryTreeBatch` | Batch | Full recursive tree sync with pagination |
| `TF_EX_MindTouchArticleContentBatch` | Batch | Fetch HTML content + video tag replacement |
| `TF_EX_MindTouchFileCollectorBatch` | Batch | Collect all file metadata into pending files object |
| `TF_EX_MindTouchFileDownloadBatch` | Batch | Download files and create ContentVersion records |
| `ContentVersionAutoDistribute` | Trigger | Auto-create ContentDistribution on file upload |
| `TF_EX_MindTouchImageUrlReplacer` | Utility | Pure HTML transformation — replace image URLs |
| `TF_EX_MindTouchImageReplaceBatch` | Batch | Batch wrapper for image URL replacement |
| `TF_EX_MindTouchHTMLCleanupBatch` | Batch | Remove Updated/Views headers and trailing TOC |
| `TF_EX_ArticleLinkRewriteBatch` | Batch | Rewrite internal MindTouch links to Salesforce URLs |
| `MindTouchKnowledgeCreateBatch` | Batch/Script | Create Knowledge__kav records from staging object |

---

## 15. Execution Order & Runbook

Run steps in this exact order. Do not skip ahead — each step depends on data from the previous.

```
Step 1  │ Configure TF_EX_MigrationConfig__mdt with API credentials
Step 2  │ Add Remote Site Setting for MindTouch tenant URL
Step 3  │ Verify authentication (Anonymous Apex test — expect status 200)
Step 4  │ Run MindTouchCategorySync.syncTopLevelCategories() to get L1 pages
Step 5  │ Run TF_EX_MindTouchCategoryTreeBatch (batch size: 1) — full tree
        │   → Verify record count matches expected (e.g. 2,100+ records)
Step 6  │ Run TF_EX_MindTouchArticleContentBatch (batch size: 5)
        │   → Verify HTMLContent__c is populated on article records
Step 7  │ Run TF_EX_MindTouchFileCollectorBatch
        │   → Verify TF_EX_MindTouchPendingFile__c count matches MindTouch @totalcount
Step 8  │ Run TF_EX_MindTouchFileDownloadBatch
        │   → Monitor file storage — do NOT exceed org storage limit
        │   → Verify Uploaded__c = true on all records
Step 9  │ Verify ContentDistribution records created (public URLs populated)
Step 10 │ Build URL map (filename → CDN URL) and run TF_EX_MindTouchImageReplaceBatch
        │   → Verify TransformedHTMLContent__c has Salesforce CDN URLs
Step 11 │ Run TF_EX_MindTouchHTMLCleanupBatch
        │   → Spot-check before/after on 5-10 records
Step 12 │ Run TF_EX_ArticleLinkRewriteBatch (if internal article links exist)
Step 13 │ Deploy Data Category XML via Salesforce CLI or Change Set
        │   → Fix any naming validation errors (see Section 12)
Step 14 │ Run MindTouchKnowledgeCreateBatch or script
        │   → Verify Knowledge__kav records created with correct RecordType
Step 15 │ Assign Data Categories to articles
Step 16 │ QA review — spot-check articles, images, categories, video embeds
Step 17 │ Publish articles (update PublishStatus to 'Online')
```

### Resetting Processed__c for Re-runs

If a batch needs to be re-run (e.g. after fixing a bug):

```apex
// Reset all:
update [SELECT Id, Processed__c FROM KnowledgeCategoryMap__c WHERE Processed__c = true];
// (Set Processed__c = false in a loop or Data Loader)

// Reset specific records:
List<KnowledgeCategoryMap__c> toReset = [
    SELECT Id FROM KnowledgeCategoryMap__c
    WHERE MindTouchId__c IN ('1234', '5678')
];
for (KnowledgeCategoryMap__c r : toReset) r.Processed__c = false;
update toReset;
```

---

## 16. Known Limitations & Gotchas

### Salesforce Apex Limitations

| Limitation | Impact | Workaround |
|---|---|---|
| 100 callout limit per transaction | Batch execute() can't do too many HTTP calls per record | Set batch size to 1 for callout-heavy batches |
| CPU time limit (10s sync / 60s async) | Complex regex on very large HTML can hit limit | Process in smaller chunks; avoid nested loops |
| Long Text Area not filterable in SOQL | Can't WHERE on `HTMLContent__c`, `MindTouchPath__c` | Use indexed fields (`Processed__c`, `MindTouchId__c`) |
| `stripTrailing()` doesn't exist in Apex | Compile error | Use `replaceAll('\\s+$', '')` |
| `StringBuffer`, `appendReplacement()`, `appendTail()` are Java-only | Compile error | Use `html.replace(match, replacement)` in a while loop |
| `@api` boolean props on LWC default to false | LWC warning if initialized to `true` | Invert logic and default to `false` |
| `ContentDownloadUrl` not filterable | Can't WHERE on it | Query all ContentDistribution records and filter in Apex |

### MindTouch API Quirks

| Quirk | Detail |
|---|---|
| Single child returns Map not List | `/subpages` returns `{}` for 1 child, `[]` for multiple — always normalize |
| Pagination cap at 100 | `@count` ≤ 100 even if `@totalcount` is 577 — always paginate |
| Base64 inline images | Some articles embed images as base64 data URIs instead of src URLs — handle separately |
| HTML contains MindTouch CSS classes | `mt-section-origin`, `mt-content-wrapper` etc. — strip or leave as-is (Salesforce ignores unknown classes) |
| Path in `uri.ui` field | Full article path is nested in `page → uri → @ui` attribute |

### Salesforce Knowledge Limitations

| Limitation | Detail |
|---|---|
| 50 published articles (production default) | Contact Salesforce AE to increase before migration |
| 100 Data Categories per group (default) | Contact Salesforce Support to increase if taxonomy > 100 |
| Rich Text Area supports iframes | `<video>` tags are stripped — must convert to `<iframe>` before storing |
| URL name must be unique | Generate from Title with special char stripping + collision handling |

---

## 17. Troubleshooting Reference

| Error / Symptom | Root Cause | Fix |
|---|---|---|
| `Too many callouts: 101` | execute() making >100 HTTP calls | Reduce batch size; split file list + download into separate batches |
| `STORAGE_LIMIT_EXCEEDED` | Org file storage full | Delete test files; request storage increase from Salesforce |
| `Invalid field for upsert, must be External Id` | Field not marked as External ID in Setup | Go to Object Manager → field → check "External ID" |
| `Insert failed: MIXED_DML_OPERATION` | Inserting setup + non-setup objects in same transaction | Use `System.runAs()` or `@future` for setup object DML in tests |
| `field X can not be filtered in a query call` | Trying to WHERE on Long Text Area | Remove from WHERE; filter in Apex after querying |
| `Invalid developer name set in category tree` | API name starts with digit or has invalid chars | See Section 12 fix table |
| `Exceeded maximum limit for data categories` | > 100 categories in group | Contact Salesforce Support |
| `Element n invalid` (metadata deploy) | Using `<n>` instead of `<name>` in XML | Replace all `<n>`/`</n>` with `<name>`/`</name>` |
| Token format error / 401 from MindTouch | HMAC signature wrong or key/secret swapped | Verify API Key and Secret are not transposed; check epoch is in seconds not milliseconds |
| Images not replaced in HTML | Filename used as dedup key — same name, different pages | Switch dedup key to full source URL |
| Articles missing from migration | Pagination truncated at 100 subpages | Implement offset loop in `fetchSubpages` |
| `Contains iframe: false` after DML on Knowledge | Wrong field type (Plain Text instead of Rich Text Area) | Ensure `KnowledgeContent__c` is Rich Text Area on `Knowledge__kav` |
| Duplicate collaborator pills in LWC | State managed in two places simultaneously | Consolidate to single source of truth; avoid combining `@api` prop + internal state |

---

*This document covers the complete A–Z migration pattern. For org-specific configuration values (tenant URLs, API keys, record type DeveloperNames, Data Category group API names), always verify directly in the target org before running any batch.*
