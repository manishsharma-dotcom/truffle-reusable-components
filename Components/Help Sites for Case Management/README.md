# Experience Help Site

**Category:** Experience Cloud (Digital Experience) — full site backup
**Type:** Metadata export of two separate Experience Cloud properties (not a single reusable component)

---

## Description

Unlike the other backups in this batch, this is not a discrete, drop-in component — it is a full metadata snapshot of **two Digital Experience sites from two different orgs**, kept here as a reference/restore point:

1. **"Tebra Site"** — a classic Aura-template Experience Cloud site ("Customer Community" / "Customer Community Old"), exported in the older Community/Network metadata format: Network + Site + navigation menus + a couple of legacy Site.com sites (Emma, LiveAgent, Survey, Web_To_Case) + related static resources (logos, footer assets, jQuery, icons).
2. **"Weave Site"** — a newer LWR ("Build Your Own" / Lightning Web Runtime) self-service Help Center, exported in the CMS-based Experience Bundle format. Multiple historical versions/clones are present at the network level (Weave, Weave Help, Weave Help V1, Weave Help Center), with the fullest build living under `Weave_Help_V11/` — a complete LWR site definition with 46 pages/routes covering Help Center browsing, Case self-service, search, auth, and various feature-area landing pages.

**Why it's here:** Kept as a full-fidelity backup/reference for "what did our Help Center site look like" — useful for restoring a deleted/broken site, diffing against a current live site to see what changed, or as a structural reference when building a new self-service Help Center from scratch (page list, navigation menus, theme layout, branding set, CMS content model) rather than for a straight redeploy into an unrelated org (Experience Cloud site metadata is heavily org/Id-dependent — see below).

---

## Technical Guide

### Folder Contents

