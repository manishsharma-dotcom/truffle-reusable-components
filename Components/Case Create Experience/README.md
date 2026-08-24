# Case Create on Experience — Technical Guide

**Category:** Experience Cloud (Digital Experience) / Case Management
**Type:** 1 LWC + 1 Apex Controller (shared with the Case Collaborator package)
**Prefix:** `TF_EX_` (Apex) / `tF_EX_` (LWC) — Truffle Consulting delivery, Tebra org

---

## Folder Contents

- **`TF_EX_CaseCommunityCreateController.cls`** (+ Test)
  This is the **same class** already delivered in the "Case Collaborator Component for Experience" package ("Collaborator Tebra" folder). If both packages are deployed to the same org, deploy this class **once** — do not deploy two copies.
  - `getInitialData()` → current user info, linked Accounts, allowed Case Record Types, `"Collaborators"` CaseTeamRole Id.
  - `createCase(...)` → inserts the Case, links uploaded ContentDocuments via `ContentDocumentLink`. Collaborator/`CaseTeamMember` insertion code exists but is commented out (`COLLAB_SUPPRESSED` markers) — see the Case Collaborator guide for what to re-enable.
  - `getCollaborators(accountId)` → also currently a disabled stub (returns empty list).

- **`tF_EX_CaseCommunityCreate/`** (LWC) — **not included in the Case Collaborator package**, this is the actual create-Case UI:
  - **Step 1:** radio-button Record Type selection (`Customer_Support_New`, `Enrollments_Support`, `Integration_Request`, `Training`, `Digital_Marketing_Support`, `Account_Invoice_Support`, `Website_Design_Change`).
  - **Step 2:** a large, dynamic form — Account dropdown (auto-hidden/auto-filled if the user only has one Account), cascading Category → Issue → Issue Detail picklists (via `lightning/uiObjectInfoApi` `getPicklistValues`, which respects Record-Type-scoped picklist values), a Subject/Description pair, plus **many conditionally-shown extra field groups** driven by the specific Category+Issue+Issue Detail combination selected — e.g. Missing ERA (payer name/ID, NPI, TIN, up to 5 ERA check date/number/amount rows), Error Troubleshooting, New API Connection, FHIR, Calendar Activation, Appointment Reminders, Payer Connection, Lab Connection, EPCS/eRx/Add Refill, Provider Detail Update, Template Creation/Troubleshooting, University Troubleshooting, Template/Custom/Advanced Training, ERA Payment Posting, Advanced Payment Posting.
  - All of these extra answers get appended into the Case `Description` as formatted text (`additionalDescription`) rather than stored in dedicated fields — see Known Gaps below.
  - A `HIDDEN_ISSUE_DETAILS_BY_CONTEXT` config array lets you hide specific Issue Detail picklist values from community users only (for one Record Type + Category + Issue combo) while leaving them visible/usable internally.
  - **Child components used:** `c-tF_EX_CaseCollaborator` (from the Case Collaborator package — the searchable picker) and `c-tF_EX_FileUpload` (from the Custom File Upload package). **Both are required dependencies** — this component will not compile/render without them.
  - Also imports `TF_EX_CaseFileUploadController.deleteFiles` directly (from the Custom File Upload package) to clean up any uploaded-but-unsubmitted files if the user cancels.
  - Fires `casecreated` (`{caseId, caseNumber}`) and `modalclosed` events to its parent — designed to be opened as a modal from `tF_EX_CaseListView` (see the Experience List View package), not used as a standalone page.
  - Exposes an `@api cancel()` method the parent can call to trigger cleanup + close.

## How to Reuse / Deploy

1. **Deploy dependencies first:**
   - `tF_EX_CaseCollaborator` LWC + its Apex methods on `TF_EX_CaseCommunityCreateController` (from the Case Collaborator package).
   - `tF_EX_FileUpload` LWC + `TF_EX_CaseFileUploadController` (from the Custom File Upload package).
2. Deploy `TF_EX_CaseCommunityCreateController.cls` (+ test) if not already present from the Collaborator package, then `tF_EX_CaseCommunityCreate`.
3. Confirm these custom fields exist on Case: `Contact_Code_Category__c`, `Contact_Code__c`, `Sub_Contact_Code__c`, `TF_EX_Description__c`, plus whatever fields back the Record-Type-specific picklists referenced above.
4. Confirm the 7 Record Types listed in `getInitialData()` exist with those exact DeveloperNames, and that the Category/Issue/Issue Detail picklists have record-type-scoped values matching every `if(this.selectedCategory == ... )` branch in the JS (there are ~20 such branches — this is highly org-specific business logic).
5. Embed `tF_EX_CaseCommunityCreate` as a child of a parent component (typically `tF_EX_CaseListView`) that opens it in a modal and listens for `casecreated`/`modalclosed`.

## Known Gaps / Gotchas

- **Business logic is heavily hardcoded.** ~20 conditional branches match on exact Category/Issue/Issue Detail label strings. If you reuse this for another org/brand, you'll likely replace most of this conditional logic rather than configure it — treat the Step 1/Step 2 wizard shell, file upload integration, and collaborator integration as the reusable parts, not the specific field logic.
- **All the "extra" answers land in the Case Description** as concatenated text (`additionalDescription`), not in dedicated fields — anyone reporting on ERA check numbers, NPI, TIN, etc. will need to parse free text, not query a field. Consider adding real fields if this is reused for reporting-heavy processes.
- Description length is capped/truncated at 131,072 characters (Salesforce long text area limit) with a manual slice — verify this truncation logic still makes sense if you change what's appended.
- Depends on two other packages (`tF_EX_CaseCollaborator`, `tF_EX_FileUpload`) — this is not a self-contained deploy.
- Collaborator functionality is disabled by default in the shared controller (see Case Collaborator guide) — collaborator IDs are collected in the UI but never persisted unless you re-enable the suppressed Apex.
