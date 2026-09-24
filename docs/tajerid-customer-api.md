# Tajer ID / Digital Commerce Integration — Customer Mobile API

**Audience:** the Flutter mobile team building the customer apps.
**Generated:** 2026-09-22, verified against the controllers in the Laravel repo (`app/Http/Controllers/Api/**`) and `routes/api.php`.
**Companion files:**
- `tajerid-api.postman_collection.json` + the two environment files — every request, runnable, foldered by audience.
- `tajerid-flutter-integration-prompt.md` — the build brief for the coding agent.

---

# 0. One app, two workspaces

**The same app serves the trader (buyer) and the supplier (seller).** Which screens a user sees is decided at runtime from `GET /api/v2/bootstrap`:

| `organizations[].business_mode` | App shell |
|---|---|
| `trader` | Trader workspace only |
| `supplier` | Supplier workspace only |
| `hybrid` | **Both**, with a workspace switcher |

Legacy mapping: `users.type = buyer` → trader, `seller` → supplier (`users.b2b_workspace` overrides). Read `business_mode`, not `users.type`.

**There is no workspace-switch endpoint.** The active workspace is *client-side state*. The server enforces it per endpoint from `business_mode`, and several endpoints take `?role=` or `?workspace=` to scope the response to one side.

## 0.1 The two sides of one flow

| Stage | **Trader does** | **Supplier does** |
|---|---|---|
| Discovery | browse suppliers, follow, request relationship | approve/suspend relationship, set credit profile |
| Catalog | **reads** products, SKUs, resolved prices | **writes** SKU rules, price lists, price items |
| Ordering | build draft, add lines, **submit** | review → `approved`/`rejected` → `ready` |
| Cancelling | may only **request** cancellation after approval | **decides** the cancel request |
| Shipping | creates the **goods receipt**; may **dispute** | creates the **delivery note**, seals, **dispatches** |
| Invoicing | **reads** invoice, `due_schedules`, `outstanding_amount` | **issues** invoice, edits due schedules |
| Payment | **claims** a payment | **records** + **confirms/rejects** collections |
| Returns | **submits** a post-invoice return | **approves/rejects** (credit note) |
| Adjustments | reads | **issues** debit/credit notes |

## 0.2 Workspace-gated endpoints

Violation → **`403 organization_workspace_not_allowed`**. `hybrid` passes both.

**Trader-only writes**
`/purchase_drafts/*` (all) · `POST /goods_receipts` · `POST /goods_receipts/{id}/dispute` · `POST /collections/claim` · `POST /post_invoice_returns`

**Supplier-only writes**
`POST /delivery_notes` · `PATCH /delivery_notes/{id}/status` · `POST /delivery_notes/{id}/{cancel,reschedule,seals}` · `POST /invoices` · `POST /invoices/proforma` · `PATCH /invoices/due_schedules/{id}` · `POST /collections` · `PATCH /collections/{id}/status` · `POST /adjustments` · `PATCH /adjustments/{id}/status` · `POST /pricing/price_lists` · `POST /pricing/price_items` · `PUT /relationships/{id}/credit` · `GET /delivery/tracking/supplier_fleet`

## 0.3 `?role=` and `?workspace=` — the defaults bite hybrid orgs

| Endpoints | Param | Default when omitted |
|---|---|---|
| `/purchase_orders`, `/delivery_notes`, `/invoices` | `role=trader\|supplier` | **both sides merged** |
| `/ops/panel`, `/ops/quick_actions`, `/ops/documents`, `/action_center` | `workspace=trader\|supplier` | `trader` mode → `trader`; **`supplier` *and* `hybrid` → `supplier`** |

A hybrid org that omits `workspace` **always lands on the supplier home**. Always send both params explicitly.

## 0.4 The server ships a per-workspace theme

`/ops/panel` and `/ops/quick_actions` return a `theme`:

| token | supplier | trader |
|---|---|---|
| `primary_color` | `#1E56A0` (blue) | `#F26A1F` (orange) |
| `secondary_color` | `#F26A1F` | `#1E56A0` |
| `accent_color` | `#0C2D57` | `#B24A0F` |
| `surface_color` | `#F5F8FB` | `#FFF8F2` |

## 0.5 Per-document side: `viewer_role` / `my_role`

`GET /purchase_orders/{id}` returns **`viewer_role`**; relationship rows return **`my_role`**. For a hybrid org these differ document by document — the same org can be the supplier on one order and the trader on another. **Never infer the side from the active workspace switch.**

## 0.6 Quick-action catalogue (workspace-tagged)

`/ops/quick_actions` returns these, filtered by workspace **and** the member's permissions (owner sees all):

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

⚠️ Each entry's `route` field still carries the **pre-REST RPC path** (`/v2/purchase_draft/store`). Navigate off **`key`**, not `route`.

There are **two API surfaces** in this backend and the app talks to both:

| Surface | Prefix | What it is |
|---|---|---|
| **v1 — marketplace** | `/api/...` | The original B2C-ish shop: register/login, home feed, categories, products, favourites, cart, checkout, orders, chat, addresses, subscription packs. Still the only place `auth/login` and `auth/register` live, so **every app starts here.** |
| **v2 — B2B platform** | `/api/v2/...` | The real platform: organizations, supplier catalog, purchase drafts → purchase orders → delivery notes → goods receipts → invoices → collections, contracts & consignment shelf, wallet & subscription, notifications, live delivery tracking. |

> The v1 `users` row and the v2 `organizations` row are linked: a user logs in on v1, gets a `jwt`, then calls `GET /api/v2/bootstrap` to discover which organizations and workspaces (`trader` / `supplier` / `hybrid`) they can act as.

---

# 1. Connection basics

## 1.1 Base URL

```
https://<your-domain>/api
```

Set it per flavour (`dev` / `staging` / `prod`). Never hardcode it in a widget.

## 1.2 Headers

| Header | When | Notes |
|---|---|---|
| `Authorization: Bearer <jwt>` | every authenticated call | The **Android convention**. |
| `jwt: <jwt>` | alternative | The **iOS convention**. The server accepts either — `helper.php::jwt()` checks the `jwt` header first, then `Authorization: Bearer`. Pick one and use it everywhere. |
| `X-Organization-Id: <id>` | every `/v2` call | Which organization you are acting as. **Omit it and the server falls back to the user's `primary_organization_id`.** Send it explicitly once the user can switch orgs. |
| `Accept-Language: ar` / `en` | every call | Drives every `*_name`, `*_text`, `title`, `body` field, plus push copy. Unknown/missing → defaults to **`ar`**. |
| `Accept: application/json` | every call | |
| `X-Fleet-Company-Id` / `X-Fleet-Session-Token` | fleet-company portal only | Not used by the customer app. |

The `jwt` is **not** a JWT despite the name — it is a 200-char random string stored in `users.jwt`. It **never expires** and is only rotated when the user's row has an empty `jwt` at login. There is no refresh-token flow. Store it in secure storage and treat a `400 validation_error` naming `user_id` as "logged out".

## 1.3 Authentication mechanics (important)

There is no auth middleware. Instead, `App\Http\Middleware\ResolveApiRequestContext` runs on every `/api/*` route and:

1. Merges path parameters into the request input — `GET /v2/purchase_orders/91` makes `$request->purchase_order_id == 91`.
2. If the body/query has no `user_id`, resolves it from the token header and merges it in.
3. Maps `X-Organization-Id` → `organization_id`, `X-Fleet-Company-Id` → `fleet_company_id`, `X-Fleet-Session-Token` → `session_token`.

Then each controller validates:

```php
'user_id' => 'required|exists:users,id,deleted,0,status,active,jwt,<the token you sent>'
```

**Consequence:** a bad/missing/expired token produces **`400 validation_error`** with `bag.user_id`, *not* a `401`. Your Dio interceptor must treat that specific shape as an auth failure.

## 1.4 Rate limiting

`app/Http/Kernel.php` puts `throttle:60,1` on the whole `api` group — **60 requests/minute per IP**, on top of the per-route throttles noted in the tables below (e.g. `throttle:10,1` on login). Exceeding it returns **`429`** with `Retry-After` + `X-RateLimit-*` headers. Build backoff into the client; do not poll tracking endpoints faster than ~5 s.

---

# 2. Request conventions

Converted from POST-only RPC to REST on 2026-09-03 (`docs/api-rest-migration.md` holds the old→new map).

| Verb | Shape | Meaning |
|---|---|---|
| `GET` | `/things`, `/things/{id}` | list / show. **Filters go in the query string.** Arrays as `sku_ids[]=1&sku_ids[]=2`. |
| `POST` | `/things` | create |
| `PATCH` | `/things/{id}` | partial update |
| `PATCH` | `/things/{id}/status` | state transition — `status` (+ optional `note`) in the body |
| `PUT` | `/things/{id}/...` | idempotent replace / upsert |
| `DELETE` | `/things/{id}` | delete (a body is still allowed for optional fields such as `reason`) |
| `POST` | `/things/{id}/<verb>` | command that is not plain CRUD (`submit`, `cancel`, `claim`, `follow`, `toggle`) |

**Every `{..._id}` path segment is constrained to `[0-9]+`** (except Nafath `transaction_id`, which is `[A-Za-z0-9_\-]+`). Sending a non-numeric id gives a **404 from the router**, not a validation error.

**Multipart uploads stay `POST`** because PHP only parses multipart bodies on POST. That applies to: profile image, product image/gallery, pack subscription receipt, order payment receipt, search-request attachments, organization logo/cover, onboarding documents, and the generic `/v2/uploads`.

**`user_id` and `organization_id` never need to be sent** — headers cover both. Sending them explicitly still works and wins over the headers.

---

# 3. Response conventions

Every response goes through `helper.php::r_json()`.

## 3.1 Success

There is **no `{status, data}` envelope**. The controller's array *is* the body:

```jsonc
// GET /api/v2/purchase_orders/91
{ "purchase_order": { "id": 91, "code": "PO-...", ... } }

// GET /api/v2/wallet
{ "wallet": { ... } }

// GET /api/v2/catalog/suppliers   ← a Laravel paginator, verbatim
{ "current_page": 1, "data": [ ... ], "last_page": 3, "per_page": 15, "total": 41, ... }
```

`204 No Content` with an **empty body** is used for many successful mutations (`PATCH /api/auth/city`, `DELETE /api/auth/addresses/{id}`, `POST /api/favorites/{id}/toggle`, `PATCH /api/orders/{id}/status`, …). Do not try to decode it.

## 3.2 List endpoints: the paginator + `formatted` pattern

All `/v2` list endpoints return the raw Laravel paginator. Each row is the **Eloquent model** with a **`formatted` key** holding the mobile-shaped payload:

```jsonc
{
  "current_page": 1,
  "data": [
    {
      "id": 91,
      "supplier_organization_id": 7,      // ← raw model columns, ignore these
      "created_at": "2026-09-19 12:00:00",
      "formatted": {                      // ← THIS is what you map to your Dart model
        "id": 91, "code": "PO-20260919-AB12CD34", "status": "approved",
        "subtotal": 1200.0, "tax_total": 180.0, "grand_total": 1380.0,
        "supplier": { "id": 7, "display_name": "..." }, "..."
      }
    }
  ],
  "first_page_url": "...", "from": 1, "last_page": 3, "last_page_url": "...",
  "next_page_url": "...", "path": "...", "per_page": 15, "prev_page_url": null,
  "to": 15, "total": 41
}
```

