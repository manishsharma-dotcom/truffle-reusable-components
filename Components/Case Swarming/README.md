# Case Swarming — Technical Guide

**Category:** Case Management / Collaborative Case Resolution (Service Cloud "Swarming" + Slack)
**Type:** 7 Flows
**Prefix:** `SSV_` — Weave org delivery

---

## Important Context

This package is a **customization layer on top of Salesforce's built-in "Case Swarming" feature** (Service Cloud's Slack-integrated collaboration tool for pulling experts together on hard cases), not a fully custom-built system. The flows use Salesforce-provided Flow action types — `slackCreateChannel`, `slackPostMessage`, `slackJoinChannel`, `slackInviteUsersToChannel`, `slackPinMessage`, `slackGetConversationInfo`, `getAvailableSwarmObject`, `swarmingCollaborationToolSettings`, `addSkillRequirements`, `routeWork` — which only exist if **Swarming and the Slack for Salesforce integration are enabled** in the target org. The standard `Swarm`, `SwarmMember`, and `CollaborationRoom` objects that ship with that feature are used throughout.

## Folder Contents

- **`SSV_BeginSwarming.flow-meta.xml`** (2,420 lines — by far the largest) — the main "start a swarm" flow:
  - Checks Collaboration Tool Settings (`swarmingCollaborationToolSettings`) to determine if Slack is configured, and whether swarming happens via a **dedicated channel** or a **thread** within an existing channel.
  - Checks whether Skills-Based Routing is enabled; if so, loops through selected Skills to help find the right experts.
  - Creates the Slack channel (`slackCreateChannel`) or sets up a thread, invites the swarm owner, joins/pins messages as needed, and creates/updates a `Swarm` record with the resulting `CollaborationRoomId`/`CollaborationUrl`.
  - Creates a `SwarmMember` record for the swarm owner.
  - Handles "swarm already exists for this record" (shows a multi-swarm warning) and "channel already exists" cases rather than blindly creating duplicates.

- **`SSV_SwarmMemberSelectionProcess.flow-meta.xml`** — subflow used to find and add experts to a swarm ("Add To Swarm With Expert Finder"), looping over selected Skills to assign them.

- **`SSV_CaseEscalationDetail.flow-meta.xml`** — a screen/data flow (references `Case`, `SwarmMember`) showing "Case Escalation Detail" — likely a display panel used within the swarm UI to show the underlying Case context to participants, branching by Case Record Type ("Customer Support" path).

- **`SSV_CaseEscalationDetailsForm.flow-meta.xml`** — a distinct escalation **form** flow (not just a display), used when escalating a case to Tier 2 support: assigns a Tier 2 Queue owner, sets Priority based on Case Source (Chat/Email/Web/Voice), and writes an escalation description onto the Case. Has a "Called from Escalate Tier 2" branch, suggesting it's invoked as a subflow from a broader escalation action rather than launched directly.

- **`SSV_CaseSwarmReRouting.flow-meta.xml`** — **Record-Triggered (After Save, Update)** on Case, with a "Run After 2 Minutes" scheduled path. If a case tied to a `SwarmMember` needs re-routing, this clones a `PendingServiceRouting` (PSR) record with the required Skills and re-queues the work in Omni-Channel — effectively "if nobody picked up the swarmed work in time, put it back in the routing queue." Deletes the triggering record after processing (`Delete_Triggering_Record`), suggesting it works off a helper/queue object rather than the Case directly.

- **`SSV_CloseSelectedSwarm.flow-meta.xml`** — closes out a swarm: updates `Swarm` and `SwarmMember` status to closed, and — if using Slack — posts a closing message to the channel/thread, unpins the original pinned message, updates it to show a "Reopen" button, and optionally **archives the Slack channel** if the closer checked an "archive" option. Checks whether Slack integration is enabled before attempting any Slack-specific steps (so it degrades gracefully if Slack isn't configured).

- **`SSV_FinishSwarming.flow-meta.xml`** — the user-facing wrapper for closing a swarm: lets the user select which open Swarm to finish (in case there are multiple), confirms/cancels, and calls `SSV_CloseSelectedSwarm` as a subflow. Includes fault handling with a dedicated Failure screen.

## How to Reuse / Deploy

1. **Prerequisite: enable Case Swarming and the Slack for Salesforce (or Slack for Service Cloud) integration in the target org first** — the Flow actions this package relies on (`slack*`, `getAvailableSwarmObject`, `swarmingCollaborationToolSettings`) are provided by that feature and won't be available otherwise. This is a licensing/setup prerequisite, not something these flows create.
2. Deploy order: `SSV_SwarmMemberSelectionProcess` and `SSV_CaseEscalationDetail`/`SSV_CaseEscalationDetailsForm` first (used as subflows), then `SSV_BeginSwarming` (which references the member-selection subflow), then `SSV_CloseSelectedSwarm` and `SSV_FinishSwarming` (which depends on Close), then `SSV_CaseSwarmReRouting` (the automated re-routing safety net).
3. Confirm the standard `Swarm`/`SwarmMember`/`CollaborationRoom` objects and their fields are available in your org's Swarming feature version — Salesforce has iterated on this feature, so field names/actions can shift between releases; verify against your org's actual Swarming setup rather than assuming an exact match.
4. `SSV_CaseSwarmReRouting`'s "2 minutes" wait and PSR-cloning approach is fairly advanced Omni-Channel usage — test this specifically in a sandbox with real routing configs before trusting it in production, since silently mis-routing swarmed work could leave cases stuck.
5. This whole feature set is best treated as one connected unit (all 7 flows together) rather than picking individual pieces — they call each other as subflows extensively.

## Known Gaps / Gotchas

- Because this is built on a Salesforce product feature rather than fully custom code, its behavior is partly governed by Setup configuration (Swarming settings, Slack app installation/permissions) that **isn't captured in this metadata backup at all** — deploying the flows without also redoing that Setup configuration will not produce a working feature.
- The Skills-Based Routing branches assume that feature is already enabled and configured (Skills, Service Channels, Routing Configurations) — same category of external dependency as the separate Case Transfer package in this project.
- `SSV_CaseSwarmReRouting` deletes its own triggering record after running — make sure you understand what object that is (a PendingServiceRouting-adjacent helper, not the Case) before assuming "delete" here is safe to reuse elsewhere.
