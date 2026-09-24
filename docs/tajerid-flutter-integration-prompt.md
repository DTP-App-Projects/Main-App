# Flutter build brief — Tajer ID / Digital Commerce Integration

## One app. Two workspaces. Different screens.

> **How to use this file.** Paste it as the opening prompt to your coding agent (Claude Code, Cursor, …), with `tajerid-api.postman_collection.json` imported into Postman so you can see every request live. Everything below is derived from the actual Laravel controllers — the quirks are real, not hypothetical.

---

## 0. The prompt

You are building the Flutter client for **Tajer ID / Digital Commerce Integration**, a Saudi B2B commerce platform. The backend is Laravel.

**This is a single app that serves two completely different user types.** The same binary, the same login, the same account — but a **trader** (buyer) and a **supplier** (seller) see different home screens, different navigation, different colours, and different actions. Building this as "one screen set with a few `if` statements" will fail. Build it as **two workspace shells over one shared core**.

The complete request catalogue is the Postman collection `tajerid-api.postman_collection.json` (260 requests, foldered by audience: `10–15 = trader`, `20–24 = supplier`, `30–33 = both`). Import it, run `00 → Login` then `01 → Bootstrap`, and read the folder descriptions — they carry the per-endpoint contract. Do not invent endpoints, field names, or status values; if something is missing, list it as an open question instead of guessing.

---

## 1. The workspace model — read this before anything else

### 1.1 What decides the workspace

`GET /api/v2/bootstrap` returns, per organization:

```jsonc
"business_mode": "trader" | "supplier" | "hybrid",
"approved_workspaces": ["trader"],          // which profiles passed review
"permissions": ["purchase_orders.manage"],  // what this member may do
"is_owner": true                            // bypasses EVERY permission check
```

| `business_mode` | App shell |
|---|---|
| `trader` | Trader workspace only. No switcher. |
| `supplier` | Supplier workspace only. No switcher. |
| `hybrid` | **Both.** Show a workspace switcher in the shell. |

Legacy mapping, for reference: `users.type = buyer` → trader, `seller` → supplier; `users.b2b_workspace` overrides. You read `business_mode`, not `users.type`.

### 1.2 There is no workspace-switch endpoint

**The active workspace is client-side state.** Nothing is posted when the user flips the switcher. What changes is:

1. Which shell/navigation you render
2. The `?workspace=` param you send to `/ops/panel`, `/ops/quick_actions`, `/ops/documents`, `/action_center`
3. The `?role=` param you send to `/purchase_orders`, `/delivery_notes`, `/invoices`
4. The theme (see §1.4)

The server enforces workspace separately, per endpoint, from `business_mode`. If you call a supplier-only endpoint from a trader-mode org you get **`403 organization_workspace_not_allowed`** — which is a bug in your navigation, not something to surface to the user.

### 1.3 The `?role=` / `?workspace=` defaults are a trap for hybrid orgs

| Endpoint family | Param | Default when omitted |
|---|---|---|
| `/purchase_orders`, `/delivery_notes`, `/invoices` | `role=trader\|supplier` | **both sides merged** |
| `/ops/panel`, `/ops/quick_actions`, `/ops/documents`, `/action_center` | `workspace=trader\|supplier` | `trader` mode → `trader`; **`supplier` *and* `hybrid` → `supplier`** |

So a hybrid org that omits `workspace` **always lands on the supplier home**, and a workspace-specific list that omits `role` shows the other side's documents mixed in. **Always send both params explicitly**, derived from the active workspace. The only place omitting `role` is correct is a deliberate combined "all my documents" view for a hybrid org.

### 1.4 The theme is server-driven and differs per workspace

`/ops/panel` and `/ops/quick_actions` return a `theme` object:

| token | supplier | trader |
|---|---|---|
| `primary_color` | `#1E56A0` (blue) | `#F26A1F` (orange) |
| `primary_on` | `#FFFFFF` | `#FFFFFF` |
| `secondary_color` | `#F26A1F` | `#1E56A0` |
| `accent_color` | `#0C2D57` | `#B24A0F` |
| `surface_color` | `#F5F8FB` | `#FFF8F2` |

