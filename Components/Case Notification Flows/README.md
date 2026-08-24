# Case Notification Flows — Technical Guide

**Category:** Case Management / Notifications (Inventory Only)
**Type:** 7 `FlowDefinition` pointer files — **no actual flow logic included**
**Prefix:** `SSV_` — Weave org delivery

---

## ⚠️ Important: This Backup Contains Pointers, Not Logic

Every file in this package is a `.flowDefinition-meta.xml` — a small wrapper that only records which **version number** of a flow is currently active:

```xml
<FlowDefinition xmlns="http://soap.sforce.com/2006/04/metadata">
    <activeVersionNumber>18</activeVersionNumber>
</FlowDefinition>
```

**None of these have an accompanying `.flow-meta.xml` file**, which is where the actual screens, decisions, record operations, and business logic live. In other words, **this backup tells you these 7 flows exist and which version is active, but not what any of them actually do.** You cannot redeploy or restore functioning automation from this package alone.

## What's in the Inventory

| Flow Name | Active Version | Likely Purpose (from name only) |
|---|---|---|
| `SSV_CASE_TRG_AfterSave_EmailSendonCaseCreate` | 18 | Sends an email when a Case is created |
| `SSV_Case_Afte_Update_EmailNewCollaborators` | 2 | Emails newly-added Case collaborators |
| `SSV_Case_TRG_AfterUpdate_Notification` | 40 | Status-change/notification flow — **the real logic for this one is included in the separately-uploaded "Case Record Triggered Flows" package**, deploy from there instead |
| `SSV_EMAILMESSAGE_TRG_AfterSave_caseautomation` | 41 | Runs automation when an EmailMessage is saved against a Case (likely reopens/updates the case on customer reply) |
| `SSV_Notify_Case_Owner_on_New_Customer_Comment` | 4 | Notifies the Case owner when the customer adds a new comment |
| `SSV_QualtricsSurveyInitiationFlow` | 4 | Kicks off a Qualtrics customer-satisfaction survey (third-party integration) |
| `SSV_Send_Expired_Docusign_Notifications` | 3 | Notifies someone when a DocuSign envelope tied to a Case has expired (third-party integration) |

The high `activeVersionNumber` values (18, 40, 41) on three of these indicate they've been iterated on heavily over time — these are mature, well-used automations in the source org, which makes the missing logic more of a loss (a lot of accumulated business-rule refinement isn't captured here).

## How to Reuse / Deploy

1. **This package cannot be deployed as-is** — there is nothing to deploy. Treat it strictly as a checklist of flow names to go re-retrieve properly from the source org (a full metadata retrieve of Flows, not just Flow Definitions, will pull the `.flow-meta.xml` bodies).
2. `SSV_Case_TRG_AfterUpdate_Notification` is the one exception — its real content is available in the "Case Record Triggered Flows" package from this same project; use that instead of trying to reconstruct it from this pointer.
3. For the other 6, if you need the actual automation, re-export them from the source Salesforce org (Setup > Flows > select flow > View Details and Versions, or a proper `sf project retrieve` targeting the Flow metadata type) rather than relying on this backup.
4. The two third-party integration flows (Qualtrics, DocuSign) are worth flagging separately if reused elsewhere — they imply external API/connected-app dependencies (Qualtrics API credentials, DocuSign connector) that would need to be reconfigured in any new org regardless of whether the flow logic is recovered.

## Known Gaps / Gotchas

- No functional content in this package — this is the most important gap to communicate up front to anyone who might assume "I have a backup of these 7 notification flows."
- If this gap matters for your archival purposes, re-export these 7 flows properly before they're needed, rather than discovering the gap during an actual restore.