**Tebra Site/**
- `communities/PatientPop Staff.community-meta.xml` — legacy Community definition.
- `networks/` — `Customer Community.network-meta.xml`, `Customer Community Old.network-meta.xml`: Network (Digital Experience) settings — login/registration/forgot-password email templates, guest user + Chatter settings, member visibility, CDN caching flags, etc.
- `navigationMenus/` — `Default_User_Profile_Menu`, `SFDC_Default_Navigation_Customer_Community` (+ `_Old`), `User_Profile_Navigation`: navigation menu structures for the community header/profile menu.
- `sites/` and `siteDotComSites/` — `Customer_Community(.site / _Old)`, `Emma`, `LiveAgent`, `Survey`, `Web_To_Case` (+ raw `.site` Site.com page bundles for `Customer_Community1` / `Customer_Community_Old1`): site definitions, including several legacy Site.com "microsites" that were sub-sites/pages tied to the main community.
- `staticresources/` — branding assets referenced by the above: `FooterTebra`, `GraphicsPack` (+ example png), `PatientPop_Logo`, `WelcomeEmailLogo`, `favicon`, `Survey_Yes/No_Icon`, `VJQuery.js` (a vendored jQuery build), `SiteSamples`, `fsc_Quickchoice_Images`, plus two CDN-cache resource stubs (`SNA_XDBpU_...` / `SNA_stnI1_...`) that Salesforce auto-generates for CDN-enabled sites — these are **not** meant to be hand-edited or redeployed; they'll regenerate automatically.
- `iframeWhiteListUrlSettings/` — allow-list of external domains permitted to iframe this site.

**Weave Site/**
- Four Network + Site shell exports at the root: `Weave.network-meta.xml`/`Weave1.site-meta.xml`, `Weave Help.network-meta.xml`/`Weave_Help.site-meta.xml`, `Weave Help V1.network-meta.xml`/`Weave_Help_V1.site-meta.xml`, `Weave Help Center.network-meta.xml`/`Weave_Help_Center.site-meta.xml` — these look like four sequential clones/iterations of the same site as it evolved (Weave → Weave Help → Weave Help V1 → Weave Help Center). Only network/site-level settings were exported for these three older ones (no page content) — likely kept purely as a settings history.
- `Weave_Help_V11/` (Experience Bundle / LWR "Build Your Own" site — the current/fullest version):
  - `sfdc_cms__site/Weave_Help_V11` — site record: title "Weave Help V1", urlName "weave-help-v1", `authenticationType = AUTHENTICATED_WITH_PUBLIC_ACCESS_ENABLED` (supports both logged-in and guest access).
  - `sfdc_cms__route/` — **46 page routes**, the full site map (see below). Each route is a folder with `_meta.json` (routing config: URL, themeLayout, public/private, SEO) + `content.json` (page component tree).
  - `sfdc_cms__view/` — 46 matching view definitions (one per route, the actual LWR page/component layout).
  - `sfdc_cms__appPage/` — App-level page wrapper(s).
  - `sfdc_cms__theme/Build_Your_Own_LWR/` — the LWR theme configuration.
  - `sfdc_cms__themeLayout/` — `scopedHeaderAndFooter`, `snaThemeLayout`, `Weave_Theme_Layout`: reusable header/footer/nav layouts assigned to routes.
  - `sfdc_cms__brandingSet/` — colors/fonts/branding tokens.
  - `sfdc_cms__styles/` — `styles_css` and `print_css` bundles (raw CSS).
  - `sfdc_cms__languageSettings/` — enabled languages.
  - `sfdc_cms__trustedSites/` — CSP/trusted site allow-list for the LWR runtime.
  - `sfdc_cms__mobilePublisherConfig/` — Mobile Publisher app config, if the site is also wrapped as a mobile app.

### What This Site Map Tells You (useful as a blueprint)

The `Weave_Help_V11` route list describes a fairly complete Help Center / Customer Self-Service portal pattern:

- **Auth:** Login, Register, Forgot/Check Password, guest + authenticated access on the same site.
- **Self-service Case management:** `Case_List__c`, `Case_Detail__c`, `Case_Related_List__c`, `submitarequest__c` / `Contact_Us__c` to create new Cases.
- **Knowledge/Help content:** `Knowledge_List__c`, `Knowledge_Detail__c`, `Knowledge_Related_List__c`, `Categories__c`, `Search_Results__c` — this pairs naturally with the separately-backed-up "Category Articles Custom Tree on Experience" component in this same batch, and reuses the same `TF_EX_` naming convention and Data-Category driven approach.
- **Feature-area landing pages** named after the product's own modules (Scheduling, Payments, Messages, Digital Forms, Team Chat, Analytics, Integrations, Marketing, Reviews, TaskCenter, Phones/Fax) — one hub page per product area, each presumably listing articles scoped to that Data Category.
- **Standard error/rate-limit pages:** Error, Service_Not_Available, Too_Many_Requests.

Full route list: `Analytics__c`, `Best_Practices__c`, `Case_Detail__c`, `Case_List__c`, `Case_Related_List__c`, `Categories__c`, `Check_Password`, `Contact_Us__c`, `Detail__c`, `Digital_Forms__c`, `Emergency_Contact__c`, `Error`, `Fax__c`, `Forgot_Password`, `Get_Started__c`, `Home`, `Integrations__c`, `Internal_Use__c`, `Knowledge_Detail__c`, `Knowledge_List__c`, `Knowledge_Related_List__c`, `Login`, `Marketing__c`, `Messages__c`, `News_Detail__c`, `Patients_Customers__c`, `Payments__c`, `Phone__c`, `Phones__c`, `Register`, `Reviews__c`, `Router_Configurations__c`, `Scheduling__c`, `Search_Results__c`, `Service_Not_Available`, `TaskCenter__c`, `Team_Chat__c`, `Too_Many_Requests`, `Training__c`, `Troubleshootings__c`, `WeaveTrueLark__c`, `Whats_New__c`, `contactusclone__c`, `submitarequest__c`, `testpage__c`.

### How to Reuse / Restore

This is **not** a simple "deploy anywhere" component — Experience Cloud site metadata is heavily tied to the source org's Ids, CMS content records, Knowledge data, and enabled features. Two realistic reuse paths:

**A) Restore into the same org (most reliable):**
1. Retrieve/compare against the currently live site metadata first (this backup may be older than what's live — check dates/labels).
2. Redeploy via Setup > Digital Experiences > All Sites, or via `sf project deploy` (Salesforce CLI) using this folder structure as the source, targeting the matching Network/Site by name.
3. Static resources and CMS content (article bodies, images referenced inside `content.json` bodies) may not be fully captured by a metadata retrieve alone — verify actual CMS Content records and file assets separately in Digital Experience > CMS Workspaces if a full content restore is needed.

**B) Use as a blueprint in a different org** (recommended if the goal is "build something similar for another client/brand"):
1. Treat the `sfdc_cms__route` list above as your page-planning checklist.
2. Don't attempt to deploy `sfdc_cms__site`/`sfdc_cms__route`/etc. directly into an unrelated org — recreate the site fresh in Experience Builder (LWR "Build Your Own" template) and use this backup's `content.json`/`_meta.json` files as a reference for field bindings, component choices, and layout, rather than as literal deployable metadata.
3. Rebuild the theme layout/branding set to match the new org's brand, referencing `sfdc_cms__theme` and `sfdc_cms__brandingSet` for the original structure/approach only.
4. Re-point `Knowledge_List__c`/`Categories__c` pages at the target org's own Data Category Group (see the separate "Category Articles Custom Tree on Experience" backup in this batch for the matching Apex/LWC pattern used for category-driven Knowledge browsing).

### Known Gaps / Gotchas

- Only `Weave_Help_V11` has full page content in this backup; the other three Weave network/site exports (Weave, Weave Help, Weave Help V1/Weave Help Center) are settings-only shells with no `sfdc_cms__` page content — do not assume they can be restored to a working site as-is.
- The two auto-generated CDN cache static resources under Tebra Site (`SNA_XDBpU_...` / `SNA_stnI1_...`) will regenerate on their own; don't hand-edit or worry about "restoring" their contents.
- Site.com legacy sub-sites (Emma, LiveAgent, Survey, Web_To_Case) use the old Site.com engine, which Salesforce has deprecated for new development — treat these as historical reference only, not a pattern to build new work on.
- CMS content bodies (actual article/rich-text content, images) referenced inside `content.json` are unlikely to be fully self-contained in a metadata-only export — if a true content restore is needed (not just page structure), check whether the CMS Workspace content was exported/backed up separately.