Build the `ThemeData` from this response, with the values above as compile-time fallbacks for cold start / offline. Switching workspace must visibly recolour the app — that is the product's own signal for "you are now acting as the supplier."

### 1.5 The home screen is server-driven

`/ops/panel?workspace=X` returns `{workspace, theme, kpis, attention, notifications, quick_actions, document_groups, user, organization, generated_at}`.

- **`kpis`** — four tiles: `approvals`, `logistics`, `finance`, `overdue`. Each has `label_ar`, `label_en`, `value`, `severity` (`ok`|`info`|`warn`|`danger`), `icon`. Render from the response; don't compute them.
- **`quick_actions`** — the action grid, **already filtered by workspace *and* by the member's permissions** (owner sees all), sorted by `group` then `priority` desc. Each entry: `{key, label_ar, label_en, icon, workspace, permission, permission_alts[], route, group, priority, workspace_resolved}`.
- **`attention`** and **`document_groups`** — also permission-filtered server-side.

⚠️ **The `route` field still carries pre-REST RPC paths** (`/v2/purchase_draft/store`). **Key your navigation off `key`**, with a local `key → screen` map. Treat an unknown `key` as "hide it", never as a crash.

The workspace-tagged action catalogue:

| `key` | workspace | permission (alts) |
|---|---|---|
| `create_purchase_draft` | **trader** | `purchase_orders.manage` |
| `confirm_goods_receipt` | **trader** | `goods_receipts.manage` (`deliveries.manage`) |
| `claim_payment` | **trader** | `collections.manage` (`invoices.manage`) |
| `create_delivery_note` | **supplier** | `deliveries.manage` |
| `dispatch_delivery` | **supplier** | `deliveries.manage` |
| `track_outbound_shipments` | **supplier** | `deliveries.manage` |
| `issue_invoice` | **supplier** | `invoices.manage` |
| `record_collection` | **supplier** | `collections.manage` |
| `confirm_collection` | **supplier** | `collections.manage` |
| `approve_purchase_order` | any | `approvals.act` (`purchase_orders.manage`) |
| `review_contract` | any | `contracts.view` (`contracts.manage`, `contracts.approve`) |
| `create_contract` | any | `contracts.manage` |
| `manage_shelves` | any | `shelf.manage` (`settlements.manage`) |

### 1.6 The two workspaces are mirror halves of one business flow

Every document has an owner side and a counterpart side. Never build a screen without deciding which side it serves.

| Stage | **Trader does** | **Supplier does** |
|---|---|---|
| Discovery | browses suppliers, follows, requests the relationship | approves/suspends the relationship, sets the credit profile |
| Catalog | **reads** products, SKUs, resolved prices | **writes** SKU rules, price lists, price items |
| Ordering | builds a draft, adds lines, **submits** | reviews → `approved` / `rejected` → `ready` |
| Cancelling | may only **request** cancellation of an approved order | **decides** the cancel request |
| Shipping | receives; creates the **goods receipt**; may **dispute** | creates the **delivery note**, applies seals, **dispatches** |
| Invoicing | **reads** the invoice, sees `due_schedules` + `outstanding_amount` | **issues** the invoice, edits due schedules |
| Payment | **claims** a payment (`POST /collections/claim`) | **records** and **confirms/rejects** collections |
| Returns | **submits** a post-invoice return | **approves/rejects** it (credit note) |
| Adjustments | reads | **issues** debit/credit notes |

Each row is two screens, not one screen with a flag. They share the same **model** (`DeliveryNote`, `Invoice`, …) and the same **repository**, and diverge at the **view + actions** layer.

### 1.7 Endpoints that hard-fail on the wrong workspace

`403 organization_workspace_not_allowed`. `hybrid` passes both.

**Trader-only writes**
`/purchase_drafts/*` (all) · `POST /goods_receipts` · `POST /goods_receipts/{id}/dispute` · `POST /collections/claim` · `POST /post_invoice_returns`

**Supplier-only writes**
`POST /delivery_notes` · `PATCH /delivery_notes/{id}/status` · `POST /delivery_notes/{id}/{cancel,reschedule,seals}` · `POST /invoices` · `POST /invoices/proforma` · `PATCH /invoices/due_schedules/{id}` · `POST /collections` · `PATCH /collections/{id}/status` · `POST /adjustments` · `PATCH /adjustments/{id}/status` · `POST /pricing/price_lists` · `POST /pricing/price_items` · `PUT /relationships/{id}/credit` · `GET /delivery/tracking/supplier_fleet`