**Rule: parse `data[].formatted`, not `data[]`.** Detail (`show`) endpoints return the same formatted payload directly under a named key (`{"purchase_order": {...}}`) with extra detail fields.

Paging: `?limit=N` sets the page size on most v2 lists (default **15**); notifications use `?per_page=N` (default **20**, max 100). The page itself is always `?page=N`.

## 3.3 Errors

| Status | Body | Meaning |
|---|---|---|
| **400** | `{"msg":"validation_error","bag":{"field":["message", ...]}}` | Laravel validation failed. **This is the 422 you were expecting — there is no 422 for validation.** |
| **400** | `{"msg":"some_snake_case_reason"}` | Business-rule rejection (`qty_less_than_min_order_qty`, `invoice_or_due_schedule_required`, …). |
| **401** | `{"msg":"<translated text>"}` | v1 only, for credential-style failures (`invalid_password`, `invalid_email`, `email_exists`, `insufficient_product_count`, …). **v1 `msg` here is human-readable localized text, not a code.** |
| **403** | `{"msg":"permission_denied","permission":"purchase_orders.manage"}` | Membership lacks the permission. Also `organization_membership_not_found`, `organization_workspace_not_allowed`. |
| **404** | `{"msg":"<entity>_not_found"}` | |
| **409 / 410 / 422 / 500** | `{"msg":"<code>"}` | Used sparingly — see the per-endpoint tables. |
| **429** | throttle body | Rate limited. |

`bag` is Laravel's MessageBag: `{"email":["The email field is required."],"phone":["..."]}`. Messages are localized by `Accept-Language`. **Key off the field names, not the message text.**

## 3.4 Two traps that will break your models

### Trap 1 — `JSON_NUMERIC_CHECK`

`r_json()` encodes with `JSON_NUMERIC_CHECK`. **Every numeric-looking string becomes a JSON number.** So:

- `"iban": "1234567890"` arrives as `1234567890` (int)
- `"phone": "0501234567"` would arrive as `501234567` — **leading zero lost**
- `"barcode": "0012345"` → `12345`
- `"code": "20260919"` → `20260919` (number)

**Never type a field as `String` and hope.** Every scalar that can look numeric must go through a coercion helper:

```dart
String asStr(dynamic v) => v == null ? '' : v.toString();
double asNum(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int    asInt(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
bool   asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
```

### Trap 2 — the `m_p` prefix

To defend free-text fields against Trap 1, the backend prepends the literal string **`m_p`** to certain values. You must strip it:

```dart
String unwrap(dynamic v) {
  final s = v == null ? '' : v.toString();
  return s.startsWith('m_p') ? s.substring(3) : s;
}
```

Fields known to carry it:

| Endpoint | Field(s) |
|---|---|
| `POST /api/auth/login`, `/register`, `/profile` | `user.phone` |
| `GET /api/v2/bootstrap` | `user.phone` |
| `GET /api/auth/addresses`, and `user.addresses[]` everywhere | `text`, `number`, `close_to`, `notes` |
| `GET /api/chat/{with_id}` | `data[].text` |

Apply `unwrap()` defensively on every user-authored string — the prefix may be added to more fields over time.

## 3.5 Dates, money, images

- **Dates** are `"Y-m-d H:i:s"` strings in **server local time, no timezone offset**. Some fields return `""` (empty string) instead of `null` when unset — handle both. A few v1 fields are UNIX timestamps (`timestamp` on notifications/chat).
- **Money** is a plain number (`1380.0`), rounded to 2 dp server-side. Currency lives beside it as `currency` / `currency_code`, defaulting to `"SAR"`. Use `Decimal`/int-minor-units for any client-side arithmetic; never re-derive totals the server already sent.
- **Images** come back as **absolute URLs already** (`legacy_upload_url()` → `https://host/uploads/<folder>/<file>`). Do not prepend the base URL. An unset image is `""`; the user default is `web_assets/images/default-user.png`. `proof_file` / `file_path` fields on v2 documents are **relative storage paths**, not URLs — pair them with the `file_url` returned by the upload endpoint.

---

# 4. v1 — marketplace endpoints

Namespace `App\Http\Controllers\Api`. Auth is `user_id` + token unless marked **public**.

## 4.1 Settings (all public)

| Method | Path | Response |
|---|---|---|
| `GET` | `/api/countries` | Array of `{id, name, currency, tax_percentage, cities:[{id,name}]}` — main countries with their sub-cities. Needed for the register form. |
| `GET` | `/api/abouts` | `{text}` (HTML) |
| `GET` | `/api/terms` | `{text}` (HTML) |
| `GET` | `/api/privacy` | `{text}` (HTML) |
| `GET` | `/api/support` | `{phone, whatsapp, email, hours}` |

## 4.2 Auth

### `POST /api/auth/register` — public, `throttle:10,1`

| Field | Rule |
|---|---|
| `type` | required, `seller` \| `buyer` |
| `first_name`, `last_name` | required |
| `company_name` | optional (**required-unique for `type=seller`** — a duplicate returns `401 company_name_exists`) |
| `email` | required, email, must be unused → `401 email_exists` |
| `phone` | required, numeric, must be unused → `401 phone_exists` |
| `password` | required, min 6 |
| `token` | required unless `fcm_token` is sent — the FCM device token |
| `fcm_token` | preferred alias for `token` |
| `country_id` | required, `countries.id` where `type=main` |
| `city_id` | required, `countries.id` where `type=sub` |
| `address` | optional — creates the user's `main` address |
| `bank_info` | optional free text |
| `platform` | optional `android`\|`ios`\|`web` (sniffed from UA otherwise) |
| `app_variant` | optional `driver`\|`supplier`\|`trader`\|`owner`\|`admin` |
| `locale`, `device_id`, `device_model`, `os_version` | optional push-registration metadata |

**200** → `{ "user": { id, jwt, type, first_name, last_name, company_name, email, phone: "m_p…", image, country_id, city_id, addresses: [...], is_driver, ... } }`
**Persist `user.jwt`.** Errors: `400 validation_error`, `401 {email_exists|phone_exists|company_name_exists}`.

### `POST /api/auth/login` — public, `throttle:10,1`

Body: `email`, `password`, `token`/`fcm_token` (+ the same optional device metadata).
**200** → same `{user}` payload as register. Errors: `401 invalid_email`, `401 invalid_password`, `200 {"status":"failed","msg":"suspended user"}` for a suspended account — **note this one is a 200, check `status` before assuming success.**

### `PUT /api/auth/device_token`

Body: `token` or `fcm_token` (+ `platform`, `app_variant`, `locale`, `device_id`, `device_model`, `os_version`). Idempotent upsert into `tokens` and `push_tokens`. **204.** Call on every cold start and on FCM token refresh.

### `POST /api/auth/profile` — **multipart**

`first_name`, `last_name`, `email`, `phone` required; `company_name`, `bank_info`, `image` (image file) optional. **200** → `{user}`. Errors `401 email_exists|phone_exists|company_name_exists`.

### `PATCH /api/auth/password` — `throttle:10,1`
`old_password`, `new_password` (min 6). **204.** `401 old_password_incorrect`.

### `PATCH /api/auth/city`
`city_id`. **204.**

### Password reset
| Method | Path | Body | Response |
|---|---|---|---|
| `POST` | `/api/auth/password/forgot` | `email` | **204** — e-mails a 6-digit code valid for 1 h. `throttle:6,1` |
| `POST` | `/api/auth/password/verify_code` | `code` | **200** `{user:{id, jwt}}` — use this `jwt` for the next call. `throttle:10,1` |
| `POST` | `/api/auth/password/reset` | `password` (min 6) | **204.** `throttle:6,1` |

### Addresses
| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/api/auth/addresses` | — | Array of `{id, city_id, text, number, close_to, notes, city}` — **`text`/`number`/`close_to`/`notes` are `m_p`-prefixed.** |
| `POST` | `/api/auth/addresses` | `city_id`, `text`, `number`, `close_to`, `notes` — **all required** | `{id}` |
| `PATCH` | `/api/auth/addresses/{address_id}` | same 5 fields, all required | the address list |
| `DELETE` | `/api/auth/addresses/{address_id}` | — | **204** (soft delete) |

### Notifications (legacy feed)
| Method | Path | Response |
|---|---|---|
| `GET` | `/api/auth/notifications` | Paginator of `{id, type, action_id, text, timestamp}` (20/page) |
| `DELETE` | `/api/auth/notifications/{notification_id}` | **204** |

> Same rows as the v2 bell. Prefer `GET /api/v2/notifications` in the B2B app — it adds `event_code`, `entity_type`, `entity_id`, `is_read`, `unread_count`.

## 4.3 Public/contact

| Method | Path | Body | Notes |
|---|---|---|---|
| `POST` | `/api/contact_us` | `name`, `email`, `phone`(numeric), `text` | **204** |
| `POST` | `/api/search_requests` | **multipart** — `type` (`product`\|`seller`), `name`, `email`, `phone`, `text`, `address`, `attachments[]` (files, optional) | **204** |
| `GET` | `/api/sellers/{seller_id}` | — | `{id, first_name, last_name, image, country, city, email, phone, whatsapp, company_name, products: <paginator of {id,name,image,price_meta,is_favorite,is_cart}>}` |

## 4.4 Home & catalog

| Method | Path | Query | Response |
|---|---|---|---|
| `GET` | `/api/home` | — | `{sliders:[{url,image}], categories:[{id,type,name,image}] (5), best_selling:[…9], most_viewed:[…9], discount:[…9], cart_count:int}` |
| `GET` | `/api/search` | `text` **required** | Paginator of products. Arabic/Latin detected from the query; matches `ar_name` or `en_name`. |
| `GET` | `/api/categories` | `parent` **required numeric** — `0` = top level | `[{id, name, image, subs:bool}]` |
| `GET` | `/api/categories/{cat_id}/products` | — | Paginator of products. `cat_id` must be a **`type=sec`** (third-level) category. |
| `GET` | `/api/products` | `type` **required**: `best_selling` \| `most_viewed` \| `discount` | Paginator of products |
| `GET` | `/api/products/{product_id}` | — | see below |
| `POST` | `/api/products` | **multipart**, sellers only | see below |

**Product list item:** `{id, type, name, image, price_meta: {price, sale_price, sale_till, sale, count}, is_favorite, is_cart}`.
Products are **scoped to the caller's `country_id`**. Requesting a product from another country returns `401 product_not_same_country_as_user`.

**`GET /api/products/{product_id}` → 200**
```jsonc
{
  "product": {
    "id": 12, "name": "…", "image": "https://…", "rate": 4,
    "type": "static" | "variable",
    "price_meta": {"price":100,"sale_price":90,"sale_till":"","sale":1,"count":20},
    "is_negotiated": 0, "discount": 1,
    "category": {"id": 33, "name": "…"},
    "desc": "…", "custom": "…",
    "images": [{"image": "https://…"}],
    "variations": [], "variations_data": [],   // populated when type == "variable"
    "is_favorite": false, "is_cart": false
  },
  "seller": {"id":7,"first_name":"…","last_name":"…","image":"https://…","phone":…,"whatsapp":…,"country":{"name":"…"}},
  "similars": [ /* 2 product list items */ ]
}
```
Calling this **increments the product's view counter** — do not prefetch it in a list.

**`POST /api/products`** (multipart, caller must be `type=seller`, else `403 not_seller`):
`city_id`, `sec_cat_id`, `ar_name`, `en_name`, `ar_desc`, `en_desc`, `is_negotiated` (`0|1`), `price`, `count`, `image` (required, jpg/jpeg/png/tif/gif/webp) — plus optional `ar_custom`, `en_custom`, `sale_price`, `sale_till` (date), `images[]`.
**200** → `{msg:"created", product_id}`.

## 4.5 Favourites

| Method | Path | Response |
|---|---|---|
| `GET` | `/api/favorites` | Paginator of product list items |
| `POST` | `/api/favorites/{product_id}/toggle` | **204** — adds if absent, removes if present. Flip your local state optimistically. |

## 4.6 Cart & checkout

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/api/cart` | — | see below. **Buyers only** (`type,buyer` is in the validation rule) — a seller account gets `400 validation_error`. |
| `POST` | `/api/cart` | `product_id`, `product_variation_id` (numeric; send `0` for `static` products), `count` (integer) | the same cart payload |
| `DELETE` | `/api/cart/{cart_id}` | — | the same cart payload |
| `POST` | `/api/cart/checkout` | `address_id` | see below |

