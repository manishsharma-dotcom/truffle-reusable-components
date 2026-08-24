# Waiting on Customer Automation — Technical Guide

**Category:** Case Management / Customer Nurture Automation
**Type:** 4 Flows (2 schedule triggers + 1 worker flow + 1 subflow reference) + 2 Apex classes
**Prefix:** `SSV_` — Weave org delivery

---

## Folder Contents

- **`SSV_WaitingOnCustomerDatesHelper.cls`** (+ Test) — invocable Apex, entry point `getDates(List<IdListWrapper> requests)`:
  - Reads reminder thresholds from Custom Metadata `SSV_ServiceSetting__mdt.getInstance('SSV_WaitingOnCustomerReminderHours')`, whose `SSV_WaitingOnCustomerHours__c` field holds a JSON blob deserialized into `{twentyFourHours, SeventyTwoHours, NinetySixHours}` — i.e. **the reminder cadence is admin-configurable via one JSON field**, not hardcoded.
  - For each Case passed in (with `waitingOnCustomerDate` and `waitingOnCustomerLastReminder`), computes **business hours elapsed** (Mon–Fri only, hour-by-hour loop) since the case entered Waiting-on-Customer, and decides which of three outcomes applies: `firstReminderDate` (~1 business day, no reminder sent yet), `thirdReminderDate` (~3 business days, already had one reminder), or `fourthClosureDate` (~4 business days — auto-close territory). Priority order checks closure first, then third reminder, then first reminder.
  - **Dependency gap:** the method returns `List<SSV_ReminderDatesOuput>` — this output wrapper class is **referenced but not included** in this backup. It must exist in the target org (a simple wrapper with `caseId`, `firstReminderDate`, `thirdReminderDate`, `fourthClosureDate` fields, matching how the calling flow consumes it).

- **`SSV_WaitingOnCustomerCaseDetailsInput.cls`** — `global` invocable-variable wrapper (`caseId`, `waitingOnCustomerDate`, `waitingOnCustomerLastReminder`) passed into the helper above.

- **`SSV_WaitingOnCustomerReminder_1.flow-meta.xml`** and **`SSV_WaitingOnCustomerReminder_2.flow-meta.xml`** — two nearly-identical **Scheduled Flows** (Daily), each doing nothing but calling the `SSV_WaitingOnCustomerReminderEmails` subflow. They run at two different times (`01:38 UTC` and `20:00 UTC`) — likely to cover the process twice within a business day rather than waiting a full 24 hours between checks.

- **`SSV_WaitingOnCustomerReminder.flow-meta.xml`** (954 lines) — appears to be an earlier/parallel version or a related scheduled entry point; review alongside the `_1`/`_2` pair to confirm which is the currently-intended trigger in your target org (the `.flowDefinition-meta.xml` files' `activeVersionNumber` will tell you which version is live).

- **`SSV_WaitingOnCustomerReminderEmails.flow-meta.xml`** (1879 lines) — the actual worker flow:
  1. Queries all Cases currently in Waiting-on-Customer status.
  2. Calls `SSV_WaitingOnCustomerDatesHelper` (Apex action) to bucket them into Day-1 / Day-3 / Day-4 groups.
  3. For **Day 1** and **Day 3** cases with a valid contact/recipient: sends a reminder email (`emailSimple` action) and posts a Chatter comment on the case, then stamps a "last reminder" tracking field so the next run doesn't re-fire.
  4. For **Day 4** cases: sets Status to Solved (auto-closes the case) rather than sending another reminder.
  5. Skips/logs cases with no valid contact name or recipient rather than failing the whole batch.

## How to Reuse / Deploy

1. Source or rebuild the missing `SSV_ReminderDatesOuput` Apex class before deploying `SSV_WaitingOnCustomerDatesHelper` — the flow will not resolve without it.
2. Create Custom Metadata Type `SSV_ServiceSetting__mdt` with a record `SSV_WaitingOnCustomerReminderHours` and a long-text field `SSV_WaitingOnCustomerHours__c` containing JSON like `{"twentyFourHours":24,"SeventyTwoHours":72,"NinetySixHours":96}`.
3. Confirm the Case fields this relies on exist: a "waiting on customer since" date/datetime field and a "last reminder sent" date/datetime field (exact API names aren't shown in this excerpt — check the full worker flow's variable mappings when you deploy).
4. Decide whether you need both `SSV_WaitingOnCustomerReminder_1` and `_2` (twice-daily) or just one daily run — deploy only the schedule(s) you want active to avoid double-processing (the worker flow does track "last reminder sent" to guard against duplicate sends, but confirm that guard covers your desired cadence).
5. Since Day 4 = auto-Solved, make sure your Case-closed notification automation (see Case Notification Flows / Case Record Triggered Flows packages) is deployed too, so customers get a "we've closed this due to no response" message rather than a silent status change.

## Known Gaps / Gotchas

- `SSV_ReminderDatesOuput` class is missing from this backup — required dependency.
- The naming jumps from "first reminder" straight to "third reminder" (no "second") — this appears to be intentional (based on the hour thresholds: ~24h/~72h/~96h map to roughly day 1/day 3/day 4), not a missing piece, but worth confirming with the business owner if you're extending this.
- Two nearly-duplicate scheduled flows (`_1` and `_2`) both calling the same subflow at different times — verify both are actually still wanted before redeploying, or you may end up running the batch twice a day unintentionally.
- Business-hours calculation is a manual hour-by-hour loop (`while (temp < endDT)`) rather than using Salesforce Business Hours object — it hardcodes Sat/Sun as non-business days and does not account for holidays or org-specific business hours.
