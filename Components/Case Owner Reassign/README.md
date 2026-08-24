# Case Owner Reassign — Technical Guide

**Category:** Case Management / Ownership Automation
**Type:** 1 Flow (marked Obsolete in the source org)
**Prefix:** `SSV_` — Weave org delivery

---

## Folder Contents

- **`SSV_CaseOwnerReassign.flow-meta.xml`** (+ flowDefinition) — a small **Record-Triggered Flow** (After Save, Update) on Case:
  - **Trigger condition:** fires when `Case.SSV_AssignToQueue__c` (a checkbox) is both `true` and has just changed (`IsChanged`).
  - **Action:** looks up the `Group` record where `DeveloperName = 'SSV_AgentQueueTier2'` and `Type = 'Queue'`, then sets the Case's `OwnerId` to that queue.
  - **Status: `<status>Obsolete</status>`** — this flow is explicitly deactivated in the source org. It is not currently running; it's included in this backup purely as a historical/reference pattern, not a live automation.

## How to Reuse / Deploy

1. **This is not an active process** — confirm with the business why it was deprecated before reviving it (it may have been superseded by the more general-purpose Case Transfer / Case Swarming routing flows in this same project, which use full Skills-Based Routing rather than a single fixed queue).
2. If you do want to reuse the pattern (simple "checkbox → reassign to a specific queue" automation):
   - Prerequisites: a checkbox field on Case (`SSV_AssignToQueue__c` or your own equivalent) and a Queue (`Group` with `Type = 'Queue'`) with a known Developer Name.
   - This is about as simple as record-triggered automation gets — a single `Get Records` + `Update Records` — good as a **starter template** if you need a "one click assigns to a fixed queue" pattern without the complexity of skills-based routing.
3. If reactivating in the target org, set `<status>Active</status>` in the flow metadata (or activate via Setup > Flows) after deployment — flows deploy in whatever status is set in the file, and Salesforce will not auto-activate an Obsolete flow.

## Known Gaps / Gotchas

- Deployed as-is, this flow will sit inactive and do nothing — that's expected, not a bug, given its Obsolete status. Don't be surprised if "it doesn't seem to work" after deployment; you need to explicitly activate it if you intend to use it.
- No validation for what happens if the Tier 2 queue lookup finds no matching Group (e.g. wrong DeveloperName in target org) — the Update element would attempt to set `OwnerId` to a null Id, which will error out the save. Add a null-check/decision if you revive this for a new org.