**Cart payload:**
```jsonc
{
  "carts": { "current_page":1, "data":[ {"id":5,"product_id":12,"product_variation_id":0,"count":2,"price":180,
             "product":{"id":12,"type":"static","name":"…","image":"…","price_meta":{…}}} ], "per_page":21, … },
  "totals": { "total": 180, "tax": 23.48, "cart": 156.52 },
  "addresses": [ {"id":3,"text":"…"} ]
}
```
`totals.total` is the **gross** (tax-inclusive) sum; `totals.cart` is `total - tax`. Country tax % comes from `countries.tax_percentage`.

Errors on `POST /api/cart`: `401 insufficient_product_count`, `401 product_not_same_country_as_user`.

**`POST /api/cart/checkout` → 200** `{ "totals": {total, tax, items}, "seller_info": {id, first_name, last_name, company_name, bank_info} }`

Checkout **splits the cart by seller and creates one `Order` per seller**, decrements stock, pushes a notification to each seller, then **empties the cart**. The returned `totals`/`seller_info` describe only the *last* seller processed — after checkout, refresh `GET /api/orders` to show what was actually created. It returns `401 insufficient_product_count` mid-loop if stock ran out, **after some orders may already have been created**; always re-fetch orders on any checkout outcome.

## 4.7 Orders

| Method | Path | Query / Body | Response |
|---|---|---|---|
| `GET` | `/api/orders` | `status` **required**: `all`\|`pending`\|`confirmed`\|`processing`\|`delivered`\|`declined` | Paginator of `{id, status, code, items_count, timestamp, merchant:{id,first_name,last_name,image}}` |
| `GET` | `/api/orders/{order_id}` | — | see below |
| `POST` | `/api/orders/{order_id}/receipt` | **multipart** `image` (required) | **204** — uploads the bank-transfer proof and notifies the seller |
| `PATCH` | `/api/orders/{order_id}/status` | `status`: `confirmed`\|`processing`\|`delivered`\|`declined` | **204** — **seller-only**; the route validates `orders.seller_id == caller` |

The list auto-detects the caller's side from `users.type` (`seller` → orders they received; `buyer` → orders they placed) and `merchant` is always **the other party**.

**`GET /api/orders/{order_id}` → 200** (object)
```jsonc
{
  "id": 44, "status": "pending", "status_lang": "قيد الانتظار", "code": 1234567890,
  "address": "…", "items_count": 2, "items_fee": 156.52, "tax_fee": 23.48, "total_fee": 180,
  "timestamp": "2026-09-19 12:00:00", "image": "…",
  "merchant": {"id":7,"first_name":"…","last_name":"…","image":"…","bank_info":"…"},
  "items": [ {"id":12,"type":"static","name":"…","image":"…","price_meta":{…}} ]
}
```
`404 order_not_found`; `401 user_not_allowed` if the caller is neither the buyer nor the seller.

> **Known backend quirk:** in `items[]` the controller builds per-line `price`/`count`/`options_str` but pushes only the `product` object. Render quantities from your own cart/PO state, or ask backend to include the line data — do not expect `count` inside `items[]`.

## 4.8 Subscription packs

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/api/packs` | `country_id` **required** (query) | `{user:{pack_id, expire_at, pack:{name,price,image}}, packs:[{id,name,price,image}], banks:[{id,name,desc}]}` |
| `POST` | `/api/packs/{pack_id}/subscribe` | **multipart** — `country_id`, `bank_id`, `user_name`, `account_no`, `user_notes`, `image` (transfer receipt) | **204** — creates a `BankTransfer` for admin review |

## 4.9 Chat

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/api/chat` | — | `[{id, first_name, last_name, image, message:{…latest…}}]` — **plain array, not a paginator** |
| `GET` | `/api/chat/{with_id}` | — | Paginator (20) of `{id, sender_id, text, timestamp}` newest-first; **`text` is `m_p`-prefixed**; fetching marks them read |
| `POST` | `/api/chat` | `sender_id` (required — **this one is NOT auto-filled, send it**), `target_id`, `text` | **204**; broadcasts a `BroadcastMsg` event + FCM push |

Live delivery is a Laravel broadcast event (`BroadcastMsg`) carrying `{message, date, image}`. Confirm the broadcaster/Pusher credentials with backend before wiring a socket; otherwise poll `GET /api/chat/{with_id}` and rely on the `click_action: "chat"` push.

---

# 5. v2 — B2B platform endpoints

Namespace `App\Http\Controllers\Api\V2`. **All calls need the token + an organization context.** Most also need a **permission** on the caller's membership — the organization **owner bypasses every permission check**.

Standard context errors on any v2 route:
`400 validation_error` (bad/absent token or `organization_id`) · `403 organization_membership_not_found` · `403 organization_workspace_not_allowed` · `403 {"msg":"permission_denied","permission":"<code>"}`

## 5.1 Bootstrap — call this right after login

### `GET /api/v2/bootstrap`
```jsonc
{
  "user": { "id":1, "name":"…", "legacy_type":"buyer", "workspace_type":"trader",
            "available_workspaces":["trader"], "primary_organization_id":3,
            "image":"https://…", "email":"…", "phone":"m_p0501234567" },
  "organizations": [{
    "id":3, "display_name":"…", "business_mode":"trader|supplier|hybrid",
    "supplier_nature":"manufacturer|supplier|both|", "status":"draft|pending_review|active|suspended|blacklisted",
    "is_owner":true, "default_branch_id":9,
    "approved_workspaces":["trader"],
    "journey": { "state":"setup|…", "state_label":"…", "profiles_ready":1, "profiles_pending":0,
                 "hybrid_ready":false, "next_best_action":"…",
                 "trader":{"status":"draft|active|…","score":80,"missing":["…"]},
                 "supplier":{…},
                 "timeline":[{"date":"…","title":"…","status":"…","text":"…"}] },   // last 5
    "roles":[{"code":"owner","name":"…"}],
    "permissions":["purchase_orders.manage", "..."],
    "branches":[{"id":9,"type":"hq","name_ar":"…","name_en":"…","is_default":true,"status":"active","address_text":"…"}],
    "stats":{"products_count":0,"skus_count":0,"relationships_count":2,"open_drafts_count":1,
             "open_orders_count":4,"bank_accounts_count":1}
  }],
  "feature_flags": { "single_app_workspaces":true, "catalog_v2_enabled":true, "pricing_v2_enabled":true,
                     "purchase_v2_enabled":true, "delivery_v2_enabled":true, "receivables_v2_enabled":true,
                     "collections_v2_enabled":true, "adjustments_v2_enabled":true, "contracts_v2_enabled":true,
                     "shelf_v2_enabled":true, "settlements_v2_enabled":true, "dashboards_v2_enabled":true,
                     "credit_strict_mode":true, "legacy_orders_read_only":true, "legacy_pack_enforcement":false },
  "platform_flags": { "payment_gateway_enabled":true, "apple_pay_enabled":true, "bank_transfer_enabled":true,
                      "credit_module_enabled":false, "nafath_enabled":true, "default_commission_rate":…,
                      "default_trial_days":…, "shelf_settlement_period":… }
}
```

**This response drives the whole app shell:** which tabs to show (`business_mode`, `approved_workspaces`), which actions to enable (`permissions`), which modules to hide (`feature_flags` / `platform_flags`), and whether to route into onboarding (`journey.state`, `organizations[].status`). Cache it and re-fetch on org switch, login, and resume.

### `GET /api/v2/platform/flags`
`{flags: {...}}` — the `platform_flags` subset, callable before an org context exists.

## 5.2 Onboarding (`/api/v2/onboarding/...`)

| Method | Path | Body | Response |
|---|---|---|---|
| `POST` | `/api/v2/onboarding/register_owner` | `business_mode` (`trader`\|`supplier`\|`hybrid`), `first_name`, `last_name`, `organization_name`, `email` (unique), `phone` (optional, unique), `whatsapp` (optional), `password` (min 6), `token` (FCM), `country_id` (main), `city_id` (sub of `country_id`), `address`, `sector_ids[]` (optional) | `{user, organization_id, approved_workspaces, next_screen, b2b_workspace}` — **this is the B2B sign-up; it creates user + organization in one shot and returns the `jwt`.** |
| `GET` | `/api/v2/onboarding/bootstrap` | — | `{organization, journey, profiles}` |
| `PUT` | `/api/v2/onboarding/organization` | `legal_name_ar`*, `legal_name_en`, `trade_name`*, `country_id`*, `city_id`*, `commercial_reg_no`, `tax_no`, `vat_no`, `notes` | `{msg, organization}` |
| `PUT` | `/api/v2/onboarding/profile` | `profile_type`* (`trader`\|`supplier`), `profile_id`, `supplier_nature` (`manufacturer`\|`supplier`\|`both`), `sector_ids[]`, `channel_codes[]`, `notes` | `{msg, profile, organization}` |
| `POST` | `/api/v2/onboarding/profile/submit` | `profile_type`* | `{msg, profile}` — sends the profile for review |
| `POST` | `/api/v2/onboarding/branches` | **upsert** (`branch_id` optional): `branch_type`* (`hq`\|`warehouse`\|`store`\|`delivery_point`\|`shelf_location`), `name_ar`*, `name_en`, `country_id`*, `city_id`*, `address_text`*, `contact_name`, `contact_phone` | `{msg, branch}` |
| `POST` | `/api/v2/onboarding/bank_accounts` | **upsert** (`bank_account_id` optional): `bank_name`*, `account_name`*, `account_number`, `iban`, `swift_code`, `currency_code`, `raw_details` | `{msg, bank_account}` |
| `POST` | `/api/v2/onboarding/documents` | **multipart, upsert** (`document_id` optional): `document_type`*, file, `issued_at`, `expires_at` (≥ `issued_at`), `notes` | `{msg, document}` |

