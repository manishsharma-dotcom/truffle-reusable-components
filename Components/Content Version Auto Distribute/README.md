# Content Version Auto Distribute Trigger

**Category:** Files / Content Management (Salesforce CMS-adjacent)
**Type:** 1 Apex Trigger + 1 Apex Helper Class (no LWC)
**Prefix:** `TF_EX_` — Truffle Consulting delivery

---

## Description

Automatically creates a public/shareable download link (a `ContentDistribution` record) every time a new file version (`ContentVersion`) is uploaded, and writes the resulting public URL back onto the file itself (`ContentVersion.KnowledgeReferenceURL__c`). This is typically used so that files uploaded to Salesforce (e.g. Knowledge attachments, Help Center documents) automatically get a public URL that can be referenced elsewhere (embedded in an article, sent to an external system such as MindTouch, displayed in a Help Center page, etc.) without an admin manually generating a public link for every file.

The behavior is togglable per-org via a Custom Metadata Type record (`MindTouch_Config__mdt`), so it can be turned off without a deployment.

**Why it's reusable:** Any org that needs "every new file automatically gets a public share link" can reuse this trigger as-is. It is idempotent (skips files that already have a `ContentDistribution`) and bulk-safe (works correctly for any number of files uploaded in a single transaction).

---

## Technical Guide

### Folder Contents

**`triggers/TF_EX_ContentVersionAutoDistribute.trigger`**
- Fires on `ContentVersion` (after insert) only.
- First checks a Custom Metadata Type record: `MindTouch_Config__mdt where DeveloperName = 'siteURL'`. Fields read: `SiteURL__c`, `matchingPattern__c`, `TriggerActive__c`.
- Only proceeds if that record's `TriggerActive__c` checkbox is `TRUE` — this is the on/off switch for the whole feature, no deployment needed to disable it, just untick the field on the CMDT record.
- **Note:** `SiteURL__c` and `matchingPattern__c` are queried but not actually used anywhere in the helper class included in this backup. They were likely used by other logic (e.g. filtering which files qualify by a URL/site pattern) that either lives elsewhere in the source org or was simplified out. If you rebuild this from scratch you can drop those two fields, or use them to add filtering (see Security Note below).
- Delegates all real work to `TF_EX_ContentVersionAutoDistributeHelper.createPublicLinks(Trigger.new)`.

**`classes/TF_EX_ContentVersionAutoDistributeHelper.cls`**
- `createPublicLinks(List<ContentVersion> newVersions)`:
  1. Filters to only `IsLatest=true` versions (ignores older versions of a file being re-inserted, e.g. via version history operations).
  2. Bulk-queries `Title` for those versions.
  3. Bulk-queries existing `ContentDistribution` records to skip files that already have one (prevents duplicates if the trigger fires more than once for the same version).
  4. Builds and inserts one `ContentDistribution` per remaining file: `Name = file Title`, `PreferencesAllowOriginalDownload = true`, `PreferencesAllowPDFDownload = true`, `PreferencesAllowViewInBrowser = true` (i.e. a fully open public/unauthenticated distribution — see Security Note below).
  5. Calls `writeDownloadUrlsAsync()` as a `@future` method — this is required because `ContentDistribution.ContentDownloadUrl` is not populated until **after** the DML transaction commits.
- `writeDownloadUrlsAsync(List<Id> distributionIds)` *[@future]*: re-queries the just-inserted `ContentDistribution` rows (their `ContentDownloadUrl` is now populated by Salesforce), and writes that URL back onto `ContentVersion.KnowledgeReferenceURL__c`.

### How to Reuse / Deploy

1. **Prerequisites in target org** (not included in this backup — must exist before deploying):
   - Custom field: `ContentVersion.KnowledgeReferenceURL__c` (URL or Text, long enough for a full URL, e.g. 255+ chars).
   - Custom Metadata Type: `MindTouch_Config__mdt` with fields `SiteURL__c` (Text/URL), `matchingPattern__c` (Text), `TriggerActive__c` (Checkbox), and one record with `DeveloperName = 'siteURL'`.
2. Deploy `classes/` then `triggers/` (or together — no strict order issue since there's only one class + one trigger and no other dependency between them).
3. Create/verify the `MindTouch_Config__mdt` `'siteURL'` record and set `TriggerActive__c = true` to turn the automation on.
4. **Important** — write a test class before deploying to Production. This backup does not include a test class for this trigger/helper, and Salesforce requires ≥75% Apex code coverage org-wide (and >0% for this specific class/trigger) to deploy to Production. A minimal test should:
   - Insert a `ContentVersion` (with `PathOnClient`/`VersionData`) inside a `MindTouch_Config__mdt`-active context (Custom Metadata records can be queried in tests, but consider relying on whatever CMDT records already exist in the target org, since CMDT records are not created via DML in Apex tests).
   - Assert a `ContentDistribution` was created and (since `@future` runs async) either use `Test.startTest()`/`Test.stopTest()` to force the future method to run synchronously in the test, then assert `ContentVersion.KnowledgeReferenceURL__c` is populated.

### Security Note

`ContentDistribution` created here has `PreferencesAllowOriginalDownload` / `PreferencesAllowPDFDownload` / `PreferencesAllowViewInBrowser` all set to `true` with no password/expiration configured — this creates a **public, unauthenticated link for every uploaded file version**. Before reusing this in an org with sensitive files, consider:
- Restricting which files trigger this (a `ContentVersion` field/tag check, or actually using the `SiteURL__c` / `matchingPattern__c` CMDT fields to scope it), so not every file in the org gets a public link.
- Adding `PreferencesExpires` / `PreferencesPasswordRequired` if appropriate.

### Known Gaps / Gotchas

- No test class included (see above) — required before Production deploy.
- `SiteURL__c` / `matchingPattern__c` on the CMDT are read but unused in the Apex included here; verify whether the source org uses them anywhere else (e.g. a Flow, another trigger, or an outbound integration) before assuming they're safe to remove.
- Because this runs on every `ContentVersion` insert org-wide, confirm there isn't already a similar automation (Flow/other trigger) creating `ContentDistribution` records, to avoid duplicate/competing automations.
