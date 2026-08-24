# Case Transfer — Technical Guide

**Category:** Case Management / Omni-Channel Skills-Based Routing
**Type:** 2 Flows (1 active, 1 deprecated)
**Prefix:** `SSV_` — Weave org delivery

---

## Folder Contents

- **`SSV_CaseTransfer.flow-meta.xml`** (+ flowDefinition, **active version 6**) — the current, live version. A Screen Flow (likely launched as a Quick Action from the Case record page):
  1. Validates the input `recordId` is a Case Id (`StartsWith '500'`).
  2. Looks up the Case; blocks with an "Invalid Status" screen unless the Case's Status is in the custom label list `$Label.SSV_InProgressStatuses` (i.e. only in-progress cases can be transferred — not on-hold or resolved ones).
  3. Restricts to the 3 SSV Case Record Types (`SSV_CustomerSupport`, `SSV_CustomerSupportEmergencyAfterHours`, `SSV_OwnershipTransfer`).
  4. Looks up the Case's current `AgentWork` record (its live Omni-Channel work item) and its existing `AgentWorkSkill` assignments, to pre-populate the skill picker with what's already assigned.
  5. Shows a screen with a multi-select Skill lookup (max 5), pre-populated with existing skills.
  6. Loops through the selected skills and calls the standard Flow action `addSkillRequirements` to build a `SkillRequirement` list.
  7. Calls the standard Flow action `routeWork` with `routingType = SkillsBased`, targeting the **`Case`** Service Channel and a routing configuration named **"Case Transfer"** — this re-routes the case's work item through Omni-Channel to the next agent who matches the selected skills.
  8. Shows a confirmation screen.
  - Runs in `SystemModeWithoutSharing`.
  - **Contains hardcoded, org-specific record Ids:** `serviceChannelId = 0N9WH00000003fR0AQ` and `routingConfigId = 0K9WH0000000Sdp0AE`. These are Salesforce Ids from the source org and **will not exist in any other org** — this is the single most important thing to fix before reuse.

- **`SSVCaseTransfer.flow-meta.xml`** (+ flowDefinition) — an older flow, explicitly labeled `"Deprecated - SSV Case Transfer"` in its `FlowDefinition` and marked `<status>Obsolete</status>` in the flow itself. **Do not use this one** — it's kept here only as historical reference; the active logic is entirely in `SSV_CaseTransfer` above.

## How to Reuse / Deploy

1. **Only deploy `SSV_CaseTransfer`** — skip `SSVCaseTransfer` (Obsolete/Deprecated) unless you specifically need to compare old vs new logic.
2. Prerequisites in target org:
   - **Enhanced Omni-Channel with Skills-Based Routing enabled**, including a `ServiceChannel` record for Case and a Routing Configuration named "Case Transfer" (or update the flow to reference your own).
   - `Skill` records set up and assignable via `SkillRequirement`.
   - Custom Label `SSV_InProgressStatuses` containing the comma/list of Status values considered "in progress" for your Case Status picklist.
   - The 3 SSV Case Record Types, or update the `CheckValidRecordType` decision to match your own Record Type DeveloperNames.
3. **Replace both hardcoded Ids** (`serviceChannelId`, `routingConfigId`) with the actual Ids from your target org before activating — these are looked up once via `GetServiceChannel` for the channel Id but the **routing config Id is a literal string constant** in the `routeWork` action call, so it must be manually updated per org (Setup > Omni-Channel > Routing Configurations, copy the Id of your target config).
4. Expose the flow as a Quick Action on the Case Lightning Record Page (or Global Action) so agents can launch "Transfer" from a case they're working.

## Known Gaps / Gotchas

- The hardcoded `routingConfigId` (and to a lesser extent `serviceChannelId`, though that one is re-looked-up by DeveloperName `SSV_Case`) means this flow **will fail silently or route to the wrong place** if deployed to a new org without updating that value first — always re-point it during migration.
- No test coverage is included for Screen Flows (Flows generally don't need Apex-style test classes, but validate this flow manually in a sandbox with Omni-Channel test users before going live).
- The max-5-skills UI limit is a flow-runtime lookup component setting (`maxValues: 5.0`) — adjust if your routing needs more skill dimensions.
