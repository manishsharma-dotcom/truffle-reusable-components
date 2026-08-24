# Truffle Consulting — Reusable Components

Single source of truth for reusable Salesforce components, automations, and reference
implementations built across Truffle Consulting client engagements. Each component lives
in its own folder under `components/`, with its own README covering what it does,
dependencies, installation, and usage.

This repo consolidates what was previously tracked only as a flat list of Google Drive
folders. As each component is migrated in, its `Location` below moves from "Pending
migration" to a path inside this repo.

> **Status legend:** ✅ Migrated to this repo · 🕓 Not yet migrated · ⚠️ Needs cleanup/attention before reuse · ❓ Not yet documented (missing from source tracker)

---

## Contents

- [Case Management — Core](#case-management--core)
- [AI / Agentforce](#ai--agentforce)
- [Knowledge Management](#knowledge-management)
- [Portal / UI Building Blocks](#portal--ui-building-blocks)
- [Reference Backups](#reference-backups)
- [Platform Utilities](#platform-utilities)
- [Channel Setup](#channel-setup)
- [Adding a New Component](#adding-a-new-component)
- [Known Data Gaps](#known-data-gaps)

---

## Case Management — Core

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Case List View | Veeranch | Customer-facing "my cases" list/table — search, filter, sort, switch between own/company cases, "New Case" button. Admin version adds bulk close. | Pending migration | 🕓 |
| Case Detail Component | Veeranch | Customer-facing "view my case" screen — status, description, details, close/reopen within a grace window. | Pending migration | 🕓 |
| Case Create Component | Veeranch | Guided two-step "New Case" form — pick team/category, then a form that adjusts fields based on issue type. Supports attachments and collaborators. | Pending migration | 🕓 |
| Case Transfer Flow | Veeranch | Replaces standard "transfer to skill" (lost after enabling Enhanced Omni-Channel) — agents pick up to 5 skills, case auto-routes via Omni-Channel. | Pending migration | 🕓 |
| Case Record Triggered Flows | Veeranch | Three save-time automations: spam block/SLA setup on create, AI case-summary on Solved (Prompt Builder), and change-based notification routing + milestone sync. | Pending migration | 🕓 |
| Triggers Case | Veeranch | Core on-save automation — tracks time-in-status/owner for age reporting, sets priority from account-level priority program, flags paid-support-queue cases. | Pending migration | ⚠️ Trigger dispatch mechanism this relies on is **not included** in the backup — see guide |
| Validation Rules | Veeranch | 77 field-requirement/status-change guardrails on Case (e.g. required fields to close, supervisor-only close, no edits >7 days post-close). Reference library. | Pending migration | ⚠️ ~40% of rules already disabled in source org |
| Case Owner Reassign | Veeranch | Moves a case to a support queue when an "assign to queue" checkbox is set. | Pending migration | ⚠️ Inactive/retired in source org — kept as reference pattern only |
| Mass Case Actions | Veeranch | Bulk screens from a case list — mass comment, mass field update, mass email, with permission checks and a daily send limit. | Pending migration | 🕓 |
| Case Swarming | Veeranch | Salesforce Swarming — expert-suggestion swarm start, escalation/hand-off form, auto-reroute if unpicked, Slack channel close/archive on resolution. | Pending migration | 🕓 |
| Feed Item Triggers | Veeranch | Blocks new comments/replies on cases closed past a threshold, prompting a new case instead. | Pending migration | 🕓 |
| Waiting on Customer Notification Flow | Veeranch | Scheduled follow-up automation — 2 reminder emails + Chatter note, then auto-close if the customer doesn't respond. Configurable gap/templates per email; a companion flow reopens on customer reply. | Pending migration | 🕓 |
| Notification Flows | Veeranch | Inventory of 7 notification automations (creation email, new-comment alert, collaborator email, e-signature expiry reminder, satisfaction survey trigger, etc.). | Pending migration | ⚠️ Backup captured only the "pointer" record per flow, not the internal logic — inventory only, **not redeployable as-is** |
| Collaborators Component LWC | Veeranch | Lets portal customers add other people (coworker/manager) to a case for visibility without making them the main contact. | Pending migration | 🕓 |
| Spam Email Management | Veeranch | *No description or link recorded in source tracker.* | — | ❓ |

## AI / Agentforce

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Agentforce Sales Coach Agent on Custom Object | Veeranch | Reference implementation deploying Agentforce Sales Coach on a custom object (built for Rochester Electronics' PitchIQ program) instead of standard Opportunity. Includes 2 custom objects, 4 automation flows (enrollment, evaluation routing, grounding retrieval, feedback persistence), 5 prompt templates (multilingual, auto-fail criteria), and a New Builder agent script. Works around two platform gaps: Sales Coach doesn't natively persist feedback, and Coaching Scenarios support only one Prompt Template action — solved via a template-triggered capability flow chain. Also includes Enablement Program integration, Salesforce Files grounding library, OWD Private security with 3 access pathways, and edit-guard validation rules. Designed to extend to new programs/products with just a new prompt template + flow branch + Enablement Measure. | Pending migration | 🕓 |
| Agentforce SDR Implementation | Suraj / Abhishek / Pranika | *No description or link recorded in source tracker.* | — | ❓ |
| Case Resolution, Summary, Issue and Sentiment using AI | Suraj | *No description or link recorded in source tracker.* | — | ❓ |

## Knowledge Management

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Category Level Knowledge Articles Tree Browser | Veeranch | Works around Salesforce's Topic depth/hierarchy limits to show category-wise Knowledge Articles on a community with no cap on article count or sub-category depth. | Pending migration | 🕓 |
| Mindtouch Knowledge Migration | Veeranch | End-to-end structured Knowledge migration from the MindTouch platform into Salesforce. | Pending migration | 🕓 |

## Portal / UI Building Blocks

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Custom Toast Component | Veeranch | Two building blocks for Screen Flow pop-up banners: a working custom toast UI, and a wrapper meant to trigger Salesforce's native toast. | Pending migration | ⚠️ The native-toast wrapper has leftover debug code that forces a page redirect and throws an error on load — needs cleanup before reuse (see guide) |
| Custom File Upload on Community | Veeranch | Drag-and-drop file attachment widget for the portal — immediate upload, 2MB limit with error messaging, remove option, cleans up unused files on cancel. | Pending migration | 🕓 |

## Reference Backups

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Help Sites for Case Management | Veeranch | Full backup of two customer-facing help center sites (current self-service portal + an older legacy version) — reference/restore point and template for a full customer help site. | Pending migration | 🕓 |

## Platform Utilities

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| Content Version Auto Distribute | Veeranch | Automatically creates a shareable public link for every uploaded file, so it's instantly referenceable/embeddable outside Salesforce without manual admin action. | Pending migration | 🕓 |

## Channel Setup

| Name | Owner | Description | Location | Status |
|---|---|---|---|---|
| MIAW Logged in User Script and Omni Flow setup | Sandeep | Quick-start guide for Messaging for In-App and Web (MIAW) — embedded setup script captures the user ID and passes it to an Omni flow to route and update the messaging user's Contact Id. | Pending migration | 🕓 |

---

## Adding a New Component

1. Create a new folder under `components/` using a kebab-case slug of the component name (e.g. `components/case-list-view/`).
2. Add a `README.md` inside it covering: Owner, Type (LWC/Aura/Apex/Flow/etc.), Description, Features, Dependencies, Installation, and Usage.
3. Commit the component's source alongside its README.
4. Add a row to the appropriate category table above, and update its Status.
5. If a Confluence 1-pager exists for it, link it from the component's own README.

## Known Data Gaps

Carried over from the source tracker as-is, not filled in or guessed at:

- **Spam Email Management**, **Agentforce SDR Implementation**, and **Case Resolution, Summary, Issue and Sentiment using AI** have no description or Drive link recorded — need the owner(s) to supply these before migration.
- The source tracker's `Sr No.` column has three rows numbered `10` (Custom Toast Component, Triggers Case, Validation Rules) — not corrected here, just flagging in case that numbering is referenced elsewhere.
- Several components are explicitly **not redeployable as-is** per their own descriptions (Notification Flows is an inventory only; Triggers Case is missing its dispatch mechanism; Custom Toast Component's wrapper needs debug-code cleanup) — see the Status column above before assuming any ⚠️ item is drop-in ready.
