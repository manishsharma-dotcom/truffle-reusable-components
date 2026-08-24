# Case Record Triggered Flows — Technical Guide

**Category:** Case Management / Core Record Automation
**Type:** 3 Record-Triggered Flows
**Prefix:** `SSV_` — Weave org delivery

---

## Folder Contents

### `SSV_CaseBeforeSaveRecordTriggered.flow-meta.xml`
**Before-Save, Create only**, on Case. Runs in this order:
1. Custom Permission bypass check (`skipProcesses`) — same "escape hatch" pattern seen elsewhere in this project.
2. If `SuppliedEmail` is populated and the Case's Record Type is Customer Support / Emergency / Ownership Transfer: looks up a custom object `SSV_SpamEmails__c` matching that email address.
   - If found **and** `SSV_Blacklisted__c = true` → **blocks case creation entirely** with a custom error ("Block new case").
   - If found **and not** blacklisted → **allows creation but marks it as spam**: reassigns Owner to a queue referenced by Custom Label `$Label.Spam_Case_Queue`, sets Status = Closed, and sets `ssv_MarkedCaseAsSpam__c = true`. (So "known spam sender, not yet blacklisted" still creates a case, but auto-closes it into a spam queue instead of blocking outright.)
3. Regardless of spam outcome, assigns an **Entitlement** to the Case based on Record Type: looks up the `Entitlement` named `SSV_CustomerSupport` or `SSV_CustomerEmergencySupport` and sets `EntitlementId` — this is what starts SLA/Milestone tracking for the case (ties into `SSV_Case_TRG_AfterUpdate_Notification`'s Milestone-update logic below).
- Because this is a **before-save** flow, all field changes happen without a second database write (efficient, standard best practice for this kind of "prepare the record before it's inserted" logic).

### `SSV_CaseRecordTriggeredCaseSummaryPrompt.flow-meta.xml`
**After-Save, Update**, on Case, filtered to `SSV_RecordTypeName__c = 'SSV_CustomerSupport'` AND `Status = 'Solved'` (only fires when a case is freshly marked Solved):
- Calls a **Prompt Builder / Einstein Generative AI** action (`generatePromptResponse`, prompt template `Case_Summary_Field`) with the whole Case record as input, and writes the AI-generated response into `SSV_EinsteinCaseSummary__c`.
- **This requires Prompt Builder (Salesforce's Generative AI / Data Cloud-adjacent feature) enabled and licensed in the target org**, plus the specific Prompt Template `Case_Summary_Field` configured there — this template itself is Setup configuration, not something captured in this metadata backup, and must be rebuilt separately (Setup > Prompt Builder).

### `SSV_Case_TRG_AfterUpdate_Notification.flow-meta.xml`
**After-Save, Update**, on Case — the largest of the three (603 lines). Handles several distinct concerns in one flow:
- **Status-change email notifications**, one Email Alert per target status: In Progress, Reopened, Solved, Waiting On Customer, plus a "Case Closed" notification to the contact + collaborators, and a Chatter "Feed Post added" notification (email alert developer names follow the pattern `Case.SSV_Case_StatusUpdateNotification<Status>`).
- **Emergency SLA violation alert** — a decision (`Is_Emergency_SLA_Violated`) that, when true, fires an `emailSimple` action labeled "Emergency SLA Violation Slack Msg" (the label says Slack but the action type is a plain email — likely a labeling leftover from when this may have sent to a Slack-integrated email address, or simply a naming inconsistency; verify the actual recipient/behavior before assuming it posts to Slack).
- **Case Milestone syncing** — a `Update_Related_Case_Milestones` record-update element that sets `IsCompleted`/`CompletionDate` on related Milestone records, tying back to the Entitlement assigned in the before-save flow above.
- Same `skipProcess` bypass pattern as the before-save flow.
- **Note:** this exact flow (same name) also appears as a **pointer-only** `flowDefinition-meta.xml` (no logic) inside the separately-uploaded **Case Notification Flows** package — this package is where the real, deployable version lives.

## How to Reuse / Deploy

1. Deploy `SSV_CaseBeforeSaveRecordTriggered` first (it sets up Entitlements that Milestone logic in the after-update flow depends on).
2. Prerequisites: `SSV_SpamEmails__c` custom object (with `ssv_Emails__c`, `ssv_Blacklisted__c`), Custom Label `Spam_Case_Queue`, Case field `ssv_MarkedCaseAsSpam__c`, `Entitlement` records named `SSV_CustomerSupport`/`SSV_CustomerEmergencySupport`, Entitlement Process + Milestones configured against those Entitlements.
3. For the Case Summary Prompt flow: enable/configure Prompt Builder in the target org, recreate the `Case_Summary_Field` prompt template (define its inputs/output to match what this flow expects — a Case-shaped input, and `promptResponse` as the text output it writes to `SSV_EinsteinCaseSummary__c`), and confirm your org's Data Cloud / Einstein Generative AI licensing supports this.
4. For the After-Update Notification flow: recreate the 6 Email Alerts (`Case.SSV_Case_StatusUpdateNotification*`, `Case.SSV_Case_FeedPostNotification`, `Case.SSV_Case_StatusClosedNotification`) as standard Salesforce Email Alerts pointing at the templates you want, and confirm what "Emergency SLA Violation" actually notifies (email vs. Slack) before relying on the label.
5. Custom Permission `skipProcesses` should exist if you want the bypass escape hatch used consistently across this project's automations (also seen in the Waiting on Customer and Case Validation packages' conceptual siblings).

## Known Gaps / Gotchas

- The Prompt Builder integration is the most "new tech" piece here — confirm licensing/availability before promising this feature works, since Prompt Builder isn't available in every Salesforce edition.
- "Emergency SLA Violation Slack Msg" label vs. `emailSimple` action type mismatch — don't assume this posts to Slack without checking the actual recipient configuration.
- This same `SSV_Case_TRG_AfterUpdate_Notification` flow is duplicated (as a pointer-only reference) in the Case Notification Flows package — deploy the real version from here, and treat that other package's reference to it as informational only.
