# Driver App Design System

Extracted from the 7 reference screenshots in `assets/driver_screens/` (all Arabic / RTL, light mode):

| # | File | Screen |
|---|------|--------|
| S1 | `…5.09.56 AM.jpeg` | Login — resting |
| S2 | `…5.09.57 AM.jpeg` | Login — validation errors |
| S3 | `…5.09.57 AM (3).jpeg` | Account tab — gradient header, stat tiles, grouped menu |
| S4 | `…5.09.57 AM (1).jpeg` | Account tab — "Delete account" bottom sheet |
| S5 | `…5.09.57 AM (2).jpeg` | Account tab — "Log out" confirm dialog |
| S6 | `…5.09.57 AM (4).jpeg` | Routes tab — empty state |
| S7 | `…5.09.57 AM (5).jpeg` | Home tab — greeting, today's route card, status badge |

**How values were obtained.** Colors were sampled from pixels. For fills that is the mode color of the region; for text and hairlines it is the darkest or most saturated pixel, which JPEG compression softens slightly. Sizes were measured in pixels and converted to dp assuming a 1080 px / ~393 dp device (≈ 2.75 px/dp). The 540 px images are half resolution (≈ 1.37 px/dp). Values marked **≈** are estimates rounded to the nearest sensible step on a 4 dp grid. They reproduce the appearance but are not pixel-exact.

---

## Color Palette

### Brand

| Token | Hex | Evidence |
|---|---|---|
| `brandBlue` | `#0350A8` | Gradient start: login button (`#0151A8`), header (`#034FAD`), nav pill (`#03589B`) |
| `brandTeal` (**primary**) | `#037460` | Gradient end: button (`#037262`), dialog primary button (`#037460`), empty-state icon (`#017560`), active nav label, count badge text |
| `brandGradient` | `brandBlue → brandTeal`, horizontal | Primary button, profile header, active nav pill, logo tile |
| `primaryTint` | `#E6F0EF` | Icon circles in the menu (S3), empty-state disc (S6), dialog secondary fill (S5) |
| `primaryTintSoft` | `#EBF4F3` | Count badge background (S7) |

**Gradient direction.** In every RTL screenshot blue sits on the **left** and teal on the **right**. Blue is on the physical left in RTL, which makes it the *end* edge. Since it is a brand mark and not a reading direction, keep it **physical**: `Alignment.centerLeft → Alignment.centerRight` (blue → teal) in both locales. The logo tile uses the same two colors diagonally (teal top-right, blue bottom-left).

### Neutrals

| Token | Hex | Evidence / use |
|---|---|---|
| `background` | `#F5F6FA` | Page background on all tabbed screens (S3, S6, S7) |
| `surface` | `#FFFFFF` | Cards, sheets, dialogs, nav bar, stat tiles |
| `inputFill` | `#FBFBFB` | Text field fill (S1) — slightly off-white, not pure white |
| `border` | `#EEEFF1` | Card outlines (S3 `#F1F2F6`, S7 `#EEEFF1`) |
| `divider` | `#F1F2F4` | Row separators inside grouped cards, card header rule (S7) |
| `inputBorder` | `#EAEAEA` | Text field outline in resting state |
| `chipBorder` | `#DEDEDE` | Language pill outline (S1) |
| `textPrimary` | `#12161F` | Titles, names, row titles, route code (S6/S7 `#111723`–`#12171D`) |
| `textSecondary` | `#454545` | Greeting, date, meta lines, empty-state body, subtitle |
| `textTertiary` | `#8A8A8A` | Placeholder (`#868686`), hint, input leading icon (`#8C8C8C`) |
| `iconMuted` | `#9AA0AC` | Chevrons (`#95989F`), inline meta icons (location pin) |
| `navInactive` | `#5C5F66` | Inactive bottom-nav icon + label |
| `scrim` | `#000000` @ 55 % | Behind dialog/sheet: `#F5F6FA` darkens to `#707173` |

### Semantic