### 1.8 `viewer_role` and `my_role` — trust the server

`GET /purchase_orders/{id}` returns **`viewer_role`**: which side *this* org is on for *this* document. `GET /relationships` rows return **`my_role`**. For a hybrid org these can differ document by document — the same org may be the supplier on one order and the trader on another. **Never infer the side from the active workspace switch.** Read `viewer_role` / `my_role` and render accordingly.

---

## 2. Non-negotiable API constraints

These come from how this specific backend behaves.

### 2.1 No `{status, data}` envelope
Responses are bare objects keyed by entity name, or a raw Laravel paginator. Many successful mutations return **`204` with an empty body**. Your handler must tolerate: keyed object, paginator, bare array, no body.

### 2.2 Validation failures are `400`, not `422`
`{"msg":"validation_error","bag":{"field":["message"]}}`. There is no `422` for validation anywhere. Map `bag` keys onto form-field error slots.

### 2.3 An expired token produces `400 validation_error` with `bag.user_id`, not `401`
There is no auth middleware — each controller validates `user_id` against `users.jwt`. Special-case this exact shape, or users see "The user id field is invalid" instead of a login screen.

```dart
bool isAuthFailure(int? status, dynamic body) =>
    status == 401 ||
    (status == 400 &&
     body is Map &&
     body['msg'] == 'validation_error' &&
     (body['bag'] as Map?)?.containsKey('user_id') == true);
```

The `jwt` is a 200-char random string, **never expires**, and has **no refresh flow**. Secure storage, and a hard logout on the shape above.

### 2.4 `JSON_NUMERIC_CHECK` is on
Every numeric-looking string arrives as a JSON **number**: `"0501234567"` → `501234567`, `"0012345"` → `12345`. IBANs, barcodes, order codes, reference numbers. **Never declare a model field as `String` and read it directly.**

### 2.5 The `m_p` prefix must be stripped
The backend prepends the literal `m_p` to free text to defend it from §2.4. Known: `user.phone` (login/register/profile/bootstrap), address `text`/`number`/`close_to`/`notes`, chat `text`. Apply `unwrap()` defensively to every user-authored string.

### 2.6 Lists: parse `data[].formatted`
Every `/v2` list endpoint returns a raw paginator whose rows are Eloquent models with the mobile payload under **`formatted`**. Sibling raw columns are noise. Detail endpoints return that payload directly under a named key.

### 2.7 Rate limit: 60 req/min per IP, globally
Plus per-route throttles (login `10/min`, dispute `6/min`, account deletion `5/hour`). No parallel fan-out on screen load. Debounce search ≥ 400 ms. Tracking polls: 5 s foreground / 30 s background / off on dispose. Handle `429` with `Retry-After` backoff.

### 2.8 Never hardcode a state machine
`GET /purchase_orders/{id}` returns `allowed_transitions`, `reason_required_for`, `next_action`, `viewer_role`, `can_request_cancel`. Build buttons from those. `note` is **required, 3–500 chars**, on `rejected` and `canceled` → else `400 reason_required`.

### 2.9 Two-step uploads
Every v2 field named `proof_file`, `file_path`, `*_photo_path`, `image_url`, `receipt_file` wants a **string path**, not a file:

```
1. POST /api/v2/uploads  (multipart: attachment, module, field_key)  → { file: { path, url } }
2. send file.path in the JSON body of the real call
```

≤ 10 MB, mimes `jpg,jpeg,png,webp,pdf,doc,docx,xls,xlsx,csv,txt`. Validate client-side before the round trip.
**v1 endpoints are different** — profile image, product images, order receipt, pack receipt, search-request attachments are **direct multipart POSTs**. Two patterns; keep them distinct.

### 2.10 Some HTTP 200s are business failures
- Suspended login → `200 {"status":"failed","msg":"suspended user"}`
- Nafath disabled → `200 {"msg":"nafath_disabled","nafath_enabled":false,"fallback":…}`

