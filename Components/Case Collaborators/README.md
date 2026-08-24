# Case Collaborator Component for Experience

**Category:** Experience Cloud (Digital Experience) / Case Management
**Type:** LWC + Apex (two independent implementations)
**Prefix conventions:** `ssv_` / `SSV_` = Weave org, `tF_EX_` / `TF_EX_` = Tebra org

---

## Description

Lets a Case owner / portal user add other people as "collaborators" on a Case so those people get visibility/notifications on that Case, without making them the Case owner. Two different implementations of the same idea are bundled in this backup, built for two different clients/orgs:

1. **"Collaborator Weave"** — a simple 5-slot text-field based collaborator list. Collaborator emails are stored directly on the Case record (`SSV_Collaborator1__c` ... `SSV_Collaborator5__c`) and mirrored onto the CaseTeamMember related list (`"Collaborator"` CaseTeamRole) so Chatter/Case Team visibility rules pick them up.
2. **"Collaborator Tebra"** — a more polished, reusable multi-select "pill" picker LWC (`c-tF_EX_CaseCollaborator`) that searches Contacts/Users tied to an Account (via `AccountContactRelation`) and returns selected User Ids to a parent component (e.g. a Case-creation form). Standard `CaseTeamMember` records are the intended storage mechanism.

**Why it's reusable:** Any Experience Cloud (portal/community) project that needs "let the customer add a colleague to watch this Case" can reuse either pattern — the Weave pattern for a quick, low-config solution, or the Tebra picker LWC for a scalable, search-based, unlimited-collaborator UX wired to standard `CaseTeamMember`.

> **Note:** In the Tebra version, all `CaseTeamMember` insert/delete logic is present in the Apex controllers but is currently **commented out** (`COLLAB_SUPPRESSED` blocks). See the Guide below for what needs to be re-enabled before reuse.

---

## Technical Guide

### Folder Contents

