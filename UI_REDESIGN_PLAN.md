# UI Redesign Plan — Supplier / Trader App → Driver Design System

Companion to `DRIVER_DESIGN_SYSTEM.md`. **Status: decisions approved (§0), implementation in progress.**

The scope is presentation only. Repositories, models, `api_paths.dart`, the cubit state classes, cubit methods, the router's redirect logic and all business rules stay untouched. Every screen keeps its existing `BlocProvider` / `BlocBuilder` / `BlocListener` wiring. Only the widget tree under it changes.

---

## 0. Decisions — APPROVED (2026-09-24)

| # | Decision | Outcome |
|---|---|---|
| D1 | Brand vs. server colors | **Option A.** Fixed Driver blue→teal everywhere. The server palette is used only as the subtle accent of the **role badge** (Home header, More header, workspace switcher). See `DRIVER_DESIGN_SYSTEM.md` › Adoption. |
| D2 | Status display | **Pills** (Driver badge style), same tone mapping |
| D3 | List rows | **Driver item cards / menu rows** replace ledger rows |
| D4 | Bottom nav | **Keep 4 tabs**, Driver styling + Driver bell on Home |
| D5 | Dark mode | **Yes.** A dark variant from the same centralized tokens (table in the design doc) |
| D6 | Dead code | **Delete in Phase 7**, after verifying no static *or* dynamic reference (string-based lookups, asset paths, reflection-free `get_it` registrations). Only UI widgets / legacy style helpers are removed; Cubits, services, models and API code are kept. |
| D7 | "Documents" tab name | **"Trade" / "التجارة"**. The tab is the role's hub for the full trade cycle (suppliers/catalog → orders → shipments → invoices / collections / returns / pricing / relationships), which matches the product slogan *"One account. Both sides of the trade."*. "Operations" was rejected because Home is already the ops panel. New keys: `nav.trade` in en and ar. |
| B1–B10 | Functional bugs in §4 | **Fix all**, scoped to the documented issue only |

<details><summary>Original options considered</summary>

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | **Brand color vs. server palette.** Today `buildAppTheme` recolors the whole app from the per-workspace palette sent by `/ops/panel`: trader orange `#F26A1F`, supplier blue `#1E56A0`. The code documents this recolor as *"the product's own signal for 'you are now acting as the supplier'"*. The Driver app is fixed blue→teal. | **A.** Fixed Driver brand (gradient + teal) for all chrome. Workspace identity moves to a visible **workspace badge** in the home header, tinted with the server's `primary`. `ThemeTokens` is still parsed and cached, so the API contract is unchanged. **B.** Keep the server primary as `colorScheme.primary` and adopt only Driver structure (radius, cards, spacing, nav). Buttons and nav would then be orange or blue, not the Driver gradient. | **A.** Option B can't look like the Driver app while the trader side is orange. This is a product decision, though, so it needs your sign-off. |
| **D2** | **Status display.** `StatusChip` is deliberately *plain colored text* ("Not a pill"). Driver uses tinted pills (`متأخر` on `#FCECEC`). | Pill vs. text | Pill (Driver badge), keeping the existing tone mapping (`toneForStatus`). |
| **D3** | **Document lists.** `DocumentTile` renders full-bleed "ledger rows" with a 3dp colored start-edge mark and hairlines. Driver uses stacked rounded **item cards**. | Cards vs. ledger rows | Item cards with the amount kept in tabular figures at the end side. |
| **D4** | **Bottom nav.** Driver has 3 tabs plus a notifications bell in the home header. We have 4 tabs: Home, Documents, Notifications, More. | Keep 4 restyled tabs, **or** move Notifications to a header bell with an unread dot and keep 3 tabs | Keep 4 tabs (no feature moves). Also add the Driver-style bell on Home. |
| **D5** | **Dark mode.** The app follows `ThemeMode.system`. The Driver screenshots are light only. | Derive a dark variant, or force light | Derive a dark variant from the same tokens so nothing regresses. |
| **D6** | **Dead code.** 17 of the 18 files in `lib/core/shared_widgets/` have zero references (only `BrandBackground` is used), plus `Styles` (splash only), `AppConstants` sizing and `features/shared/home/workspace_home_scaffold.dart`. | Delete in Phase 7, or leave | Delete in Phase 7, in a separate commit. |
| **D7** | **Copy.** The "Documents" tab is really the workspace's feature hub. | Rename to "Workspace" / "الأعمال", or keep | Rename. It needs new ar/en keys only. |

</details>

---

## 1. Where the design system will live (reuse, no duplicates)

The project already has a **real** token layer (`lib/core/utils/theme/`) plus a **legacy** layer (`colors/colors.dart`, `text_styles/styles.dart`). The redesign goes into the real layer.