Check these before treating a 200 as success.

### 2.11 Arabic is the default
Missing or unrecognised `Accept-Language` → the server serves **`ar`**. The app must be fully **RTL-correct**, not merely translated.

### 2.12 Loading skeletons are part of the deliverable
Every screen that fetches data ships with a **skeleton/shimmer placeholder matching the real layout's shape** — not a centered spinner, not an empty scaffold. A screen without a skeleton state is not done. Build one reusable skeleton primitive; compose list/card/detail/KPI-tile variants from it. The skeleton must use the **active workspace's theme colours**.

---

## 3. Architecture

```
lib/
  core/
    config/        flavors (dev|staging|prod), feature-flag cache
    network/       dio client, interceptors, ApiResult, coercion, Paged
    workspace/     ⭐ WorkspaceController: active workspace, switching, can(), role params
    storage/       secure token store, org-context store, offline cache
    error/         error-code → localized message map
    push/          FCM setup, workspace-aware deep-link router
    i18n/          ARB (ar, en), RTL helpers, number/date/currency formatting
    ui/            design system: skeletons, empty/error states, money & date widgets
                   + ThemeData built from the server `theme`
  data/
    models/        one model per `formatted` payload (SHARED across workspaces)
    dto/           request bodies
    repositories/  one per domain (SHARED; the workspace only changes params)
  features/
    shared/        auth, onboarding, organization, notifications, contracts, shelf,
                   settlements, wallet, subscription, ratings, lookups, profile, settings
    trader/        home, suppliers, catalog_browse, drafts, orders, receipts, payments, returns
    supplier/      home, catalog_manage, pricing, orders_inbox, shipments, invoicing,
                   collections, credit, fleet
  app/
    shell/         ⭐ TraderShell + SupplierShell + WorkspaceSwitcher
    router/        go_router with workspace-scoped branches
```

**Rules:**
- **Models and repositories are shared.** A `DeliveryNote` is a `DeliveryNote` on both sides. Only the *screen* and the *action set* differ.
- **Never duplicate a model per workspace.** If you're tempted, the difference belongs in the view.
- Widgets never touch Dio. Widget → controller/notifier → repository → api client.
- Repositories return a sealed `ApiResult<T>`; they never throw across the boundary.

**Suggested stack:** `dio` · `riverpod` (or `bloc`) · `freezed` + `json_serializable` · `go_router` · `flutter_secure_storage` · `firebase_messaging` + `flutter_local_notifications` · `intl` · `cached_network_image` · `shimmer` · `local_auth`.

---

## 4. Build the plumbing first

### 4.1 WorkspaceController — build this before any screen

```dart
enum Workspace { trader, supplier }

class WorkspaceState {
  final int organizationId;
  final String businessMode;          // trader | supplier | hybrid
  final Workspace active;
  final Set<String> permissions;
  final bool isOwner;
  final ThemeTokens theme;            // from /ops/panel, with local fallback

  bool get canSwitch => businessMode == 'hybrid';
  bool get isTrader   => active == Workspace.trader;
  bool get isSupplier => active == Workspace.supplier;

  /// Owner bypasses every permission check — the server behaves that way.
  bool can(String permission) => isOwner || permissions.contains(permission);
  bool canAny(List<String> perms) => isOwner || perms.any(permissions.contains);

  /// ALWAYS send these explicitly — the server defaults bite hybrid orgs.
  String get roleParam      => active == Workspace.trader ? 'trader' : 'supplier';
  String get workspaceParam => roleParam;
}
```

Initial `active`: `business_mode == 'trader'` → trader; `'supplier'` → supplier; **`'hybrid'` → last user choice, defaulting to trader**. Persist the choice. Switching must: swap the shell, rebuild the theme, invalidate every workspace-scoped provider, and reset navigation to that workspace's home. It must **not** log out or re-fetch bootstrap.

### 4.2 Dio client + interceptors

```dart
final dio = Dio(BaseOptions(
  baseUrl: '${Env.apiBase}/api',
  connectTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 30),
  headers: {'Accept': 'application/json'},
  validateStatus: (s) => s != null && s < 500,   // we branch on the body, not exceptions
));
```