| Token | Hex | Tint (bg) | Evidence |
|---|---|---|---|
| `danger` | `#E84540` | `#FCECEC` | Delete button (`#E84442`), "Late" badge text (`#E74542`) and bg, warning icon, dialog title (`#EE3C48`), logout row |
| `dangerTintBorder` | `#EBC3C4` | — | Border of the warning circle button (S7), outline of the "Yes" button in the logout dialog |
| `fieldError` | `#B3261E` ≈ | — | Input error border + message in S2 is a **deeper** red than `danger` (required-asterisk sample `#AB2C23`) |
| `success` | `#22C55E` ≈ | — | "Online" dot (`#45E176`, lightened by the gradient behind it) |
| `info` / stat blue | `#0250B4` | — | "Pickups" stat number |
| `warning` / stat amber | `#EA9C14` | `#FDF3E1` ≈ | "Rating" stat number |
| stat teal | `#007B5F` | — | "Deliveries" stat number (= `brandTeal`) |

**Rule.** Semantic colors appear only as **text/icon on a ~10 % tint of the same hue**, never as solid fills. The one exception is the destructive CTA inside the delete sheet (solid `danger`).

### Gradients

Only one gradient exists (blue → teal), used on exactly **four** things: the primary CTA, the profile header, the active nav pill, and the logo tile. The login and splash backgrounds carry a very faint brand-tinted glow: bluish top-right and greenish bottom-left (`#E4F0EE` at the corner), fading to white. No other gradients.

---

## Typography

**Family:** IBM Plex Sans Arabic for both scripts. The Latin glyphs in S1 (`Example@yourmail.com`) and S3 (`bill man`) are Plex. The project already bundles it as `IBMPlex`.