`*` = required. Document types come from `config/b2b_documents.php`.

**Owner console bridge** — the same handlers are also exposed under `/api/v2/b2b/owner-console/...` with extra `GET` listings (`/branches`, `/employees`, `/documents`, `/bank_accounts` → `{items}`) and `POST /employees`, `POST /request_workspace` (`workspace`: `trader`\|`supplier`), `POST /submit_for_review`. Use these if the app embeds the owner console.

`POST .../employees` body: `name`*, `email`, `phone`, `whatsapp`, `job_title`, `role`, `role_id`, `role_ids[]`, `status` (`active`\|`suspended`), `default_branch_id`, `password` (min 6, `confirmed`) → `{msg, employee, temporary_password}`.

## 5.3 Organization

| Method | Path | Perm | Notes |
|---|---|---|---|
| `GET` | `/api/v2/organizations` | — | `{user}` + the caller's memberships |
| `GET` | `/api/v2/organization` | — | `{organization}` — see fields below |
| `PATCH` | `/api/v2/organization` | `organizations.manage` | `trade_name`, `legal_name_ar/en`, `business_mode` (`trader`\|`supplier`\|`hybrid`), `supplier_nature`, `tax_no`, `commercial_reg_no`, `vat_no`, `notes`, `status` |
| `POST` | `/api/v2/organization/branches` | `branches.manage` | `branch_type`* + `name_ar`/`name_en` (**one of the two required** → `400 branch_name_required`), `country_id`, `city_id`, `address_text`, `contact_name`, `contact_phone`, `latitude`, `longitude`, `is_default`, `status` |
| `PATCH` | `/api/v2/organization/branches/{branch_id}` | `branches.manage` | same fields, all `sometimes`. `404 branch_not_found` |
| `POST` | `/api/v2/organization/logo` | `organization.edit` | **multipart** `file` — jpg/jpeg/png/webp, ≤ 5 MB → `{msg, organization_id, field, file_path, file_url}` |
| `POST` | `/api/v2/organization/cover` | `organization.edit` | same |
| `PATCH` | `/api/v2/organization/bio` | `organization.edit` | `bio` ≤ 1000 → `{msg, organization_id, bio}` |

**`organization` payload:** `id, code, display_name, trade_name, legal_name_ar, legal_name_en, business_mode, supplier_nature, status, tax_no, commercial_reg_no, vat_no, country, city, is_owner, default_branch_id, roles[], permissions[], stats{}` — plus `notes, branches[], bank_accounts[], documents[]` on `show`.
**`branch` payload:** `id, type, name_ar, name_en, address_text, country_id, city_id, contact_name, contact_phone, latitude, longitude, is_default, status`.

### Organization social feed

| Method | Path | Body / Query | Response |
|---|---|---|---|
| `GET` | `/api/v2/organization/posts` | `limit` (1–50), `before_id` | `{organization_id, items, has_more}` — **cursor pagination, not a paginator** |
| `POST` | `/api/v2/organization/posts` | `body` ≤ 4000, `image_url` ≤ 500 | `{msg, post}`; `400 invalid_image_url` |
| `DELETE` | `/api/v2/organization/posts/{post_id}` | — | `{msg}`; `403 not_authorized` |
| `POST` | `/api/v2/organization/posts/{post_id}/like` | — | toggles the like |
| `GET` | `/api/v2/organization/posts/{post_id}/comments` | `limit` (1–100) | `{items}` |
| `POST` | `/api/v2/organization/posts/{post_id}/comments` | `body`* ≤ 2000 | `{msg, comment}` |
| `DELETE` | `/api/v2/organization/comments/{comment_id}` | — | `{msg}`; `403 not_authorized` |

## 5.4 Suppliers & relationships

### Discover suppliers
| Method | Path | Query | Response |
|---|---|---|---|
| `GET` | `/api/v2/catalog/suppliers` | `search`, `status`, `limit` | Paginator; each row has `formatted` (below) |
| `GET` | `/api/v2/catalog/suppliers/{supplier_organization_id}` | — | `{supplier}`; `404 supplier_organization_not_found` |
| `GET` | `/api/v2/suppliers/{supplier_organization_id}/public_catalog` | `limit` (1–50), `search` | `{supplier_organization_id, total_active_count, items}` — browsable **before** a relationship exists |

**Supplier `formatted`:** `id, display_name, business_mode, supplier_nature, status, profile_status, sectors[{id,name}], relationship_id, relationship_status ("none" when absent), relationship_classification, active_contracts_count, has_active_contract, latest_contract{id,display_name,contract_type,status}, products_count, skus_count, branches_count, order_entry_ready`.

> **`order_entry_ready`** is the single boolean gating the "Create order" button: the relationship must be `approved`/`active` **and** there must be ≥ 1 active contract.

### Follow
| Method | Path | Response |
|---|---|---|
| `POST` | `/api/v2/suppliers/{id}/follow` | `{msg, supplier_organization_id, is_following, follower_count}`; `400 cannot_follow_self` |
| `DELETE` | `/api/v2/suppliers/{id}/follow` | same |
| `GET` | `/api/v2/suppliers/{id}/follow` | `{supplier_organization_id, is_following}` |
| `GET` | `/api/v2/suppliers/following` | `{items}` |

### Relationships
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/relationships` | — | `?status=&limit=` → paginator |
| `POST` | `/api/v2/relationships` | `relationships.manage` | `counterparty_organization_id`*, `as` (`trader`\|`supplier`), `classification` (`A`–`D`), `status`, `notes`, and credit-profile seeds: `credit_limit`, `grade`, `max_due_days`, `max_overdue_days`, `upfront_required_percent`, `auto_freeze_on_limit`, `auto_freeze_on_overdue`, `review_cycle_days`. **Quota-gated** (`plan.quota:max_active_relationships`). `400 invalid_counterparty_organization` |
| `GET` | `/api/v2/relationships/{relationship_id}` | — | `{relationship}` |
| `PATCH` | `/api/v2/relationships/{relationship_id}/status` | `relationships.manage` | `status`*: `pending_review`\|`approved`\|`suspended`\|`blacklisted`\|`closed`, `notes` |

**`relationship` payload:** `id, my_role, classification, status, opened_at, closed_at, supplier{}, trader{}, counterparty{}, credit{}, contracts_count, open_purchase_orders_count` (+ `notes` on show).

### Credit
| Method | Path | Perm | Notes |
|---|---|---|---|
| `GET` | `/api/v2/relationships/{id}/credit` | — | `{relationship_id, credit_profile, credit_exposure}` |
| `PUT` | `/api/v2/relationships/{id}/credit` | `credit.manage` | `grade`* (`A`–`D`), `credit_limit`*, `currency_code`, `max_due_days`, `max_overdue_days`, `upfront_required_percent` (0–100), `auto_freeze_on_limit`, `auto_freeze_on_overdue`, `review_cycle_days`, `status`. **Supplier side only** → `403 credit_profile_can_only_be_managed_by_supplier_side` |

`credit_profile`: `id, grade, credit_limit, currency_code, max_due_days, max_overdue_days, upfront_required_percent, auto_freeze_on_limit, auto_freeze_on_overdue, review_cycle_days, status`
`credit_exposure`: `id, open_orders_amount, issued_invoices_amount, due_amount, overdue_amount, available_credit, last_calculated_at`

## 5.5 Catalog & pricing

| Method | Path | Perm | Query / Body |
|---|---|---|---|
| `GET` | `/api/v2/catalog/products` | — | `?search=&category_id=&status=&payment_term_id=&limit=` → paginator |
| `GET` | `/api/v2/catalog/products/{product_id}` | — | `{product}` with `skus[]`; `403 product_not_accessible`, `404 product_not_found` |
| `PUT` | `/api/v2/catalog/products/{product_id}/skus/{sku_id}/rules` | `catalog.manage` + `pricing.manage` | `business_sector_ids[]`, `min_order_qty`, `order_step_qty`, `pack_quantity`, `sku_status` (`active`\|`suspended`\|`blocked`), `barcode` ≤128, `barcode_required`, `tiers[]{payment_term_id, min_qty, max_qty, final_price}` |

**`product` payload:** `id, organization_id, name, ar_name, en_name, type, status, image, thumb_image, discount, is_negotiated, supplier{}, relationship_id, relationship_status, categories[], skus_count, primary_sku{}` (+ `catalog_readiness{}, skus[]` on show).

**`sku` payload:** `id, sku_code, name, display_name_ar, display_name_en, packaging_type, unit_label_ar, unit_label_en, pack_quantity, min_order_qty, order_step_qty, barcode, barcode_required, status, track_inventory, has_batch, has_expiry, attribute_options[], available_qty, pricing{}` (+ `business_sectors[], general_tiers[], relationship_tiers_count, contract_tiers_count, catalog_checklist{}` on show).

### Pricing
| Method | Path | Perm | Notes |
|---|---|---|---|
| `GET` | `/api/v2/pricing/payment_terms` | — | `{payment_terms}` |
| `GET` | `/api/v2/pricing/price_lists` | — | paginator |
| `POST` | `/api/v2/pricing/price_lists` | `pricing.manage`, supplier | **upsert** (`price_list_id` optional): `scope_type`* (`default`\|`organization`\|`relationship`\|`contract`\|`campaign`), `scope_id` (required for non-default → `400 scope_id_required_for_selected_scope`), `name_ar`/`name_en` (one required → `400 price_list_name_required`), `currency_code`, `start_date`, `end_date`, `status` |
| `POST` | `/api/v2/pricing/price_items` | `pricing.manage`, supplier | `price_list_id`*, `sku_id`*, `payment_term_id`, `min_qty`*, `max_qty`, `unit_price`*, `discount_type` (`amount`\|`percent`), `discount_value`, `tax_included`. `403 sku_not_belong_to_current_organization` |
| `GET` | `/api/v2/pricing/resolve` | — | `?sku_id=*&qty=&payment_term_id=&relationship_id=` |

**`GET /pricing/resolve` → 200** — **call this before adding a draft line so the UI shows the real tiered price.**
```jsonc
{ "sku_id": 55, "relationship_id": 12, "available_qty": 340.0,
  "pricing": { "matched": true, "source": "…", "scope_type": "relationship", "scope_id": 12,
               "price_list_id": 4, "price_list_name": "…", "payment_term_id": 2,
               "currency_code": "SAR", "unit_price": 12.5, "final_price": 11.25,
               "unit_discount": 1.25, "discount_type": "percent", "discount_value": 10,
               "tax_included": false, "line_subtotal": 112.5 } }