**AuthInterceptor** — `Authorization: Bearer <jwt>` (pick ONE convention app-wide; the server also accepts a raw `jwt:` header), `X-Organization-Id: <orgId>` on every `/v2` path, `Accept-Language: <ar|en>`.

**ErrorInterceptor** — normalize into `ApiResult`:

```dart
sealed class ApiResult<T> { const ApiResult(); }
class Ok<T>             extends ApiResult<T> { final T data; const Ok(this.data); }
class NoContent<T>      extends ApiResult<T> { const NoContent(); }
class Invalid<T>        extends ApiResult<T> { final Map<String, List<String>> bag; const Invalid(this.bag); }
class Failed<T>         extends ApiResult<T> { final String code; final int status; final String? permission; const Failed(this.code, this.status, {this.permission}); }
class WrongWorkspace<T> extends ApiResult<T> { const WrongWorkspace(); }   // 403 organization_workspace_not_allowed
class Offline<T>        extends ApiResult<T> { const Offline(); }
class RateLimited<T>    extends ApiResult<T> { final Duration retryAfter; const RateLimited(this.retryAfter); }
class SessionExpired<T> extends ApiResult<T> { const SessionExpired(); }
```

Decision order:
1. no connectivity / timeout → `Offline`
2. `429` → `RateLimited(Retry-After)`
3. auth-failure shape (§2.3) → `SessionExpired` → clear token, route to login
4. `403` + `msg == 'organization_workspace_not_allowed'` → **`WrongWorkspace`** — log it loudly in debug; this is a navigation bug, show a generic error in release
5. `403` + `msg == 'permission_denied'` → `Failed(code, 403, permission: body['permission'])`
6. `400` + `msg == 'validation_error'` → `Invalid(bag)`
7. any `msg` with non-2xx → `Failed`
8. **`200` with `status == 'failed'` or `msg == 'nafath_disabled'`** → `Failed` *(do not skip — these are 200s)*
9. `204` / empty → `NoContent`
10. otherwise → `Ok(parse(body))`

**LoggingInterceptor** — dev only; **redact** `password`, `jwt`, `token`, `fcm_token`, `signature`, `public_key`.

### 4.3 Coercion helpers — use in every `fromJson`

```dart
String asStr(dynamic v)  => v == null ? '' : v.toString();
String unwrap(dynamic v) { final s = asStr(v); return s.startsWith('m_p') ? s.substring(3) : s; }
int    asInt(dynamic v)  => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double asNum(dynamic v)  => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
bool   asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
DateTime? asDate(dynamic v) {            // "" and null both mean "unset"
  final s = asStr(v);
  return s.isEmpty ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));
}
List<T> asList<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : const [];
```

Review-checklist item: **no `json['x'] as String` anywhere.**

### 4.4 Paginated list parsing

```dart
class Paged<T> {
  final List<T> items; final int currentPage, lastPage, perPage, total; final int? unreadCount;
  bool get hasMore => currentPage < lastPage;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) f,
                         {bool formattedKey = true}) {
    final rows = (j['data'] as List? ?? const []);
    return Paged(
      items: rows.whereType<Map>().map((r) {
        final m = r.cast<String, dynamic>();
        final src = formattedKey && m['formatted'] is Map
            ? (m['formatted'] as Map).cast<String, dynamic>() : m;
        return f(src);
      }).toList(),
      currentPage: asInt(j['current_page']), lastPage: asInt(j['last_page']),
      perPage: asInt(j['per_page']), total: asInt(j['total']),
      unreadCount: j['unread_count'] == null ? null : asInt(j['unread_count']),
    );
  }
}
```

Page-size param differs: **`limit`** on most v2 lists (default 15), **`per_page`** on notifications (default 20, max 100). `page` is always `page`. Organization posts use **cursor** pagination — `{organization_id, items, has_more}` with `?limit=&before_id=` — give it its own type.

---

## 5. Screen plan

Phases 1–3 are shared foundation. Then **trader and supplier are built as separate tracks** — they can be parallelised across two developers once the core lands.

