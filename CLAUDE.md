# Tajer ID — Digital Commerce Integration (Flutter app)

B2B trade platform connecting **suppliers / manufacturers** and **traders** (plus drivers and the
platform team). This repo is the mobile client of the Laravel backend at `https://tacaml.com`
(`/api/...`; one environment — staging = production host). The web portal is the reference:
the app should behave the way the website does.

**Read before any business-logic work:** `docs/workflow-guide.md` — the complete logic of the
official user guide (every step, field, rule, validation message, status table and notification,
with the website's exact Arabic labels). It is the source of truth for how the app must behave.
Also: `docs/tajerid-customer-api.md` (API reference) ·
`docs/tajerid-flutter-integration-prompt.md` (original build brief) · `docs/compliance-implementation.md`.
The original PDF is `docs/دليل-دورة-العمل-الكاملة.pdf`; if it is updated, regenerate
`workflow-guide.md` from it (its text layer is visual-order RTL: extract with PyMuPDF and reverse
the word order per line).

## The business cycle (what the app exists for)

1. **Sign-up** (4 steps, like `/register`): business mode (`trader` | `supplier` | `hybrid`) +
   activity (`retailer`, `marketer` / `factory`, `supplier_trader`) → owner → organization → terms.
   New accounts confirm their email with a 6-digit code before getting a session.
2. **Onboarding** (web "Owner Console"): organization legal data → branches → documents (≤ 8 MB,
   `document_type` codes from the server) → bank account (required for suppliers only) → trader /
   supplier profile (sectors **and** channels) → each profile is submitted for review on its own.
3. **Admin review** → profile active → workspace (shell) opens. Then appoint the **authorized
   signatory** — only they accept agreements and sign with OTP.
4. **Supplier prep**: branches with map pin, catalog, SKU rules + price tiers, stock, fleet.
5. **Relationship** (`REL-`): requested with a supply model — cash / credit (term, limit, debt
   documentation) / consignment; the other side's signatory accepts by OTP. No PO without it.
6. **Framework agreement** (`FA-`, both signatories, OTP) → contract / quotation (`QT-`).
7. **Purchase order** (`PO-`) by trader → supplier accepts **on the order page with OTP** →
   credit acknowledgment (`ACK-`) for credit orders.
8. **Delivery note** (`DN-`) → driver → trader shows QR / code → **goods receipt** (`GRN-`),
   confirmed by OTP or photo+declaration within 48 h → stock posts automatically.
9. **Tax invoice** (`INV-`, from accepted GRN quantities) → payment notice → collection → closed.
   Returns / credit notes (`RN-` / `CN-`), consignment custody ledger, late-payment notices.

## Stack & decisions (don't change without asking)

- Flutter, Dart `^3.10`. **Bloc/Cubit + get_it** (not Riverpod). **go_router**. **dio** via
  `lib/core/network/api_client.dart`. **easy_localization** (ar default + en, RTL).
- **No codegen** (no freezed / json_serializable): models are hand-written `fromJson` using
  `lib/core/network/coerce.dart` (`asInt`, `asStr`, `asMap`, `asList`, `unwrap`, …).
- Repositories **never throw**: they return `ApiResult<T>` (`Ok`, `NoContent`, `Invalid(bag,
  text)`, `Failed(code, status, message, details)`, `RateLimited`, `Offline`, `SessionExpired`,
  `WrongWorkspace`) built by `lib/core/network/response_normalizer.dart`. Map failures to UI with
  `lib/core/error/api_failure_ui.dart` (`failureState`, `failureMessage`).
- Global request budget is **60 req/min**: load sequentially, re-read only what changed.

## Layout

```
lib/app/            shell (workspace_shell), app widget
lib/core/           network, session (SessionCubit/SessionStore), workspace, ui (design system),
                    i18n, language/{ar,en}.json, utils/roots/app_router.dart (routes + redirect)
lib/data/           api_paths.dart, models/, repositories/
lib/features/shared auth, onboarding, compliance, organization, notifications, advanced, home
lib/features/trader suppliers, catalog, drafts, orders, shipments, receipts, payables, returns, home
lib/features/supplier
test/               core/ data/ ui/ — fake backend in test/core/fake_backend.dart
```

## Conventions

- Match the surrounding code: comment density (comments explain *why*, often citing a live
  server behaviour), naming, widget kit. Use `lib/core/ui/` (`AppField`, `AppButton`, `AppCard`,
  `AppBanner`, `StatusChip`, `CodePicker`, `IdPicker`, `SubmitButton`, `FormMessage`,
  `AppBottomBar`, `showAppConfirm`, `showAppSheet`) and `context.tokens` colours — no raw colours.
- Strings: every key in **both** `lib/core/language/en.json` and `ar.json`. Edit them with a
  Python `json.load` / `json.dump(ensure_ascii=False, indent=2)` + trailing newline (round-trips
  the files exactly). Use `EdgeInsetsDirectional`, LTR for numbers/emails/IBANs.
- `import 'package:easy_localization/easy_localization.dart' hide TextDirection;` when the file
  also uses Flutter's `TextDirection`.
- Formatting width is **100** (`dart format -l 100`, never the default 80).
- Session refreshes from inside a flow use `SessionCubit.refresh(silent: true)` — a loud refresh
  goes through `loading`, which the router answers with the splash screen.
- Add tests for behaviour changes (`test/data/*_test.dart` with `clientWith(FakeAdapter…)`).

## Verify

```
flutter analyze lib test     # expected: only the old cache_helper.dart:6 info
flutter test                 # all must pass
```

## Live API facts (verified against tacaml.com — trust these over the docs)

- Cloudflare blocks default Python/curl user agents: send `User-Agent: Dart/3.10 (dart:io)`.
  In Git Bash set `MSYS_NO_PATHCONV=1` (else `/v2/...` becomes a Windows path) and
  `PYTHONIOENCODING=utf-8`. Never type Arabic into curl in Git Bash — it is sent as `?????`; use a
  Python script with UTF-8 JSON.
- Errors: `{msg: <code>, bag}`; a dead token is `400 validation_error` with `bag.user_id` (or 401).
  Newer endpoints send `{msg: <translated sentence>, error: <code>}` and `400 {msg:
  validation_error, text: <sentence>}` with an empty bag — the normalizer handles both.
- `/v2` lists are Laravel paginators; each row's real payload is under `formatted`.
- `GET /v2/catalog/suppliers/{id}` → `{supplier, relationship: {id, status, …}, contracts}` —
  the relationship is a **sibling**, not inside `supplier`. Rejected request ⇒ relationship
  `closed`; re-POSTing `/v2/relationships` reopens it as `pending_review`.
- Relationship-request decision field is **`note`**, not `decision_note`.
- `POST /v2/relationships` (the request): `counterparty_organization_id`, `as` (`trader`|`supplier`),
  `requested_model` (`direct`|`credit`|`consignment`, else `422 supply_model_invalid`), and for
  credit `requested_credit_term_days` (1–365), `requested_credit_limit`, `debt_documentation`
  (`acknowledgment_only`|`promissory_note`|`both`), `notes`. Answers `{relationship}`; the term /
  limit / documentation show on `GET /v2/relationship_requests`, not in that answer.
- No order-entry endpoint: the guided purchase order is built from `/v2/lookups/payment_terms`
  (`term_mode` `cash` | `deferred`), `/relationships?my_role=trader`, `/contracts`, `/branches`
  (`is_default`), then `POST /v2/purchase_drafts` with `contract_id`. `contract_type` values
  (from the website): `direct_cash`, `direct_credit`, `installment`, `shelf` (consignment).
  `GET /v2/approvals` → `{contracts, purchase_orders, counts}`.
- Branch map pin: the onboarding branch upsert **ignores** `latitude`/`longitude`; set them (and
  `is_default`) with `PATCH /v2/organization/branches/{id}`. The owner-console branch listing has
  no coordinates; `GET /v2/organization` → `organization.branches[]` does.
- **Not in the API yet** (backend needed): creating/editing catalog products (`/v2/catalog/products`
  is GET-only), inventory balances/adjustments, and contract `terms[]` / per-SKU contract prices
  (`POST /v2/contracts` accepts the header but stores `terms: []`). A created contract comes back
  with `contract_type: "cash"` for `direct_cash`. Also missing: a consignment **sales invoice**
  endpoint, and a "paid to account" field on the trader's `POST /v2/collections/claim`.
- Team: `POST /v2/b2b/owner-console/employees` creates (answers `temporary_password`) or, with
  `membership_id`, updates — **an update clears every field it omits**, so always send the whole
  row. Roles: `available_roles` on the onboarding bootstrap. Phones come back as numbers
  without the leading 0.
- Public profile: logo/cover upload (multipart `file`) and `PATCH /organization/bio` work, but
  **nothing reads them back** (no logo/cover/bio on `GET /v2/organization`) — backend needed.
- Approval of a workspace: use `organization.journey.<side>.status` (`active`), not
  `approved_workspaces` (`Organization.approvedProfileWorkspaces`).
- The legacy `post_invoice_returns` flow (approved without OTP) is retired in the app: returns go
  through return notes (`RN-`, OTP, auto `CN-`); old routes and pushes redirect there.
- Supplier's traders directory: `GET /v2/lookups/traders` → `{items}` with `relationship_status`
  (`relationship_id: 0` = none); `search`, `limit`.
- `organization.approved_workspaces` is **not** approval (lists the workspace even while in
  review) — use the profile's own `status` (`draft`, `pending_review`, `active`).
- Onboarding bootstrap `profiles.<type>.channel_codes` / `score` / `checks` include channels
  **guessed** from sectors; `profile/submit` checks only *saved* channels. The app records its own
  successful saves (`SavedChannels`). Never send an empty `channel_codes` (it wipes the list).
- Onboarding bootstrap carries `sector_options`, `channel_options`, `document_type_options`
  (`commercial_record`, …) — use server codes, never hardcode. Documents upload as multipart
  field `document_file`.
- `GET /v2/organization` sends `country_id: null` + nested `country: {id}`.
- `/v2/lookups/*` needs auth (no sectors before sign-up).
- Fleet (`/v2/fleet/van_trips`, `/v2/fleet/contracts`) and `/v2/internal_transfers` want
  `organization_id` in the query (GET) / body (writes) — `FleetRepository` and
  `InternalTransfersRepository` stamp it from the session. Van sales validate as `422
  {msg: validation_failed, errors}` (→ `Invalid`) and refuse as `422 {msg: van_*_refused, error,
  message_ar, message_en}`; the normalizer picks the message by `Accept-Language`. Load / return
  codes are strings (leading zeros). `fleet_company.service_types` are codes (`last_mile`, …);
  `coverage_areas` came back `[]` (2026-10-27).

## Test accounts

Throwaway accounts created during development live on the server (password kept out of the
repo — in Claude's local memory, or ask the user): trader org 21 `tajerid.apptest.1791284353@mailinator.com`, supplier org 23
`tajerid.supplier.1791286753@mailinator.com`. The user's own test accounts are supplier org 5
and trader org 6 — ask for their passwords, never store them. Ask before creating more accounts
or sending anything to a real (non-throwaway) organization.