```
`pricing.matched == false` (source `legacy_fallback`) means no price rule applies — block the add-to-draft.

## 5.6 Purchase drafts → purchase orders  **(the trader's core flow)**

### Drafts — trader workspace only
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/purchase_drafts` | — | `?status=&limit=` |
| `POST` | `/api/v2/purchase_drafts` | `purchase_orders.manage` | **upsert** (`draft_id` optional): `supplier_organization_id`*, `relationship_id`, `delivery_branch_id`, `payment_term_id`, `contract_id`, `notes`. Quota `max_purchase_orders_per_month`. `403 relationship_is_blacklisted` |
| `GET` | `/api/v2/purchase_drafts/{draft_id}` | — | `{draft}` |
| `POST` | `/api/v2/purchase_drafts/{draft_id}/lines` | `purchase_orders.manage` | `sku_id`*, `qty`* (min 0.001) |
| `DELETE` | `/api/v2/purchase_drafts/{draft_id}/lines/{line_id}` | `purchase_orders.manage` | |
| `POST` | `/api/v2/purchase_drafts/{draft_id}/submit` | `purchase_orders.manage` | → `{msg, purchase_order}` |

**Line-add rejections (all `400`) — surface these verbatim to the user:**
`sku_not_belong_to_draft_supplier` · `qty_less_than_min_order_qty` · `qty_not_matching_order_step` · `insufficient_supplier_inventory` · `pricing_not_found_for_sku`
**Submit rejections:** `404 draft_not_found_or_not_open` · `400 draft_has_no_lines` · `400 approved_business_relationship_required_before_submit` · `400 relationship_must_be_approved_before_submit` · `500 purchase_order_submit_failed`

**`draft` payload:** `id, status, trader_organization_id, supplier_organization_id, business_relationship_id, delivery_branch_id, payment_term_id, contract_id, notes, subtotal, tax_total, grand_total, supplier{}, payment_term{}, lines_count, lines[]`.

### Purchase orders
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/purchase_orders` | — | `?status=a,b,c` (**comma-separated multi-value**), `role=`, `credit_check_status=`, `business_relationship_id=`, `contract_id=`, `limit=` |
| `GET` | `/api/v2/purchase_orders/{id}` | — | `{purchase_order}` |
| `GET` | `/api/v2/purchase_orders/{id}/timeline` | — | event feed |
| `PATCH` | `/api/v2/purchase_orders/{id}/status` | `purchase_orders.manage` | `status`*: `under_review`\|`approved`\|`rejected`\|`ready`\|`canceled`; `note` **required (3–500) when `rejected` or `canceled`** |
| `POST` | `/api/v2/purchase_orders/{id}/cancel_request` | `purchase_orders.manage` | `reason`* 3–500. `throttle:10,1` |
| `POST` | `/api/v2/purchase_orders/{id}/cancel_request/decision` | `purchase_orders.manage` | `decision`*: `accepted`\|`rejected`; `note` required when `rejected` |

**`purchase_order` payload:** `id, code, status, credit_check_status, trader_organization_id, supplier_organization_id, business_relationship_id, payment_term_id, delivery_branch_id, requested_delivery_date, notes, subtotal, tax_total, grand_total, ordered_items_count, ordered_units_total, shipped_units_total, outstanding_items_count, outstanding_units_total, supplier{}, trader{}, payment_term{}, approvals[]`
**on `show` also:** `draft_delivery_note, next_action, viewer_role, allowed_transitions[], reason_required_for[], can_request_cancel, cancel_request{}, timeline[], lines[]`

> **Drive your UI off `allowed_transitions`, `reason_required_for`, `next_action` and `can_request_cancel`.** Do not hardcode the state machine client-side — `PurchaseOrderStatusService` owns the single transition map and it will change.

Errors: `403 credit_manage_permission_required_for_override` (the order failed the credit check and the actor lacks `credit.manage`), `500 purchase_order_status_update_failed`.

### Approvals inbox
| Method | Path | Response |
|---|---|---|
| `GET` | `/api/v2/approvals` | `{contracts}` + pending PO approvals |
| `POST` | `/api/v2/approvals/purchase_orders/{purchase_order_approval_id}` | `status`*: `approved`\|`rejected`\|`pending`, `note` → `{msg, approval}`; `403 approval_actor_not_allowed` |

## 5.7 Delivery notes & goods receipts

### Delivery notes — created by the **supplier**
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/delivery_notes` | — | `?status=&role=&purchase_order_id=&exclude_closed=&limit=` |
| `GET` | `/api/v2/delivery_notes/{id}` | — | `{delivery_note}` |
| `POST` | `/api/v2/delivery_notes` | `deliveries.manage`, supplier | **upsert**: `purchase_order_id`*, `delivery_note_id`, `supplier_branch_id`, `trader_branch_id`, `proof_file`, `notes`, `lines[]{purchase_order_line_id, sku_id, shipped_qty}`. `422 supplier_or_trader_branch_missing` |
| `PATCH` | `/api/v2/delivery_notes/{id}/status` | `deliveries.manage`, supplier | `status`*: `dispatched`\|`delivered`\|`rejected`, `proof_file`, `note`. `422 pickup_seals_required_before_dispatch` |
| `POST` | `/api/v2/delivery_notes/{id}/cancel` | `deliveries.manage`, supplier | `reason`* ∈ `out_of_stock`\|`order_canceled`\|`order_error`\|`vehicle_issue`\|`trader_request`\|`other`, `note` ≤ 500. `throttle:20,1` |
| `POST` | `/api/v2/delivery_notes/{id}/reschedule` | `deliveries.manage`, supplier | → `{msg, route, delivery_note}`. `422 delivery_note_not_reschedulable_in_status_<x>` |
| `POST` | `/api/v2/delivery_notes/{id}/seals` | `deliveries.manage`, supplier | `seals[]`* 1–50 strings ≤ 64. `409 seals_can_only_be_set_before_dispatch` |
| `GET` | `/api/v2/delivery_notes/{id}/tracking` | — | `{delivery_note}` live tracking snapshot |

**`delivery_note` payload:**
`id, purchase_order_id, purchase_order_code, code, status, cancel_reason, cancel_reason_label, cancel_note, canceled_at, supplier_branch_id, trader_branch_id, dispatched_at, en_route_at, arrived_at, delivered_at, proof_file, notes, supplier_branch{id,name}, trader_branch{id,name}, subtotal, tax_total, grand_total, currency, route_stop{}, driver{id,name,phone}, vehicle{id,plate_number}, pickup_seal_numbers[], seals_match` (+ `lines[], goods_receipts_count`).

`route_stop` = `{id, status, planned_arrival_time, actual_arrival_time, actual_departure_time, arrival_latitude, arrival_longitude, receiver_otp_status, proofs[{id, proof_type, proof_category, file_path, file_type, signer_name, signer_role, captured_at}]}`.
`proofs` is the chain-of-custody trail (pickup photo + signature at the supplier, delivery photo + signature at the trader) — render it as the visual handoff timeline.

Line: `{id, purchase_order_line_id, sku_id, sku_name, product_id, product_name, shipped_qty, accepted_qty, rejected_qty, unit_price, tax_value, line_total}`.

### Trader edit window (after dispatch, before receipt)
| Method | Path | Body |
|---|---|---|
| `GET` | `/api/v2/delivery_notes/{id}/edit_window` | — |
| `POST` | `/api/v2/delivery_notes/{id}/edit_window/adjust` | `adjustments[]`* (min 1) `{line_id*, …}` |
| `POST` | `/api/v2/delivery_notes/{id}/edit_window/close` | — |

### Goods receipts — created by the **trader**
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/goods_receipts` | — | `?status=&purchase_order_id=&delivery_note_id=&limit=` |
| `GET` | `/api/v2/goods_receipts/{id}` | — | `{goods_receipt}` |
| `POST` | `/api/v2/goods_receipts` | `deliveries.manage` + `goods_receipts.manage`, trader | `delivery_note_id`*, `proof_file`, `notes`, `lines[]{delivery_note_line_id, sku_id, received_qty, rejected_qty, rejection_reason}` |
| `POST` | `/api/v2/goods_receipts/{id}/dispute` | same | `reason`* 10–1000. `throttle:6,1`. **`410 goods_receipt_edit_window_closed`** |

**`goods_receipt` payload:** `id, purchase_order_id, delivery_note_id, receiver_organization_id, status, received_at, notes, proof_file, delivery_proof_id, delivery_proof{}, driver_delivered_qty_total, trader_accounted_qty_total, qty_mismatch_with_driver, disputed_at, disputed_by_user_id, dispute_reason` (+ `lines[]`).
`qty_mismatch_with_driver` is your "flag this receipt" signal.

## 5.8 Invoices, collections, adjustments, returns

### Invoices
| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/invoices` | — | `?status=&role=&purchase_order_id=&limit=` |
| `GET` | `/api/v2/invoices/{id}` | — | `{invoice}` |
| `POST` | `/api/v2/invoices` | `invoices.manage`, supplier | `purchase_order_id`*, `delivery_note_id`, `invoice_date`, `currency_code`, `lines[]{sku_id, qty}`. Quota `max_invoices_per_month` |
| `POST` | `/api/v2/invoices/proforma` | same | `purchase_order_id`*, `invoice_date`, `currency_code` |
| `PATCH` | `/api/v2/invoices/due_schedules/{due_schedule_id}` | `due_schedules.edit`, supplier | `due_date`, `due_amount` (≥ 0.01) |

**`invoice` payload:** `id, purchase_order_id, purchase_order{}, delivery_note_id, contract_id, business_relationship_id, payment_term_id, invoice_no, invoice_date, due_date, status, subtotal, tax_total, grand_total, currency_code, payment_term{id,display_name,name,code,term_mode,due_days,installment_count,installment_interval_days}, due_schedules[{id,installment_no,due_date,…}], outstanding_amount` (+ `lines[]`).

### Collections
| Method | Path | Perm | Body |
|---|---|---|---|
| `GET` | `/api/v2/collections` | — | `?status=&invoice_id=&limit=` |
| `GET` | `/api/v2/collections/{collection_receipt_id}` | — | `{collection_receipt}` |
| `POST` | `/api/v2/collections` | `collections.manage`, **supplier** | `amount`* ≥ 0.01, plus `invoice_id` **or** `due_schedule_id` (→ `400 invoice_or_due_schedule_required`), `payment_method` (`transfer`\|`cash`\|`cheque`\|`gateway`\|`adjustment`), `received_at`, `bank_account_id`, `reference_no`, `proof_file` |
| `POST` | `/api/v2/collections/claim` | `collections.manage` or `invoices.view`, **trader** | same minus `bank_account_id`, `payment_method` limited to `transfer`\|`cash`\|`cheque`, plus `note` ≤ 500. **This is "I paid — please confirm".** `throttle:20,1` |
| `PATCH` | `/api/v2/collections/{id}/status` | `collections.manage`, supplier | `status`*: `confirmed`\|`rejected` |

**`collection_receipt` payload:** `id, business_relationship_id, invoice_id, due_schedule_id, receipt_no, payment_method, amount, received_at, confirmed_at, reference_no, proof_file, status, invoice{id,invoice_no,status}, due_schedule{id,installment_no,due_date}`.