### Phase 1 — Shared shell & session
Splash → restore session → `GET /api/v2/bootstrap` → route by `business_mode`.
Login · B2B sign-up (`POST /api/v2/onboarding/register_owner`, `business_mode` picked on screen one) · password reset (3 steps) · `PUT /api/auth/device_token` on every cold start + FCM refresh.
Org switcher from `bootstrap.organizations`. **Workspace switcher visible only when `business_mode == 'hybrid'`.**
Handle the suspended-login `200 {"status":"failed"}`.

### Phase 2 — Shared onboarding
Drive the wizard from `bootstrap.journey`: `profiles_ready`, `profiles_pending`, `next_best_action`, `trader.missing[]`, `supplier.missing[]`.
Organization details · **profile — one per workspace the org wants; both = hybrid** · branches · bank accounts · documents (upload) · submit for review · read-only review-status screen from `journey.timeline`.
`POST /api/v2/b2b/owner-console/request_workspace` is how an existing org adds the second workspace.

### Phase 3 — Shared core UI
`ThemeData` from the server `theme`, rebuilt on workspace switch. Skeleton primitives. Error/empty/offline states. Notifications bell + deep-link router. Money/date/RTL widgets. Lookup-backed pickers.

### Phase 4 — TRADER track
1. **Home** — `/ops/panel?workspace=trader`: KPI tiles, attention feed, quick-action grid (`create_purchase_draft`, `confirm_goods_receipt`, `claim_payment`), document groups. Orange theme.
2. **Find suppliers** — `/catalog/suppliers` (search, paginated), supplier detail, `public_catalog` for pre-relationship browsing, follow/unfollow, request relationship. **Gate the "Create order" CTA on `order_entry_ready`.**
3. **Browse catalog** — products, SKUs (read-only), `GET /pricing/resolve` before every add — **block on `pricing.matched == false`**. Use `/lookups/skus` as the order-entry picker (price + stock in one call).
4. **Draft → order** — create/update draft (upsert, safe to retry), add/remove lines, submit. Surface each line rejection with its own message: `qty_less_than_min_order_qty`, `qty_not_matching_order_step`, `insufficient_supplier_inventory`, `pricing_not_found_for_sku`, `sku_not_belong_to_draft_supplier`.
5. **My orders** — `?role=trader`, `?status=` comma-separated multi-value. Detail with `timeline[]`; actions from `allowed_transitions`. Cancel before approval = `PATCH /status`; **after approval the trader may only `POST /cancel_request`** and wait.
6. **Incoming shipments** — `?role=trader`. Tracking screen from `route_stop` + the **`proofs[]` handoff timeline**; `seals_match` tamper check; driver/vehicle cards.
7. **Goods receipt** — per-line `received_qty` / `rejected_qty` / `rejection_reason`; flag `qty_mismatch_with_driver`; dispute (reason 10–1000, `410` = window closed).
8. **Payables** — invoices `?role=trader` with `due_schedules[]` + `outstanding_amount`; **claim payment** with proof upload; claim status list.
9. **Returns** — submit a post-invoice return with lines + reason.

### Phase 5 — SUPPLIER track
1. **Home** — `/ops/panel?workspace=supplier`: same structure, different actions (`create_delivery_note`, `dispatch_delivery`, `issue_invoice`, `record_collection`, `confirm_collection`, `track_outbound_shipments`). **Blue theme.**
2. **Catalog management** — product list, SKU rules (`min_order_qty`, `order_step_qty`, `pack_quantity`, `barcode`, tiers). These settings are what produce the trader's order rejections — say so in the UI copy.
3. **Pricing** — price lists (scopes `default`/`organization`/`relationship`/`contract`/`campaign`; `scope_id` required for all but `default`) and price items.
4. **Order inbox** — `?role=supplier`, `?status=submitted,under_review`. Approve / reject (note required) / mark ready. **Handle `403 credit_manage_permission_required_for_override` as "escalate to a manager"**, not a generic error. Decide trader cancel requests.
5. **Relationships & credit** — approve/suspend relationships; **write the credit profile** (`grade`, `credit_limit`, `auto_freeze_*`). Explain that `auto_freeze_*` is what blocks the trader's next order.
6. **Shipments** — create delivery note (upsert), apply seals (`409` if after dispatch), dispatch (`422` if seals missing), cancel with reason code, reschedule. Dispatch board from `/delivery/tracking/supplier_fleet`.
7. **Invoicing** — issue invoice / proforma, edit due schedules.
8. **Collections** — record a collection; **confirm/reject the trader's claims**; issue debit/credit adjustment notes; approve/reject returns.
9. **Fleet** (optional, if the org runs its own) — routes, drivers, vehicles, maintenance, fuel, alerts, live tracking.

