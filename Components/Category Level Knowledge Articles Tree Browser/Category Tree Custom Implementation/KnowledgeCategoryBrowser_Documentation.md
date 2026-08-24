# Knowledge Category Browser — Component Documentation

**Package:** `tF_EX_CategoryBrowser`
**Version:** 1.0
**Platform:** Salesforce Experience Cloud (LWC)

---

## What It Does

Displays a two-panel Knowledge Article browser on any Experience Site page:

- **Left panel** — collapsible category tree built from Salesforce Data Categories
- **Right panel** — paginated list of Knowledge Articles for the selected category

The two panels communicate via a Lightning Message Channel — they can be placed anywhere on the same page without a parent-child relationship.

---

## Components Included

| Component | Type | Purpose |
|---|---|---|
| `tF_EX_CategoryTree` | LWC | Left panel — renders category hierarchy |
| `tF_EX_CategoryArticles` | LWC | Right panel — shows articles for selected category |
| `TF_EX_DataCategoryController` | Apex Class | Data layer — fetches tree structure and articles |
| `tF_EX_CategorySelected__c` | Message Channel | Communication bridge between the two LWCs |
| `Data_Category_Mapping__c` | Custom Object | Optional mapping for category metadata |

---

## Prerequisites

Before placing the components:

1. **Knowledge must be enabled** in the org (Setup → Knowledge Settings)
2. **Data Category Group** must exist — default is `External`. If your group has a different name, update the constant `CATEGORY_GROUP` in `tF_EX_CategoryTree.js`
3. **Articles must be published** — only `PublishStatus = Online` articles appear
4. **Experience Site** must be active and the page must be accessible to the intended user profile

---

## How to Use

**Step 1 — Add components to an Experience Builder page**

Open Experience Builder, navigate to the target page, and drag both components onto the canvas:

- Place `tF_EX_CategoryTree` in the **left column** (recommended width: 25–30%)
- Place `tF_EX_CategoryArticles` in the **right column** (remaining width)

Both components work independently — no configuration linking is needed between them.

**Step 2 — Publish the page**

No design attributes to set. Both components are zero-config out of the box.

---

## Behaviour

**On page load**
The first top-level category is automatically selected and its articles load in the right panel. Users see content immediately without needing to click anything.

**Clicking a category with sub-categories**
The row expands to reveal child categories. Articles shown are all articles under that category and all its descendants (using `BELOW` scope).

**Clicking a leaf category**
Articles shown are only those directly assigned to that specific category.

**Pagination**
Articles load 10 per page. Previous/next buttons appear when there are more than 10 results. Current position is shown as `1–10 of 24`.

---

## Customisation

**Changing the Data Category Group**
Open `tF_EX_CategoryTree.js` and update line 8:
```js
const CATEGORY_GROUP = 'External';  // change to your group name
```
Make the same change in the two `@wire` calls within the same file.

**Changing the article URL base path**
Open `tF_EX_CategoryArticles.js` and update line 7:
```js
const ARTICLE_BASE = '/s/article/';  // update if your site uses a different path
```

**Changing articles per page**
Open `tF_EX_CategoryArticles.js` and update line 6:
```js
const PAGE_SIZE = 10;  // increase or decrease as needed
```

---

## Apex Methods

| Method | Cacheable | Description |
|---|---|---|
| `getCategoryTree(objectName, categoryGroup)` | Yes | Returns full category hierarchy as nested nodes. Strips the root `All` node automatically. |
| `getArticleCountByCategory(objectName, categoryGroup)` | Yes | Returns article count per category. Uses exactly 2 SOQLs regardless of category count — no loop queries. |
| `getArticles(groupName, categName)` | No | Returns published articles under the given category using `BELOW` scope, ordered by Title. |

---

## Known Limitations

- The category tree depth is visually capped at indent level 4 in CSS. Deeper levels still render but share the same indent as level 4. Extend `.indent-5`, `.indent-6` etc. in the CSS if needed.
- `getArticleCountByCategory` counts articles at exact category level (`AT`). A parent category's count does not include articles from its children — this is intentional to match the tree display.
- Guest/unauthenticated users can access this component if the Experience Site and Knowledge articles are set to public visibility.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Tree is empty | Category group name mismatch | Verify `CATEGORY_GROUP` constant matches your org's Data Category Group API name |
| Articles not showing | Articles not published | Ensure articles have `PublishStatus = Online` |
| Wrong articles showing | Using `BELOW` fetches descendants | Expected behaviour — clicking a parent shows all child articles |
| Component not visible in builder | Targets missing | Verify `js-meta.xml` includes `lightningCommunity__Default` |