### Adjustment notes (debit/credit)
| Method | Path | Perm | Body |
|---|---|---|---|
| `GET` | `/api/v2/adjustments` | — | `?status=&invoice_id=&note_side=&limit=` |
| `GET` | `/api/v2/adjustments/{adjustment_note_id}` | — | `{adjustment_note}` |
| `POST` | `/api/v2/adjustments` | `adjustments.manage` or `invoices.manage`, supplier | `invoice_id`*, `note_side`* (`debit`\|`credit`), `amount`* ≥ 0.01, `reason_type` ≤ 120, `note_text`, `status` (`draft`\|`issued`) |
| `PATCH` | `/api/v2/adjustments/{id}/status` | `due_schedules.edit`, supplier | `status`*: `issued`\|`approved`\|`canceled` |

### Post-invoice returns — raised by the **trader**
| Method | Path | Perm | Body |
|---|---|---|---|
| `GET` | `/api/v2/post_invoice_returns` | — | `?status=&invoice_id=&reason_type=&limit=` |
| `GET` | `/api/v2/post_invoice_returns/{id}` | — | `{post_invoice_return}` |
| `POST` | `/api/v2/post_invoice_returns` | `adjustments.manage`, trader | `invoice_id`*, `reason_type`* (`latent_defect`\|`damage`\|`wrong_item`\|`quality`\|`other`), `reason_notes` ≤ 5000, `currency_code` (3), `lines[]`* min 1 `{invoice_line_id, sku_id, qty*, line_reason}` |
| `PATCH` | `/api/v2/post_invoice_returns/{id}/status` | — | `status`*, `reason` ≤ 2000. `403 post_invoice_return_transition_not_allowed_for_role` |

## 5.9 Dashboards, ops panel, action center

| Method | Path | Perm | Response |
|---|---|---|---|
| `GET` | `/api/v2/dashboard/overview` | `organizations.view` | `{dashboard}` |
| `GET` | `/api/v2/dashboard/aging` | `organizations.view` | `{aging}` — receivables aging buckets |
| `GET` | `/api/v2/dashboard/risk_shelf` | `organizations.view` | `{risk_and_shelf}` |
| `GET` | `/api/v2/ops/panel` | — | `?workspace=supplier\|trader&attention_limit=1..50` → `{user, organization, …}` |
| `GET` | `/api/v2/ops/quick_actions` | — | `{workspace, theme, quick_actions}` — **server-driven action buttons** |
| `GET` | `/api/v2/ops/documents` | — | `{workspace, theme, document_groups}` — **server-driven document menu** |
| `GET` | `/api/v2/action_center` | — | `?workspace=&limit=1..100` — the prioritized "what needs you now" feed |
| `POST` | `/api/v2/action_center/mark_read` | — | `ack_key` or `ack_keys[]` (one is required → `400 ack_key_required`) → `{msg, stored}` |
| `GET` | `/api/v2/document_flow/{entity_type}/{entity_id}` | — | `?timeline_limit=1..200` → `{document, …}` |
| `GET` | `/api/v2/document_flow/{entity_type}/{entity_id}/timeline` | — | `?limit=1..200` |
| `GET` | `/api/v2/health/launch_readiness` | `organizations.view` | `?relationship_id=&limit=` |
| `GET` | `/api/v2/health/reconciliation` | `audit.view` | `?relationship_id=&limit=` |

`ops/quick_actions` and `ops/documents` return **server-driven menus** (with a `theme`). Render them dynamically rather than hardcoding the home grid — that is how the backend hides modules per workspace.

## 5.10 Notifications

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/v2/notifications` | `?unread=1&per_page=20&page=1` → paginator **plus a top-level `unread_count`** |
| `PATCH` | `/api/v2/notifications/{notification_id}/read` | `{msg, notification}`; `404 notification_not_found` |
| `PATCH` | `/api/v2/notifications/read_all` | `{msg, updated, unread_count}` |

Row shape:
```jsonc
{ "id":981, "type":"global", "event_code":"purchase_order.rejected",
  "entity_type":"purchase_order", "entity_id":1234,
  "title":"…", "body":"…", "text":"title • body", "text_ar":"…", "text_en":"…",
  "click_action":"purchase_order", "is_read":false, "read_at":null,
  "created_at":"2026-09-19 14:02:11" }
```
These are the **same rows as the web bell** — reading in one place reads everywhere. Full event catalogue in **§7**.

## 5.11 Ratings

| Method | Path | Body / Query |
|---|---|---|
| `GET` | `/api/v2/ratings` | `?business_relationship_id=*&dimension=&source=`. `403 relationship_not_accessible` |
| `POST` | `/api/v2/ratings` | `business_relationship_id`*, `dimension`*, `score`* 1–5, `note` ≤ 2000 → `{msg, rating}` |
| `GET` | `/api/v2/ratings/aggregate` | `?organization_id_target=` or `?business_relationship_id=` → `{rated_organization_id, business_relationship_id, aggregate}`. `403 no_shared_relationship_to_view_ratings` |
| `GET` | `/api/v2/ratings/suggest_classification` | `?target_organization_id=` (or `organization_id_target`/`business_relationship_id`) → `{target_organization_id, business_relationship_id, suggestion}`. `400 target_organization_id_required` |

Allowed `dimension` values are an enum on the server — read them from the aggregate response rather than hardcoding.

## 5.12 Subscription & wallet

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/api/v2/subscription/plans` | — | `{plans}` |
| `GET` | `/api/v2/subscription/current` | — | `{summary}` |
| `PUT` | `/api/v2/subscription/billing_mode` | `mode`*: `subscription`\|`commission` | `{msg, subscription}` |
| `POST` | `/api/v2/subscription/trial` | — | `{msg, subscription}`; **`422 already_subscribed`** |
| `GET` | `/api/v2/wallet` | — | `{wallet}` |
| `GET` | `/api/v2/wallet/transactions` | — | `{data}` (paginator) |
| `GET` | `/api/v2/wallet/topup_methods` | — | `{methods}` |
| `POST` | `/api/v2/wallet/topup_requests` | `amount`* ≥ 1, `method`*: `bank_transfer`\|`hyperpay`\|`apple_pay`, `bank_reference`, `transfer_proof_path`, `gateway_payment_id` | `{topup_request}` |

`POST /api/v2/admin/subscriptions` and `/admin/subscriptions/{id}/cancel` are admin-only (`403 admin_auth_required`) — not for the customer app.

**Plan quotas** are enforced by the `plan.quota:<key>` middleware on: relationships (`max_active_relationships`), purchase drafts (`max_purchase_orders_per_month`), invoices (`max_invoices_per_month`), contracts (`max_contracts`). A quota block comes back as a rejection body from that middleware — surface it as an upsell, not a crash.

## 5.13 Contracts & consignment shelf

| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/contracts` | `contracts.view` | `?status=&contract_type=&relationship_id=&limit=` |
| `GET` | `/api/v2/contracts/{contract_id}` | `contracts.view` | `{contract}` |
| `POST` | `/api/v2/contracts` | `contracts.manage` | **upsert**: `relationship_id`*, `contract_type`*, `billing_period` (`weekly`\|`monthly`), `name_ar`/`name_en`, `start_date`, `end_date`, `auto_renew`, `status`, `change_summary`, `terms[]`, `documents[]`, `approvals[]`. Quota `max_contracts` |
| `PATCH` | `/api/v2/contracts/{id}/status` | `contracts.manage` | `status`*: `draft`\|`under_review`\|`approved`\|`active`\|`suspended`\|`expired`\|`terminated`, `note` |
| `POST` | `/api/v2/contracts/{id}/approvals/{contract_approval_id}` | `contracts.approve` | `status`*: `approved`\|`rejected`\|`pending`, `note` |

**`contract` payload:** `id, business_relationship_id, contract_type, code, name_ar, name_en, display_name, start_date, end_date, auto_renew, status, approved_at, relationship{}` (+ `terms[], documents[], approvals[], versions[]`).

| Method | Path | Perm | Body / Query |
|---|---|---|---|
| `GET` | `/api/v2/consignment_shipments` | `contracts.view` | `?status=&contract_id=&limit=` |
| `GET` | `/api/v2/consignment_shipments/{id}` | `contracts.view` | |
| `POST` | `/api/v2/consignment_shipments` | `deliveries.manage` | **upsert**: `contract_id`*, `source_branch_id`, `destination_branch_id`, `notes`, `lines[]`* min 1 |
| `PATCH` | `/api/v2/consignment_shipments/{id}/status` | `deliveries.manage` | `status`*: `draft`\|`sent`\|`received`\|`closed`\|`canceled`, `notes`, `lines[]` |
| `GET`/`POST` | `/api/v2/sales_reports` | `settlements.manage` | `contract_id`*, `branch_id`, `period_start`*, `period_end`* (≥ start), `notes`, `lines[]`* |
| `PATCH` | `/api/v2/sales_reports/{id}/status` | `settlements.manage` | `status`*: `draft`\|`submitted`\|`verified`\|`rejected`\|`closed` |
| `GET`/`POST` | `/api/v2/stock_counts` | `settlements.manage` or `stock_counts.manage` | `contract_id`*, `branch_id`, `count_type` (`opening`\|`closing`\|`cycle`\|`investigation`), `count_date`*, `notes`, `lines[]` |
| `PATCH` | `/api/v2/stock_counts/{id}/status` | same | `status`*: `draft`\|`submitted`\|`verified`\|`rejected`\|`closed` |
| `GET`/`POST` | `/api/v2/shelf_adjustments` | `settlements.manage` or `shelf.manage` | `contract_id`*, `branch_id`, `target_branch_id`, `adjustment_type`* (`return`\|`damage`\|`expiry`\|`manual`), `visit_type` (`driver_visit`\|`supplier_self`\|`trader_count`), `driver_user_id`, `notes`, `lines[]`* `{sku_id*, previous_count, current_count, added_count, damaged_count, expired_count, current_count_photo_path, before_photo_path, after_photo_path}` |
| `PATCH` | `/api/v2/shelf_adjustments/{id}/status` | same | `status`*: `draft`\|`submitted`\|`approved`\|`rejected`\|`closed` |
| `GET` | `/api/v2/shelf_adjustments/previous_count` | same | `?contract_id=*&branch_id=*&sku_ids[]=*` → `{data}` — **prefill the shelf-count form with this** |
| `GET` | `/api/v2/shelf/contracts` | `settlements.manage` or `shelf.manage` | `{contracts, count, workspace}` |
| `GET` | `/api/v2/shelf/contracts/{id}/visits` | same | `404 shelf_contract_not_found_or_not_accessible` |
| `GET` | `/api/v2/shelf/contracts/{id}/invoices` | same | |
| `GET` | `/api/v2/shelf/visits/{visit_id}` | same | `{visit}` |

### Settlements & payouts
| Method | Path | Perm | Body |
|---|---|---|---|
| `GET` | `/api/v2/settlements` | — | `?status=&contract_id=&branch_id=&limit=` |
| `GET` | `/api/v2/settlements/{settlement_run_id}` | — | `{settlement}` |
| `POST` | `/api/v2/settlements` | `settlements.manage` | `contract_id`*, `branch_id`, `period_start`*, `period_end`*, `shelf_fees`, `service_fees`, `notes` |
| `PATCH` | `/api/v2/settlements/{id}/status` | `settlements.manage` | `status`*: `draft`\|`calculated`\|`reviewed`\|`approved`\|`paid`\|`closed` |
| `POST` | `/api/v2/settlements/{id}/payouts` | `settlements.manage` | `bank_account_id`, `amount`, `paid_at`, `reference_no`, `status` (`pending`\|`completed`\|`failed`), `notes` |
| `GET` | `/api/v2/payouts/{payout_id}` | — | `{payout}` |
| `PATCH` | `/api/v2/payouts/{payout_id}/status` | `settlements.manage` | `status`*, `paid_at`, `reference_no`, `notes` |

**`settlement` payload:** `id, contract_id, branch_id, period_start, period_end, status, gross_sales, returns_total, damage_total, expiry_total, shelf_fees, service_fees, net_payable_supplier, notes, approved_at, paid_at` (+ `lines[], payouts[]`).

## 5.14 Internal transfers (branch → branch)

| Method | Path | Perm | Body |
|---|---|---|---|
| `GET` | `/api/v2/internal_transfers` | `internal_transfers.view` | |
| `GET` | `/api/v2/internal_transfers/{id}` | `internal_transfers.view` | `{internal_transfer}` |
| `POST` | `/api/v2/internal_transfers` | `internal_transfers.manage` | `source_branch_id`*, `destination_branch_id`*, `required_by_date`, `priority` (`normal`\|`urgent`\|`critical`), `lines[]`* `{sku_id*, requested_qty*}` |
| `PATCH` | `/api/v2/internal_transfers/{id}/status` | — | `400 invalid_status` |
| `POST` | `/api/v2/internal_transfers/{id}/lines` | `internal_transfers.manage` | → `{msg, line}` |
| `DELETE` | `/api/v2/internal_transfers/{id}/lines/{line_id}` | `internal_transfers.manage` | → `{msg}` |

## 5.15 Live tracking

| Method | Path | Perm | Response |
|---|---|---|---|
| `GET` | `/api/v2/tracking/live` | `fleet.tracking.view` | `{drivers}` — current positions |
| `GET` | `/api/v2/tracking/drivers/{driver_id}/trail` | `fleet.tracking.view` | `?route_id=` → `{trail}` |
| `GET` | `/api/v2/tracking/routes/{route_id}/status` | `fleet.routes.view` | `{route, actual_distance_km, progress}` |
| `GET` | `/api/v2/delivery/tracking/notifications` | — | `{notifications}` — **trader-facing** delivery events |
| `GET` | `/api/v2/delivery/tracking/supplier_fleet` | supplier | `{deliveries}` |
| `GET` | `/api/v2/delivery_notes/{id}/tracking` | — | `{delivery_note}` — the one a trader's "track my order" screen uses |

Poll at **5 s while a map is visible, 30 s in the background, stop when the screen is gone.** Remember the 60 req/min global cap.

## 5.16 Fleet & vehicle management (supplier-owned fleets)

Only relevant if the org runs its own fleet.

| Method | Path | Perm |
|---|---|---|
| `GET`/`POST` | `/api/v2/fleet/drivers`, `/fleet/vehicles`, `/fleet/companies`, `/fleet/assignments` | `fleet.*` |
| `GET` | `/api/v2/fleet/drivers/{driver_id}` | |
| `PATCH` | `/api/v2/fleet/drivers/{driver_id}/status`, `/fleet/vehicles/{vehicle_id}/status` | |
| `GET` | `/api/v2/fleet/performance/summary`, `/fleet/performance/drivers/{id}` | |
| `GET`/`POST` | `/api/v2/routes`, `/api/v2/routes/{route_id}` | `fleet.routes.view` / `fleet.routes.manage` |
| `PATCH` | `/api/v2/routes/{route_id}/status` | `fleet.routes.manage` |
| `PUT` | `/api/v2/routes/{route_id}/stops/order` | `fleet.routes.manage` |
| `POST` | `/api/v2/routes/stops/{stop_id}/reassign` | `fleet.routes.manage` |
| `GET` | `/api/v2/routes/pending_tasks` | `fleet.routes.view` → `{pending_tasks}` |
| `GET`/`POST` | `/api/v2/vehicles/{vehicle_id}/maintenance`, `/fuel_logs` | `fleet.manage` |
| `PATCH` | `/api/v2/vehicles/maintenance/{maintenance_record_id}/status` | `fleet.manage` |
| `GET`/`POST` | `/api/v2/vehicles/alerts`, `/vehicles/alerts/scan` | `fleet.manage` |
| `POST` | `/api/v2/vehicles/alerts/{vehicle_alert_id}/acknowledge` | `fleet.manage` — `resolution_notes`, `new_status` (`acknowledged`\|`resolved`\|`ignored`) |

`POST /api/v2/routes` body: `fleet_assignment_id`*, `driver_id`*, `vehicle_id`, `route_date`*, `stops[]{stop_type* ∈ pickup|delivery|internal_transfer_pickup|internal_transfer_delivery|return_to_base, branch_id*, reference_type ∈ delivery_note|consignment_shipment|internal_transfer, reference_id}`.
`POST /vehicles/{id}/fuel_logs`: `liters`*, `unit_price`, `total_cost`, `currency_code`, `odometer_reading`, `fuel_type`, `station_name`, `receipt_file`, `filled_at`, `notes`, `driver_id`.
Incidents: `POST /api/v2/incidents/{id}/{acknowledge|investigate|resolve|reopen}`, `GET /api/v2/incidents/{id}/age`.

> **Out of scope for the customer app:** everything under `/api/v2/driver/*` (the driver app — see `docs/driver-api-changes-2026-09-19.md`) and `/api/v2/fleet_company/*` (the fleet-company portal, which uses `X-Fleet-Company-Id` + `X-Fleet-Session-Token` instead of a JWT).

## 5.17 Lookups (read-only pickers)

All under `/api/v2/lookups/`, all returning `{items}` (plus `{diagnostics}` on `suppliers`/`traders`). Use these to populate dropdowns — they are cheap and already scoped to the caller's organization.

| Path | Useful query params |
|---|---|
| `/suppliers`, `/traders` | `search`, `status`, `limit`, `profile_type` |
| `/relationships` | `counterparty_organization_id`, `my_role`, `status` |
| `/contracts` | `relationship_id`, `contract_type`, `status` |
| `/payment_terms` | `term_mode` |
| `/branches` | `branch_type`, `organization_id` — `403 organization_not_accessible` |
| `/bank_accounts` | `organization_id` — `403 organization_not_accessible` |
| `/products` | `supplier_organization_id`*, `search` — `403 supplier_not_accessible` |
| `/skus` | `product_id` **or** `supplier_organization_id` (→ `400 supplier_organization_id_or_product_id_required`), `payment_term_id`, `relationship_id`, `contract_id`, `branch_id`, `inventory_context` (`catalog`\|`shelf`), `qty` — **returns resolved price + availability per SKU, so it is the right picker for the order-entry screen** |
| `/purchase_orders` | `status`, `credit_check_status`, `business_relationship_id` |
| `/delivery_notes` | `purchase_order_id`, `status` |
| `/invoices` | `status` |
| `/settlements` | `contract_id`, `status` |
| `/business_sectors` | — |

## 5.18 Uploads

### `POST /api/v2/uploads` — **multipart**
`attachment`* (file, ≤ **10 MB**, `jpg,jpeg,png,webp,pdf,doc,docx,xls,xlsx,csv,txt`), `module` ≤ 100, `field_key` ≤ 100.
**200** → `{msg, file: {path, url, …}}`.

**Two-step upload pattern:** every v2 field named `proof_file`, `file_path`, `*_photo_path`, `image_url`, `receipt_file` expects a **string path from this endpoint**, not a file. Upload first, then send the returned path in the JSON body.

## 5.19 Push registration

| Method | Path | Body |
|---|---|---|
| `POST` | `/api/v2/push/register` | `token`* ≤ 512, `platform`* (`android`\|`ios`\|`web`), `app_variant` (`driver`\|`supplier`\|`trader`\|`owner`\|`admin`), `locale` ≤ 8, `device_id` ≤ 128, `device_model` ≤ 191, `os_version` ≤ 32 |
| `POST` | `/api/v2/push/unregister` | `token` |
| `POST` | `/api/v2/push/test` | — (dev aid) |

Also register the FCM token via `PUT /api/auth/device_token` — v1 `tokens` and v2 `push_tokens` are separate tables and both are used. Backend runs FCM **HTTP v1** with a service account.

## 5.20 Biometric login

| Method | Path | Auth | Body |
|---|---|---|---|
| `POST` | `/api/v2/biometric/credentials` | JWT | `device_id`*, `device_name`, `device_platform`* (`android`\|`ios`), `device_os_version`, `biometric_type`* (`fingerprint`\|`face`\|`passcode`), `public_key`* ≤ 8192, `key_algorithm` (`EC_P256`\|`RSA_2048`) |
| `GET` | `/api/v2/biometric/credentials` | JWT | list |
| `DELETE` | `/api/v2/biometric/credentials/{credential_id}` | JWT | `reason` |
| `POST` | `/api/v2/biometric/challenge` | **public**, `throttle:10,1` | `device_id`*, `email` |
| `POST` | `/api/v2/biometric/verify` | **public**, `throttle:10,1` | `device_id`*, `challenge`* (exactly 64 chars), `signature`* ≤ 4096 |

Flow: enrol after a password login (store the private key in the Secure Enclave / Android Keystore) → on next launch `challenge` → sign it → `verify` → receive the session.

## 5.21 Nafath identity verification

| Method | Path | Throttle | Body |
|---|---|---|---|
| `POST` | `/api/v2/nafath/initiate` | 10/min | `national_id`* exactly 10 chars, `purpose` (`owner_registration`\|`login`\|`document_signature`), `user_id` |
| `GET` | `/api/v2/nafath/transactions/{transaction_id}` | 60/min | → `{msg, transaction}` — poll for the result |
| `POST` | `/api/v2/nafath/transactions/{transaction_id}/cancel` | 20/min | `404 nafath_transaction_not_found` |

If the feature is off, `initiate` returns **200** with `{msg:"nafath_disabled", nafath_enabled:false, fallback:…}` — **check `platform_flags.nafath_enabled` before showing the entry point.**

## 5.22 Payments

### HyperPay
| Method | Path | Throttle | Body |
|---|---|---|---|
| `POST` | `/api/v2/payment/hyperpay/checkout` | 30/min | `plan_id`*, `brand`* (`visa`\|`master`\|`mada`\|`apple_pay`), `billing_cycle` (`monthly`\|`yearly`) → `{msg, payment_id, checkout_id}`; `422 plan_not_available` |
| `GET` | `/api/v2/payment/hyperpay/status` | 60/min | `?resource_path=*&brand=*` → `{msg, payment}`; `403 payment_not_owned_by_organization` |
| `POST` | `/api/v2/payment/hyperpay/webhook` | 120/min | server-to-server, not for the app |

Use `checkout_id` with the HyperPay mobile SDK / COPYandPAY widget, then poll `status` with the `resourcePath` the SDK hands back.

### Apple Pay
| Method | Path | Body |
|---|---|---|
| `POST` | `/api/v2/payment/apple_pay/validate_merchant` | `validation_url`* (valid URL ≤ 512) → `{msg, session}` |
| `POST` | `/api/v2/payment/apple_pay/process` | `plan_id`*, `billing_cycle` → `{msg, payment_id, checkout_id}` |

Gate both on `platform_flags.payment_gateway_enabled` / `apple_pay_enabled`.

## 5.23 Account deletion (App Store / Play Store requirement)

| Method | Path | Throttle | Notes |
|---|---|---|---|
| `POST` | `/api/v2/account/deletion_request` | 5/hour | `reason` ≤ 1000 → **201** `deletion_request_submitted`; `409 request_already_exists`; `401 unauthorized` |
| `GET` | `/api/v2/account/deletion_request` | — | `{request}` |
| `DELETE` | `/api/v2/account/deletion_request` | 10/hour | `{msg, request}`; `404 no_active_request` |

**Ship this screen** — both stores require an in-app delete path.

## 5.24 Web bridge

### `POST /api/v2/mobile/web_bridge`
`target`* ≤ 500, `organization_id`, `workspace` (`supplier`\|`trader`\|`hybrid`\|`under_review`), `lang` (`ar`\|`en`) → `{url, target, expires_in_seconds}`.

Returns a **short-lived signed URL** for opening a web-only screen inside a WebView with the session already established. Use it for anything the native app does not implement yet; refresh before `expires_in_seconds`.

---

# 6. Permission codes

From `resolveMembership()` checks across the controllers. **`is_owner` short-circuits every one of them.** `GET /api/v2/bootstrap` returns the effective list per organization — drive button enablement from it.

```
organizations.view      organizations.manage    organization.edit      branches.manage
relationships.manage    credit.manage           catalog.manage         pricing.manage
purchase_orders.manage  approvals.act           deliveries.manage
goods_receipts.manage
invoices.view           invoices.manage         due_schedules.edit
collections.manage      adjustments.manage
contracts.view          contracts.manage        contracts.approve
settlements.manage      shelf.manage            stock_counts.manage
internal_transfers.view internal_transfers.manage
fleet.manage            fleet.routes.view       fleet.routes.manage    fleet.tracking.view
audit.view
```

Workspace gating (`businessModes`) is separate: some endpoints are `trader`-only, some `supplier`-only. `business_mode == "hybrid"` passes both. Violations → `403 organization_workspace_not_allowed`.

---

# 7. Push notifications (FCM)

Every push carries a localized `notification` block (title/body chosen from `users.lang`, then the device token locale) plus a `data` map where **all values are strings**.

| `data` key | Example | Notes |
|---|---|---|
| `event_code` | `purchase_order.approved` | see below |
| `entity_type` | `purchase_order` | |
| `entity_id` | `1234` | |
| `click_action` | `purchase_order` | the deep-link route key |
| `code` | `PO-20260919-AB12CD34` | |
| `status` | `approved` | entity status after the event |
| `side` | `supplier` / `trader` | who acted |
| `note` / `reason` | `الكمية غير متوفرة` | only on rejected / canceled |
| `lang` | `ar` | language the text was rendered in |

**Deep-link rule:** map `click_action` → screen, `entity_id` → id.
`purchase_order` → `GET /api/v2/purchase_orders/{id}` · `delivery_note` → delivery tracking · `invoice` · `goods_receipt` · `post_invoice_return` · `supplier_fleet_contract` · v1: `order` → `GET /api/orders/{id}`, `chat` → chat room with `click_id`.

### Event catalogue

**Purchase orders** — recipients: the org owner(s) + every active member with `purchase_orders.manage`; the actor is never notified.
`purchase_order.submitted` (→supplier) · `.under_review` · `.approved` · `.ready` · `.rejected` · `.canceled` (either side; `data.side` says who) · `.cancel_requested` (→supplier) · `.cancel_accepted` · `.cancel_rejected`

**Shipments** (`entity_type=delivery_note`; trader recipients hold `goods_receipts.manage`, supplier recipients `deliveries.manage`)
`delivery_note.created` · `.dispatched` · `.rejected` · `.canceled` · `.stop_skipped` (`data.stop_id`) · `.returned_to_base`
`data` always has `delivery_note_id`, `code`, `purchase_order_id`, `status`. Cancel reason codes: `out_of_stock`, `order_canceled`, `order_error`, `vehicle_issue`, `trader_request`, `other`.

**Money & receipts**
`invoice.issued` (→trader) · `invoice.overdue` (→trader) · `invoice.paid` (→supplier) · `goods_receipt.disputed` (→supplier) · `post_invoice_return.submitted` (→supplier) · `.approved` (→trader) · `.rejected` (→trader)

**Fleet contracts (supplier only)**
`fleet_contract.accepted` · `fleet_contract.rejected`

---

# 8. Error code index

Anything not in the `msg`-as-localized-text v1 group is a **stable snake_case key** — switch on it, show your own localized copy.

**Auth / context**
`validation_error` (400, has `bag`) · `organization_membership_not_found` (403) · `organization_workspace_not_allowed` (403) · `permission_denied` (403, has `permission`) · `unauthenticated` (401) · `unauthorized` (401) · `admin_auth_required` (403) · `not_a_driver` (403)

**v1 (localized text in `msg`, 401 unless noted)**
`invalid_email` · `invalid_password` · `invalid_code` · `email_exists` · `phone_exists` · `company_name_exists` · `old_password_incorrect` · `insufficient_product_count` · `invalid_product_variation_id` · `product_not_same_country_as_user` · `user_not_allowed` · `not_seller` (403) · `order_not_found` (404)

**Orders / drafts**
`draft_not_found` · `draft_not_found_or_not_open` · `draft_line_not_found` · `draft_has_no_lines` · `sku_not_belong_to_draft_supplier` · `qty_less_than_min_order_qty` · `qty_not_matching_order_step` · `insufficient_supplier_inventory` · `pricing_not_found_for_sku` · `relationship_is_blacklisted` · `approved_business_relationship_required_before_submit` · `relationship_must_be_approved_before_submit` · `purchase_order_submit_failed` (500) · `purchase_order_not_found` · `credit_manage_permission_required_for_override` (403) · `purchase_order_status_update_failed` (500) · `purchase_order_cancel_request_failed` · `purchase_order_cancel_decision_failed` · `reason_required` · `purchase_order_approval_not_found` · `approval_actor_not_allowed` (403)

**Deliveries / receipts**
`purchase_order_not_found_for_supplier` · `supplier_or_trader_branch_missing` (422) · `delivery_note_not_found` · `delivery_note_not_found_for_supplier` · `pickup_seals_required_before_dispatch` (422) · `seals_can_only_be_set_before_dispatch` (409) · `delivery_note_not_reschedulable_in_status_<x>` (422) · `delivery_note_not_found_for_trader` · `goods_receipt_not_found` · `goods_receipt_not_found_for_trader` · `goods_receipt_edit_window_closed` (410) · `goods_receipt_create_failed` (500) · `goods_receipt_dispute_failed` (500)

**Money**
`invoice_not_found` · `purchase_order_not_found_for_invoice_issue` · `invoice_issue_failed` (500) · `due_schedule_not_found_for_supplier` · `due_schedule_update_failed` (500) · `collection_receipt_not_found` · `invoice_or_due_schedule_required` · `invoice_not_found_for_supplier_collection` · `due_schedule_not_found_for_supplier_collection` · `invoice_not_found_for_trader_claim` · `due_schedule_not_found_for_trader_claim` · `collection_receipt_create_failed` (500) · `collection_receipt_status_change_failed` (500) · `adjustment_note_not_found` · `invoice_not_found_for_adjustment` · `post_invoice_return_not_found` · `post_invoice_return_transition_not_allowed_for_role` (403) · `post_invoice_return_create_failed` (500)

**Catalog / pricing / relationships**
`product_not_found` · `product_not_accessible` (403) · `supplier_organization_not_found` · `supplier_organization_id_required` · `product_or_sku_not_found` · `sku_not_found` · `sku_not_belong_to_current_organization` (403) · `price_list_not_found` · `price_list_name_required` · `scope_id_required_for_selected_scope` · `max_qty_must_be_greater_than_or_equal_min_qty` · `relationship_not_found` · `invalid_counterparty_organization` · `credit_profile_can_only_be_managed_by_supplier_side` (403) · `cannot_follow_self` · `relationship_not_accessible` (403) · `no_shared_relationship_to_view_ratings` (403) · `target_organization_id_required` · `supplier_not_accessible` (403) · `organization_not_accessible` (403) · `supplier_organization_id_or_product_id_required`

**Contracts / shelf / settlements**
`contract_not_found` · `contract_approval_not_found` · `consignment_shipment_not_found` · `sales_report_not_found` · `stock_count_not_found` · `shelf_adjustment_not_found` · `settlement_not_found` · `payout_not_found` · `shelf_contract_not_found_or_not_accessible` · `shelf_visit_not_found_or_not_accessible` · `internal_transfer_not_found` · `invalid_status` · `internal_transfer_create_failed` (500) · `status_change_failed` (500)

**Other**
`branch_not_found` · `branch_name_required` · `post_not_found` · `comment_not_found` · `not_authorized` (403) · `invalid_image_url` · `notification_not_found` · `ack_key_required` · `document_flow_not_found` · `already_subscribed` (422) · `subscription_not_found_or_already_canceled` · `subscription_assign_failed` (500) · `plan_not_available` (422) · `payment_not_owned_by_organization` (403) · `nafath_transaction_not_found` · `nafath_disabled` (**200**) · `request_already_exists` (409) · `no_active_request` (404) · `vehicle_not_accessible` (403) · `alert_not_accessible` (403) · `maintenance_record_not_accessible` (403) · `route_create_failed` (500) · `route_status_change_failed` (500) · `rating_create_failed` (500)

---

# 9. Backend-side references

| File | What it is |
|---|---|
| `routes/api.php` | the authoritative route list |
| `docs/api-rest-migration.md` | old RPC → new REST map |
| `docs/notifications-api.md` | the notifications contract in full |
| `docs/driver-api-changes-2026-09-19.md` | the driver app surface (not this app) |
| `tools/api-smoke.php` | smoke-tests every endpoint — ask backend to run it against your target env |
| `tests/Feature/ApiRouteConventionsTest.php` | enforces the REST conventions above |
| `app/Http/Middleware/ResolveApiRequestContext.php` | the header/path → input adapter |
| `app/Http/Controllers/Api/V2/Concerns/` | the `format*()` payload builders — the single source of truth for response field names |

## Questions to settle with backend before you start

1. **Base URLs** for dev / staging / prod, and whether staging seeds demo organizations.
2. **Three test accounts**: a `trader`-mode org, a `supplier`-mode org, and a **`hybrid`** org — with an approved relationship and an active contract between trader and supplier so the full order→delivery→invoice→collection loop is walkable from both sides. **The hybrid account is the one that finds workspace bugs.**
3. **`ratings.dimension` and `contracts.contract_type` enums** — these are server-side lists that did not read cleanly from the validation rules.
4. **Broadcasting driver + credentials** for v1 chat (`BroadcastMsg`), or confirmation that polling is acceptable.
5. **FCM sender ID / `google-services.json` / `GoogleService-Info.plist`** for both flavours.
6. Whether **`GET /api/orders/{id}` `items[]`** will be fixed to include per-line `count`/`price` (see §4.7).
