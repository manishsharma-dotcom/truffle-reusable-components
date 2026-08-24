# Case Detail on Experience — Technical Guide

**Category:** Experience Cloud (Digital Experience) / Case Management
**Type:** LWC + Apex (two independent implementations)
**Prefix conventions:** `ssv_` / `SSV_` = Weave org, `tF_EX_` / `TF_EX_` = Tebra org

---

## Folder Contents

### Case Detail Weave/

- **`SSV_PortalFetchCaseDetails.cls`** (+ Test) — minimal `with sharing` controller, one method:
  - `fetchCaseFormType(recordId)` → returns `Case.SSV_CaseFormType__c` (a picklist/text field), or the literal string `'Case Not Found'` if the query returns nothing.

- **`sSV_CaseDetail/`** (LWC) — a **form-type-aware** Case detail page:
  - Uses `lightning-record-view-form` + `lightning-output-field` (standard, read-only field rendering — no custom Apex data-shaping beyond the form-type lookup).
  - On load, calls `fetchCaseFormType`, then shows a **different subset of fields** depending on the value returned: `New Weave Workspace`/`New Workspace`/`Billing` (`isNWW`), `Payment Contact Us` (`isPC`), `Support Request` (`isSR`), `Emergency After Hours` (`isESR`), `Phone Call Queue` (`isPCQSR`), `Ownership Transfer` (`isOwnershipTransfer`).
  - The `Phone Call Queue` form type shows by far the most fields — a full phone/call-routing configuration snapshot (queue name, greeting, routing type, phone assignment, fallback option, escape option, hold music, max hold time, position announcement, etc.) — this looks like it's used for a very specific "set up my phone tree" request type, not a generic support case.
  - The `Ownership Transfer` form type shows business-transfer fields (new legal business name, new address, EIN, new/current super admin email & name, current business owner name, etc.).
  - Renders a `c-s-s-v-_-protal-case-close-button` child component at the top of the page — **this component is referenced but NOT included in this backup.** The detail page will not fully render/compile without it (or a stub in its place).
  - Targets: `lightning__RecordPage`, `lightning__HomePage`, `lightningCommunity__Page/Default`.

### Case Detail Tebra/

- **`TF_EX_CaseCommunityDetailController.cls`** (+ Test) — same class already delivered in the "Case Collaborator Component for Experience" package ("Collaborator Tebra" folder); deploy once if both packages are used together.
  - `getCaseDetail(caseId)` → Case fields (CaseNumber, Status, IsClosed, Subject, `TF_EX_Description__c`, ContactPhone, IsEscalated, AccountId, ContactId, ClosedDate), plus a `canReopen` flag (true only if the Case was closed within the last 5 business days). Collaborator list/query section is present but commented out (`COLLAB_SUPPRESSED`).
  - `getClosedReasonOptions()` → active `Closed_Reason__c` picklist values filtered to `'Resolved'` / `'No Longer Needed'`.
  - `closeCase(caseId, closedReason)` → sets Status = `Closed` + `Closed_Reason__c`.
  - `reopenCase(caseId, reason)` → posts a rich-text Chatter `FeedItem` with the reason, sets Status = `ReOpened`.
  - `addCollaborator` / `removeCollaborator` → also `COLLAB_SUPPRESSED` stubs.

- **`tF_EX_CaseCommunityDetail/`** (LWC) — the active Tebra Case detail page:
  - Loads Case + closed-reason options in parallel (`Promise.all`) on `connectedCallback`.
  - Status badge with a color map (`New`, `Working`, `On Hold`, `Escalated`, `Closed`, `Pending Reply - Customer`, `Resolved`, `Pending`).
  - **Close Case modal** — requires a `Closed_Reason__c` selection, calls `closeCase`, then reloads the page (`window.location.reload()`, 1.5s delay) on success.
  - **Reopen Case modal** — shown only if `canReopen` is true; requires free-text reason, calls `reopenCase`, reloads on success.
  - Contains a `tF_EX_CaseCollaborator` picker integration and full add/remove collaborator wiring in the JS, but **all of it is currently disabled**: `_pickerVisible` defaults to `false`, `hasCollaborators` always returns `false`, and `handleCollaboratorChange`/`handleRemoveCollaborator` bodies are commented out. The collaborator section effectively does not render or function as delivered.
  - Meta config: exposed on Case record pages (`lightning__RecordPage`, scoped to Case object) and on Experience Cloud pages, with `recordId` bound to `{!recordId}`.

## How to Reuse / Deploy

**Weave pattern:**
1. Prerequisites: `Case.SSV_CaseFormType__c` field with the exact values checked in the JS (`New Weave Workspace`, `New Workspace`, `Billing`, `Payment Contact Us`, `Support Request`, `Emergency After Hours`, `Phone Call Queue`, `Ownership Transfer`), plus every `Case.SSV_*__c` field referenced (~25 custom fields — see the full import list in the LWC source for exact API names).
2. Source or stub the missing `c-s-s-v-_-protal-case-close-button` component before deploying, or remove that line from the HTML if a close button isn't needed.
3. This pattern is best reused as a **template for "one detail page, many form layouts"** — if your org has several Case Record Types/form types that each need a different read-only field layout, copy this `if:true={isXxx}` branching pattern rather than building N separate detail pages.

**Tebra pattern:**
1. Deploy the shared `TF_EX_CaseCommunityDetailController` (once, alongside the Case Collaborator / Case Create packages if used together).
2. Confirm `Case.TF_EX_Description__c` and `Case.Closed_Reason__c` (with `'Resolved'`/`'No Longer Needed'` active values) exist.
3. Drop `tF_EX_CaseCommunityDetail` onto a Case record page or Experience Cloud page, bind `recordId`.
4. If you want the collaborator section working, uncomment the suppressed blocks — same instructions as in the Case Collaborator guide (this is the "detail page" half of that feature; the "create" half lives in Case Create on Experience).

## Known Gaps / Gotchas

- Weave version has a missing dependency (`c-s-s-v-_-protal-case-close-button`) not included in this backup.
- Tebra version's collaborator UI is fully wired in code but fully disabled by flags/comments — don't assume it works out of the box.
- Both "Close Case" and "Reopen Case" success handlers use a hard `window.location.reload()` rather than refreshing component state in place — acceptable for a portal page but worth knowing if you want a smoother SPA-style update.
- The Weave version's field-per-form-type approach means every new "form type" value requires a code change (new `isXxx` flag + new template block) — there's no metadata-driven way to add a new form type without editing the LWC.