### Phase 6 — Shared advanced
Contracts + approvals · consignment shipments · sales reports · stock counts · shelf adjustments (**prefill from `/shelf_adjustments/previous_count`**, before/after photos via upload) · shelf panel · settlements + payouts · internal transfers · ratings (both sides rate each other) · wallet · subscription + HyperPay/Apple Pay behind `platform_flags` · biometric login · Nafath · **account deletion (both app stores require it)** · `POST /mobile/web_bridge` WebView fallback.

### Phase 7 — v1 marketplace (only if the product needs the shop)
Home, categories, search, product detail, favourites, cart, checkout, orders, chat.
⚠️ **Checkout splits the cart by seller into multiple orders and empties the cart**; the returned `totals`/`seller_info` describe only the last seller. **Always re-fetch `GET /api/orders` afterwards, including on the `401 insufficient_product_count` path** — some orders may already exist. Never auto-retry it.
⚠️ `GET /api/products/{id}` **increments a view counter** — never prefetch it from a list.
⚠️ `POST /api/chat` requires an explicit `sender_id`; it is not auto-filled.

---

## 6. Push notifications — workspace-aware routing

Register with **both** `POST /api/v2/push/register` and `PUT /api/auth/device_token` — v1 `tokens` and v2 `push_tokens` are separate tables. Set `app_variant` to the **active workspace** (`trader` / `supplier` / `owner`). Backend runs FCM **HTTP v1**.

All `data` values arrive as **strings** — coerce ids with `asInt`.

```
click_action → screen
  purchase_order          → PO detail (entity_id)
  delivery_note           → delivery tracking
  invoice                 → invoice detail
  goods_receipt           → receipt detail
  post_invoice_return     → return detail
  supplier_fleet_contract → fleet contract
  order (v1)              → GET /api/orders/{click_id}
  chat  (v1)              → chat room with click_id
```

**`data.side` (`supplier` / `trader`) tells you which workspace the event belongs to.** For a hybrid org, a tap on a `purchase_order.submitted` push (supplier-side event) must **switch the app into the supplier workspace** before pushing the detail route — otherwise the user lands on a screen whose actions don't match. For a non-hybrid org, a push for the other side should open a read-only view, not a broken action bar.

Handle all three entry paths: foreground (in-app banner + badge refresh), background tap, terminated cold start (`getInitialMessage`). Unknown `click_action` → notifications list, never a crash.

**Event catalogue.** Purchase orders (recipients: owners + `purchase_orders.manage`; the actor is never notified): `submitted` → supplier · `under_review` / `approved` / `ready` / `rejected` → trader · `canceled` → either (`data.side`) · `cancel_requested` → supplier · `cancel_accepted` / `cancel_rejected` → trader.
Shipments (trader needs `goods_receipts.manage`, supplier `deliveries.manage`): `delivery_note.created|dispatched|rejected|canceled|stop_skipped|returned_to_base`; cancel reasons `out_of_stock`, `order_canceled`, `order_error`, `vehicle_issue`, `trader_request`, `other`.
Money: `invoice.issued|overdue` → trader · `invoice.paid` → supplier · `goods_receipt.disputed` → supplier · `post_invoice_return.submitted` → supplier, `.approved|.rejected` → trader.
Fleet: `fleet_contract.accepted|rejected` → supplier.

---

## 7. Localization, RTL, formatting

