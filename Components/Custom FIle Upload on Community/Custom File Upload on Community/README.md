# Custom File Upload on Community — Technical Guide

**Category:** Experience Cloud / File Attachments
**Type:** 1 LWC + 1 Apex Controller
**Prefix:** `TF_EX_` — Truffle Consulting delivery

---

## Folder Contents

- **`TF_EX_CaseFileUploadController.cls`** (+ Test)
  - `uploadFile(fileName, base64Data, contentType)` → decodes the base64 payload, inserts a `ContentVersion` (`IsMajorVersion = true`), re-queries it for the system-generated `ContentDocumentId`, and returns that Id. Throws `AuraHandledException` if fileName/base64Data are blank.
  - `deleteFiles(List<Id> contentDocumentIds)` → bulk-deletes `ContentDocument` records (used both for the per-file "✕" remove button and for cleaning up orphaned uploads if a parent form/modal is cancelled).
  - `getFileDetails(List<Id> contentDocumentIds)` → re-fetches Title/ContentSize for a set of `ContentDocumentId`s (`IsLatest = true`), used to restore the file list display after a re-render (originally written for a Screen Flow that re-renders on validation error).
  - **Note:** the class doc-comment says "Declared without sharing," but the actual class modifier in this backup is `public with sharing`. Verify which is intended for your org before deploying — `without sharing` may be needed if community/guest users don't otherwise have access to `ContentVersion`/`ContentDocument`.

- **`tF_EX_FileUpload/`** (LWC)
  - Click-to-browse **and** drag-and-drop file selection.
  - **2 MB per-file limit** (`MAX_FILE_BYTES` constant), oversized files are rejected client-side with a toast listing each rejected file name + size before any upload attempt.
  - Reads each valid file via `FileReader.readAsDataURL`, strips the data-URL prefix, and calls `uploadFile` in Apex.
  - Shows each file immediately in an "uploading" state (optimistic UI) before the Apex call resolves, then flips to "uploaded" (or removes it and shows an error toast if the Apex call fails).
  - Per-file remove button calls `deleteFiles` immediately (optimistic removal from the UI first).
  - Publishes an `@api uploadedFileIds` array (also has a setter, so a parent/Flow can push previously-uploaded Ids back in to restore state) and dispatches a `filesupdated` CustomEvent — `{ uploadedFileIds, hasUploadingFiles }` — after every add/remove, so a parent component can track current file state and disable "Submit" while an upload is still in progress.
  - Meta config currently targets `lightning__FlowScreen` **only** (`uploadedFileIds` is configured as a Flow output-only property) — but in practice this component is also used as a **plain child LWC** (not inside a Flow) by `tF_EX_CaseCommunityCreate` (see the Case Create on Experience package), listening to `filesupdated` directly. If you want to drag this component directly onto an Experience Builder page (rather than nesting it inside another LWC or a Flow screen), add `lightningCommunity__Default`/`lightningCommunity__Page` to the `<targets>` list.

## How to Reuse / Deploy

1. Deploy the Apex class (+ test) and the LWC — no custom fields or objects required, only standard `ContentVersion`/`ContentDocument`/`ContentDocumentLink`.
2. Decide where this will be used:
   - **As a Screen Flow component:** drop it on a Flow Screen, map the `uploadedFileIds` output to a Text Collection variable, and loop through it in the flow to create `ContentDocumentLink` records against your target record after the flow's Case/record is created.
   - **As a nested LWC (current usage in this backup):** import it as `c-t-f_-e-x_-file-upload`, listen for `filesupdated`, and read `event.detail.uploadedFileIds` to know what to link once the parent record is saved (see `tF_EX_CaseCommunityCreate` for a working example).
3. If reused outside a Case-creation context, nothing here is Case-specific — the Apex only deals with `ContentVersion`/`ContentDocument`, so this can be attached to any object's create/edit flow as-is.
4. Adjust `MAX_FILE_BYTES` if 2 MB is too restrictive/generous for your use case.

## Known Gaps / Gotchas

- Sharing model mismatch between the doc comment (`without sharing`) and the actual class declaration (`with sharing`) — resolve this explicitly before deploying to a community where guest/portal users need file access that standard sharing rules wouldn't otherwise grant.
- Meta XML only declares `lightning__FlowScreen` as a target even though the component is actively used as a nested LWC elsewhere in this batch — add community targets if you want it directly placeable in Experience Builder.
- No file-type restriction (only a size limit) — add an extension/MIME allow-list in `_processFiles` if you need to block specific file types (e.g. executables).
- Uploads happen one-by-one via base64/Apex rather than using the native `lightning-file-upload` multipart upload — this gives full control over the UI/validation but is less efficient for very large files or many files at once than Salesforce's built-in uploader.