| Driver token group | Existing home | Change |
|---|---|---|
| Colors | `theme/tokens.dart` (`AppTokens` ThemeExtension) + `colors/colors.dart` (`AppColors` already has `#03745F`, `#014EAF`, `#E84442`, `brandGradient`) | Extend `AppTokens`: `background`, `surface`, `inputFill`, `border`, `divider`, `textPrimary/Secondary/Tertiary`, `iconMuted`, `navInactive`, `primaryTint`, `danger`/`dangerTint`/`dangerBorder`, `fieldError`, `success`, `info`, `warning` (+ tints), and `brandGradient`. Keep the existing names (`paper`, `ink`, `rule`, `good`/`warn`/`danger`) as **aliases** so all 60+ call sites keep compiling. `AppColors` becomes the single source for brand constants. |
| Typography | `theme/typography.dart` (`AppType`, IBMPlex, Arabic size and leading correction) | Re-map the `TextTheme` sizes and weights to the Driver scale (§Typography). Keep `ledger`/`code` figure styles. |
| Spacing | `AppTokens.space1…space8`, `touchTarget` | Add `gutter = 20`, `cardPadding = 20`, `sectionGap = 24`, `rowHeight = 72`. |
| Radius | `AppTokens.recordRadius (3)`, `controlRadius (10)` | Replace with `radiusSm 8 / Md 12 / Lg 16 / Xl 20 / Sheet 24 / Full`. Keep the old names pointing at the new values during migration. |
| Shadows | none ("nothing floats") | Add `AppShadows.soft` and `AppShadows.nav` (the only two). |
| Theme | `theme/app_theme.dart` `buildAppTheme()` | Rewrite the component themes (see §2). The signature stays the same so `main.dart` is untouched. |

---

## 2. Shared components (Phase 3 + 4)

Every change below is to a file that already exists, unless marked **new**.

