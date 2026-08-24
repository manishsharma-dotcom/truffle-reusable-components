# Case Validation Rules — Technical Guide

**Category:** Case Management / Data Quality & Status Governance
**Type:** 77 Validation Rules on the Case object (declarative metadata only — no Apex/Flow)
**Mixed prefixes:** `SSV_`/`Swat_` (Weave-specific, newer) alongside many un-prefixed rules referencing Jira-style ticket numbers (`SFM-####`) — this backup appears to span **two eras/teams of Case configuration** on the same org.

---

## Summary

77 Validation Rules total: **45 active, 32 inactive**. They fall into a few clear families:

### 1. Status-lockdown / governance rules (mostly `SSV_` prefixed, all active)
- `SSV_RestrictCaseUpdate` — blocks **any** field update on a Customer Support / Emergency case more than 7 days after it was closed (bypassed only for System Administrator profile), using a formula field `SSV_7DaysFromClose__c`.
- `SSV_OnlySupervisorUpdatetoClose` — only users with Custom Permission `SSV_PersonaServiceSupervisor` can set Status to Closed.
- `SSV_CantUpdateStatusOnceClosed` — once a case is Closed or Solved, only a Supervisor can change Status again (specifically checks `$User.ProfileName__c = 'Customer Support'` to scope who's restricted).
- `SSV_CannotUpdateCaseStatuswithoutContact`, `SSV_CannotUpdateCaseStatusToSolved`, `SSV_CannotMoveCaseToResolvedOrClosed` (inactive), `SSV_LinearFieldCannotBeUpdatedByTier1` (inactive) — additional status/field-locking guardrails layered on top of the above.
- `PreventStatusUpdateIfCaseCompleted` — on the `RMA` Record Type, blocks reverting Status away from Complete, with an unusual carve-out: **specific individuals by last name** (`$User.LastName = 'Dwiggins'`, `'Marcelo'`, `'Rasmussen'`, `'Jackson'`) are allowed to move it to specific follow-up statuses. See Known Gaps below — this is fragile.
- `Only_if_its_assigned_to_you` — likely restricts some action to the case's current owner (name is self-explanatory; check the rule body if reusing).

### 2. Required-field-when-picklist-selected rules (the largest family, mixed active/inactive)
A very repetitive pattern — "if Cancellation Subreason / Secondary Cancellation Subreason = X, then field Y must be populated": `RequireAcquisitionInfo`, `RequireBillingIssues`, `OtherBillingIssuesRequired`, `RequireOnboardingNotes`, `RequireSalesNotes`, `RequireSupportNotes`, `NonCompatiblePM_Required`, `Onboarding_Reason_Required`, `Sales_Reason_Required`, `Support_Reason_Required`, `RequireProductIssues`, `OtherProductIssueRequired` (inactive), `Desired_Features`, `OtherDesiredFeaturesRequired`, `RequireWhatFunctionality`, `RequireCompetitorPhonesOther`, `RequireCompetitorSoftwareOther`, `RequireNativePMS` (inactive), `RequireIntegrationType` (inactive), `RequireDetails`/`RequireSecondaryDetails` (inactive), `SubReasonsOtherRequired`, `SecondarySubReasonsOtherRequired` (inactive), `ISPRequired`/`Other_ISP_Required` (inactive), `Call_Quality_Issues`/`Other_Call_Quality_Issue` (inactive), `Software_Issues` (inactive), `Hardware_Options_Required` (inactive), `Closed_Won_Reasons_Required` (inactive), `UnfulfilledSalesPromiseDetailsRequired` (inactive), `ContactNameRequiredForOnboarding` (inactive), `Dissatisfaction_with_blank_Reason` (inactive), `Unclear_on_Billing` (inactive), `Failure_to_Resolve_Issues` (inactive), `Swat_Case_*Required` variants.
- This is clearly a **cancellation/onboarding intake wizard's worth of conditional-required-field rules**, all built the same way. If reusing this pattern for another org, treat the whole family as one reusable *template* (declarative rule shape: `AND(ISPICKVAL(subreason field, "X"), ISBLANK(detail field))`) rather than copying each rule individually.

### 3. Process/workflow guardrails
- `Contact_Required` — Contact is required for Installation and Network Audit cases.
- `PreventNetworkAudit`, `RequireNetworkAuditToClose`, `Nationwide_Network_Audit`, `Network_Followup_Needed` (inactive), `Installation_Network_Email_Sent` — network-audit-specific process gates for what looks like a hardware/onboarding install workflow.
- `Install_Complete_Verification`, `PhonesConfiguredComplete` (inactive), `PhonesInstalledCompleted` (inactive), `SoftwareInstalledComplete` (inactive), `Completed_Port_Date_Onboarding_Asset` (inactive) — install-completion checklist gates.
- `PreventSWATSubjectChanage`, `Swat_Case_Save_Summary`, `Swat_Case_Close_Competitor_Info`, `Swat_Case_Discount_Given`, `Swat_Case_Disc_Percent_and_Payments`, `Swat_Case_Acquisition_Info` (inactive), `Swat_Case_Non_Compatible_Integration` (inactive), `Swat_Case_Multi_Specific_Desired_Feature` (inactive) — a distinct "SWAT case" (likely a retention/save-the-sale case type) family of rules requiring close-out documentation before a cancellation case can be closed.
- `SWAT_Ready_To_Cancel_Validation`, `RMA_New_Process` (inactive), `WeaveInitiatedReturnRestriction`, `Close_case_3rd_Party_Install` (inactive), `Close_case_3rd_Party_Software_only` (inactive) — additional cancellation/RMA/return process gates.
- `SSV_ResolutionRequiredFields` — when Status = Resolution, requires Platform, Need, and Outcome fields populated.
- `SSV_SecondRequiredforBilling` — requires a Secondary value whenever Primary = Billing.
- `SSV_CannotAddRelatedLinearRecord` — restricts adding a "Related Linear Record" (Linear.app integration ticket link) under some condition.
- `Cases_Bugs`, `Cases_Bugs_Onboarding`, `Cases_Bugs_Sales` — restricts who can label a case as a "Bug" (must be Tech Support).
- `Enter_URL_for_Linear_Record`, `Analytics_Case_Needs_Training_Sent` (inactive), `Competitor_Phone_and_Competitor_Software` — assorted single-purpose field checks.

## How to Reuse / Deploy

1. **Don't deploy all 77 blindly.** 32 of these are inactive in the source org for a reason (superseded, no longer relevant to current process, or replaced by something else) — deploying them active in a new org could immediately start blocking saves in unexpected ways. Review the active/inactive breakdown above and only bring across what actually matches your target org's process.
2. Most of these rules are **tightly coupled to this org's specific picklist value set** (Cancellation Subreason, Secondary Cancellation Subreason, Contact Code Category, etc.) — treat the individually-listed rules as a **reference library of patterns** (conditional-required-field, status-lockdown, role-gated-close) rather than a drop-in package, unless you're working with the exact same picklist schema.
3. The status-lockdown family (`SSV_RestrictCaseUpdate`, `SSV_OnlySupervisorUpdatetoClose`, `SSV_CantUpdateStatusOnceClosed`) is the most broadly reusable — these depend only on generic building blocks (a formula field for days-since-close, a Custom Permission for supervisor status, Record Type checks) and are good candidates to port as-is into another support org that wants similar close-out governance.
4. Cross-check `SSV_OnlySupervisorUpdatetoClose`'s Custom Permission (`SSV_PersonaServiceSupervisor`) and `SSV_CantUpdateStatusOnceClosed`'s custom field (`$User.ProfileName__c` — note this reads a **custom field on User**, not the standard `$Profile.Name`) exist in your target org.

## Known Gaps / Gotchas

- **`PreventStatusUpdateIfCaseCompleted` hardcodes specific employees by last name** (`Dwiggins`, `Marcelo`, `Rasmussen`, `Jackson`) as an exception carve-out. This is fragile — if any of those people leave the company or change their name, the rule silently stops granting the intended exception with no error or warning. Recommend replacing this with a Permission Set or Public Group check before reusing in another org.
- Several rules reference a custom field `$User.ProfileName__c` rather than the standard `$Profile.Name` — this implies the org maintains a custom "shadow" field mirroring profile name on User, possibly for formula-field convenience. Confirm this field exists (and is kept in sync) before reusing rules that depend on it.
- Given the sheer number of conditional-required-field rules, consider whether a **Screen Flow / dynamic form with server-side validation** would be more maintainable than dozens of individual Validation Rules if you're building this from scratch for a new org — the existing rules work but are hard to keep track of collectively (this is a common trade-off, not a defect).
