# Agentforce Sales Coach on a Custom Object
## Technical Implementation Guide

> **Package:** `Sales_Coach_Agent_on_Custom_Object_Setup`
> **Reference Implementation:** PitchIQ Sales Coach — Rochester Electronics
> **Prepared by:** Truffle Consulting
> **Platform:** Salesforce — Agentforce / Sales Cloud / Enablement

---

## Overview

This guide documents how to implement Agentforce Sales Coach on a **custom Salesforce object** instead of the standard Opportunity record page. The reference implementation (PitchIQ) is a pitch evaluation and coaching system embedded into Sales Enablement programs, where field sellers practice product pitches and receive AI-driven Pass/Fail feedback without any Opportunity or Account context.

This package is intended for architects and developers who need to:
- Deploy Sales Coach against a custom object
- Persist coaching feedback to a custom record (Agentforce does not do this natively)
- Integrate coaching milestones into an Enablement Program gate
- Support multilingual evaluation and feedback
- Apply automatic fail criteria beyond standard topic evaluation

---

## Table of Contents

1. [Key Architectural Decisions](#1-key-architectural-decisions)
2. [Package Contents](#2-package-contents)
3. [Data Model](#3-data-model)
4. [Security and Sharing](#4-security-and-sharing)
5. [Agentforce Agent](#5-agentforce-agent)
6. [Prompt Templates](#6-prompt-templates)
7. [Flows](#7-flows)
8. [Enablement Program Integration](#8-enablement-program-integration)
9. [Grounding — Salesforce Files Library](#9-grounding--salesforce-files-library)
10. [Pre-Deployment Steps](#10-pre-deployment-steps)
11. [Deployment Steps](#11-deployment-steps)
12. [Post-Deployment Steps](#12-post-deployment-steps)
13. [Adapting This Package for a New Use Case](#13-adapting-this-package-for-a-new-use-case)
14. [Known Issues and Platform Constraints](#14-known-issues-and-platform-constraints)
15. [Component Reference](#15-component-reference)

---

## 1. Key Architectural Decisions

Understanding these decisions is essential before adapting this package. Each one exists to solve a real platform constraint.

### 1.1 Custom Object Instead of Opportunity

Agentforce Sales Coach is designed out-of-the-box to sit on the Opportunity record page. In this implementation the coach lives on a custom object (`PitchIQ_Assignment__c`) which has no Opportunity or Account context. The Coaching Scenario is configured with `PitchIQ_Assignment__c` as the Salesforce Object — this is the key change that makes the agent work on a non-standard object.

### 1.2 Feedback Is Not Natively Persisted

Agentforce Sales Coach does not save coaching feedback anywhere automatically. The seller sees it on screen and it disappears. This package solves that using a **two-track architecture**:

- **Track 1 — UI:** The Coaching Scenario calls the Wrapper Prompt Template which displays feedback to the seller
- **Track 2 — Backend:** The same Wrapper Template triggers a capability Flow chain which calls a JSON extraction prompt, parses Result and Fail Reason, creates a `PitchIQ_Attempt__c` record, and updates the parent Assignment Status

This works because a Prompt Template can call a Template-Triggered Prompt Flow (capability flow) as part of its execution, even when invoked from a Coaching Scenario.

### 1.3 Single Coaching Scenario for Multiple Programs

Coaching Scenarios cannot dynamically route to different subagents based on record field values. This package uses a single Coaching Scenario (object: `PitchIQ_Assignment__c`) with a single subagent. Program-level routing (TLS360 vs ADI RF) happens inside the Flow chain based on the `Enablement_Program__c` text field on the Assignment record — not at the agent/scenario level.

### 1.4 Enablement Program Field Is Plain Text

The `Enablement_Program__c` field on `PitchIQ_Assignment__c` is a plain **Text** field storing the program short name ("TLS360" or "ADI RF"). It is not a Lookup to any program object. This drives Flow routing, Enablement Measure filtering, and grounding file scoping without relationship complexity. When extending to new programs simply store the new program's short name.

### 1.5 OWD Private with Three Access Pathways

The `PitchIQ_Assignment__c` object uses OWD = Private. Three distinct mechanisms grant access depending on how enrollment happens:

| Scenario | Mechanism |
|---|---|
| Seller self-enrolls | Seller is record owner — PitchIQ Access PS grants CRE |
| Supervisor assigns seller | Flow creates `PitchIQ_Assignment__Share` for the AssigneeId |
| Agent needs to read record | Criteria sharing rule shares all records with Agent Public Group |

### 1.6 Program Qualification — Dual Check

The enrollment flow checks two things before creating a `PitchIQ_Assignment__c` record:
1. The Enablement Program name contains "TLS360" or "ADI RF"
2. The Enablement Program has at least one section whose name contains "PitchIQ"

This prevents PitchIQ Assignments from being created for same-named programs (e.g. Inside Sales programs) that do not include the PitchIQ coaching process.

### 1.7 New Builder Agent Script

This implementation uses the **New Builder** (AiAuthoringBundle) agent script format. The agent is deployed as a `.agent` file. Old Builder agents cannot chain a Flow action after a Prompt Template action deterministically — New Builder's `after_reasoning` block is required for reliable post-evaluation record creation. See the Known Issues section for more detail.

### 1.8 Automatic Fail Criteria (STEP 0)

Beyond standard topic coverage evaluation, both evaluation prompt templates implement a **STEP 0 Automatic Fail Check** that fires before topic evaluation. If any disqualifying statement is detected — regardless of topic coverage — the result is FAIL immediately. This is implemented entirely in the prompt template instructions, not in Salesforce automation.

---

## 2. Package Contents

```
Sales Coach Agent on Custom Object Setup/
│
├── aiAuthoringBundles/
│   └── PitchIQ_Agent_4/              ← Current active agent version
│       ├── PitchIQ_Agent_4.agent     ← Agent script (New Builder format)
│       └── PitchIQ_Agent_4.bundle-meta.xml
│
├── objects/
│   ├── PitchIQ_Assignment__c/        ← Parent custom object
│   │   ├── fields/
│   │   │   ├── Enablement_Program__c   Text(255) — program routing key
│   │   │   ├── LatestFeedback__c       Long Text Area — UI feedback
│   │   │   ├── NumberOfAttempts__c     Roll-Up Summary COUNT
│   │   │   ├── Seller_User__c          Lookup(User) — Measure attribution
│   │   │   └── Status__c               Picklist — New/Attempted/Passed
│   │   ├── listViews/
│   │   │   └── My_PitchIQ_Assignments  Filtered to Current User, Status != Passed
│   │   └── validationRules/
│   │       └── Prevent_Edit_Without_Admin_Permission
│   │
│   └── PitchIQ_Attempt__c/           ← Child custom object (Master-Detail)
│       ├── fields/
│       │   ├── Fail_Reason__c          Picklist
│       │   ├── Feedback__c             Long Text Area — backend feedback
│       │   ├── PitchIQ_Assignment__c   Master-Detail
│       │   └── Result__c               Picklist — Pass/Fail
│       └── validationRules/
│           └── Prevent_Edit_Without_Admin_Permission
│
├── flows/
│   ├── PitchIQ_Assignment_Auto_Creation.flow-meta.xml
│   ├── PitchIQ_Attempt_Create.flow-meta.xml
│   ├── PitchIQ_Prompt_Execution_and_Feedback.flow-meta.xml
│   └── Pitch_IQ_Files_Reader.flow-meta.xml
│
├── genAiPromptTemplates/
│   ├── Pitch_Evaluation_Wrapper_Template    Sales Coaching type — entry point
│   ├── PitchIQ_TLS360_Pitch_Feedback        Sales Coaching type — TLS360 eval
│   ├── PitchIQ_ADI_RF_Pitch_Feedback        Sales Coaching type — ADI RF eval
│   ├── PitchIQ_Feedback_Analysis            Flex type — JSON extraction
│   └── PitchIQ_File_Reader                  Flex type — grounding file reader
│
├── enablementMeasureDefinitions/
│   ├── PitchIQ_TLS360_Program_Pass          Two-filter measure for TLS360
│   └── PitchIQ_ADI_RF_Program               Two-filter measure for ADI RF
│
├── sharingRules/
│   └── PitchIQ_Assignment__c.sharingRules-meta.xml
│
├── lightningTypes/
│   └── FeedbackAnalysis/schema.json        Structured output type for JSON extraction
│
└── tabs/
    ├── PitchIQ_Assignment__c.tab-meta.xml
    └── PitchIQ_Attempt__c.tab-meta.xml
```

> **Note:** The `bots/` folder in the package contains bot versions from iterative development. The active agent is `aiAuthoringBundles/PitchIQ_Agent_4`. The `CMS Content` folder and `enablementProgramDefinitions/` are org-specific and should not be deployed to a target org.

---

## 3. Data Model

### 3.1 PitchIQ Assignment (`PitchIQ_Assignment__c`)

Parent object. One record per seller per Enablement Program. Tracks overall pitch status.

| Field | API Name | Type | Notes |
|---|---|---|---|
| PitchIQ Assignment Name | Name | AutoNumber | Format: PIQ-{0000} |
| Seller User | Seller_User__c | Lookup(User) | Used as User Field in Enablement Measures |
| Enablement Program | Enablement_Program__c | Text(255) | Stores program short name — plain text, NOT a lookup |
| Status | Status__c | Picklist | New / Attempted / Passed |
| Number Of Attempts | NumberOfAttempts__c | Roll-Up Summary | COUNT of child Attempt records |
| Latest Feedback | LatestFeedback__c | Long Text Area | UI-facing feedback — must be Long Text Area NOT Rich Text |

**OWD:** Private

> **Critical:** The Feedback field MUST be Long Text Area, not Rich Text Area. Rich Text Area causes HTML entity encoding (`&quot;`, `&#39;`) in stored feedback text.

### 3.2 PitchIQ Attempt (`PitchIQ_Attempt__c`)

Child object (Master-Detail). One record per pitch submission. Sharing is Controlled by Parent.

| Field | API Name | Type | Notes |
|---|---|---|---|
| PitchIQ Attempt Name | Name | AutoNumber | Format: PIQ Attempt-{0000} |
| PitchIQ Assignment | PitchIQ_Assignment__c | Master-Detail | Parent relationship |
| Result | Result__c | Picklist | Pass / Fail |
| Fail Reason | Fail_Reason__c | Picklist | Missing Key Topic / Disallowed Claim Made / None |
| Feedback | Feedback__c | Long Text Area | Backend stored feedback — plain text |

**OWD:** Controlled by Parent

### 3.3 FeedbackAnalysis Lightning Type

Located in `lightningTypes/FeedbackAnalysis/schema.json`. This custom structured output type defines the JSON schema used by the `PitchIQ_Feedback_Analysis` prompt template to return structured data:

```json
{
  "Result": "Pass or Fail",
  "FailureReason": "Missing Key Topic | Disallowed Claim Made | None"
}
```

The `PitchIQ_Attempt_Create` flow reads these properties to populate the `Result__c` and `Fail_Reason__c` fields on the Attempt record.

---

## 4. Security and Sharing

### 4.1 Permission Sets (create manually — not in package)

| Permission Set | Assign To | What It Grants |
|---|---|---|
| PitchIQ Access | All sellers enrolled in programs | CRE on PitchIQ_Assignment__c and PitchIQ_Attempt__c |
| PitchIQ Agent Access | Agent user only | CRE on both objects + Opportunity Read |
| PitchIQAdminAccess | Admins and managers | Contains `PitchIQAdminAccess` custom permission — bypasses validation rules |

### 4.2 Sharing Rule (included in package)

**Rule:** `ShareRecordsWithPitchIQSalesCoachAgent`
- Shared To: Public Group `PitchIQ_Agent_Group`
- Criteria: Name not equal to (blank) — matches all records
- Include Records Owned By All: true
- Access Level: Edit

The agent user must be added to `PitchIQ_Agent_Group` in post-deployment.

### 4.3 Validation Rules (included in package)

Both `PitchIQ_Assignment__c` and `PitchIQ_Attempt__c` have identical validation rules:

```
AND(
    NOT(ISNEW()),
    NOT($Permission.PitchIQAdminAccess)
)
```

**Error message:** "You do not have permission to edit PitchIQ Assignment records. Contact your Manager if changes are required."

> **Important:** The agent user must have the `PitchIQAdminAccess` permission set assigned, otherwise the Flow that updates `Status__c` on the Assignment record will fail when the validation rule fires.

### 4.4 Enrollment Flow — Share Record Creation

When a supervisor assigns a seller (rather than the seller self-enrolling), the auto-creation Flow detects the mismatch between `$User.Id` and `AssigneeId` and creates a `PitchIQ_Assignment__Share` record:

- `AccessLevel`: Edit
- `RowCause`: Manual
- `ParentId`: new Assignment Id
- `UserOrGroupId`: AssigneeId

---

## 5. Agentforce Agent

### 5.1 Agent Configuration

The active agent script is `PitchIQ_Agent_4.agent`.

| Setting | Value |
|---|---|
| Agent Label | PitchIQ Agent |
| Developer Name | PitchIQ_Agent |
| Agent Type | SalesEinsteinCoach |
| Template | sales_einstein_coach_copilot__Sales_Coach_Agent |
| Default Locale | en_US |

> **Note:** The `additional_locales` in the current script only includes `en_GB`. To enable Spanish, Japanese, and Chinese Simplified update the language settings in Agent Builder after deployment — this is done in the UI, not in the script.

### 5.2 Agent Script Structure

```yaml
system:
  instructions: [coach persona]

config:
  agent_type: SalesEinsteinCoach
  agent_template: sales_einstein_coach_copilot__Sales_Coach_Agent

language:
  default_locale: en_US

start_agent topic_selector:
  reasoning:
    actions:
      go_to_PitchIQ: transition to @subagent.PitchIQAssignment

subagent PitchIQAssignment:
  label: "PitchIQ Assignment Topic"
  reasoning:
    instructions: receive transcript, call Run Wrapper Template
    actions:
      Run_Wrapper_Template: @actions.Run_Wrapper_Template
  actions:
    Run_Wrapper_Template:
      target: generatePromptResponse://Pitch_Evaluation_Wrapper_Template
      inputs:
        Input:Transcript (required)
        Input:RelatedObject (required — recordInfoType)
        outputLanguage (optional)
        isPreviewOnly (optional)

access:
  default_agent_user: pitchiq_agent@[org].ext
```

### 5.3 Coaching Scenario (create manually in Agent Builder)

| Field | Value |
|---|---|
| Name | PitchIQ Assignment |
| Salesforce Object | PitchIQ_Assignment__c |
| Scenario Type | StandAndDeliver (Present) |
| Feedback Topic | PitchIQ Assignment Topic |
| Agent Action | Run Wrapper Template |
| Description | Select this scenario if you are launching your pitch from a PitchIQ Assignment record. |
| User Guidance | Review the key topics that should be included in your certification pitch before recording your assessment. |

> **Platform constraint:** Coaching Scenarios page is only accessible when the agent retains at least the three standard OOTB subagents (OpportunityCoaching, NegotiationRolePlay, ProposalRolePlay). The deployment sequence in Section 12 accounts for this.

### 5.4 Standard Subagents

The agent retains the three standard subagents to maintain Coaching Scenarios page access. They are not used for PitchIQ functionality but must remain in the script. Do not remove them.

---

## 6. Prompt Templates

### 6.1 Template Inventory

| Template | API Name | Type | Purpose |
|---|---|---|---|
| Pitch Evaluation Wrapper Template | Pitch_Evaluation_Wrapper_Template | Sales Coaching | Entry point called by Coaching Scenario. Calls execution flow for program routing. Returns feedback to UI. |
| PitchIQ TLS360 Pitch Feedback | PitchIQ_TLS360_Pitch_Feedback | Sales Coaching | Evaluates TLS360 pitch against 6 key topics with STEP 0 auto-fail check |
| PitchIQ ADI RF Pitch Feedback | PitchIQ_ADI_RF_Pitch_Feedback | Sales Coaching | Evaluates ADI RF pitch against 7 key topics with STEP 0 auto-fail check |
| PitchIQ Feedback Analysis | PitchIQ_Feedback_Analysis | Flex | Extracts Result and FailureReason as structured JSON from feedback text |
| PitchIQ File Reader | PitchIQ_File_Reader | Flex | Reads a ContentDocument record and returns its text content |

### 6.2 Evaluation Prompt Structure (TLS360 and ADI RF)

Both evaluation templates follow a four-step reasoning structure:

**STEP 0 — Automatic Fail Check (fires first, internal)**
Scans transcript for 7 disqualifying statement categories. If any are found:
- Result is FAIL regardless of topic coverage
- Topic count is suppressed from output
- Exact disqualifying phrase is quoted in feedback

Automatic fail categories:
1. Confidential information disclosure (customer purchasing history, internal investment strategy)
2. Misrepresentation of Rochester's role as original manufacturer (excludes licensed manufacturing context)
3. Discouraging a purchase order
4. Guaranteeing future supply or availability (excludes current quality claims and conditional PO-linked language)
5. Claiming TLS360 eliminates all lifecycle risk
6. Claiming permanent or indefinite availability
7. Negative supplier or competitor positioning

**STEP 1 — Topic Evaluation (internal)**
Each topic is evaluated as COVERED or NOT COVERED against grounding file content. Evidence can appear across multiple sentences. Transcription artifacts do not cause topic failures.

**STEP 2 — Pass/Fail Determination**
PASS = all topics COVERED. FAIL = any single topic NOT COVERED.

**STEP 3 — Write Feedback**
Output language matches transcript language dynamically. Headers, topic counts, and result labels are all translated. PASS and FAIL remain in English capitals as system values parsed by the backend.

### 6.3 Abbreviation Tolerance

Both evaluation templates include a tolerance block for speech-to-text transcription variants:

```
BOM, SKU, ADI RF, TLS360 (and variants: TS 360, TS360, TLS 360 etc),
Through Life Support 360 (and variants), JEDEC (and variants: JIDEC, Jedeck etc),
EOL / End of Life, HMC
```

If a garbled word phonetically resembles one of these terms it is interpreted as the correct term for evaluation purposes. Garbled terms are not flagged as errors in feedback output.

### 6.4 Wrapper Template Flow

The Wrapper Template calls two things:

1. `PitchIQ_Prompt_Execution_and_Feedback` flow — routes to the correct evaluation prompt based on `Enablement_Program__c`, returns feedback text to display in UI
2. `PitchIQ_Attempt_Create` flow — triggered after evaluation, creates the backend Attempt record

This dual-call pattern is the mechanism that makes the two-track architecture work within the Coaching Scenario single-action constraint.

---

## 7. Flows

### 7.1 PitchIQ Assignment Auto-Creation

**Type:** Record-Triggered | **Object:** LearningItemAssignment | **Trigger:** Created | **Run:** Asynchronously

**Purpose:** Creates a PitchIQ Assignment when a seller is enrolled in a qualifying Enablement Program.

**Flow steps:**

```
START (LearningItemAssignment created)
  ↓
GET LearningItem by LearningItemId
  ↓
GET EnablementProgram by LearningItem.EnablementProgramId
  ↓
DECISION: Program name contains TLS360 or ADI RF?
  → No → END
  → Yes → ↓
GET EnablementProgramSection
  [Filter: ProgramId = Program.Id AND Name CONTAINS PitchIQ]
  [First Record only]
  ↓
DECISION: PitchIQ Section exists? (Id not null)
  → No → END (program does not include PitchIQ process)
  → Yes → ↓
SET varProgramShortName = TLS360 or ADI RF
  ↓
GET existing PitchIQ Assignment
  [Filter: Seller_User__c = AssigneeId AND Enablement_Program__c = varProgramShortName]
  ↓
DECISION: Already exists?
  → Yes → END (duplicate prevention)
  → No → ↓
CREATE PitchIQ Assignment
  [Seller_User__c = AssigneeId, Enablement_Program__c = varProgramShortName, Status__c = New]
  ↓
DECISION: Running user = AssigneeId?
  → Same user → END (seller is owner, PS grants access)
  → Different user → ↓
GET new Assignment Id
  ↓
CREATE PitchIQ_Assignment__Share
  [AccessLevel = Edit, RowCause = Manual, UserOrGroupId = AssigneeId]
  ↓
END
```

### 7.2 PitchIQ Attempt Create

**Type:** Autolaunched Capability | **Trigger:** Called from Pitch_Evaluation_Wrapper_Template

**Purpose:** Parses evaluation output and persists results to Salesforce records.

**Flow steps:**

```
START (triggered by Wrapper Template with Transcript + RelatedObject)
  ↓
CALL PitchIQ_Feedback_Analysis prompt template
  [Input: feedback text from evaluation]
  [Output: FeedbackAnalysis { Result, FailureReason }]
  ↓
DECISION: Result = Pass?
  → Pass → UPDATE PitchIQ Assignment Status__c = Passed
  → Fail → UPDATE PitchIQ Assignment Status__c = Attempted
  ↓
CREATE PitchIQ Attempt record
  [Result__c, Fail_Reason__c, Feedback__c from prompt output]
  ↓
END
```

### 7.3 PitchIQ Prompt Execution and Feedback

**Type:** Autolaunched Capability | **Trigger:** Called from Pitch_Evaluation_Wrapper_Template

**Purpose:** Routes to the correct program-specific evaluation prompt and returns feedback text.

**Flow steps:**

```
START (receives Transcript + RelatedObject)
  ↓
DECISION: Enablement_Program__c = TLS360?
  → TLS360 → CALL PitchIQ_TLS360_Pitch_Feedback prompt
  → ADI RF (default) → CALL PitchIQ_ADI_RF_Pitch_Feedback prompt
  ↓
CAPTURE prompt response
  ↓
UPDATE PitchIQ Assignment LatestFeedback__c with feedback text
  ↓
RETURN feedback text to Wrapper Template
END
```

### 7.4 Pitch IQ Files Reader

**Type:** Autolaunched Capability | **Trigger:** Called from evaluation prompt templates

**Purpose:** Retrieves grounding file content scoped to the current program.

**Flow steps:**

```
START (receives PitchIQ Assignment record)
  ↓
READ Custom Label PitchIQ_Library_Id (library Id)
  ↓
GET ContentDocumentLinks for the library
  [Filter: Title CONTAINS Enablement_Program__c value]
  ↓
LOOP through matching files
  → CALL PitchIQ_File_Reader prompt per file
  → ADD file Title + Content to consolidated output string
  ↓
RETURN consolidated content to calling prompt template
END
```

> **Critical:** The file title filter (`Title CONTAINS Enablement_Program__c`) is what prevents cross-program content contamination. TLS360 grounding content is only passed to TLS360 evaluation and vice versa.

---

## 8. Enablement Program Integration

### 8.1 Enablement Measures

Two measures are included in the package. Each uses **two filters** to ensure cross-program milestone accuracy:

| Measure | Filter 1 | Filter 2 | Why Two Filters? |
|---|---|---|---|
| PitchIQ TLS360 Program | Status__c = Passed | Enablement_Program__c = TLS360 | Without Filter 2, passing TLS360 would also complete the ADI RF milestone |
| PitchIQ ADI RF Program | Status__c = Passed | Enablement_Program__c = ADI RF | Same — without Filter 2, cross-program milestone credit would occur |

Both measures:
- Object: `PitchIQ_Assignment__c`
- User Field: `Seller_User__c`
- Date Field: `LastModifiedDate`
- Calculation Method: Count
- Target: 1

### 8.2 Program Builder Setup (manual)

Add a **PitchIQ Sales Coach** section to each Enablement Program containing:

1. **Other exercise** (link type) — "Launch Your Pitch Practice" — links to the `My_PitchIQ_Assignments` list view URL:
   ```
   /lightning/o/PitchIQ_Assignment__c/list?filterName=My_PitchIQ_Assignments
   ```

2. **Milestone** — linked to the corresponding Enablement Measure with Target = 1

The milestone acts as a mandatory gate — sellers cannot complete the program without achieving a Pass on their PitchIQ Assignment.

### 8.3 Seller Journey

```
Seller/Supervisor clicks Enroll or Assign on Enablement Program
  ↓
LearningItemAssignment record created
  ↓
PitchIQ Assignment Auto-Creation flow fires (async)
  [Checks: program name + PitchIQ section exists + no duplicate]
  ↓
PitchIQ Assignment record created (Status = New)
  ↓
Seller opens Guidance Center → PitchIQ Sales Coach section
  ↓
Clicks "Launch Your Pitch Practice" → My PitchIQ Assignments list view
  ↓
Opens their Assignment record → Sales Coach component visible
  ↓
Clicks Start → selects PitchIQ Assignment coaching scenario
  ↓
Records pitch → submits → feedback displayed
  ↓
[Backend] Attempt record created, Assignment Status updated
  ↓
If Passed: seller refreshes program panel → Refresh Progress → Milestone Complete
```

---

## 9. Grounding — Salesforce Files Library

### 9.1 Setup

1. Create a Salesforce Files Library named **PitchIQ Library** (exact name not required — the Id is what matters)
2. Run: `SELECT Id, Name FROM ContentWorkspace` to get the library Id
3. Store the Id in Custom Label: `PitchIQ_Library_Id`
4. Upload product knowledge files to the library — name files to include the program short name in the title (e.g. "TLS360 Grounding Document", "ADI RF Grounding Document")
5. Share the library and individual files with the agent user

### 9.2 File Naming Convention

File titles must contain the program short name for the scoping filter to work:

| Program | File Title Must Contain |
|---|---|
| TLS360 | `TLS360` |
| ADI RF | `ADI RF` |

The `Pitch_IQ_Files_Reader` flow filters `ContentDocument.Title CONTAINS Enablement_Program__c`. If file titles do not match the program name stored in the Assignment record, grounding will fail silently.

### 9.3 Recommended File Types

- Product brochures (PDF converted to text or MD)
- Ideal pitch transcripts
- Key topic definitions and approved messaging guides

> Knowledge articles are not supported as grounding sources for Sales Coach.

---

## 10. Pre-Deployment Steps

### 10.1 Enable Platform Features

In the **target org**:
1. Setup → Prompt Builder → confirm enabled
2. Setup → Einstein Setup → confirm Allow Unsafe Changes is enabled
3. Setup → Agentforce Sales Coach → confirm enabled

### 10.2 Validate the Change Set / Package

1. Deploy the package to target org
2. If validation fails on Prompt Templates or capability Flows:
   - Setup → Process Automation Settings → confirm **Activate Process and Flows from Deployment** is DISABLED
   - If still failing: remove Prompt Templates and their dependent Flows from the deployment, deploy the remaining components, then recreate Prompt Templates manually in target org

### 10.3 Pre-Deployment for Reports

Before deploying any reports or dashboards:
1. Manually create the Custom Report Type (PitchIQ Assignment + PitchIQ Attempts related)
2. Confirm at least one user in target org has the same username as the report folder owner in source org

---

## 11. Deployment Steps

Deploy components in this order to avoid dependency failures:

1. Custom Objects (`PitchIQ_Assignment__c`, `PitchIQ_Attempt__c`) and all fields
2. Tabs
3. Lightning Type (`FeedbackAnalysis`)
4. Sharing Rules
5. Custom Labels (`PitchIQ_Library_Id`)
6. Enablement Measure Definitions
7. Flows (activate after Prompt Templates)
8. Prompt Templates
9. Agent Bundle (`PitchIQ_Agent_4`)
10. Reports and Dashboard (last — requires Custom Report Type to pre-exist)

---

## 12. Post-Deployment Steps

### 12.1 Activate Prompt Templates

Setup → Prompt Builder → activate in this order:
1. `PitchIQ_File_Reader`
2. `PitchIQ_TLS360_Pitch_Feedback`
3. `PitchIQ_ADI_RF_Pitch_Feedback`
4. `PitchIQ_Feedback_Analysis`
5. `Pitch_Evaluation_Wrapper_Template`

### 12.2 Activate Flows

Setup → Flows → activate:
1. `PitchIQ_Assignment_Auto_Creation`
2. For capability flows — if activation fails (known platform issue with prompt-referencing flows): open flow → Save As New Version → activate the new version

### 12.3 Create Permission Sets and Assign

Create manually (not in package):
- `PitchIQ Access` — CRE on both objects — assign to all sellers
- `PitchIQ Agent Access` — CRE on both objects — assign to agent user only
- `PitchIQAdminAccess` — contains `PitchIQAdminAccess` custom permission — assign to admins, managers, and **the agent user**

### 12.4 Create Agent User

1. New User → First Name: PitchIQ, Last Name: Coach
2. License: Einstein Agent
3. Profile: Einstein Agent User
4. Save → assign `PitchIQ Agent Access` and `PitchIQAdminAccess` permission sets

### 12.5 Set Up PitchIQ Library

1. App Launcher → Files → Libraries → New Library → name it
2. Query `ContentWorkspace` for the Id
3. Setup → Custom Labels → `PitchIQ_Library_Id` → Edit → paste Id
4. Upload grounding files with correct title naming convention
5. Share library and files with agent user

### 12.6 Create and Configure Agent

Follow this exact sequence — order matters:

1. App Launcher → Agentforce Studio → Agents → New Agent → Sales Coach Agent → Name: PitchIQ Agent
2. **Do NOT remove standard subagents** at this stage
3. Save Version → Commit → verify standard Coaching Scenarios are present
4. New Version → add `PitchIQAssignment` subagent from script → Save → Commit
5. Coaching Scenarios → New Scenario → fill in values from Section 5.3 → Save → Activate
6. New Version → remove standard subagents → update Topic Selector routing → add languages → Save → Commit
7. Verify only PitchIQ Assignment scenario is active
8. Activate the agent

### 12.7 Configure Agent User Access

1. Add agent user to `PitchIQ_Agent_Group` Public Group
2. Share PitchIQ Library with agent user
3. Share each grounding file with agent user individually

### 12.8 Add Sales Coach Component to Record Page

1. Lightning App Builder → PitchIQ Assignment record page
2. Drag `Agentforce Sales Coach` component (`runtime_enablement_coaching:coachingMomentCard`) to right column
3. Save → Activate → Org Default

### 12.9 Configure Enablement Programs

For each program (TLS360, ADI RF):
1. Program Builder → add PitchIQ Sales Coach section
2. Add Other exercise linking to list view URL
3. Add Milestone linked to the corresponding Enablement Measure

### 12.10 Activate Validation Rules

Confirm both validation rules are Active:
- `PitchIQ_Assignment__c` → `Prevent_Edit_Without_Admin_Permission`
- `PitchIQ_Attempt__c` → `Prevent_Edit_Without_Admin_Permission`

### 12.11 Smoke Test

1. Enroll test seller in TLS360 program
2. Confirm PitchIQ Assignment auto-created (Status = New, Enablement_Program__c = TLS360)
3. Open Assignment record → confirm Sales Coach component visible
4. Complete a pitch → confirm feedback displays
5. Confirm PitchIQ Attempt created on Related tab (Result, Feedback, Fail Reason populated)
6. Confirm Assignment Status updated
7. Confirm Number of Attempts = 1
8. If Passed: go to program panel → Refresh Progress → confirm milestone Complete
9. Repeat for ADI RF
10. Test validation rule: non-admin user tries to edit Assignment → confirm error message

---

## 13. Adapting This Package for a New Use Case

### 13.1 Adding a New Program

1. Add a new evaluation prompt template (copy TLS360 or ADI RF template, replace key topics)
2. In `PitchIQ_Prompt_Execution_and_Feedback` flow: add a new Decision branch for the new program name, call the new prompt template
3. Create a new Enablement Measure with two filters: Status = Passed AND Enablement_Program__c = [new program name]
4. Add the grounding file to PitchIQ Library with the new program name in the title
5. Add PitchIQ Sales Coach section to the new Enablement Program
6. No changes needed to: the agent script, the wrapper template, or the enrollment flow

### 13.2 Replacing the Custom Object

The PitchIQ-specific fields and object can be replaced with any custom object. Key things to update:

- `Enablement_Program__c` — keep this field or replace with your program identifier
- `Seller_User__c` — keep this or replace with your user field for Measure attribution
- `Status__c` — keep New/Attempted/Passed or use your equivalents
- Update all Flow references to the new object API name
- Update the Coaching Scenario Salesforce Object field
- Update the Custom Report Type primary object
- Update the Enablement Measure object reference

### 13.3 Replacing the Topic Evaluation Criteria

The key topics in the evaluation prompt templates are entirely in the prompt text — they are not stored in Salesforce metadata. To change them:

1. Open the relevant prompt template in Prompt Builder
2. Update the topic list in `<TLS360_KEY_TOPICS>` or `<ADI_RF_KEY_TOPICS>`
3. Update the STEP 1 topic definitions
4. Update the topic count references in STEP 2 (e.g. "All six must be covered")
5. Save as New Version → Activate

### 13.4 Replacing the Grounding Content

Simply replace or add files in the PitchIQ Library. The Files Reader flow will pick up updated content on the next evaluation session. No code changes needed. Ensure new file titles contain the program short name.

### 13.5 Using a Different Grounding Source (SharePoint / Data Cloud)

To replace Salesforce Files with SharePoint or Data Cloud:

1. Configure the Salesforce-to-SharePoint connector and create a Data Lake Object
2. In `Pitch_IQ_Files_Reader` flow: replace the `ContentDocument` query with a retriever query against the UDLO
3. Add the EinsteinSearch retriever to the evaluation prompt templates
4. Remove the `{!$Flow:Pitch_IQ_Files_Reader.Prompt}` reference and replace with the retriever variable
5. No changes needed to: the agent, the wrapper template, or the Attempt Create flow

---

## 14. Known Issues and Platform Constraints

### 14.1 Coaching Scenario Single-Action Limitation

**Issue:** Agentforce Sales Coach Coaching Scenarios only support a single Agent Action. That action must be Reference Action Type = Prompt Template. A second Flow action cannot be chained directly.

**Resolution in this package:** The Wrapper Prompt Template is the single Coaching Scenario action. It calls two capability flows internally — one for UI feedback routing, one for backend record creation. This works because Template-Triggered Prompt Flows can execute Salesforce logic (Create/Update Records) as part of a prompt template's execution.

### 14.2 Old Builder vs New Builder

**Issue:** In Old Builder (legacy Agentforce Builder), the `after_reasoning` deterministic action chaining block is not available. Actions after the Prompt Template evaluation in Old Builder are not reliably called.

**Resolution:** This package requires New Builder (AiAuthoringBundle format). If your org only has Old Builder, the two-track capability flow approach via the Wrapper Template is the correct workaround.

### 14.3 Coaching Scenarios Page Requires Standard Subagents

**Issue:** The Coaching Scenarios page in Agent Builder is only accessible when the agent contains at least the three standard OOTB subagents (OpportunityCoaching, NegotiationRolePlay, ProposalRolePlay).

**Resolution:** The deployment sequence in Section 12 keeps standard subagents until after the Coaching Scenario is created, then removes them in a subsequent version commit.

### 14.4 Capability Flow Activation After Deployment

**Issue:** Flows that reference Prompt Template actions sometimes fail to activate directly after deployment.

**Resolution:** Open the flow → Save As New Version → activate the new version. Do not attempt to activate the deployed version directly.

### 14.5 Rich Text Area Causes HTML Entity Encoding

**Issue:** If the Feedback field on any object is Rich Text Area, stored feedback text will contain `&quot;`, `&#39;`, `&amp;` HTML entities.

**Resolution:** All Feedback fields must be **Long Text Area** only. This package correctly uses Long Text Area on both objects.

### 14.6 Speech-to-Text Transcription Artifacts

**Issue:** The Sales Coach agent transcribes seller speech to text before passing it to the prompt template. Heavy distortion (e.g. "less resistance" instead of "TLS360") can cause topic evaluation failures even when the seller covered the topic correctly.

**Resolution:** The evaluation templates include an abbreviation tolerance block and topic definitions that accept garbled versions of key terms. However extremely poor microphone quality will still cause failures. Recommend advising sellers to use quality headset microphones.

### 14.7 LearningItemAssignment Cannot Be Directly Accessed via URL

**Issue:** Navigating directly to a LearningItemAssignment record URL returns "Insufficient Privileges" even for admins. The Debug tool in Flow Builder also cannot find these records via search.

**Resolution:** Test the enrollment flow by actually enrolling a user in the program (Actions → Enroll or Assign to Programs). Check PitchIQ Assignment list view for created records. Check Paused and Failed Flow Interviews if no record appears.

---

## 15. Component Reference

| Component | API Name | Type | Notes |
|---|---|---|---|
| PitchIQ Assignment | PitchIQ_Assignment__c | Custom Object | OWD: Private |
| PitchIQ Attempt | PitchIQ_Attempt__c | Custom Object | OWD: Controlled by Parent |
| Enrollment Flow | PitchIQ_Assignment_Auto_Creation | Record-Triggered Flow | LearningItemAssignment, Async |
| Attempt Create Flow | PitchIQ_Attempt_Create | Capability Flow | Called by Wrapper Template |
| Prompt Execution Flow | PitchIQ_Prompt_Execution_and_Feedback | Capability Flow | Routes by program, updates Assignment |
| Files Reader Flow | Pitch_IQ_Files_Reader | Capability Flow | Grounding content retrieval |
| Wrapper Template | Pitch_Evaluation_Wrapper_Template | Sales Coaching Prompt Template | Coaching Scenario entry point |
| TLS360 Eval Template | PitchIQ_TLS360_Pitch_Feedback | Sales Coaching Prompt Template | 6 topics + STEP 0 auto-fail |
| ADI RF Eval Template | PitchIQ_ADI_RF_Pitch_Feedback | Sales Coaching Prompt Template | 7 topics + STEP 0 auto-fail |
| Feedback Analysis Template | PitchIQ_Feedback_Analysis | Flex Prompt Template | JSON: Result + FailureReason |
| File Reader Template | PitchIQ_File_Reader | Flex Prompt Template | ContentDocument content extraction |
| Agent | PitchIQ_Agent | SalesEinsteinCoach Agent | Single subagent, one Coaching Scenario |
| TLS360 Measure | PitchIQ_TLS360_Program_Pass | Enablement Measure | Two filters: Status=Passed + Program=TLS360 |
| ADI RF Measure | PitchIQ_ADI_RF_Program | Enablement Measure | Two filters: Status=Passed + Program=ADI RF |
| Agent Sharing Rule | ShareRecordsWithPitchIQSalesCoachAgent | Criteria Sharing Rule | PitchIQ_Agent_Group — Edit access |
| Feedback Analysis Type | FeedbackAnalysis | Lightning Type | Structured output schema |
| Library Id Label | PitchIQ_Library_Id | Custom Label | ContentWorkspace Id — update per org |

---

*Guide prepared by Truffle Consulting | Reference implementation: PitchIQ Sales Coach for Rochester Electronics*
*For questions on this implementation contact the Truffle Consulting delivery team.*
