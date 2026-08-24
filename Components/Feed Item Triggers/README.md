# Feed Item Trigger and Flow to Restrict Customers

**Category:** Experience Cloud / Case Management / Chatter
**Type:** 1 Record-Triggered Flow (FeedItem) + 1 Apex Trigger & Handler (FeedComment)
**Prefix:** `TF_EX_` — Truffle Consulting delivery

---

## Description

Prevents portal/community customers (`"Customer User"` and `"Customer User Admin"` profiles) from posting new Chatter feed items or comments on a Case that has been closed for more than 5 business days. This stops customers from reviving old, closed support tickets via Chatter instead of opening a new Case — the standard support workflow you want to enforce is "open a new Case," not "comment on a stale one."

Two automations work together to cover both entry points into Chatter on a Case:

1. **`TF_EX_FeedRestrictFlow`** (Flow, before-save on FeedItem) — blocks the initial post (e.g. a customer commenting on the case feed for the first time / creating a new feed item).
2. **`TF_EX_FeedCommentTrigger` + `TF_EX_FeedCommentTriggerHandler`** (Apex, before insert/update on FeedComment) — blocks replies to existing feed posts.

Both show the same user-facing error: *"You Cannot Add or Update Comment on Closed Case, Please Create a new Case."*

**Why it's reusable:** This is a drop-in guardrail for any Experience Cloud Case portal. The "5 business days" threshold, the allowed profiles, and the error message are all easy to adjust (see below) without redesigning the logic.

---

## Technical Guide

### Folder Contents

**`flows/TF_EX_FeedRestrictFlow.flow-meta.xml`** (+ flowDefinition, Active)
- Type: Record-Triggered (Before-Save) Flow on `FeedItem`.
- Entry filter (on Start element): only fires when `FeedItem.ParentId` starts with `'500'` (i.e. the Key Prefix for Case — this scopes the flow to Case feeds only, ignoring feed items on other objects) and `recordTriggerType = CreateAndUpdate`.
- Elements, in order:
  1. **GetProfile** — looks up Profile by `$Profile.Id` (running user's profile), returns Name.
  2. **Get_Case** — looks up the parent Case by `$Record.Parent:Case.Id`, returns Id, IsClosed, ClosedDate, Status.
  3. **Formula "Check5BusinessDate"** — a Boolean business-day calculator using the standard "WORKDAY difference" Salesforce formula pattern (based on days-since-1900-01-08, which was a Monday) to determine whether ≥5 business days have passed between `Get_Case.ClosedDate` and `TODAY()`.
  4. **Decision "Check_5_Days"** — rule `X5_Business_Days_Crossed` fires only if all of: `Check5BusinessDate = true` AND `Case.Status = 'Closed'` AND `Case.IsClosed = true` AND (`Profile.Name = 'Customer User Admin'` OR `Profile.Name = 'Customer User'`).
  5. **Custom Error "Error_on_Feed_Item_Creation"** — blocks the save with message: *"You cannot add comment on Closed Case, Please Create a new Case"*.

**`classes/TF_EX_FeedCommentTriggerHandler.cls`** (+ Test)
- `with sharing` class, single entry point `handle(List<FeedComment>)`.
- Mirrors the Flow's logic but for `FeedComment` (replies), because before-save Flows are not available on `FeedComment` the same way — this is why it's Apex here instead of a second Flow:
  1. Exits early unless running user's `Profile.Name` is `'Customer User'` or `'Customer User Admin'`.
  2. Bulk-collects `FeedItemId` from all new FeedComments, queries the parent FeedItems, and keeps only those whose `ParentId` starts with `'500'` (Case).
  3. Bulk-queries the related Cases (`IsClosed=true`, `ClosedDate!=null`).
  4. For each closed Case, computes business days between `ClosedDate` and today (custom `businessDaysBetween()` helper — Mon-Fri count, start date exclusive, end date inclusive); if >5, the Case is "blocked."
  5. For every FeedComment whose parent Case is blocked, calls `fc.addError(...)` with the same message text as the Flow.
- `businessDaysBetween` is `@TestVisible` for direct unit testing.

**`triggers/TF_EX_FeedCommentTrigger.trigger`**
- `trigger on FeedComment (before insert, before update)` — one line, delegates entirely to `TF_EX_FeedCommentTriggerHandler.handle()`.

**`classes/TF_EX_FeedCommentTriggerHandlerTest.cls`** — included test class for the handler.

### How to Reuse / Deploy

1. Deploy the Apex class + test class + trigger together (classes must exist before the trigger compiles against them).
2. Deploy the Flow (`flows/` folder) — it activates automatically since `flowDefinition-meta.xml` sets `activeVersionNumber=1` and the flow's own `<status>` is Active. If your deploy pipeline holds flows inactive by default, manually activate `TF_EX_FeedRestrictFlow` after deploy.
3. No custom fields or objects required — everything used (FeedItem, FeedComment, Case.Status/IsClosed/ClosedDate, Profile.Name) is standard.
4. Confirm the exact Profile API/Display Names in your target org. Both automations hardcode the literal strings `'Customer User'` and `'Customer User Admin'` — if your org's community profiles are named differently, update the Flow's decision rule conditions and the `ALLOWED_PROFILES` set in `TF_EX_FeedCommentTriggerHandler.cls`.
5. To change the grace period from 5 business days: edit the Flow's `Check5BusinessDate` formula's `>= 5` comparison, and the `BUSINESS_DAYS_LIMIT` constant in the handler class.
6. To scope to different objects than Case (key prefix `'500'`): change the Flow's Start element `ParentId` "StartsWith" filter value, and the `'500'` prefix check in `handle()`.

### Known Gaps / Gotchas

- The Flow's business-day formula and the Apex `businessDaysBetween()` method use slightly different counting conventions — both were tuned to produce a ">5 business days" cutoff correctly in testing, but if you change the threshold, verify both independently; they are not a shared/single source of truth for the day-counting logic.
- Both automations run an extra SOQL query per invocation to resolve the running user's Profile Name. This is normal and bulk-safe, but be aware if you already query Profile elsewhere in the same transaction, there's no de-duplication between the Flow and the Apex.
- Error message text is duplicated in two places (Flow's Custom Error element and the Apex `ERROR_MSG` constant) — keep both in sync if you ever change the wording.
