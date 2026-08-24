# Case Trigger — Technical Guide

**Category:** Case Management / Core Trigger Automation
**Type:** 2 Apex Triggers + 1 Apex Handler Class (extends an external `TriggerHandler` base class not included in this backup)
**Prefix:** `SSV_` (Apex) — Weave org delivery

---

## Folder Contents

- **`CaseTrigger.trigger`** — the single entry-point trigger on Case, covering all 7 DML contexts (`before/after insert/update/delete`, `after undelete`):
  ```
  trigger CaseTrigger on Case (...) {
      if(!FeatureManagement.checkPermission('skipTrigger')) TriggerService.onTrigger();
  }
  ```
  - Gated by Custom Permission `skipTrigger` — assigning this permission to a user/integration bypasses **all** Case trigger logic for their transactions (useful for data loads/migrations).
  - Delegates everything to `TriggerService.onTrigger()` — **this `TriggerService` class is not included in this backup.** It appears to be a central dispatcher/registry (a common enterprise pattern where a metadata-driven or hardcoded registry decides which handler class(es) — such as `SSV_CaseAgeTriggerHandler` below — actually run for a given object). Without `TriggerService.cls`, this trigger will not compile, and the link between this trigger and the handler class below is not visible in this backup alone.

- **`SSV_CaseAgeTriggerHandler.cls`** (+ Test) — `public with sharing`, extends a class called `TriggerHandler` (this is the class/method signature pattern used by the well-known open-source "sfdc-trigger-framework" library — that base class is **not included** in this backup and must be sourced separately if this is the framework in use). Implements:
  - **`afterInsert`** → creates a `SSV_CaseAgeRecord__c` history row per new Case (start time, initial status, owner) — run asynchronously via a `@future` method that re-queries the Cases by Id (a common workaround for `@future` methods, which can't accept sObjects directly).
  - **`beforeUpdate`** → strips HTML tags out of `SSV_RecentPublicComment__c` whenever it changes (turns `<p>`/`<br/>` into newlines, then strips remaining tags) — cleans up rich-text Chatter/portal comment content for plain-text display elsewhere. Also calls `updatePaidSupportFlag`.
  - **`afterUpdate`** → when Status or Owner changes, closes the currently-open `SSV_CaseAgeRecord__c` (stamps `SSV_EndTime__c`) and opens a new one — this builds a full timeline of "who owned this case, in what status, for how long," useful for case-age/SLA reporting.
  - **`beforeInsert`** → auto-assigns `Priority` and a `SSV_PriorityProgram__c` lookup based on the Case's Account (or the Account resolved from Contact if AccountId is blank), using the **lowest-order** `SSV_PriorityProgram__c` record tied to that Account (via `SSV_CollabHelperClass.getPriorityProgram()` — same missing helper class flagged in the Case Collaborator package). Restricted to the two "SSV Customer Support" Record Types.
  - **`updatePaidSupportFlag`** → flags a Case as `SSV_IsPaidSupportCase__c = true` if it's newly assigned to a specific "Paid Support" queue (looked up via `SSV_CollabHelperClass.getPaidSupportQueue()`) and its source resolves to `'Email'` (via a `getCaseSource()` helper that also distinguishes Chat/Web/Voice based on the running user type or a chatbot username).
  - Handles the **guest-user case specially**: since Experience Cloud guest users can't insert/update these records under normal sharing, all guest-context DML for `SSV_CaseAgeRecord__c` and Case updates is routed through `SSV_CollabHelperClass` (a `without sharing`-style helper, not included in this backup — same dependency gap noted in the Case Collaborator package).
  - **A large block of SLA-timer logic (Email/Chat/Emergency/Linear-ticket SLA tracking) is present but fully commented out**, with inline notes like `//removed as part of SSV-1101`. This was clearly a real feature at some point but has since been disabled — treat it as historical reference, not something to re-enable without checking why it was removed.

- **`CaseTeamMemberTrigger.trigger`** — despite the filename, this is **not actually a CaseTeamMember trigger**:
  ```
  trigger CaseTeamMemberTrigger on Account (before insert) {
  }
  ```
  It's declared on **`Account`**, not `CaseTeamMember`, and the body is **completely empty**. This looks like either a leftover placeholder, a renamed/repurposed file that was never finished, or a mistake carried over from a copy-paste. It currently does nothing at all.

## How to Reuse / Deploy

1. **You need the `TriggerService` dispatcher class and the `TriggerHandler` base class before any of this compiles.** Neither is included. If your target org already has a trigger framework in place (many orgs standardize on the open-source sfdc-trigger-framework, which this pattern strongly resembles), you may be able to wire `SSV_CaseAgeTriggerHandler` into your existing framework instead of sourcing `TriggerService` verbatim.
2. Also source or rebuild `SSV_CollabHelperClass` (referenced across multiple packages in this project — see Case Collaborator, Case Create, this guide) — it provides `getPriorityProgram()`, `getPaidSupportQueue()`, `resolveIdToName()`, and guest-safe DML helpers for Case Age records.
3. Prerequisites: custom object `SSV_CaseAgeRecord__c` (fields: `SSV_Case__c`, `SSV_StartTime__c`, `SSV_EndTime__c`, `SSV_Status__c`, `SSV_OwnerId__c`, `SSV_OwnerName__c`), custom object `SSV_PriorityProgram__c` (with `SSV_Account__c`, `SSV_ProgramPriority__c`), Case fields `SSV_RecentPublicComment__c`, `SSV_IsPaidSupportCase__c`, `SSV_PriorityProgram__c`, plus the two SSV Case Record Types.
4. **Investigate and likely fix or remove `CaseTeamMemberTrigger.trigger` before deploying it anywhere** — as written it's dead code sitting on the wrong object. Don't assume it's meant to do something; confirm with the source org whether a real CaseTeamMember trigger exists elsewhere that this file was supposed to represent.

## Known Gaps / Gotchas

- Missing `TriggerService` and `TriggerHandler` base classes — this package is not deployable standalone.
- Missing `SSV_CollabHelperClass` — same recurring dependency seen in the Case Collaborator and Case Create packages; worth sourcing once and sharing across all of them.
- `CaseTeamMemberTrigger.trigger` is mislabeled/empty/on the wrong object — flag this to whoever owns the source org rather than assuming it's intentional.
- Large commented-out SLA timer logic — don't re-enable without understanding why it was removed (ticket reference `SSV-1101` in the comments is your starting point if you need to ask the original team).