**Collaborator Weave/**

- `SSV_PortalCaseCollaboratorController.cls` (+ `.cls-meta.xml`)
  - `@AuraEnabled` Apex controller used by `sSV_CaseCollaboratorCC` (the working, portal-facing LWC).
  - `getData(recordId)` → returns current 5 collaborator slots as a `List<Wrapper>{email, index}`.
  - `addColabOnCase(recordId, email)` → fills the first empty `SSV_Collaborator1..5__c` slot on the Case, updates the record, then calls `updateCaseWatchers()` to mirror the addition into `CaseTeamMember` (role `"Collaborator"`) via `SSV_CollabHelperClass`.
  - `removeColabFromCase(recordId, fieldNumber)` → clears that slot and calls `SSV_CollabHelperClass.DeleteCaseTeamMembers()` to remove the matching `CaseTeamMember`.
- `SSV_PortalCaseCollaboratorControllerTest.cls` — unit test shell for the above (included).
- `sSV_CaseCollaboratorCC/` (LWC) — the **active**, portal-facing collaborator widget. Renders existing collaborators as removable "pill" chips, plus an email input + Add button (validates email format client-side, blocks duplicates, enforces the 5-collaborator max). Calls `getData` / `addColabOnCase` / `removeColabFromCase` above. Targets: `lightning__RecordPage`, `lightningCommunity__Page/Default`. Public property: `recordId` (auto-bound to `{!recordId}` on a record page).
- `ssv_CaseCollaboratorComponent/` (LWC) — a **second, older/unused variant**. It imports `@salesforce/apex/SSV_CaseCollaboratorController.setupCollaborators` — note the class name (`SSV_CaseCollaboratorController`) is **different from, and not included in,** this backup (only `SSV_PortalCaseCollaboratorController` is included). This component will **not deploy/run standalone**. Treat it as reference-only / deprecated unless you also locate `SSV_CaseCollaboratorController` and `SSV_ServiceUtil.SecurityException` from the source org.

**Collaborator Tebra/**

- `TF_EX_CaseCommunityCreateController.cls` (+ Test)
  - Powers the Experience Cloud "create a Case" form (`TF_EX_CaseCommunityCreate` LWC — not included in this backup, only its controller is).
  - `getInitialData()` → current user info, linked Accounts, allowed Case Record Types, `"Collaborators"` CaseTeamRole Id.
  - `createCase(...)` → inserts the Case, links uploaded ContentDocuments via `ContentDocumentLink`. Collaborator/CaseTeamMember insertion code is present but wrapped in comments (`COLLAB_SUPPRESSED` markers) — currently a no-op.
  - `getCollaborators(accountId)` → returns eligible portal Users for an Account (Customer/Customer Admin profiles) for the picker LWC below. Also currently commented out — returns an empty list as a stub.
- `TF_EX_CaseCommunityDetailController.cls` (+ Test)
  - Powers a Case detail page in Experience Cloud: `getCaseDetail()`, `getClosedReasonOptions()`, `closeCase()`, `reopenCase()` (posts a Chatter FeedItem + sets `Status='ReOpened'`), `addCollaborator()`/`removeCollaborator()` (also `COLLAB_SUPPRESSED` stubs).
  - Also contains a reusable `canReopen` calculator: a Case can be reopened only if it was closed within the last 5 business days.
- `tF_EX_CaseCollaborator/` (LWC) — reusable multi-select collaborator **picker** (not a full save widget).
  - `@api accountId` (setter triggers reload), `@api excludedUserIds`, `@api hidePills`.
  - Fires a `collaboratorchange` event with `detail.selectedUserIds = [id1, id2, ...]` — the **parent component** is responsible for actually saving these to `CaseTeamMember` (e.g. via `createCase()`'s `collaboratorUserIds` param, once re-enabled).
  - Search box + dropdown + selected-pill UI, all in the component (SLDS classes, custom CSS, no external libs).

### How to Reuse / Deploy

1. Decide which pattern fits: quick 5-slot text field approach → Weave pattern; scalable searchable picker tied to standard `CaseTeamMember` → Tebra pattern (recommended for new builds).

2. **Weave pattern prerequisites** (must exist in target org before deploying):
   - 5 custom fields on Case: `SSV_Collaborator1__c` ... `SSV_Collaborator5__c` (Text/Email type).
   - A `CaseTeamRole` record named exactly `"Collaborator"`.
   - Apex classes `SSV_CollabHelperClass` and `SSV_ServiceUtil` (with an inner `SecurityException` class) — these are **referenced but not included** in this backup. You must source them from the original Weave org or rebuild them (they only need to insert/delete `CaseTeamMember` rows by email/role and throw a custom security exception).
   - Case Team feature enabled, and running user needs access to add Case Team Members.

3. **Tebra pattern prerequisites:**
   - Standard `CaseTeamRole` named `"Collaborators"` (plural — note the difference from the Weave org's singular `"Collaborator"`).
   - `AccountContactRelation` data populated (used to resolve which portal Users belong to which Account).
   - Custom fields referenced: `Case.TF_EX_Description__c`, `Case.Contact_Code_Category__c`, `Case.Contact_Code__c`, `Case.Sub_Contact_Code__c`, `Case.Closed_Reason__c` (picklist with at least `'Resolved'` and `'No Longer Needed'` values).
   - Before going live, **uncomment** the `COLLAB_SUPPRESSED` blocks in both controllers (`getCollaborators`, the CaseTeamMember insert block in `createCase`, `addCollaborator`, `removeCollaborator`, and the collaborator query block in `getCaseDetail`) — as delivered, collaborator functionality on this org is intentionally disabled.
   - Drop the `tF_EX_CaseCollaborator` LWC onto a Case-creation or Case-detail Experience Cloud page/LWC and listen for `oncollaboratorchange` to capture `selectedUserIds`.

4. Run/update the included test classes and confirm ≥75% org-wide Apex coverage before deploying to Production.

### Known Gaps / Gotchas

- `ssv_CaseCollaboratorComponent` (Weave) references a class not present in this backup — do not deploy it as-is.
- Tebra collaborator save/remove/list logic is currently commented out end-to-end; the picker LWC alone only emits selected IDs, it does not persist them until you wire it back up.
- `"Collaborator"` (Weave) vs `"Collaborators"` (Tebra) CaseTeamRole names differ — match whichever your target org actually uses.
