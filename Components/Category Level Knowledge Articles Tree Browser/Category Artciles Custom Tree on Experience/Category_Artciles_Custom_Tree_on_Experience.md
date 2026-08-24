# Category Articles Custom Tree on Experience

**Category:** Experience Cloud (Digital Experience) / Salesforce Knowledge
**Type:** 2 LWCs + 1 Apex controller + 1 Lightning Message Channel
**Prefix:** `TF_EX_` (Apex) / `tF_EX_` (LWC) — Truffle Consulting delivery

---

## Description

Renders a custom, collapsible Data Category tree (like a Knowledge/Help Center sidebar) on an Experience Cloud page, and a matching article list panel that shows published Knowledge articles for whichever category the visitor clicks — including nested/child categories, article counts per category, and pagination.

It replaces the standard Salesforce "Knowledge" community components with a fully custom, styled tree + list, useful for any self-service Help Center / FAQ portal that organizes articles by Data Category.

**How the pieces talk to each other:** `tF_EX_CategoryTree` (left-hand tree) publishes the selected category on a Lightning Message Channel (`tF_EX_CategorySelected__c`), and `tF_EX_CategoryArticles` (right-hand list) subscribes and loads the matching articles. The two LWCs are decoupled — they can be placed anywhere on the same Experience Cloud page (or even different regions) and will still communicate.

**Why it's reusable:**
- Fully generic: only two constants (`OBJECT_NAME` / `CATEGORY_GROUP`) in `tF_EX_CategoryTree.js` need to change to point at a different Data Category Group.
- No hardcoded category names — the tree is built dynamically from whatever category structure exists in the target org.
- Efficient: article counts are computed with exactly 2 SOQL queries regardless of how many categories exist (no N+1 query pattern).

---

## Technical Guide

### Folder Contents

- **`TF_EX_DataCategoryController.cls`** (+ Test) — `with sharing` Apex controller, 3 `@AuraEnabled` read methods:
  - `getCategoryTree(objectName, categoryGroup)` *[cacheable]* — uses `Schema.describeDataCategoryGroupStructures()` to pull the full category tree for a given SObject + Data Category Group. Skips the synthetic root "All" node and returns its direct children as the top-level nodes (recursive `CategoryNode`: label, name, items[]).
  - `getArticleCountByCategory(objectName, categoryGroup)` *[cacheable]* — returns a per-category count of published (`PublishStatus='Online'`) `Knowledge__kav` articles, using exactly 2 SOQL queries total (1 to get article Ids via `WITH DATA CATEGORY ... BELOW All__c`, 1 to get their `Knowledge__DataCategorySelection` rows, then tallies in Apex). Scales regardless of category count/depth.
  - `getArticles(groupName, categName)` — returns published articles (Id, Title, UrlName, Summary, LastPublishedDate) assigned to the given category or any descendant category, using `WITH DATA CATEGORY <group> BELOW <category>`.

- **`tF_EX_CategoryTree/`** (LWC)
  - Wires `getCategoryTree` + `getArticleCountByCategory` on load.
  - Flattens the recursive tree into a single array (`flattenTree()`) so it can render arbitrary depth with one `<template for:each>` instead of a recursive child component — rows track level (for indent), expanded/collapsed state, and visibility (a row is only visible if every ancestor is expanded).
  - Click a row: toggles expand/collapse if it has children, and always calls `_select(name)`, which publishes `{categoryName, categoryLabel, groupName}` on the `tF_EX_CategorySelected__c` message channel.
  - Auto-selects/expands the first top-level category on initial load.
  - Hardcoded constants to change per org/site: `OBJECT_NAME = 'KnowledgeArticleVersion'`, `CATEGORY_GROUP = 'External'` (the Data Category Group **developer name**).

- **`tF_EX_CategoryArticles/`** (LWC)
  - Subscribes to `tF_EX_CategorySelected__c`; on message received, calls `getArticles(groupName, categoryName)` and renders a card per article (date, title → links to `/s/article/{UrlName}`, summary).
  - Client-side pagination, 10 articles/page (`PAGE_SIZE` constant).
  - Shows a disclaimer line about screenshots — replace/remove the copy in the `.html` for your own brand (currently references "Tebra").

- **`messageChannels/tF_EX_CategorySelected.messageChannel-meta.xml`** — `LightningMessageChannel` with fields: `categoryName`, `groupName` (`categoryLabel` is also sent at runtime even though it isn't declared as a formal field on the channel — LMS allows this, but for strict typing you may want to add a `categoryLabel` field to the channel).

### How to Reuse / Deploy

1. Deploy in this order: messageChannels → Apex class (+test) → both LWCs.
2. In target org, confirm/create a Data Category Group (Setup > Knowledge Settings/Data Category Assignments) and note its **developer name**.
3. Edit `tF_EX_CategoryTree.js`: set `CATEGORY_GROUP` to that developer name (and `OBJECT_NAME` if you're categorizing something other than Knowledge articles — though the article-count/list Apex is Knowledge-specific and would need adjusting for a non-Knowledge object).
4. In Experience Builder, drag `tF_EX_CategoryTree` and `tF_EX_CategoryArticles` onto the same page (they can be in different columns/regions — message channel communication is page-scoped, not proximity-based).
5. Make sure the community/site's guest or member profile has:
   - Read access to `Knowledge__kav` (or your KAV object) fields used (Title, UrlName, Summary, LastPublishedDate).
   - "View Data Categories" and access to the specific Data Category Group used (Setup > Data Category Visibility Settings).
6. Article links assume a Knowledge article detail page exists at `/s/article/{UrlName}` — adjust `ARTICLE_BASE` in `tF_EX_CategoryArticles.js` if your site uses a different Knowledge page URL pattern.

### Known Gaps / Gotchas

- `getCategoryTree`/`getArticleCountByCategory` are marked `cacheable=true`; if you edit categories or publish new articles, users may see stale data until the LDS cache expires/page refresh — acceptable for most Help Center use cases but worth knowing.
- `getArticleCountByCategory` builds its SOQL via `Database.query()` string concatenation of the `categoryGroup`/`objectName` parameters. These are not end-user-controlled inputs in the current usage (hardcoded JS constants), so injection risk is low, but if you ever expose these as user input, add strict allow-list validation first.
- HTML copy in `tF_EX_CategoryArticles.html` has client-specific text ("Tebra") — search and replace before reusing for another brand.