- ARB files for `ar` and `en`. `ar` is default and the server's fallback.
- Send `Accept-Language` on **every** request — it drives `*_name`, `title`, `body`, `text`, push copy and validation messages.
- Server payloads often give you both `label_ar` / `label_en` (KPIs, quick actions) and `name_ar` / `name_en` (branches, contracts, SKUs) — pick by active locale, and fall back to the other when one is empty (the backend does this in `display_name`).
- Full RTL: `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextDirection`, mirrored chevrons/back arrows, RTL-correct separators and progress timelines.
- **Off-canvas trap:** never park an offscreen element at a fixed `left: -9999px`-equivalent — in RTL it re-enters the flow and blanks the scroll area. Use `Offstage`/`Visibility`.
- Numbers, dates, currency through `intl`. Dates are `"Y-m-d H:i:s"` with **no timezone offset** — decide once whether that's server-local or UTC and apply it in one place. Some date fields return `""` instead of `null`.
- Never re-derive money the server sent; display `subtotal` / `tax_total` / `grand_total` as given. Minor units or `Decimal` for any client arithmetic.
- Never show a raw server error key to a user. Map every `msg` code to localized copy with a generic fallback.

---

## 8. Offline & resilience

- Cache `bootstrap`, lookups, and the last page of each major list **per workspace**. Render cached data with a "stale" affordance when `Offline`.
- **Idempotent upserts** — an optional id in the body turns create into update: `purchase_drafts`, `price_lists`, `delivery_notes`, `contracts`, consignment shipments, sales reports, stock counts, shelf adjustments, settlements, and onboarding `branches` / `bank_accounts` / `documents`. Use them for safe retries instead of inventing a client idempotency key.
- **Never auto-retry a non-idempotent POST:** `cart/checkout`, `drafts/{id}/submit`, `collections/claim`, `goods_receipts/{id}/dispute`, `cancel_request`. Let the user retry explicitly after you re-fetch state.
- Queue uploads; a failed upload must not lose the form the user filled in.

---

## 9. Definition of done (per screen)

- [ ] Correct workspace: it lives under `features/trader/` or `features/supplier/`, or is genuinely shared
- [ ] `?role=` / `?workspace=` sent **explicitly**, never left to the server default
- [ ] **Skeleton** state matching the real layout's shape, in the active workspace's theme
- [ ] **Empty** state with a useful next action
- [ ] **Error** state with retry, localized from the error code (never the raw key)
- [ ] **Offline** state distinguishable from an error
- [ ] `WrongWorkspace` can't happen — if it does in debug, it's a navigation bug, fix the route
- [ ] Actions gated by `can(permission)`, and `403 permission_denied` handled anyway
- [ ] Side rendered from `viewer_role` / `my_role`, not from the active switch
- [ ] Pagination (infinite scroll or "load more") + pull-to-refresh
- [ ] All scalars through the coercion helpers; no bare `as String`; `m_p` stripped
- [ ] RTL verified in Arabic at the largest text scale
- [ ] No request storm: nothing fires more than once per user intent; polls bounded and cancelled on dispose
- [ ] Widget test for the happy path + a golden for the skeleton
- [ ] For hybrid orgs: verified by switching workspace on the live screen

---

## 10. Start here

1. Import `tajerid-api.postman_collection.json` plus both environment files. Run `00 → Login`, then `01 → Bootstrap`. Read the folder descriptions.
2. Confirm with backend:
   - Base URLs per environment.
   - **Three seeded test accounts**: a `trader`-mode org, a `supplier`-mode org, and a **`hybrid`** org — with an approved relationship and an active contract between the trader and supplier so the full order → delivery → invoice → collection loop is walkable from both sides. **The hybrid account is the one that finds workspace bugs.**
   - The `ratings.dimension` and `contracts.contract_type` enums (empty `in:` rules server-side — the values are not readable from the validators).
   - Broadcast driver + credentials for v1 chat (`BroadcastMsg`), or confirmation that polling is acceptable.
   - FCM config files (`google-services.json`, `GoogleService-Info.plist`).
   - Whether `GET /api/orders/{id}` `items[]` will be fixed to include per-line `count`/`price` (the controller computes them and then discards them).
3. Build `core/network` + `core/workspace` and prove them against `GET /api/v2/bootstrap`, one paginated list, **a deliberate `400 validation_error`, a deliberate expired token, and a deliberate wrong-workspace `403`** — before writing a single screen.
4. Generate the shared models from the `formatted` payloads, one domain at a time.
5. Phase 1.

If any response disagrees with the collection, **stop and report the mismatch** — do not paper over it in the model layer.