| Role | Size (sp) ≈ | Weight | Color | Seen at |
|---|---|---|---|---|
| Display name | 30 | 700 | textPrimary | Home greeting name (S7) |
| Screen title (large) | 24 | 700 | textPrimary | "تسجيل دخول" (S1) |
| Page title | 22 | 600 | textPrimary | "خطوط السير" (S6), start-aligned, no app bar chrome |
| Header name (on gradient) | 20 | 700 | white | Profile header (S3) |
| Stat value | 24 | 700 | semantic | Stat tiles (S3) |
| Card / sheet title | 18–20 | 600–700 | textPrimary or danger | "خط سير اليوم" (S7), sheet + dialog titles (S4, S5) |
| Empty-state title | 18 | 700 | textPrimary | S6 |
| Row title | 16 | 600 | textPrimary | Menu rows (S3), route code (S7, Latin 700) |
| Button label | 16 | 700 | white / semantic | Primary CTA, dialog buttons |
| Body | 15 | 400 | textSecondary | Subtitle, dialog body, empty-state body |
| Field label | 14 | 500 | textPrimary (#333) | "البريد الالكتروني*" |
| Field input / placeholder | 15 | 400 | textPrimary / textTertiary | S1 |
| Section label | 14 | 500 | textSecondary | "الحساب", "إعدادات التطبيق" (S3) |
| Meta / caption | 14 | 400 | textSecondary | Date + station count (S7), stat label (S3) |
| Nav label | 13 | 500 inactive / 700 active | navInactive / brandTeal | S3 |
| Badge | 13 | 600 | semantic | "متأخر", count "1" |
| Error message | 13 | 400 | fieldError | S2 |

**Hierarchy** is carried by **weight + size + ink**, never by color alone. Each screen has exactly one bold anchor at the top (greeting name, page title, or login title). Everything below steps down to 16/600, then 14–15/400 muted.

**Line height.** ≈ 1.4 for body, ≈ 1.25 for titles. Arabic needs the extra leading, which the project's `AppType` already applies (`×1.12`).

---

## Spacing

The grid is 4 dp.

| Token | dp | Evidence |
|---|---|---|
| `screenGutter` | **20** | Card/button edge to screen edge on every screen (≈ 22 dp measured) |
| `cardPadding` | 20 | Login card inner inset; stat tile inset |
| `cardPaddingDense` | 16 | Inner route card (S7) |
| `sectionGap` | 24 | Header → stat row; stat row → first section label |
| `sectionLabelGap` | 12 | Section label → its card |
| `fieldGap` | 20 | Between labelled fields (S1) |
| `labelToField` | 8 | Label → input |
| `rowHeight` | 72 | Menu row (S3) |
| `rowGap` | 12 | Between tiles in a row (stat tiles) |
| `iconTextGap` | 12–16 | Circle icon → row title |
| `ctaTopGap` | 32 | Form card → primary CTA (S1) |

Content hugs the top (greeting / title at ~24 dp below the status bar). There is no vertical centering except for the empty state.

---

## Border Radius

| Token | dp ≈ | Used by |
|---|---|---|
| `radiusSm` | 8 | — (small inline chips if needed) |
| `radiusMd` | 12 | Text fields, dialog buttons |
| `radiusLg` | 16 | Primary CTA, inner cards, stat tiles, destructive CTA |
| `radiusXl` | 20 | Top-level cards (login form card, grouped menu card, home route card), dialog |
| `radiusSheet` | 24 | Bottom-sheet top corners; profile header bottom corners |
| `radiusFull` | 999 | Badges, language pill, nav active pill, avatar, icon circles |

Everything is **rounded and soft**, with no square corners anywhere. Nested surfaces step down one size (card 20 → inner card 16).

---

## Shadows

Elevation is **mostly carried by white-on-grey (#FFF on #F5F6FA) plus a 1 dp border**. Shadows are barely there.

| Token | Spec | Used by |
|---|---|---|
| `shadowNone` | — | Menu cards, stat tiles, inner cards (border only) |
| `shadowSoft` | `0 4 16 rgba(16,24,40,0.05)` | Home route card (faint halo at bottom edge in S7), circular header buttons |
| `shadowNav` | `0 -2 12 rgba(16,24,40,0.04)` | Bottom nav bar top edge (a faint fade above the bar in S6/S7) |

Never stack border + strong shadow. Never tint a shadow.

---

## Buttons

| Variant | Spec | Evidence |
|---|---|---|
| **Primary** | Height 52, full width, `radiusLg`, **brandGradient** fill, white 16/700 label, no elevation | "متابعة" (S1) |
| **Primary solid** (compact) | Height 48, `radiusMd`, solid `brandTeal`, white 16/700 | "إلغاء" in the dialog (S5) |
| **Secondary / outline-danger** | Height 48, `radiusMd`, fill `primaryTint`-ish neutral, 1 dp `dangerTintBorder`, label `danger` 16/700 | "نعم" in the logout dialog (S5) |
| **Destructive** | Height 52, full width, `radiusLg`, solid `danger`, white 16/600 | "طلب حذف الحساب" (S4) |
| **Text link** | `brandTeal` 14/600, no underline | "نسيت كلمة المرور؟" (S1) |
| **Pill / chip button** | Height 40, `radiusFull`, white fill, 1 dp `chipBorder`, icon + 14/500 label | Language toggle (S1) |
| **Circle icon button** | 48 × 48, white, `shadowSoft`, 24 dp outline icon; danger variant = `#FCECEC` fill + `dangerTintBorder` + danger icon | Bell / warning (S7) |

Loading state for buttons is not shown. Keep the label's height and swap it for a 20 dp white spinner (already done by `SubmitButton`).

The dialog's safe action is visually primary (Cancel = solid teal) and the destructive confirm is secondary (outlined, red text). **Preserve that emphasis rule:** a destructive action is never the loudest button in a confirmation.

---

## Inputs

Evidence: S1, S2.

- **Label above the field** (not floating), 14/500 `textPrimary`, required marker `*` in `fieldError` placed right after the label.
- Field: height ≈ 54, `radiusMd` 12, fill `inputFill #FBFBFB`, 1 dp `inputBorder #EAEAEA`.
- **Leading icon** (start side) 22 dp outline in `textTertiary`: mail and lock icons.
- **Trailing icon** (end side): password visibility toggle, 22 dp, `textPrimary`.
- Placeholder is an *example value* ("Example@yourmail.com", "••••••••") in `textTertiary`.
- **Focus** (not shown; inferred): 1.5 dp `brandTeal` border.
- **Error**: 1.5 dp `fieldError` border, the trailing icon turns `fieldError`, message 13/400 `fieldError` directly below at start alignment, 6 dp gap.
- **Multiline** (S4): same fill and border, `radiusLg` 16, min height ≈ 104, placeholder "Reason (optional)".
- Fields are grouped inside a white `radiusXl` card on the login screen. The card is the "form sheet", and the CTA sits **outside** the card below it.

**Search fields / dropdowns** are not in the screenshots. Derive them from the input spec: same fill, border and radius; leading search icon; dropdown uses a trailing `expand_more` and opens a bottom sheet (see Bottom Sheets).

---

## Cards

| Variant | Spec | Evidence |
|---|---|---|
| **Section card** | White, `radiusXl` 20, 1 dp `border`, no/soft shadow, padding 0 (rows fill it) | Grouped menu (S3) |
| **Form card** | White, `radiusXl`, 1 dp `border`, padding 20 | Login (S1) |
| **Header card** | White, `radiusXl`, `shadowSoft`; header row (icon + title + count badge) with 1 dp `divider` below, then body padding 16 | "Today's route" (S7) |
| **Item card** (nested) | White, `radiusLg` 16, 1 dp `border`, padding 16; code 16/700, meta lines 14/400 with inline 18 dp muted icons, status badge top-end, chevron centered-end | Route item (S7) |
| **Stat tile** | White, `radiusLg` 16, 1 dp `border`, centered: label 14/400 muted above, value 24/700 in a semantic color below; 3 per row, 12 dp gaps | S3 |

---

## Navigation

### Bottom navigation (S3, S6, S7)
- White bar, height ≈ 76 + safe area, `shadowNav`.
- 3 equally spaced destinations: outline icon (26 dp) + label.
- **Active**: icon sits in a **gradient pill** (≈ 64 × 36, `radiusFull`) with a white icon; label `brandTeal` 13/700.
- **Inactive**: `navInactive` icon, no container, label 13/500.
- RTL order follows reading direction (Home is the first item → rightmost in Arabic).

### Screen headers
There is **no Material AppBar** on the tab roots:
- **Home** (S7): greeting 16/400 muted, name 30/700, date 14/400 muted, stacked and start-aligned. Circular action buttons (notifications, alert) sit at the end side.
- **Tab page** (S6): large page title 22/600, start-aligned, directly on the background with no bar, no divider and no shadow.
- **Profile** (S3): full-bleed **gradient header** with `radiusSheet` bottom corners. It holds a 72 dp white circular avatar (initial in `brandTeal` 700), name 20/700 white, phone 14/400 white 85 %, and a status pill (white 20 % fill, white 40 % border, colored dot + white label).

---

## AppBar

Pushed (non-root) screens are not in the screenshots. Derive them from the tab-page title:
- Background `background` (#F5F6FA), no elevation, no bottom border, no scrolled-under tint.
- Leading back button: 40 dp white circle with 1 dp `border`, directional back chevron.
- Title 18/600 `textPrimary`, start-aligned.
- Actions are circle icon buttons (same style as S7).

---

## Tabs

Not shown. Derive from the nav pill: a **segmented control** on a white `radiusFull` track with 1 dp `border`. The selected segment is `primaryTint` fill with `brandTeal` 14/700 text, unselected is 14/500 `textSecondary`. Height 44, and it scrolls horizontally when there are more than 3 segments.

---

## Lists

Grouped menu (S3) is the canonical list row:
- Row height 72, horizontal padding 20.
- **Leading 44 dp circle** in `primaryTint` with a 22 dp outline icon in `brandTeal`. The danger variant uses a `#FCECEC` circle with a `danger` icon and text.
- Title 16/600 `textPrimary` (start). An optional trailing value 14/400 muted sits before the chevron ("العربية" in S3).
- Trailing **directional chevron** 20 dp `iconMuted` that points in the reading direction.
- Separator: 1 dp `divider`, **inset** so it starts under the title and doesn't cross the icon column.
- Rows are grouped inside one Section card, with a section label (14/500 muted) 12 dp above it.

Record lists (orders, routes) use **Item cards** stacked with 12 dp gaps inside the page gutter (S7).

---

## Dialogs

Evidence: S5.
- White, `radiusXl` 20, horizontal inset 24 from screen edges, padding 24.
- Title centered 18/700. It is `danger` for destructive confirmations and `textPrimary` otherwise.
- Body centered 15/400 `textSecondary`, 16 dp below title.
- **Two buttons side by side**, equal width, 12 dp gap, 24 dp above. The safe action (solid teal) is on the start side and the destructive one (outlined red) on the end side.
- Scrim black 55 %.

---

## Bottom Sheets

Evidence: S4.
- White, top corners `radiusSheet` 24, padding 20 (bottom padding plus the safe area).
- Drag handle 40 × 4, `radiusFull`, `#E4E4E7`, 12 dp from the top.
- Title start-aligned 20/700. It is `danger` for destructive sheets and `textPrimary` otherwise.
- Body 14/400 `textSecondary`, 8 dp below the title.
- Content (e.g. multiline field) sits 20 dp below, and a full-width CTA sits 24 dp below that.
- Scrim black 55 %.

---

## Icons

- **Outline / rounded-stroke** style at ~1.75 px stroke (similar to Tabler / Lucide / `Icons.*_outlined` + `_rounded`). No filled icons except inside the active nav pill (still outline, but white).
- Sizes: 22 in rows and fields, 24 in header circle buttons, 26 in the nav, 40 in empty-state discs, 18 inline with meta text.
- Colors: `brandTeal` inside tinted circles, `textTertiary` in fields, `iconMuted` for chevrons and meta, `danger` for destructive.
- Directional icons (chevrons, back) **mirror** in RTL.

---

## Empty States

Evidence: S6.
- Vertically centered in the remaining space.
- **96 dp disc** in `primaryTint` holding a 40 dp `brandTeal` outline icon that is **specific to the content** (the route icon, not a generic inbox).
- Title 18/700 `textPrimary`, 20 dp below the disc.
- Body 15/400 `textSecondary`, centered, max ~320 dp wide, 8 dp below the title.
- Optional CTA: primary gradient button, auto width, 24 dp below (inferred).

---

## Loading States

Not shown. Derive from the surfaces:
- **Skeletons** shaped like the real card or row, using white cards with `#EEF0F4` bars and a `radiusMd` bar radius on the `background` page, with a gentle shimmer.
- Inline spinners use `brandTeal` with a 2.5 dp stroke. Button spinners are white.
- Never a full-screen blocking spinner on a tab root.

---

## Error States

- **Field-level** (S2): red border + message under the field (see Inputs).
- **Screen-level** (inferred from the empty-state pattern): the same layout with a `#FCECEC` disc, a `danger` icon, title 18/700, message 15/400 muted, and a "Retry" primary button.
- **Destructive confirmations** use red **titles** instead of red blocks.

---

## RTL / Arabic Rules

1. All screenshots are RTL, and every layout mirrors: start = right. Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `BorderRadiusDirectional`, `PositionedDirectional` and `TextAlign.start`.
2. Leading icons (field icons, row icon circles) sit on the **start** side. Chevrons and trailing values sit on the **end** side.
3. Chevrons point in the reading direction (`<` in Arabic), so use a directional chevron.
4. **Non-mirrored:** the brand gradient (blue always on the physical left), Latin codes such as `RT-20260920-1EE247`, email placeholders, phone numbers and amounts (`TextDirection.ltr`).
5. Mixed digits: dates use Arabic-Indic numerals in Arabic (`٢٤ سبتمبر ٢٠٢٦`), while counts and IDs use Latin digits (`0/2`, `0.0`). Follow the existing `AppDates` / `AppMoney` behavior.
6. No letter-spacing on Arabic text.

---

## Adoption in the Supplier / Trader App (approved decisions)

### Fixed brand, role as a badge
- The Driver palette above is the **only** UI palette. The per-workspace colors the server sends (`ThemeTokens` from `/ops/panel`: trader `#F26A1F`, supplier `#1E56A0`) are still parsed and cached, but they **no longer drive `ColorScheme`**, buttons, nav or states.
- The active role is communicated by a **role badge**:
  - Pill, `radiusFull`, height 28, padding 12 horizontal, 16 dp role icon (trader = `storefront_outlined`, supplier = `local_shipping_outlined`) and 13/600 label ("Trader" / "Supplier").
  - Fill = role accent at 12 % over the surface; text and icon = role accent darkened to ≥ 4.5 : 1 contrast. The accent comes from the server palette's `primary` (fallbacks as today), so the server's role color survives **only** here.
  - On a gradient surface (profile header) it becomes the translucent white variant: white 18 % fill, white 35 % border, white text.
  - Placement: the Home greeting header (next to the org name), the More tab profile header, and the workspace switcher sheet.

### Status pills
`StatusChip` renders the **Badge** style from the Driver screens: tint background + semantic text, 13/600, `radiusFull`, height 26. The tone mapping (`toneForStatus`) is unchanged:

| Tone | Text | Tint |
|---|---|---|
| good | `#037460` (brandTeal) | `#E6F0EF` |
| inFlight | `#0350A8` (brandBlue) | `#E7EEF8` |
| warn | `#B26A00` | `#FDF3E1` |
| danger | `#E84540` | `#FCECEC` |
| unknown | `textSecondary` | `#F1F2F4` |

### Dark mode (same identity, dark surfaces)
Same tokens, same shapes, same gradient; only surfaces and ink invert, and semantic hues are lifted for contrast.

| Token | Light | Dark |
|---|---|---|
| background | `#F5F6FA` | `#0E1116` |
| surface | `#FFFFFF` | `#171B22` |
| surfaceRaised (sheets, dialogs) | `#FFFFFF` | `#1D222A` |
| inputFill | `#FBFBFB` | `#1A1F27` |
| border | `#EEEFF1` | `#262C36` |
| divider | `#F1F2F4` | `#222832` |
| inputBorder | `#EAEAEA` | `#2B323D` |
| textPrimary | `#12161F` | `#F1F3F6` |
| textSecondary | `#454545` | `#B3BAC5` |
| textTertiary | `#8A8A8A` | `#7E8794` |
| iconMuted | `#9AA0AC` | `#7E8794` |
| navInactive | `#5C5F66` | `#8A93A0` |
| primary (text / icons on surfaces) | `#037460` | `#3CC0A1` |
| primaryTint | `#E6F0EF` | `#15332E` |
| brandGradient (fills with white text) | `#0350A8 → #037460` | unchanged |
| danger / tint | `#E84540` / `#FCECEC` | `#F26B66` / `#3A1E21` |
| fieldError | `#B3261E` | `#F2837D` |
| warning / tint | `#B26A00` / `#FDF3E1` | `#F2B340` / `#3A2E17` |
| info / tint | `#0350A8` / `#E7EEF8` | `#6FA3EE` / `#19263A` |
| scrim | black 55 % | black 65 % |

In dark mode shadows are dropped (borders carry separation).

### Navigation
The app keeps **4 bottom tabs**: Home · Trade (formerly "Documents") · Alerts · More. They are styled per the Driver nav: a white bar and a gradient pill for the active tab. Home also gets the Driver circle **bell** button with an unread dot.

---

## General UI Principles

1. **Grey page, white surfaces.** `#F5F6FA` background, white cards with a hairline border. Depth comes from contrast, not shadow.
2. **One gradient, used sparingly.** Blue → teal marks brand and primary action only: CTA, header, active nav, logo.
3. **Soft and round.** 12–20 dp radii everywhere and full pills for badges and nav. No square corners.
4. **Tinted icon circles** are the main decorative device. They give lists rhythm without extra color.
5. **Semantic color = text on tint.** Status and danger never appear as saturated slabs, except the single destructive CTA.
6. **One bold anchor per screen**, then quiet 14–16 sp text.
7. **Generous targets.** Rows 72 dp, buttons 48–52 dp, icon buttons 48 dp.
8. **Calm motion** (inferred): standard Material transitions and 200 ms fades. Nothing bouncy.
9. **Content first.** No decorative imagery beyond the logo tile and the faint login glow.
