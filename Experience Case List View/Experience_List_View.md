# Experience List View — Technical Guide

**Category:** Experience Cloud (Digital Experience) / Case Management
**Type:** LWC + Apex (two independent implementations)
**Prefix conventions:** `ssv_` / `SSV_` = Weave org, `tF_EX_` / `TF_EX_` = Tebra org

---

## Folder Contents

### Case Community List View Weave/

- **`SSV_PortalCaseListController.cls`** (+ Test) — `with sharing` controller, 2 methods:
  - `getCaseList(searchText, listView, offsetVal, limitSize)` → builds a **dynamic column list** from a Custom Metadata Type, `SSV_HelpCenterCaseList__mdt` (ordered by `SSV_order__c`, each record defines a `label`, `SSV_FieldAPIName__c`, `SSV_FieldType__c`). The `CaseNumber` column is special-cased to render as a clickable link (`caseNumberURL`, `target=_blank`). Builds and runs a dynamic SOQL query using those admin-configured fields, filtered by one of 4 list views: `My Open Cases`, `My Closed Cases`, `My Company Cases - Open`, `My Company Cases - Closed` (using the running user's `ContactId`), further scoped to Cases created in the **last 30 days**, with search-text matching on CaseNumber/Subject.
  - `getCaseCount(searchText, listView)` → same filter logic, returns just the total count for pagination.
  - Both methods only permit Cases of Record Type `SSV_CustomerSupport`, `SSV_CustomerSupportEmergencyAfterHours` (`getCaseList` also allows `SSV_OwnershipTransfer`).
  - `String.escapeSingleQuotes` is applied to all user-supplied text before it's concatenated into SOQL (search text, contactId).

- **`sSV_caselist/`** (LWC)
  - Dropdown to switch between the 4 list views above; debounced (500ms) search box; a branded banner image loaded from a static resource (`SSV_WeaveHC`).
  - "Load more" pagination pattern: fetches up to 1000 rows from Apex at a time (`limitSize`), but only reveals `pagesize` (default 25, configurable) rows to the UI at once via `updateVisibleCases()` — clicking "Show More" reveals the next local batch first, and only calls Apex again once the locally-buffered rows run out.
  - Client-side column sort (via a `lightning-datatable`-style `onsort` handler) with special handling for Priority (custom High/Medium/Low/Urgent ordering), CaseNumber (numeric), and CreatedDate (date) — everything else sorts as case-insensitive string.
  - **No embedded "New Case" component.** Instead exposes an `@api submitACaseURL` property (default `/weavehelp/submitarequest`) — the "New Case" action on this list is a **link to a separate page**, not a modal. (`submitarequest__c` is one of the routes in the separately-backed-up "Experience Help Site" package — these two backups describe the same overall site.)
  - Meta targets: `lightning__Tab`, `lightning__HomePage`, `lightningCommunity__Page/Default`. Configurable properties: `pagesize`, `submitACaseURL`, `communityPath`.

### Case Community List View Tebra/

- **`TF_EX_CaseListViewController.cls`** (+ Test) — `with sharing` controller, more advanced than the Weave version:
  - **Two personas**, determined by Custom Permission `TF_EX_CaseAdminAccess` (checked via `FeatureManagement.checkPermission`): **Admin** (sees all Cases/Accounts, can bulk-close) vs **Customer** (sees only their own Contact's Cases and their linked Accounts via `AccountContactRelation`).
  - `isAdminUser()` → returns the persona flag for the LWC to branch its UI on.
  - `getAccounts()` → Account filter dropdown options, scoped to the user's active `AccountContactRelation` records.
  - `getCases(accountIds, pageSize, pageNumber, sortField, sortDirection, searchTerm, listViewType, statusFilter)` → real page-number-based pagination (not offset-only), **whitelisted sort fields** (`VALID_SORT_FIELDS = CaseNumber, Subject, Contact.Name, Account.Name, Status` — anything else silently falls back to `CaseNumber`) to prevent SOQL-injection via a sort parameter, two list view modes (`MY_CASES` vs `MY_ACCOUNT_CASES` — the latter respects a multi-select Account filter), status filter (`OPEN`/`CLOSED`/all), and a search term applied across CaseNumber/Subject/Status/Account.Name/Contact.Name. Also always restricts to a fixed Record Type allow-list (`Customer_Support_New`, `Enrollments_Support`, `Integration_Request`, `Training`, `Digital_Marketing_Support`, `Website_Design_Change`). Uses the **`WITH USER_MODE`** SOQL clause (enforces field- and object-level security for the running user automatically — a more modern/robust alternative to `WITH SECURITY_ENFORCED`).
  - `closeCases(caseIds)` → bulk-closes Cases; throws `AuraHandledException` if the running user isn't an Admin.
  - Requires **Multi-Account Contact Relationships** enabled in the org (stated directly in the class doc comment).

- **`tF_EX_CaseListView/`** (LWC) — the more feature-rich of the two list views:
  - Admin vs Customer persona drives visible columns/actions (comment references Custom Permission as `"Case_Admin_Access"`, but the Apex actually checks `"TF_EX_CaseAdminAccess"` — a naming mismatch in the code comment, not a functional bug; the real permission name is `TF_EX_CaseAdminAccess`).
  - Configurable column set (`COLUMN_DEFS`): Case Number, Subject, Contact Name, Account Name, Status, Case Type — each independently sortable/non-sortable.
  - Status badges and Priority "dot" indicators via CSS class maps, plus a Case Type badge map (Integration Request, Customer Support, Enrollments Support, Training).
  - Server-side pagination (`PAGE_SIZE = 10`), debounced search (350ms), Account multi-select filter dropdown, Status filter dropdown, row selection (`selectedRowIds`) feeding a bulk **Close** action for Admins.
  - **Embeds `c-tF_EX_CaseCommunityCreate`** directly as a modal — this is the parent component referenced throughout the Case Create on Experience package's comments/design (`casecreated`/`modalclosed` events). This is a **required dependency**, not optional.

## How to Reuse / Deploy

**Weave pattern:**
1. Prerequisites: Custom Metadata Type `SSV_HelpCenterCaseList__mdt` (fields: `label`, `SSV_FieldAPIName__c`, `SSV_FieldType__c`, `SSV_order__c`) populated with the columns you want shown; Case Record Types `SSV_CustomerSupport`, `SSV_CustomerSupportEmergencyAfterHours`, `SSV_OwnershipTransfer`; static resource `SSV_WeaveHC` (banner image asset) or remove that reference.
2. Deploy the class + LWC, drop onto an Experience Cloud page, configure `submitACaseURL`/`communityPath`/`pagesize` in Experience Builder.
3. This pattern is a good fit if you want **admin-configurable columns without redeploying code** — adding a column is a Custom Metadata record change, not an Apex/LWC change.

**Tebra pattern:**
1. Prerequisites: Custom Permission `TF_EX_CaseAdminAccess`; Multi-Account Contact Relationships enabled; the Record Types listed above.
2. **Deploy `tF_EX_CaseCommunityCreate` (and its own dependencies — `tF_EX_CaseCollaborator`, `tF_EX_FileUpload`) before this component**, since `tF_EX_CaseListView` embeds it directly and will not compile without it.
3. Deploy the class + test, then the LWC, and place on an Experience Cloud page.
4. This pattern is the better fit if you need **real admin/customer role separation with bulk actions** (close, filter by multiple accounts) rather than just a browsing list.

## Known Gaps / Gotchas

- Weave's dynamic SOQL builds field lists from Custom Metadata Type records rather than user input, so injection risk is low, but if `SSV_HelpCenterCaseList__mdt` is ever made editable by non-admins, revisit that assumption.
- Weave's "New Case" flow is a **separate page** (`submitACaseURL`), not a modal — don't assume feature parity with the Tebra version's inline modal experience when comparing the two.
- Tebra's code comment names the wrong Custom Permission (`Case_Admin_Access` vs the real `TF_EX_CaseAdminAccess`) — trust the Apex, not the comment, when granting permission sets.
- Tebra's `tF_EX_CaseListView` has a hard dependency on the Case Create package (and transitively, the Collaborator and File Upload packages) — treat all four "Tebra" LWC packages in this project as one connected feature set rather than four independent components if you're deploying the Tebra pattern.