| Component | File | Now | Driver target |
|---|---|---|---|
| Global theme | `app_theme.dart` | Paper background, 1dp rules, 10dp controls, 3dp records, no shadow | `#F5F6FA` scaffold, white surfaces, the full component theme set below |
| AppBar | `app_theme.dart` `appBarTheme` (+ **new** `AppHeader` for tab roots) | Paper background with a bottom rule, `titleLarge` | Background color matches the page, no rule, 18/600 start title. Back = 40dp white bordered circle. Tab roots use `AppHeader` (large title, no bar). |
| Primary button | `form_fields.dart` `SubmitButton` + `filledButtonTheme` | Solid server primary, 52h, r10 | **Gradient** 52h r16, 16/700 white. Busy spinner kept. |
| Secondary / outline / danger buttons | `outlinedButtonTheme`, **new** `AppButton.danger` / `.outlineDanger` | Plain outlined | Per the Driver Buttons table |
| Text field | `form_fields.dart` `AppField` + `inputDecorationTheme` | Floating label, white fill, no border | **Label above** (14/500 + red `*` when required), `#FBFBFB` fill, 1dp `#EAEAEA`, r12, optional leading icon, error = 1.5dp deep red + message below. The `AppField` API is extended (`required`, `prefixIcon`, `hint`); existing params are unchanged. |
| Dropdowns | `IdPicker`, `CodePicker`, `LookupField` (`lookup_picker.dart`) | Material `DropdownButtonFormField` | Same field shell. `LookupField` already opens a sheet, and it gets the Driver sheet style. |
| Search field | **new** `AppSearchField` (replaces 4 inline `TextField`s) | Raw `TextField` + `prefixIcon` | Field shell + search icon + clear button |
| Date field | **new** `AppDateField` (replaces 5 `InkWell(InputDecorator)` copies) | No icon, can't clear | Field shell + calendar icon + clear |
| Qty field | **new** `AppQtyField` (replaces `_QtyField`, `_CountField`, `_ReturnQtyField`) | Raw `TextField` | Field shell, numeric, unit suffix |
| Cards | `cardTheme` + **new** `AppCard` (`section`, `form`, `item`, `header` variants) | r3, bordered, paper-raised | White, r20 / r16, 1dp border, optional soft shadow |
| Stat tile | **new** `AppStatTile` (used by Ops home KPIs, wallet, ratings, credit) | `_KpiCard` with hardcoded `0xFFB26A00` | Driver stat tile (label above, 24/700 semantic value) |
| Section header | **new** `AppSectionLabel` (replaces `_Section`, `_SectionRule`, ~40 `titleSmall` headers) | Ruled `titleSmall` | 14/500 muted label, 12dp above its card |
| List row | **new** `AppMenuRow` (+ `AppMenuGroup` card) | Raw `ListTile`s, `Card(ListTile)` | 72dp row, 44dp tinted icon circle, 16/600 title, trailing value + directional chevron, inset divider |
| Document row | `document_widgets.dart` `DocumentTile` | Ledger row | **Item card** (D3): code 16/700 LTR, title, meta line with icon, status pill top-end, amount end-aligned, chevron. Constructor unchanged, so 7 call sites need no edits. |
| Status badge | `document_widgets.dart` `StatusChip` | Colored text | Pill: tint background + semantic text 13/600 (D2). Constructor unchanged. |
| Count badge | **new** `AppCountBadge` | `Chip(compact)` | `#EBF4F3` pill, teal 13/700 |
| Filter tabs | **new** `AppFilterBar` (replaces 9 copy-pasted 52h `FilterChip` rows) | `FilterChip` row + `Divider` | Driver segmented pills on a white track. Height follows the text scale (no fixed 52). Selection logic stays in each screen. |
| Detail rows | `value_widgets.dart` `DetailRow` | Bottom rule on every row, causing double rules inside cards | No per-row rule inside `AppCard`; 12dp rhythm; label 14/400 muted, value 15/600 |
| Timeline | `DocumentTimeline` | 7dp ink dots | Teal filled current dot, tinted past dots, `divider` rail. Reused by shipments `_ProofTimeline`. |
| Bottom nav | `workspace_shell.dart` `NavigationBar` + `navigationBarTheme` | M3 indicator in server primary | White bar + `shadowNav`, **gradient pill** active indicator with white icon, teal 13/700 label, grey inactive. Badge kept on notifications. |
| Dialogs | `dialogTheme` + **new** `showAppConfirm()` (replaces 7 `AlertDialog`s + `askForReason` / `_ReasonDialog` / `_DisputeDialog` / `_RejectDialog` duplicates) | Untitled `AlertDialog`s, `TextButton` + `FilledButton` | Driver dialog: centered title (red if destructive), centered body, two equal side-by-side buttons with the safe action primary. The optional reason field variant keeps the same return values. |
| Bottom sheets | `bottomSheetTheme` + **new** `showAppSheet()` (wraps the 12 `showModalBottomSheet` calls; `showEditorSheet` in `collection_scaffold.dart` delegates) | Mixed paddings, some untitled, 78% fixed height | r24 top, 40×4 handle, 20/700 title, 14 body, 20 padding, scroll-controlled, sized to content |
| Loading | `skeleton.dart`, `skeleton_variants.dart` | r3 bars tinted by server primary | White card skeletons on grey, `#EEF0F4` bars r12. Add `GridSkeleton` (shop grid currently shows a list skeleton). |
| Empty state | `state_views.dart` `AppStateView` / `AppEmptyState` | 22dp faint icon | 96dp `primaryTint` disc + 40dp teal **contextual** icon (new optional `icon` param), 18/700 title, 15 body, optional gradient CTA |
| Error / offline | `AppErrorState`, `AppOfflineState`, `StaleBanner` | Same quiet view | Danger-tint disc variant; offline uses a neutral disc; `StaleBanner` becomes a rounded warning-tint card |
| Success state | **new** `AppSuccessState` | Screens reuse `AppEmptyState` as success (returns, shelf count, receipts) | Teal disc + check, title, body, primary "Done" CTA |
| Form message | `FormMessage` | Start-edge rule | Tinted rounded banner with an icon (danger / success / info) |
| Sticky CTA | **new** `AppBottomBar` | CTAs scroll away at the bottom of long forms | White bar with `shadowNav` + safe area, holding the primary CTA |
| Toast / snackbar | `snackBarTheme` | Ink background | `textPrimary` background, r12, floating, 20dp gutters |
| Brand background | `shared_widgets/brand_background.dart` | Used by splash only | Reused on login, register, reset and splash (it already matches S1's corner glow) |
| Logo tile | **new** `AppLogoTile` | Splash uses the full-width logo image | 88dp gradient r20 tile with the logo mark (S1) |

---

## 3. Screen-by-screen plan

Legend: **Now**, **Problems**, **Driver pattern**, **Reuse**, **Redesign**, **UX**.

### Group 1 — Authentication

#### Splash — `splash/presentation/views/*`
- **Now:** White `Scaffold` + `BrandBackground` + full-width logo + gradient `ShaderMask` title + legacy `Styles`/`AppConstants` sizing; 3 pulsing dots sized by screen height.
- **Problems:** Legacy styling system. `Colors.white` is hardcoded (breaks dark mode). The logo is full-screen-width (oversized on tablets). The error/offline states render as bare views on white. The `dart:io Platform` import breaks web.
- **Driver pattern:** Login canvas (S1): brand glow background and logo tile.
- **Reuse:** `BrandBackground`, the existing animation controller.
- **Redesign:** `AppLogoTile` (capped width), title 24/700, slogan 15 muted, dots in brand colors at a fixed dp size; error/offline use the new state views on the same canvas.
- **UX:** No change to timing or flow.

#### Auth frame — `auth/.../widgets/auth_widgets.dart` (`AuthScaffold`, `_StepCounter`, `AuthFooterLink`)
- **Now:** Plain AppBar + locale toggle, `headlineMedium` title, a rule, and the CTA inside the scrolling list. No brand.
- **Problems:** No brand identity; the CTA scrolls away; the step counter is 2dp ink bars.
- **Driver pattern:** S1/S2: glow background, **language pill** top-start, logo tile, 24/700 title + 15 subtitle, fields in a **white form card**, gradient CTA **below the card**, text links in teal.
- **Reuse:** `LocaleToggleButton` (restyled as a pill), `BrandBackground`, `SubmitButton`.
- **Redesign:** `AuthScaffold` becomes: glow background, top row (back circle + language pill), logo tile, title/subtitle, a `form` card slot, and a CTA slot outside the card. `_StepCounter` becomes a teal segmented progress bar (4dp, r-full). The API gains `cta:` and `footer:` slots; existing params are kept.
- **UX:** The CTA sits right after the card (it no longer drifts to the bottom of a long list). On keyboard open the content scrolls and the CTA follows.

#### Login — `login_view.dart`
- **Now:** `AuthScaffold` + 2 `AppField` + forgot link + `SubmitButton` + register link.
- **Problems:** Floating labels vs. the Driver's labels-above; no field icons; no brand.
- **Driver pattern:** S1/S2, exactly.
- **Reuse:** All cubit wiring, validators, autofill, `serverError`.
- **Redesign:** Required labels, mail/lock leading icons, eye toggle trailing, example-value hints, teal "Forgot password?" start-aligned under the fields (S1 places it at the end side in the card, which is left in RTL), gradient "Continue".
- **UX:** Same fields, validation and error text.

#### Forgot / reset password — `password_reset_view.dart` (4 steps: request, verify, choose, done)
- **Now:** `AuthScaffold` per step; the OTP is a plain field with a visible "0/6" counter; the done step is a lone `FilledButton`.
- **Problems:** OTP UX; no success moment; inconsistent raw `FilledButton`.
- **Driver pattern:** Login card + progress bar + empty-state-style success.
- **Reuse:** `PasswordResetCubit`, the existing `pin_code_fields` dependency (already in pubspec, unused).
- **Redesign:** Verify becomes 6 OTP boxes (field style, r12, LTR) + a resend countdown link; Done uses `AppSuccessState` + gradient CTA.
- **UX:** OTP autofill hint preserved; the counter is hidden.

#### Register owner — `register_owner_view.dart` (`_ModeStep`, `_ModeBand`, `_DetailsStep`)
- **Now:** Mode bands colored with the trader/supplier fallback palettes and a 6×48 side mark; a 9-field form in one scroll; loading/error drop the `AuthScaffold` chrome.
- **Problems:** Square ripple on rounded bands; selection shown only by color; the chrome jumps between states; the form is long and flat.
- **Driver pattern:** Menu rows with tinted icon circles; form cards per section.
- **Reuse:** `RegisterOwnerCubit`, `IdPicker`s, `_Section` → `AppSectionLabel`.
- **Redesign:** Mode = 3 selectable cards (icon circle, title, body, radio on the end side, teal 1.5dp border when selected). Details = 3 form cards ("You", "Business", "Location"). Loading/error render **inside** `AuthScaffold`.
- **UX:** Show the inline required error on country/city (today the submit silently returns; see §4 B7).

### Group 2 — Main navigation

#### Shell — `app/shell/workspace_shell.dart` (`_Shell`, `_MoreTab`)
- **Now:** M3 `AppBar(OrgHeader)` + `NavigationBar` (4 tabs), tabs swapped by index (state lost), `StaleBanner` above the body.
- **Problems:** Material-default look; the workspace is only indicated by recolor; tab state and scroll reset on every switch.
- **Driver pattern:** No app bar on tab roots; white nav bar with a gradient pill.
- **Reuse:** Tab list, badge logic, `OrgHeader` logic, `WorkspaceSwitcher`.
- **Redesign:** Remove the shell AppBar. Each tab root renders its own `AppHeader`: Home shows greeting + org switcher + bell; the other tabs show large titles. Restyle the nav (see §2). Wrap tabs in an `IndexedStack` (presentation-only, preserves scroll). The `StaleBanner` becomes a rounded card under the header.
- **UX:** The workspace badge (D1) sits in the Home header next to the org name.

#### Home (both workspaces) — `trader/home/views/ops_home_view.dart` (+ `TraderHomeView`, `SupplierHomeView` wrappers)
- **Now:** `titleLarge` title, 2-column KPI grid (hardcoded warn color and 22sp), quick-action `Wrap` with manual width math, attention cards, and a "Documents" card of **non-tappable** tiles.
- **Problems:** Flat hierarchy; urgent items below the fold; dead-looking tiles; hardcoded values; the skeleton doesn't match the layout.
- **Driver pattern:** S7: greeting block (greeting / **org or user name 30/700** / date), circle bell + alert buttons on the end side, **header card** with icon + title + count badge holding item cards; S3 stat tiles.
- **Reuse:** `OpsPanelCubit`, `actionHandlers`, the `_iconFor` mapping.
- **Redesign:**
  1. Greeting header with the workspace badge and bell (unread dot).
  2. **Attention** moves up as a header card ("Needs attention" + count), with a danger/warn tinted icon circle per item.
  3. KPIs become `AppStatTile`s (2 or 3 per row, driven by `LayoutBuilder`, not `MediaQuery` math).
  4. Quick actions as a grid of tinted icon-circle tiles.
  5. Documents as an `AppMenuGroup` with count badges.
- **UX:** Wire the document-group rows to the routes the Documents tab already uses. This is navigation only, and it needs your OK; see §4 B6.

#### Documents tab — `TraderDocumentsTab` (5 items), `SupplierDocumentsTab` (8 items)
- **Now:** A flat list of `Card(ListTile)`.
- **Driver pattern:** S3 grouped menu: section labels + section cards of 72dp rows with icon circles.
- **Redesign:** Trader groups: *Buying* (Suppliers, Catalog, Orders), *Logistics* (Shipments), *Finance* (Payables). Supplier groups: *Sales* (Orders inbox, Returns inbox), *Logistics* (Outbound), *Finance* (Receivables, Collections), *Catalog* (Catalog, Pricing), *Partners* (Relationships). Page title via `AppHeader`.

#### Notifications — `notifications_view.dart`
- **Now:** Inline mode adds a second toolbar under the shell AppBar; raw `ListTile`s with `hintColor`; a 10dp dot for unread; errors are hidden when items exist.
- **Driver pattern:** Tab page (S6) with a large title + actions; item rows with icon circles; empty state S6.
- **Reuse:** `NotificationsCubit`, filter/mark-all actions, the icon mapping.
- **Redesign:** `AppHeader(title, actions: filter, mark-all)` (single header). Rows use a teal icon circle when unread and neutral when read, 16/600 title when unread, 2-line body, 13 muted time. Optional *Today / Earlier* group labels (client-side grouping of the loaded list only). Empty state gets a bell icon disc.
- **UX:** Show a snackbar when a refresh fails with items present.

#### More tab — `_MoreTab`
- **Now:** 14 flat `ListTile`s, an avatar without initials, no chevrons, and a plain logout.
- **Driver pattern:** **S3 exactly**: gradient header (avatar initial, name, email/phone, workspace status pill), grouped section cards, and a danger group (logout / delete) with red icon circles. The logout dialog is S5.
- **Redesign:** Header card with gradient; groups *Account* (org switch, onboarding, account settings, subscription), *Commerce* (contracts, shelf, settlements, wallet), *Marketplace* (shop, shop orders, chat), *App settings* (language with the current value trailing, notifications), and a danger group (logout). The logout confirm uses `showAppConfirm(destructive)`.

#### Org switcher sheet / Workspace switcher — `org_switcher_sheet.dart`, `workspace_switcher.dart`
- **Problems:** The org sheet isn't scrollable (overflows with many orgs); the raw `businessMode` string is shown; `Colors.white` is hardcoded.
- **Redesign:** `showAppSheet` + rows with initial-avatar circles, a localized mode, and a teal check on the active row. The workspace sheet shows two selectable cards. `OrgHeader` becomes the Home greeting block's tappable org line.

### Group 3 — Supplier

| Screen | Now → problems | Driver redesign |
|---|---|---|
| **Orders inbox** `orders_inbox_view.dart` | Chip row + ledger `DocumentTile`; credit badge inline-styled; default filter not explained | `AppHeader` + `AppFilterBar` (the "Submitted, Under review" preset is shown as selected) + item cards; the credit warning becomes a danger-tint badge |
| **Outbound list** `outbound_views.dart` | Same pattern | Same, with the trader branch as a meta line with a store icon |
| **Outbound detail** | Header card, seals card (chips not removable, silent limits), lines as `Card(ListTile)`, actions in an uneven `Wrap` with destructive Cancel styled neutral, Dispatch at the very bottom | Header card (code + status + `DetailRow`s) → **progress timeline** (created → dispatched → en route → delivered, from the existing status) → seals card (removable input chips, inline limit hint) → lines card → **sticky bottom bar**: primary action + an overflow "More" sheet for Reschedule / Cancel (destructive in red). The mark-delivered sheet gets a title and Cancel. |
| **Receivables** `invoicing_views.dart` | Cards flush to the edges (no padding); FAB covers the last card; nested dense `ListTile` installments; empty state with no action | Gutter padding; installments as compact rows inside the card with a clear "Edit due date" text button; empty state with an "Issue invoice" CTA; `PagedListView` bottom padding clears the FAB |
| **Due-schedule sheet / Issue invoice** | Fake date fields without an icon; disabled submit unexplained | `AppDateField`, form card, and a helper under the disabled CTA |
| **Collections** `money_views.dart` | Raw payment-method code; no confirmation on confirm/reject | Item card: amount 20/700, method (localized key), reference, date; confirm/reject via `showAppConfirm` |
| **Returns inbox** | Buttons for every status (bug B1); hint below the buttons | Item card; actions only when pending (needs OK, §4); info hint as an info-tint banner above the actions |
| **Price lists** `pricing_views.dart` | "Save" label on edit (bug B3); FAB overlap | Item card + "Edit" / "Add item" text buttons; forms in `showAppSheet` grouped into form cards |
| **Relationships** `relationships_views.dart` | 3 text buttons in an unwrapped `Row` (overflow in Arabic); asymmetric confirmations | Item card with 2 stat chips (open orders, contracts) + a Ratings/Credit/Approve row as icon-labeled `Wrap`; suspend/approve via `showAppConfirm` |
| **Credit** | Wall of `DetailRow`s + long form | Stat tiles (limit / used / available / overdue in danger), a usage bar (existing numbers only), terms in a form card with unit suffixes, freeze toggles in a section card |
| **Supplier catalog + SKU rules** `supplier_catalog_views.dart` | Permanent warning paragraph; no clear button; plain-text empty SKU list | `AppSearchField`; the warning becomes a collapsible info banner; product item cards; the SKU rules card edits in a sheet (one at a time) instead of expanding in place |

### Group 4 — Trader

| Screen | Now → problems | Driver redesign |
|---|---|---|
| **Suppliers** `suppliers_view.dart` | Cards edge-to-edge (no padding); no chevron; the "blocked" badge is grey-on-grey | `AppSearchField`; item card with an initial avatar circle, name, counts meta, status pill, and a readiness badge (teal "Ready to order" / danger-tint "Blocked") |
| **Supplier detail** `supplier_detail_view.dart` | Name twice; two chips; blocked reason twice; CTA not pinned | Gradient-free header card (avatar, name, status, sectors as chips), stat row, **sticky CTA** (create order / request relationship / disabled + reason once), catalog as `AppMenuGroup` |
| **Catalog / Product detail / SkuCard** `catalog_views.dart` | Text-only rows; price hidden behind a tap; double rules | Item cards; `SkuCard` redesigned: name + status, code/barcode LTR meta, a 2×2 mini-grid of rule values (no rules), and a price area with the "Show price" button styled as a tinted pill (same behavior) |
| **Draft editor** `draft_editor_view.dart` | Grand total twice; unconfirmed delete; trailing overflow risk | Header form card (supplier, payment term, branch) → lines card (name, qty × unit, line total, delete via confirm) → totals card; the sticky bottom bar keeps the grand total + Submit (the totals card drops the duplicate). Quantity dialog → `showAppSheet` with a stepper. |
| **Orders** `orders_views.dart` | Ledger list; "All" chip ambiguity | `AppFilterBar` + item cards |
| **Order detail** (shared) `order_detail_view.dart` | Actions mid-page, all outlined; debug-looking footer with a raw role and the wrong "last" event (B4); accept-cancel as primary | Header card → cancel-request card (warn tint) → lines card → timeline card; **sticky action bar**: the first allowed transition is primary, the rest go in the "More" sheet, reject/cancel red via confirm. Footer: localized role (existing `status.*`-style key); the timestamp fix needs OK (B4). |
| **Shipments / Tracking** `shipments_views.dart` | No visual progress; tamper card glued to the header; proofs not a timeline; confirm at the bottom | Danger-tint tamper banner; a **progress stepper** from the status; carrier card (avatar circle, call circle button); seals chips; proofs through the shared `DocumentTimeline`; sticky "Confirm receipt" |
| **Payables list / Invoice detail / Claim sheet** `payables_views.dart` | Inline `DateFormat` (inconsistent); 8+ ruled rows; hidden tap-to-claim on installments | `DateText`; header card with **outstanding as a hero amount**; installments as rows with a "Claim" text button + chevron; sticky "Claim payment" (+ "Return" in More); the claim sheet with a currency suffix |
| **Goods receipt** `goods_receipt_form_view.dart` | Raw `TextField`s; the mismatch banner is far from its lines; weak success | Progress summary chip ("3 / 5 lines checked", computed from the existing state); line cards with **shipped qty prominent** + 2 `AppQtyField`s; inline per-line warning; notes via `AppField`; sticky submit with the reason shown above it; `AppSuccessState` with Dispute / Done |
| **Return form** `return_form_view.dart` | Success reuses the empty state; qty fields on every line | Line cards with `AppQtyField` (max shown as a suffix); `AppSuccessState`. The inline cubit stays where it is (not moved: it's logic). |

### Group 5 — Details, forms, marketplace

| Screen | Redesign |
|---|---|
| **Shop home** `shop_browse_views.dart` | `AppHeader` with search/fav/cart circle buttons (cart count badge); banner `PageView` with r16 and dots; category circles in `primaryTint` (onTap → B5); product rails with height derived from text scale; `ProductCard`: r16 white card, image r12, name 14/600 2-line, price 16/700, discount pill, no hardcoded `0xFFEAECF0` / `white70` |
| **Product list / Favorites / Categories** | `AppSearchField`; `GridSkeleton`; a load-more spinner at the grid end; category rows → `AppMenuGroup` |
| **Product detail** `shop_product_view.dart` | Gallery with dots; name 20/700 above the price; rating pill in warning tint (no hardcoded amber); stock badge; variations as selectable pills; collapsible description; seller card; sticky bar (stepper with fixed width + gradient Add to cart) |
| **Cart** `shop_cart_views.dart` | Line cards (r12 image, unit × qty, line total); the info notice as an info banner; totals card; sticky checkout; "No address" as a warn banner with guidance text |
| **Shop orders / order detail** | Item cards consistent with trader orders; the filter bar is fixed above the list (not scrolling with it); sticky actions; `runSpacing` on wraps |
| **Chat list / room** `shop_chat_views.dart` | Rows with avatar circles, bold unread, time for today; bubbles r16 with a tail corner via `BorderRadiusDirectional` (mine = teal 12 %, theirs = white + border); a pill composer with the send circle disabled when empty; day separators |
| **Contracts / detail** `contracts_views.dart` | Item cards; localized type; approvals as a numbered stepper; status changes via confirm (destructive in red) |
| **Settlements / Wallet / Subscription** `finance_views.dart` | Settlement card: gross → deductions (shown with a minus, muted) → **net payable hero**; wallet balance on a **gradient hero card** (S3 header pattern), transactions as rows in one section card; subscription plans as selectable cards; billing mode `Row` → `Wrap` (overflow fix) |
| **Ratings** `ratings_view.dart` | Stat tile (average + stars); per-dimension bars; "Your rating" form card; history rows with stars |
| **Shelf panel / count / adjustments** `shelf_views.dart` | Item cards with a chevron; count cards compacted (2×2 `AppQtyField` grid, **implied sold** as a highlighted value, proofs collapsed); sticky submit; `AppSuccessState` |
| **Onboarding wizard** `onboarding_wizard_view.dart` + `journey_widgets.dart` | Progress **hero card** (fraction 30/700 + teal segmented bar + next best action); checklist as an `AppMenuGroup` whose rows carry a **leading status circle** (teal check = done, neutral number = todo, warn clock = in review); reviewer notes as warn-tint cards; timeline card; **sticky** "Submit for review" with the reason shown when disabled; logout via confirm |
| **Organization / Profile forms** | Form cards per section; sticky CTA; in the profile form, *Submit for review* becomes primary and *Save draft* secondary (hierarchy fix, same callbacks); the locked state renders read-only |
| **Branches / Bank accounts / Documents** (`CollectionScaffold`, `CollectionTile`, `showEditorSheet`) | Item cards with icon circles (store / bank / file) + status pill; editor via `showAppSheet` sized to content; `_FileRow` → a file card with the name, size and replace action; `_DateRow` → `AppDateField`; IBAN/SWIFT/account fields forced LTR |

### Group 6 — Profile & settings

| Screen | Redesign |
|---|---|
| **Account settings** `account_views.dart` | Devices section card (rows with device icon circles, revoke via confirm), Identity section (Nafath row), **danger zone** = red icon-circle rows ("Delete account"); the deletion flow uses the **S4 bottom sheet** exactly (red title, body, optional reason field, solid red CTA) instead of an `AlertDialog`; add the missing error/offline branch view |
| **Nafath sheet** | `showAppSheet`; the random number in a large teal tile (40/700, LTR); status pill + spinner |
| **Language** | The More-tab row shows the current language trailing (S3 "العربية") and opens a 2-option sheet (same `locale_switch.dart` call) |

---

## 4. Functional bugs found during the audit — APPROVED FOR FIX

Each one is fixed in the phase that redesigns its screen, scoped to the documented issue only (no unrelated refactors).

| # | Where | Issue |
|---|---|---|
| B1 | `supplier/views/money_views.dart` ReturnsInbox L193-209 | Approve/Reject shown for every status (no `isPending` guard) |
| B2 | `supplier/views/outbound_views.dart` `_markDelivered` L355-381 | Dismissing the proof sheet still calls `markDelivered` |
| B3 | `supplier/views/pricing_views.dart` L86 | Edit button labelled `common.save` |
| B4 | `shared/orders/views/order_detail_view.dart` L141-150 | Footer shows raw `viewerRole`, and `timeline.last` is the **oldest** event |
| B5 | `ops_home_view.dart` L108-116, `shop_browse_views.dart` categories | Tappable-looking rows/circles with no `onTap` |
| B6 | `shelf_views.dart` L457 | `onTap: () {}` no-op on adjustment rows |
| B7 | register / organization / branches `_submit` | Silent return when country/city/type is null (no message) |
| B8 | `shop_cart_views.dart` / `ShopOrderDetailView` | Buyer sees seller status actions |
| B9 | `account_views.dart` | No error/offline branch; a failed load renders empty data |
| B10 | `supplier/views/money_views.dart` `_RejectDialog` | "Note required" hint, but an empty note is accepted |

---

## 5. Implementation order & safety

1. **Phase 3:** tokens, `AppColors`, typography, `buildAppTheme` (aliases keep old names compiling). `flutter analyze` must stay clean.
2. **Phase 4:** shared widgets in `lib/core/ui/`. Constructor signatures of `DocumentTile`, `StatusChip`, `AppField`, `SubmitButton`, `PagedListView` and `AppStateView` stay backward-compatible, so most screens improve before they are touched.
3. **Phase 5:** groups 1 → 6, one commit per group, `flutter analyze` + a manual run in **ar and en** after each.
4. **Phase 6:** audit checklist per screen (visual / UX / technical) at 320dp and 430dp widths with text scale 1.0 and 1.3, in RTL and LTR, light and dark.
5. **Phase 7:** fixes + dead-code removal (D6).

**Never touched:** `lib/data/**`, `lib/core/network/**`, `lib/core/session/**`, `lib/core/workspace/workspace_cubit.dart`, cubit files (`*_cubit(s).dart`, `view_models/**`), `app_router.dart` routes/redirects, `api_paths.dart`, push/deeplink.

**New translation keys** (ar + en) will be needed for: section labels in the Documents/More groups, greeting ("Good morning"), the "Needs attention" header, and helper texts. Existing keys are not renamed.

---

## 6. Implementation record (2026-09-24)

**Status: phases 3–7 complete.** `flutter analyze`: 0 errors / 0 warnings (1 pre-existing info in `cache_helper.dart`). `flutter test`: 284 passed. Golden renders: 94 passed (`--dart-define=GOLDENS=true`).

### Design system (Phase 3–4)
- Tokens: `lib/core/utils/theme/tokens.dart` (light + dark, legacy names kept as aliases), `colors.dart` (brand constants + gradient), `typography.dart` (Driver scale), `app_theme.dart` (all component themes; the server palette no longer colours the UI).
- AA contrast: the Driver red `#E84540` and amber are below 4.5:1 as small text on light surfaces, so `dangerText #C8302B` / `warningText #945700` are used for words; the exact Driver values stay on fills and icons. Asserted in `test/ui/tokens_test.dart`.
- Kit (`lib/core/ui/`, barrel `ui.dart`): `AppButton` (primary gradient / solid / outline / danger / outlineDanger / text), `AppCard` (+ `.section`, `.item`), `AppHeaderCard`, `AppIconCircle`, `AppSectionLabel`, `AppMenuGroup` / `AppMenuRow`, `AppStatTile`, `AppBadge`, `AppCountBadge`, `RoleBadge`, `AppBanner`, `AppHeader`, `AppCircleButton`, `AppBackIcon` (wired into every AppBar via the theme), `AppLogoTile`, `AppGradientHeader`, `AppInitialAvatar`, `AppFieldShell` + label-above `AppField`, `AppSearchField`, `AppDateField`, `AppQtyField`, `AppUnitSuffix`, `AppFilterBar`, `showAppConfirm`, `showAppReasonDialog` (with `minLength`), `showAppSheet` / `AppSheetHeader`, `AppBottomBar`, `AppNavBar`, `ShellScope`, `AppSuccessState`; restyled `StatusChip` (pill), `DocumentTile` (item card), `DetailRow`, `DocumentTimeline`, `PagedListView`, skeletons (+ `GridSkeleton`), state views, `LookupField`, `ProofFileField`, `LocaleToggleButton` (pill), `BrandBackground`.

### Screens (Phase 5) — all groups done
Auth + splash, shell / home / Trade hub / alerts / More, all supplier screens, all trader screens, shop, contracts, finance, ratings, shelf, onboarding (wizard, forms, collections) and account settings. The "Documents" tab is now **Trade / التجارة** (`nav.trade`), built by `lib/features/shared/home/trade_hub.dart`. `workspace_switcher.dart` moved to `lib/features/shared/organization/`.

### Bug fixes (§4)
| # | Result |
|---|---|
| B1 | Returns inbox shows Approve/Reject only while the request is pending (status not approved/rejected/canceled — verify against backend enum values). |
| B2 | The mark-delivered sheet returns a result only on Continue; dismissing does nothing. |
| B3 | Price-list edit button labelled `pricing.edit_list`. |
| B4 | Order footer localizes the viewer role and uses the most recent timeline event. |
| B5 | Home document-group rows open their list (by key) or the Trade hub; shop-home category circles open the category. |
| B6 | Shelf adjustment rows are no longer announced as buttons. |
| B7 | Verified: pickers are required form fields; the organization form now validates every field (was a lazy ListView) and scrolls to the first error. |
| B8 | Shop order detail: seller sees status transitions, buyer sees receipt upload (from `bootstrap.user.legacyType`); unknown role shows both, labelled. |
| B9 | `AccountCubit.load` now reports failures (404 on the deletion request is still "nothing pending"); the screen shows an error state with retry. |
| B10 | Return rejection requires a note (`showAppReasonDialog(required: true)`). |

### Dead code removed (Phase 7)
`lib/core/shared_widgets/*` except `brand_background.dart` (19 files), `lib/core/utils/text_styles/styles.dart`, `lib/core/utils/constants.dart`, `lib/core/utils/image_type.dart`, `lib/core/utils/navigation_utility.dart`, `lib/features/shared/home/workspace_home_scaffold.dart`. Verified unreferenced (static + string/`get_it`/pubspec). No cubit, service, model or API code removed.

### Review tooling
- `test/ui/screens_golden_test.dart` (real shell: home / trade / alerts / more), `test/ui/pushed_screens_golden_test.dart` (26 pushed screens × ar-light / en-dark), `test/ui/auth_golden_test.dart`, `test/ui/golden_support.dart` (loads IBM Plex + Material Icons). Run with `--dart-define=GOLDENS=true --update-goldens`; PNGs land in `test/ui/goldens/`.
- `tool/add_i18n_keys.py` merges new translation keys into both language files without overwriting.

### Known follow-ups (not done — outside a UI pass)
- Seal chips on outbound detail are not removable: `DeliveryEditorCubit` has no remove method.
- Chat list has no unread styling: `ChatThread` has no unread field.
- `AccountState` has no offline flag, so offline shows the error state (with retry) rather than the offline state.
- Numeric fields show raw controller values (e.g. `150000.00`) without thousands grouping.
- These pubspec dependencies are no longer imported anywhere in `lib/`: `dropdown_button2`, `multi_dropdown`, `cherry_toast`, `fluttertoast`, `carousel_slider`, `flutter_spinkit`, `lottie`, `flutter_rating_bar`, `flutter_html`, `flutter_svg`, `email_validator`, `package_info_plus` — candidates for removal (left in place: dependency changes are outside a UI pass).
- B1's pending-status set and the new `status.*` words should be checked against the backend enum values (see the open-questions memo).
