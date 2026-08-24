# Case Mass Actions — Technical Guide

**Category:** Case Management / Internal Agent Productivity
**Type:** 3 Screen Flows (no Apex/LWC included in this backup — Apex actions are referenced but not bundled)
**Prefix:** `SSV_` — Weave org delivery

---

## Folder Contents

All three are **Screen Flows** designed to be launched as a **List View Mass Action / Quick Action** from a Case list view, where the flow receives the selected record Ids as an input variable (`ids`, a Text Collection).

### `SSV_Add_Mass_Comments.flow-meta.xml`
1. Checks Custom Permission `SSV_Run_Mass_Operations_on_Cases` — shows a "no access" screen and stops if missing.
2. Checks `ids` is not null/empty — shows a "please select records" screen if not.
3. Calls invocable Apex action **`SSV_CaseRecordtypeValidator`** (input: `caseIds`) → returns `supportCasesOnly` (Boolean). This validates that every selected Case is one of the "Support" record types.
4. If any non-support Case was selected → shows an error screen ("Please only select cases of type Customer Support or Customer Support - Emergency After Hours").
5. If valid → screen asks for a large-text `Case_Comments` field (required).
6. Calls invocable Apex action **`SSV_CaseMassUpdateComments`** (inputs: `caseIds`, `comments`).
7. Shows a confirmation screen: "Case(s) comment update process has been initiated. Case(s) will be updated in batches." (implies the target Apex action runs asynchronously/in Batch Apex, not synchronously in the flow transaction).

### `SSV_Mass_Update_Case_Fields.flow-meta.xml`
Same access/selection/record-type validation pattern as above, then:
- A single screen collects: Subject (text), Status (dropdown — choices: New, In Progress, On Hold, Urgent, Escalated to Prod/Dev, Escalated to Escalation Hub, Escalated to Support Leadership, Escalated to External Partner, Solved, Closed, Reopen), Owner (a `flowruntime:lookup` component scoped to Case/OwnerId), a Related Linear Record URL field, and several other custom fields on a `Case_Update_Variable` record variable: `SSV_SurveyEnabled__c`, `SSV_NotificationEnabled__c`, `SSV_Platform__c`, `SSV_Primary__c`, `SSV_Secondary__c`, `SSV_Need__c`, `SSV_Outcome__c`.
- Calls invocable Apex action **`SSV_CaseMassUpdateCaseFields`** with all of the above as named inputs.
- Same "updated in batches" confirmation screen.

### `SSV_Mass_Email_Send.flow-meta.xml`
Same access/selection/record-type validation pattern, plus an extra **daily email limit check**:
- Looks up an active `SSV_Mass_Email_Setting__mdt` Custom Metadata record (`Is_Active__c = true`) and reads `Daily_Email_Limit__c`.
- Calls invocable Apex action **`SSV_CaseMassEmailLimiter`** (input: `caseIds`) → returns `emailCountBefore`/`emailCountAfter`, presumably comparing how many emails have already gone out today against the configured limit.
- If the limit is/would be exceeded → shows a warning screen and blocks sending.
- If within limit → screen collects `Email_Subject` and `Email_Body`, shows the remaining daily allowance, then calls invocable Apex action **`SSV_CaseMassUpdateEmail`** (inputs: `caseIds`, `emailSubject`, `emailBody`) to send.

## How to Reuse / Deploy

1. **This backup is flow-definitions-only.** All five invocable Apex actions referenced (`SSV_CaseRecordtypeValidator`, `SSV_CaseMassUpdateComments`, `SSV_CaseMassUpdateCaseFields`, `SSV_CaseMassEmailLimiter`, `SSV_CaseMassUpdateEmail`) are **not included** — you must source them from the original org or rebuild them before these flows will run. Each must be exposed as `@InvocableMethod` with input/output parameter names matching exactly what's listed above (Apex invocable methods are matched by parameter name in Flow, so names must line up precisely).
2. Prerequisites in target org:
   - Custom Permission: `SSV_Run_Mass_Operations_on_Cases`.
   - Custom Metadata Type: `SSV_Mass_Email_Setting__mdt` with fields `Is_Active__c` (Checkbox) and `Daily_Email_Limit__c` (Number), and one active record (only used by the Mass Email flow).
   - Case Record Types matching the "Support" validation logic inside `SSV_CaseRecordtypeValidator` (not visible in this backup — check the source org for exactly which Record Types it treats as "support").
   - The custom fields referenced in Mass Update Case Fields: `SSV_Need__c`, `SSV_Outcome__c`, `SSV_Platform__c`, `SSV_Primary__c`, `SSV_Secondary__c`, `SSV_SurveyEnabled__c`, `SSV_NotificationEnabled__c`, and (implied) `SSV_RelatedLinearRecord__c`.
3. Wire each flow up as a List View Mass Action (or Quick Action) on the Case list view, mapping the selected record Ids to the flow's `ids` input variable.
4. Since actual updates happen in Apex (not native flow Update elements) and the confirmation screens explicitly say "batches," expect the target Apex actions to enqueue a Batch/Queueable job — plan accordingly if you need to know exactly when a mass action has finished (e.g. don't assume it's done the moment the flow screen finishes).

## Known Gaps / Gotchas

- No Apex included — this package alone will not function; treat it as the **flow/UI shell** for a mass-actions feature and pair it with the matching Apex actions from the source org.
- Every flow re-implements the same "check permission → check selection → check record type" pattern independently (copy-pasted across all three) — if you need to change the access-control logic, you'll need to update it in three places.
- The email flow's daily-limit check reads the "before" count, and separately gets an "after" count back from the same limiter call — worth confirming with the (missing) Apex exactly when the limiter increments the counter, to avoid a race condition if two agents send mass emails at the same time.
