# Custom Generic Toast Component — Technical Guide

**Category:** Flow Screen UI / Reusable Notification Widget
**Type:** 2 LWCs
**Prefix:** `sSV_` — Weave org delivery

---

## ⚠️ Important: Contains Debug Code That Needs Removal Before Reuse

One of the two components has leftover code that will cause **unwanted page redirects and console errors** if deployed as-is. Read the "Known Gaps" section before using this in any org.

## Folder Contents

### `sSV_CustomToast/` — a working, self-contained toast banner
- No `<targets>` in its meta.xml at all — it **cannot be placed directly** on a Record Page, App Page, Flow Screen, etc. It's designed to be embedded as a **child component inside another LWC**, which calls it imperatively.
- Public API: `@api showToast(variant, message)` and `@api closeToast()`.
- Renders a fixed-position (`top: 1rem; right: 1rem; z-index: 99999`) banner styled by variant — `'Success'` (green), `'Error'` (dark red), `'Warning'` (orange) — with a close button, and **auto-hides after 3 seconds** via `setTimeout`.
- Note the variant strings are capitalized (`'Success'`, `'Error'`, `'Warning'`) — case-sensitive matching, so callers must pass exactly these values or the banner will render with no color class applied.
- This component works cleanly and needs no changes to reuse — it's a genuinely portable "toast banner" building block for any LWC (Experience Cloud pages included, unlike the native `ShowToastEvent`, which does not work outside standard Lightning Experience/App pages).

### `sSV_FlowToastNotification/` — intended as a Flow Screen-compatible toast trigger, but currently broken
- Meta config targets `lightning__RecordPage`, `lightning__AppPage`, `lightning__HomePage`, and `lightning__FlowScreen`, with configurable properties `title`, `message`, `variant`, `delay` — clearly designed to be dropped onto a Screen Flow screen so the flow can show a toast without needing Apex.
- The **intended, reusable logic** is sound: `showToastMessage()` builds a toast payload from the `@api` properties, optionally delays it (`this.delay`), and fires it via `fireToastMessage()` → `this.dispatchEvent(new ShowToastEvent(toastMessage))` — this is the standard, correct way to show a native Salesforce toast from an LWC.
- **However, three problems exist in the code as delivered:**
  1. **`connectedCallback()` unconditionally redirects the whole page after 3 seconds:**
     ```js
     connectedCallback(){
         setTimeout(() => {
         window.open('/lightning/o/Case/list?filterName=__Recent', '_self');
         }, 3000);
     }
     ```
     Every time this component loads — anywhere it's placed — it will hijack navigation to the Case list view 3 seconds later. This is almost certainly leftover debug/test code, not intended production behavior.
  2. **`renderedCallback()` calls a component that isn't in the template and uses the wrong tag name:**
     ```js
     renderedCallback(){
         this.template.querySelector('c-common-toast').showToast('success','Enter Valid Email and License Id','utility:warning',10000);
     }
     ```
     The HTML template is literally empty (`<template></template>`), so `querySelector('c-common-toast')` will always return `null`, and calling `.showToast(...)` on `null` will throw a runtime error on **every render**. Also note `c-common-toast` doesn't match `sSV_CustomToast`'s actual tag name (`c-s-s-v-_-custom-toast`) — even if a template element existed, this reference is wrong.
  3. There's a separate, oddly-scoped `@api showToast()` method (no arguments) that fires a hardcoded "Get Help" / Salesforce documentation toast — unrelated to the component's stated purpose and unrelated to the `showToastMessage`/`fireToastMessage` pair that actually uses the `@api` properties.

## How to Reuse / Deploy

1. **`sSV_CustomToast` can be reused immediately as-is** — embed it in a parent LWC's template (e.g. `<c-ssv-custom-toast></c-ssv-custom-toast>`), grab a reference via `this.template.querySelector(...)`, and call `showToast('Success'|'Error'|'Warning', message)` from your parent's logic.
2. **Before reusing `sSV_FlowToastNotification`, strip it down:**
   - Delete the entire `connectedCallback()` redirect block.
   - Delete the `renderedCallback()` block (or, if the intent really was to nest `sSV_CustomToast` inside it, add `<c-s-s-v-_-custom-toast></c-s-s-v-_-custom-toast>` to the HTML template and fix the selector/tag name — but then decide whether you want native `ShowToastEvent` *or* the custom banner, not a confused mix of both).
   - Remove or repurpose the unrelated hardcoded `showToast()` "Get Help" method — it doesn't serve this component's stated purpose.
   - What should remain: the `@api title/message/variant/delay` properties and the `showToastMessage()`/`fireToastMessage()` pair, which is a clean, working pattern for firing a native toast from a Flow Screen.
3. Once cleaned up, drop `sSV_FlowToastNotification` onto a Screen Flow screen, map `title`/`message`/`variant`/`delay` from flow variables, and it will show a standard Salesforce toast at that point in the flow — remembering that `ShowToastEvent` only renders inside standard Lightning Experience contexts (App/Record/Home pages), **not** on Experience Cloud community pages, where `sSV_CustomToast` is the better choice instead.

## Known Gaps / Gotchas

- **Do not deploy `sSV_FlowToastNotification` as-is** — the forced redirect and the null-reference error in `renderedCallback` will affect every page it's placed on, immediately.
- `ShowToastEvent` (used by `sSV_FlowToastNotification`) doesn't work on Experience Cloud sites — if the goal is a portal-facing toast, use `sSV_CustomToast` instead (or as the actual rendering engine behind a cleaned-up flow-screen wrapper).
- The two components appear to have been designed to work together (`sSV_FlowToastNotification` calling into `sSV_CustomToast`) but the wiring between them was never finished/was left in a broken debug state — decide which single approach you actually want before reusing either.
