# TF_EX_FileUpload — Reusable File Upload LWC

> **Type:** Reusable LWC Component  
> **Component Name:** `c-t-f_-e-x_-file-upload`  
> **Folder:** `force-app/main/default/lwc/TF_EX_FileUpload`  
> **Last Updated:** June 2026

---

## Table of Contents

1. [Overview](#1-overview)
2. [Component Files](#2-component-files)
3. [Apex Controller — TF_EX_CaseFileUploadController](#3-apex-controller--tf_ex_casefileuploadcontroller)
4. [How the Component Works](#4-how-the-component-works)
5. [Event Contract — filesupdated](#5-event-contract--filesupdated)
6. [Embedding in a Parent Component](#6-embedding-in-a-parent-component)
7. [Apex — Linking Files to a Record on Submit](#7-apex--linking-files-to-a-record-on-submit)
8. [Cleanup — Handling Orphaned Files](#8-cleanup--handling-orphaned-files)
9. [Styling & Branding](#9-styling--branding)
10. [Behavior Reference](#10-behavior-reference)
11. [Integration Checklist](#11-integration-checklist)
12. [Known Limitations & Gotchas](#12-known-limitations--gotchas)

---

## 1. Overview

`TF_EX_FileUpload` is a self-contained LWC that handles everything related to attaching files during a form submission — browsing or drag-and-drop, per-file 2 MB validation, base64 upload to Salesforce Files (`ContentVersion`), a live file list with per-file remove, and cleanup of orphaned files when the user cancels.

**It does not link files to any record itself.** That is intentionally the parent's responsibility — the component simply gives the parent a clean list of `ContentDocumentId` values to use however it needs on submit.

### What it handles

- Click-to-browse and drag-and-drop file selection
- Per-file size validation (2 MB limit, configurable in JS)
- Parallel uploads — multiple files upload simultaneously
- Live file list with filename, size, upload spinner, and ✕ remove button
- Immediate per-file delete on remove (calls Apex, removes from org)
- Fires `filesupdated` event after every state change so the parent stays in sync
- Blocks parent submit while any file is still uploading (`hasUploadingFiles`)
- Restores file list display if the component re-renders (e.g. flow validation errors)

### What the parent must handle

- Storing the `uploadedFileIds` array from the event
- Disabling submit while `hasUploadingFiles` is true
- Passing `contentDocumentIds` to the Apex submit method
- Calling `deleteFiles` on every exit path (cancel, back, navigation away)

---

## 2. Component Files

| File | Purpose |
|---|---|
| `caseFileUpload.js` | All upload logic, validation, state management, event firing |
| `caseFileUpload.html` | Dropzone, file list, spinner, delete button markup |
| `caseFileUpload.css` | SLDS-faithful styles, Tebra brand button, tooltip |
| `TF_EX_CaseFileUploadController.cls` | Apex backend — upload, delete, getFileDetails |

---

## 3. Apex Controller — TF_EX_CaseFileUploadController

Three methods back this component. All are `@AuraEnabled`.

### `uploadFile`

```apex
@AuraEnabled
public static Id uploadFile(String fileName, String base64Data, String contentType)
```

Creates a `ContentVersion` from base64-encoded file data. Returns the `ContentDocumentId` (not the `ContentVersionId`) so the parent can directly use it for `ContentDocumentLink` creation.

**Why base64?** LWC runs in a browser — `FileReader.readAsDataURL()` is the standard way to read a file's binary content in JavaScript. The result is a base64 data URI (`data:image/png;base64,....`). The component strips the prefix before sending to Apex.

### `deleteFiles`

```apex
@AuraEnabled
public static void deleteFiles(List<Id> contentDocumentIds)
```

Permanently deletes `ContentDocument` records. Deletion cascades automatically to all related `ContentVersion` and `ContentDocumentLink` records. Called in two places:
- **By the component** — when the user clicks ✕ on a single file
- **By the parent** — when the user cancels or navigates back, to bulk-delete all pending files

### `getFileDetails`

```apex
@AuraEnabled
public static List<ContentVersion> getFileDetails(List<Id> contentDocumentIds)
```

Returns `Title` and `ContentSize` for a list of `ContentDocumentId` values. Used only in `connectedCallback` to restore the file list display if the component re-renders (e.g. after a Salesforce Flow validation error that re-renders the screen).

---

## 4. How the Component Works

### File Selection

Two entry points, both funnel into `_processFiles(files)`:

| Entry Point | Trigger |
|---|---|
| Button click | `handleChooseClick()` programmatically triggers the hidden `<input type="file">` |
| Drag and drop | `handleDrop()` reads from `event.dataTransfer.files` |

The native `<input type="file">` is hidden (`display: none`) and has no visible styling. The visible "Choose Files" button is a styled `<button>` that calls `this.template.querySelector('.fu-hidden-input').click()`.

### Validation — `_processFiles()`

Splits the array into `oversized` (> 2 MB) and `valid` (≤ 2 MB):

```javascript
const MAX_FILE_BYTES = 2 * 1024 * 1024; // 2 MB — change here to update the limit

_processFiles(files) {
    const oversized = files.filter(f => f.size > MAX_FILE_BYTES);
    const valid     = files.filter(f => f.size <= MAX_FILE_BYTES);

    if (oversized.length > 0) {
        const fileList = oversized
            .map(f => `${f.name} (${this._formatSize(f.size)})`)
            .join(', ');
        this._toast(
            `Oops! These files are larger than the 2 MB limit: ${fileList}. Please upload files under 2 MB.`,
            'error',
            'File Too Large',
            'pester'  // 5-second auto-dismiss, no close button
        );
    }
    valid.forEach(f => this._readAndUpload(f));
}
```

Oversized files are reported in a single `pester`-mode toast (5-second auto-dismiss, no close button). Valid files in the same selection upload immediately — they are not blocked.

### Upload Flow — `_readAndUpload(file)`

For each valid file:

1. A `tempId` (`tmp-{timestamp}-{random}`) is generated and an `isUploading: true` placeholder is pushed into `this.files` — the user sees a spinner immediately
2. `_notifyParent()` fires so the parent knows an upload is in progress
3. `FileReader.readAsDataURL()` reads the file
4. On `reader.onload`, the base64 string is extracted after the comma in the data URI
5. `uploadFile({ fileName, base64Data, contentType })` Apex call is made
6. On success → placeholder updated: `contentDocumentId` set, `isUploading: false`
7. On failure → placeholder removed; error toast shows the Apex error message
8. `_syncAndPublish()` is called to update `_uploadedFileIds` and notify the parent

### Internal File State — `this.files`

Each entry:

```javascript
{
    tempId           : 'tmp-1748123456-a3f9k',  // local key, used in for:each template
    contentDocumentId: '069XXXXXXXXXXXXXXX',     // null while uploading
    name             : 'invoice.pdf',
    size             : '1.2 MB',                 // pre-formatted display string
    isUploading      : false                     // true while Apex call is in flight
}
```

The `tempId` is the `key` in the `for:each` template. This ensures LWC can track each row correctly even before a real Salesforce ID exists.

### Per-File Delete — `handleDeleteFile()`

The ✕ button is only rendered when `isUploading = false` (no deleting a file mid-upload).

```javascript
async handleDeleteFile(event) {
    const cdId = event.currentTarget.dataset.id;
    const name = event.currentTarget.dataset.name;

    // Optimistic remove — update UI first, then call Apex
    this.files = this.files.filter(f => f.contentDocumentId !== cdId);
    this._syncAndPublish();

    try {
        await deleteFiles({ contentDocumentIds: [cdId] });
    } catch (err) {
        // File already removed from UI — not re-added to avoid confusion
        // Orphan will be cleaned up by parent on cancel
        this._toast(`Could not remove "${name}" from the server.`, 'error', 'Delete Error');
    }
}
```

The UI updates optimistically before the Apex call completes. If Apex fails, the file stays removed from the UI (re-adding would confuse the user). The orphaned `ContentDocument` will be caught by the parent's cleanup on cancel.

---

## 5. Event Contract — `filesupdated`

Fired after **every state change** — upload started, upload completed, file removed.

```javascript
this.dispatchEvent(new CustomEvent('filesupdated', {
    detail: {
        uploadedFileIds  : [...this._uploadedFileIds],  // Id[]
        hasUploadingFiles: Boolean                       // true if any upload in flight
    }
}));
```

| Property | Type | Value |
|---|---|---|
| `uploadedFileIds` | `String[]` | `ContentDocumentId` values for **completed** uploads only. Files still uploading are excluded. |
| `hasUploadingFiles` | `Boolean` | `true` if at least one file has `isUploading: true`. Use this to disable submit. |

### Important

`uploadedFileIds` is a **snapshot** — it reflects only files that have successfully uploaded at the moment the event fires. A file that is still uploading will not appear in this array. When the upload completes, a new `filesupdated` event fires with the updated array including that file.

---

## 6. Embedding in a Parent Component

### HTML

```html
<c-t-f_-e-x_-file-upload onfilesupdated={handleFilesUpdated}></c-t-f_-e-x_-file-upload>
```

No properties need to be passed in. The component is fully self-contained.

### JS — Imports

```javascript
import deleteFiles from '@salesforce/apex/TF_EX_CaseFileUploadController.deleteFiles';
```

### JS — State

```javascript
@track _pendingFileIds    = [];     // ContentDocumentIds of completed uploads
@track _hasUploadingFiles = false;  // true while any file is still uploading
```

### JS — Event Handler

```javascript
handleFilesUpdated(e) {
    this._pendingFileIds    = e.detail.uploadedFileIds   || [];
    this._hasUploadingFiles = e.detail.hasUploadingFiles || false;
}
```

### JS — Disable Submit While Uploading

```javascript
get isSubmitDisabled() {
    return this.isSubmitting || this._hasUploadingFiles;
}
```

```html
<button onclick={handleSubmit} disabled={isSubmitDisabled}>Submit</button>
```

### JS — Pass File IDs on Submit

```javascript
async handleSubmit() {
    // ... your validation logic ...

    const result = await yourApexMethod({
        // ... other fields ...
        contentDocumentIds: [...this._pendingFileIds]
    });
}
```

### JS — Cleanup Helper

```javascript
async _cleanupFiles() {
    if (!this._pendingFileIds.length) return;
    try {
        await deleteFiles({ contentDocumentIds: [...this._pendingFileIds] });
        this._pendingFileIds = [];
    } catch (e) {
        console.error('File cleanup error:', e);
    }
}
```

### JS — Call Cleanup on Every Exit Path

```javascript
// User clicks Cancel
@api
async cancel() {
    await this._cleanupFiles();
    this.dispatchEvent(new CustomEvent('modalclosed'));
}

// User clicks Back (multi-step form)
async handleBack() {
    await this._cleanupFiles();
    // ... reset form, go to previous step
}
```

> **Rule:** Every path that exits the form without submitting must call `_cleanupFiles()`. If you add a new exit path (e.g. an "X" button, an escape key handler, a timeout), add the cleanup call there too.

---

## 7. Apex — Linking Files to a Record on Submit

The component uploads files to Salesforce Files but does **not** link them to any record. That happens in the parent's Apex submit method. After creating the record, create `ContentDocumentLink` entries:

```apex
@AuraEnabled
public static Map<String, String> createYourRecord(
    // ... your fields ...
    List<Id> contentDocumentIds
) {
    // 1. Create your record
    Your_Object__c record = new Your_Object__c(/* fields */);
    insert record;

    // 2. Link files
    if (contentDocumentIds != null && !contentDocumentIds.isEmpty()) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId    = record.Id,
                ShareType         = 'V',   // Viewer access — adjust as needed
                Visibility        = 'AllUsers'
            ));
        }
        insert links;
    }

    return new Map<String, String>{
        'recordId' => record.Id
        // ... other return values
    };
}
```

### ShareType Values

| Value | Meaning |
|---|---|
| `V` | Viewer — can view but not edit or share |
| `C` | Collaborator — can view and edit |
| `I` | Inferred — inherits from the linked record's sharing |

For Cases and most community scenarios, `V` is appropriate.

---

## 8. Cleanup — Handling Orphaned Files

When a user uploads files but then cancels or navigates away, those `ContentDocument` records exist in Salesforce unlinked to any record. Without cleanup they accumulate as storage waste.

### Why this happens

The component uploads files immediately on selection (not on submit). This gives users instant feedback but means files can be orphaned if the form is abandoned.

### The cleanup pattern

The parent calls `deleteFiles` with all pending IDs on any non-submit exit:

```javascript
import deleteFiles from '@salesforce/apex/TF_EX_CaseFileUploadController.deleteFiles';

async _cleanupFiles() {
    if (!this._pendingFileIds.length) return;
    try {
        await deleteFiles({ contentDocumentIds: [...this._pendingFileIds] });
        this._pendingFileIds = [];
    } catch (e) {
        console.error('File cleanup error —', e);
        // Do not block the cancel flow on cleanup failure
    }
}
```

Note the `try/catch` does not rethrow — a cleanup failure should not block the user from cancelling. The orphaned file is minor storage waste; blocking the user is worse.

### All exit paths that need cleanup

When embedding this component, audit your parent for every way a user can leave the form without submitting:

- Modal X button (usually an `@api cancel()` method called by a grandparent)
- Back button in a multi-step form
- Escape key handler (if implemented)
- Browser navigation (hard to catch — rely on the above where possible)
- Any timeout or auto-close logic

---

## 9. Styling & Branding

### Button — "Choose Files"

Styled with Tebra brand colors:

```css
.fu-choose-btn {
    background   : #003A43;   /* Tebra dark teal */
    border       : 1px solid #003A43;
    color        : #ffffff;
    border-radius: 0.25rem;
    height       : 2rem;
    padding      : 0 1rem;
}

.fu-choose-btn:hover {
    background  : #ffffff;
    border-color: #003A43;
    color       : #003A43;
}
```

To adapt for a different brand, update the `background`, `border`, and `color` values in `caseFileUpload.css`. No JS changes needed.

### Dropzone

Dashed border (`#dddbda`) at rest, blue border + light blue background when a file is dragged over (`fu-dropzone--active`). The active state is toggled via `isDragOver` in JS.

### File List

SLDS table-style list — white rows, `#f3f2f2` on hover, light separator lines. File name truncates with ellipsis if too long. Size shown in muted grey to the right.

### Tooltip

A `?` info icon next to the "Attachments" label shows a tooltip on hover: "Uploads must be smaller than 2MB". Implemented in pure CSS (`:hover` on the parent shows the `.fu-help-tooltip` child). No JS required.

---

## 10. Behavior Reference

| Scenario | What Happens |
|---|---|
| File ≤ 2 MB selected (button or drop) | Spinner appears in list immediately; uploads in background; ID added to `uploadedFileIds` on completion |
| File > 2 MB selected | Blocked with a `pester` toast listing filename and size; other valid files in the same selection still upload |
| Multiple files, mixed sizes | One toast for all oversized files combined; valid files proceed in parallel |
| Upload in progress, user clicks Submit | Submit button is disabled (`hasUploadingFiles = true`); becomes enabled when all uploads complete |
| User clicks ✕ on uploaded file | File removed from UI immediately; `deleteFiles` Apex called; ID removed from `uploadedFileIds` |
| User clicks ✕ but Apex delete fails | File stays removed from UI; error toast shown; orphan cleaned up by parent on cancel |
| User cancels the form | Parent calls `deleteFiles` with all pending IDs; all orphaned files deleted from org |
| User clicks Back (multi-step form) | Same as cancel — parent calls cleanup before navigating back |
| FileReader error (corrupted file) | File removed from list; error toast shown; other files unaffected |
| Apex `uploadFile` error | File removed from list; Apex error message shown in toast; other files unaffected |
| Component re-renders (flow validation) | `connectedCallback` calls `getFileDetails` to restore the file list display from existing IDs |

---

## 11. Integration Checklist

Use this when embedding `TF_EX_FileUpload` in any new parent component:

- [ ] Add `<c-t-f_-e-x_-file-upload onfilesupdated={handleFilesUpdated}>` to HTML
- [ ] Import `deleteFiles` from `TF_EX_CaseFileUploadController` in parent JS
- [ ] Add `@track _pendingFileIds = []` and `@track _hasUploadingFiles = false` to parent JS
- [ ] Implement `handleFilesUpdated(e)` to update both tracked properties
- [ ] Add `isSubmitDisabled` getter that includes `|| this._hasUploadingFiles`
- [ ] Bind `disabled={isSubmitDisabled}` on the submit button
- [ ] Pass `contentDocumentIds: [...this._pendingFileIds]` in the Apex submit call
- [ ] Create `ContentDocumentLink` records in the Apex method linking files to the new record
- [ ] Implement `_cleanupFiles()` helper in parent JS
- [ ] Call `_cleanupFiles()` in every non-submit exit path (cancel, back, any modal close)
- [ ] Reset `_pendingFileIds = []` after successful submit or after cleanup

---

## 12. Known Limitations & Gotchas

| Limitation | Detail |
|---|---|
| 2 MB per file (not combined) | Each file is checked individually. A 1.9 MB + 1.9 MB combination totaling 3.8 MB will pass. To enforce a combined limit, sum `_pendingFileIds` sizes in the parent. |
| No file type restriction | Any file type is accepted. Add a type filter in `_processFiles` if specific types should be blocked (e.g. `.exe`, `.js`). |
| Upload on select, not on submit | Files go to Salesforce as soon as selected. This means storage is used even if the user never submits. Cleanup on cancel is essential. |
| Apex delete failure leaves orphans | If `deleteFiles` Apex fails during cancel cleanup (e.g. network issue), the `ContentDocument` stays in the org. Consider a scheduled cleanup job for unlinked `ContentDocument` records older than N hours as a safety net. |
| Flow re-render support | `connectedCallback` restores the file list if `uploadedFileIds` is pre-populated. This only works if the parent Flow variable is wired to the `@api uploadedFileIds` property. In LWC-only (non-Flow) usage this property is not needed. |
| `ContentDocumentId` not the same as `ContentVersionId` | `uploadFile` Apex returns `ContentDocumentId`. Always use this for `ContentDocumentLink` and `deleteFiles`. Do not confuse with `ContentVersionId`. |
| No progress percentage | The upload shows a spinner but no percentage indicator. Base64 Apex upload is a single synchronous call — there is no streaming progress API available in this approach. |
