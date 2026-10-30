# Contract automation spec v1.5: implementation handbook

**What this is:** the implementation guide for docs 03, 04 and 05 from the owner. The gap analysis lives in `docs/contract-compliance-gap-report.md`. Spec section numbers (§) refer to **04-تعليمات-تنفيذية-لأتمتة-العقود-v1.5**. Document texts and numbers come from **05-قوالب v1.1**, and the agreements from **03-الإطار التعاقدي v1.3**.

## Foundation (already built, use it, don't rebuild it)

### Config: `config/b2b_compliance.php`
- `prefixes`: the document number prefix for each document type.
- `template_versions`
- `otp`
- `receipt_unconfirmed_hours`
- `late_payment` (grace business days, Saudi weekend)
- `consignment` defaults (14 / 14 / 60)
- `fees.free_period_months` (6)
- `retention_years` (6)
- `documents_disk`
- **Owner switches.** Each defaults to the spec and is read with `config('b2b_compliance.x')`:
  - `wallet_enabled`
  - `commission_on_goods_invoices`
  - `consumer_checkout_enabled`
  - `installments_enabled`
  - `nafith.*`
- `platform.*`: the platform's identity for footers and service invoices.

### Services: `app/Services/B2B/Compliance/`

| Service | What it does |
|---|---|
| `DocumentNumberService::next($type)` | Returns `PREFIX-YYYY-000001`, sequential per prefix per year. **Every new document number comes from here.** |
| `DocumentFreezer::freeze($type, $id, $no, array $payload, ?string $bodyText, array $parentIds, ?$orgId, ?$counterpartyOrgId, ?User $by, $templateKey)` | Returns a `FrozenDocument`: append-only, SHA-256 hash, auto revision. |
| `DocumentFreezer` helpers | `latest($type,$id)`, `verify($doc)`, `exportJson($doc)` (same hash). |
| `AcceptanceService::requestChallenge($user, $type, $id)` | Sends a level-2 one-time code (SMS and/or email). |
| `AcceptanceService::acceptWithOtp($user, $orgId, $type, $id, $code, $opts)` | Verifies the code, then writes a `DocumentAcceptance` (§5 fields) plus an `AuditLog`. `$opts` takes `frozen`, `signer_role`, `action`, `parent_ids`, `require_signatory`. |
| `AcceptanceService::acceptClick(...)` | Level 1. |
| `AcceptanceService::record(..., 'nafath' or 'nafith', [...])` | Levels 3 and Nafith. |
| `AcceptanceService` helpers | `isSignatory($user, $orgId)`, `assertSignatory()`, `hasAccepted($type, $id, $orgId, $action)`, `acceptancesFor($type, $id)`. |
| `ComplianceException` | Carries a stable code (`errorCode()`) for the API and `localized()` text for the web. **Add your codes to `ComplianceException::MESSAGES`** (append only). |
| `LegalFooter::text($frozen, $method)` | The fixed footer from templates section ن. **Print it under every frozen document.** |
| `CompliancePdf` | `render($html)`: Arabic-capable mPDF. `frozenDocumentHtml($frozen, $title, $fields, $table, $method)` builds a generic page. |
| `BusinessDays::add($date, $n)` | Adds Saudi business days (Friday/Saturday weekend). |
| `DeviceFingerprint::from($request)` | Device fingerprint from the `X-Device-Id` header (mobile) or the `tj_did` cookie (web). |

### Models: `app/Models/B2B/`
- `FrozenDocument` (append-only): `frozenAtUtc()`, `frozenAtRiyadh()`.
- `DocumentAcceptance` (append-only): `signedAtUtc()`, `signedAtRiyadh()`, `METHOD_*`.
- `AcceptanceChallenge`
- `DocumentSequence`
- `AuditLog` (now **append-only**; it also has `occurred_at_utc`, `document_hash`, `parent_ids`, `device_fingerprint`).

### Schema added
- `organization_memberships`: `is_authorized_signatory` (owners are backfilled to true) and `signatory_authorization_path`.
- `business_relationships`: `supply_status` (`active|supply_suspended|accelerated`) and `supply_status_changed_at`.
- `delivery_notes.received_unconfirmed_at`
- `fleet_drivers.terms_accepted_at`

> **Note:** Stream D sets `supply_status` (§7.7). Stream B **must refuse** new purchase orders when the value is not `active`.

### UI building blocks
- **`<x-ws.otp-accept :action document-type document-id :label>`**: the level-2 form. It calls `POST /b2b/acceptance/challenge` to send the code, then posts `otp_code` to your accept route.
- **Mobile:** call `POST /api/v2/acceptance_challenges {document_type, document_id}`, then send `otp_code` to the document's accept endpoint.
- **New document types:** register yours in `AcceptanceService::DOCUMENT_TYPES` (append only).

### Timestamps
Evidence times are stored in **UTC** and shown in **Riyadh time**. Never read `frozen_at` or `signature_timestamp` through Eloquent date casts. Use the model helpers above.

## Rules for every stream

1. **Never `git commit`/`push`.** Leave changes in the working tree.
2. **Migrations:** guarded (`Schema::hasTable` / `hasColumn`), one per concern, inside your stream's timestamp range. Run only your own files with `php artisan migrate --path=database/migrations/<file> --force`. Never run `migrate:fresh`, `refresh` or `rollback`.

   | Stream | Timestamp range |
   |---|---|
   | A | `2026_10_06_10xxxx` |
   | B | `2026_10_06_11xxxx` |
   | C | `2026_10_06_12xxxx` |
   | D | `2026_10_06_13xxxx` |

3. **Routes:** add them **only** to your own files. Each is loaded automatically into the existing group:

   | File | Group | Controller namespace |
   |---|---|---|
   | `routes/web_b2b_compliance/<stream>.php` | `/b2b`, authenticated web | `App\Http\Controllers\Web\B2B` |
   | `routes/api_v2_compliance/<stream>.php` | `/api/v2` | `App\Http\Controllers\Api\V2` (use `InteractsWithB2BContext::resolveMembership`) |
   | `routes/admin_b2b_compliance/<stream>.php` | `/admin/b2b` | `App\Http\Controllers\Admin\B2B` |

   - API conventions are enforced by `tests/Feature/ApiRouteConventionsTest.php`:
     - reads use GET;
     - status changes use `PATCH …/status`;
     - no verbs in paths;
     - numeric `{x_id}` parameters.
   - Allowed parameter names are pre-registered in `routes/api.php`: `quotation_id`, `framework_agreement_id`, `addendum_id`, `relationship_request_id`, `return_note_id`, `credit_note_id`, `notice_id`, `dispute_pack_id`, `marketer_id`, `assignment_id`, `commission_id`, `ticket_id`, `service_invoice_id`, `terms_version_id`, `acceptance_id`, `frozen_document_id`, `promissory_note_id`, `challenge_id`. Existing ones such as `purchase_order_id` and `invoice_id` also work.
4. **Shared files:**
   - **Free to edit, with small targeted edits** (re-read right before editing, since another stream may have touched it):
     - `app/Support/B2B/StatusCatalog.php`
     - `config/b2b_documents.php`
     - `app/Files/helper.php`
     - `ComplianceException::MESSAGES`
     - `AcceptanceService::DOCUMENT_TYPES`
   - **Leave alone:** do **not** edit `resources/views/web/b2b/partials/nav.blade.php` or `routes/*.php`. List the nav entries you need in your final report.
5. **Web UI:**
   - Use the Workspace v3 layer: `@extends('web.b2b.layout')`, `ws-*` classes, `x-ws.*` components (`page-header`, `stat`, `status`, `empty`, `hint`, `drawer`, `pager`), and `b2b_text('عربي', 'English')` for every string.
   - Arabic is the primary language; use the exact UI words from §0 of the spec.
   - Loading states: use the existing `tj-skeleton` pattern for anything fetched asynchronously.
   - Responsive tables use `tjk-stacked`.
6. **Wording bans (§4, §16):**
   - Never write «توقيع إلكتروني معتمد» or «مصدّق» for click or one-time-code acceptance. Use «قبول الشروط — تعبير ملزم عن الإرادة» and «تأكيد برمز تحقق — قبول ملزم».
   - No columns or fields named penalty, interest, late_fee or agreed_compensation.
   - No internal document titled سند لأمر.
   - Consignment is named «توريد أماني», never وكالة.
7. **Tests:**
   - Add feature tests under `tests/Feature/B2B/` (SQLite in memory, `RefreshDatabase`, `BuildsFleetWorld`) for every chain rule you enforce.
   - Use `config(['mail.default' => 'array', 'b2b_compliance.otp.expose_code' => true, 'b2b_compliance.otp.channels' => 'email'])` to drive one-time-code flows.
   - Run `php artisan test` before you finish. The **whole suite must stay green**: 137+ tests, where "deprecated" output is the known PDO notice, not a failure.
8. **Checks:**
   - `php -l` every PHP file you touch.
   - Run `php artisan view:cache`, then `php -l` the compiled views in `storage/framework/views` for the templates you touched.
   - Finish with `php artisan view:clear`.
   - **Do not launch headless Chrome or a browser.**
9. **Existing data:** keep old rows working. Map legacy statuses instead of rewriting history. Data backfills go in migrations.
10. **Final report:** list your files, migrations, routes, the nav entries you need, decisions you made, and anything you could not finish.

## Streams

| Stream | Scope (spec §) | Owns |
|---|---|---|
| **A: Onboarding, legal, accounts** | §0 terms per role, §1, §2 `activity_type`, §3 frozen registration fields + signatory, §4 level 1, §6 retention/residency, §14 complaints + 7-day notice, §15 | terms versions and acceptances, joining agreements per role (doc 03 §1–4), the terms gate middleware, `organizations.activity_type`, the signatory management UI, the legal-field lock, `complaint_tickets` (user + admin), account deletion keeping evidence, the `documents_disk` docs |
| **B: Relationship → framework → quotation → purchase order** | §7.1, §7.2, §7.3, §8 (purchase-order links), §10.1, framework agreement 5.x, addenda | relationship requests (`requested_model`, term, limit, OTP acceptance), framework agreement signing (both signatories, OTP, frozen) plus addenda, `quotations`, `purchase_orders.supply_model` + framework required + `supply_status` check + hard credit-limit reject + OTP acceptance, the credit acknowledgment `ACK`, `CreditEvaluator`, `ContractService`/`ContractFlowGuard`/`PurchaseDraftService`/`PurchaseOrderStatusService`, PO and FA numbering |
| **C: Delivery → receipt → invoice → returns → consignment** | §7.4 (except the 48h piece, already done), §7.5, §7.6, §8 (invoice/note/return links), §9, §12, templates د–ح | `pod_method`, `shortage_qty`/`defect_note`, trader receipt confirmation (OTP or photo + declaration), invoice rules (PO required, receipt required for credit/consignment, consignment sale event, VAT on shelf/consignment invoices, ZATCA fields: «فاتورة ضريبية», seller and buyer VAT numbers, TLV QR), credit/debit notes (`purchase_order_id`, `return_note_id`, CN/DNADJ), returns (reasons, qty ≤ received, pre-invoice returns, statuses, auto credit note), consignment fields (14/14/60, `return_cost_bearer`, `title_holder`, custody ledger page), DN/GRN/INV/RN/CN numbering and footers on printed documents |
| **D: Late payment, evidence, money, marketer** | §7.7, §7.8, §10.2, §11, §13, §16 | the reminder → NTC1 (5 business days) → `supply_suspended` → NTC2 → `accelerated` path (no amounts), removing the immediate credit freeze in favour of `supply_status`, the contract-terms penalty whitelist, the dispute pack (PDF + JSON + hashes, one button), `marketer` role + assignments `MK` + commissions on collection, wallet and goods-invoice commission off behind the switches + `service_invoices` + `account_activated_at`/`free_until`, consumer checkout blocked by the switch, the Nafith-only promissory note (API client behind `nafith.enabled`, PDF upload removed, linked to PO + invoice, amount = invoice amount, external-link fallback) |

**Cross-stream contracts**
- **B → D:** B refuses new purchase orders when `business_relationships.supply_status != 'active'`. D owns the transitions.
- **B → C:**
  - `purchase_orders.supply_model` is `direct|credit|consignment`. B adds and backfills it: cash → direct, deferred and installments → credit, shelf → consignment.
  - C reads it to decide the invoice rules.
- **C → D:**
  - The dispute pack (D) gathers C's frozen documents through `FrozenDocument` by type and parent ids.
  - C must freeze receipts, invoices, credit notes and return notes when they are issued.
- **B → D:** marketer commission (D) is linked to PO + invoice. It is earned only when an invoice reaches `paid`/collected. C and D must not change invoice payment statuses semantically.

## Stream A notes

**Terms and joining agreements (§0, §4 level 1, §14)**
- Texts live in `terms_versions` (seeded v1 from `resources/legal/*.v1.html`). A published version is frozen (SHA-256, `FrozenDocument`) and never edited. A change is a new version, published at least 7 days before `effective_at`.
- Who accepts what: every user accepts `platform_terms` for themselves. The organization's authorized signatory accepts its joining agreement: supplier, trader (hybrid accepts both), or marketer when `activity_type = marketer`. Fleet companies and drivers accept `joining_delivery`.
- `EnforceTermsAcceptance` (web + api groups): once a version is in force and not accepted, non-GET requests on `/b2b/*` redirect to `/b2b/terms`, and on `/api/v2/*` they return `409 terms_acceptance_required`. Reads stay open. Terms, complaints, signatories, auth, account and driver paths stay open.
- `terms:notify-pending` (hourly) sends the bell/push notice for published versions not yet notified.

**Settings with code defaults** (not in the config file): `terms_notice_days` (7), `complaint_response_days` (15), `terms_gate_enabled` (true), `terms_gate_in_tests` (false), `api_signup_requires_terms` (true), `cr_verifier` (`ManualCommercialRegistryVerifier`), `archive_originals` (on outside tests).

**Mobile endpoints** (`/api/v2`)
- `GET terms_status`, `GET terms_versions`, `GET terms_versions/{terms_version_id}`, `GET|POST terms_acceptances` `{terms_version_ids[], confirm:1}`.
- `GET|POST complaint_tickets`, `GET complaint_tickets/{ticket_id}`, `POST complaint_tickets/{ticket_id}/messages`, `PATCH complaint_tickets/{ticket_id}/status {status:closed}`, `GET complaint_tickets/{ticket_id}/attachment?message=&i=`.
- `GET signatories`, `POST signatories {membership_id, authorization_document}`, `DELETE signatories/{membership_id}`.
- Signup (`onboarding/register_owner`) needs `activity_type` and `accept_terms=1`. It may send `accepted_terms_version_ids[]`; a stale list returns `409 terms_version_outdated`.

**Registration data (§3)**: `legal_name_ar/en`, `commercial_reg_no`, `vat_no` and `tax_no` are read-only for members once the organization is active (`RegistrationLock`). The admin edits them through the organization form (audited). Changing the CR number clears the CR check. The CR check is manual for now (admin organization page) behind `CommercialRegistryVerifier`.

**Storage and retention (§6)**: every evidence file goes through `ComplianceStorage` on `config('b2b_compliance.documents_disk')` (`B2B_DOCUMENTS_DISK`). That covers frozen originals, dispute packs, signatory authorizations and complaint attachments. Production must point this disk at storage hosted inside the Kingdom. Account deletion anonymises the profile and never deletes evidence. The name stays until 6 years after the relationship closed or the last invoice, whichever is later (`RetentionService`).

## Stream C notes

**Receipt (§7.4, template هـ)**
- Every goods receipt is `GRN-` numbered and frozen when recorded (revision 1). It is frozen again on the trader's confirmation, a dispute, or an edit inside the 48h window.
- `recorded_by_role` is `carrier`, `trader` or `supplier`. `pod_method` is `photo`, `signature`, `otp` or `scan`. Each line splits what was not accepted into `shortage_qty` and `defect_qty`, plus a `defect_note`.
- A line that is not fully accepted needs a shortage quantity or a note. A defective quantity needs a note.
- The trader's confirmation is `ReceiptConfirmationService`, by one of two methods. Recording a receipt is never the trader's acceptance.
  - Level 2: `otp_code`.
  - A photo (an image file) plus the declaration: `confirm_photo` and `declaration_accepted=1`.
- A confirmed receipt cannot be edited. Corrections go through a return note or a credit note.

**Invoice (§7.5, template و)**
- No invoice is created without `purchase_order_id`; this is enforced on the model.
- Credit and consignment orders need a receipt the trader confirmed. «وصل ولم يُؤكَّد» does not open invoicing. Direct orders invoice the carrier-recorded quantities. A proforma (prepaid) invoice is for direct orders only.
- A consignment order is never invoiced from receipts. The sale invoice comes from recorded sale events through `ConsignmentInvoiceService`, with VAT. It is linked to the contract's standing consignment order, which needs a signed framework agreement.
- `InvoiceComplianceService::stamp` snapshots the following:
  - seller = supplier, buyer, both VAT numbers;
  - «فاتورة ضريبية»;
  - the ZATCA phase-1 TLV QR (`ZatcaQr`);
  - `chain_refs` (PO, FA, GRNs).
- VAT can only be charged when the seller has a VAT number (`invoice_seller_vat_required`). The switch is `b2b_compliance.invoice.require_seller_vat`, which defaults to true.
- ZATCA phase 2 (Fatoora clearance/reporting, UBL XML, cryptographic stamp) is **not** implemented.

**Credit / debit notes (template ح)**
- `adjustment_notes` carry `purchase_order_id`, `return_note_id` and `note_no`: `CN-` for credit, `DNADJ-` for debit. They are frozen when issued as `credit_note` / `debit_note`.
- A return reason (`return_note`, `return`, …) needs `return_note_id`.
- An issued invoice's instalment amount cannot be lowered by hand.

**Return notes (§7.6, template ز)** are stored on `post_invoice_returns` and numbered `RN-`.
- PO required, invoice optional.
- Reasons: `defect`, `shortage_correction`, `unsold_consignment` (consignment only, 60-day window by default) and `agreed`.
- Quantity ≤ received minus other open returns. Without an invoice, only the uninvoiced quantity can go back.
- Statuses: `requested` → `accepted` (the other party, level 2) or `rejected` (the other party). With an invoice, acceptance issues a linked `CN-` and moves to `credit_issued`. The supplier then records `goods_returned`.
- A requested or accepted pre-invoice return keeps its quantity out of the next invoice.
- Legacy statuses and reasons map through `ChainLabels`.

**Consignment (§9)**
- Defaults are 14 / 14 / 60, `return_cost_bearer=buyer` and `title_holder=supplier`.
- Precedence: the order's values, then the contract's, then config.
- Either party may write the terms into a consignment order before its acceptance (`ConsignmentTermsService`). They are locked afterwards; changes go through an addendum.
- Empty terms are copied into the order when the goods leave (the DN freeze).
- Custody ledger: received (consignment shipments + GRNs of consignment orders) − sold − returned − losses.

**Mobile endpoints** (`/api/v2`)
- Goods receipts:
  - `POST goods_receipts/{goods_receipt_id}/confirmation`, sending either `{otp_code}` or `{confirm_photo, declaration_accepted}`. Before an `otp_code`, call `POST acceptance_challenges {document_type: goods_receipt}`.
  - `GET goods_receipts/{goods_receipt_id}/pdf`
- Invoice and credit note PDFs:
  - `GET invoices/{invoice_id}/pdf`
  - `GET credit_notes/{credit_note_id}/pdf`
- Return notes:
  - `GET|POST return_notes`
  - `GET return_notes/{return_note_id}`
  - `PATCH return_notes/{return_note_id}/status`, with `{status: accepted + otp_code | rejected + reason | goods_returned}`
  - `GET return_notes/{return_note_id}/pdf`
  - `GET purchase_orders/{purchase_order_id}/returnable_quantities`
- Consignment:
  - `GET consignment/custody_ledger`
  - `PATCH purchase_orders/{purchase_order_id}/consignment_terms`
  - `POST contracts/{contract_id}/consignment_sale_invoices`
- Existing payloads gained additive fields (`ChainPayloads`): receipt confirmation state, the ZATCA block on invoices, and `note_no` on adjustments.

## Stream D notes

**Late payment (§7.7, templates ي/ك).** `LatePaymentService` + `SupplyStatusService` (the only writer of `business_relationships.supply_status`). Due date + 1: `FinanceNotifier` sends «تذكير بالسداد» (not a notice) and logs `reminder_sent`. NTC1 (supplier, from the invoice page): principal only, grace = 5 Saudi business days, frozen + level-1 issue record, delivered to the trader's signatories. `b2b:late-payment-sweep` (daily 01:45): grace over and unpaid → `supply_suspended`, unexecuted orders get `purchase_orders.supply_hold_at` (a hold, never a cancel; a held order cannot move to approved/accepted/ready or get a delivery note). NTC2 (after the NTC1 grace): `accelerated`, every unpaid future instalment of the relationship becomes due today (`original_due_date` kept, amounts untouched). Everything paid → `active`, holds released; the supplier may also restore manually. `CreditEvaluator` no longer reads `auto_freeze_on_overdue`.

**Contract terms.** `ContractTermPolicy` refuses penalty/interest/late-fee/fine/compensation names (Latin and Arabic) and non-whitelisted sections on every `ContractTerm` save. Migration `130100` moved legacy rows of that kind to `notes` (prefixed, never deleted).

**Dispute pack (§7.8, template م).** `DisputePackBuilder` collects `FrozenDocument`s by own key and by parent links (plus their framework/quotation/request ancestors), adds never-frozen records marked «مستند حي — غير مجمد», the Nafith number, the notices log and the audit log; one PDF + `json/` folder in a ZIP with SHA-256 per item, stored on `documents_disk`, frozen as `dispute_pack`.

**Marketer (§11, template ل).** `MarketerService`: `MK-` assignment with a frozen rate, accepted by the marketer (level 1). Commission rows link marketer + PO + invoice; `pending` until the invoice turns `paid`, then `earned` on the invoice net of approved credit notes; void on cancel / full return before collection; recomputed after a credit note following collection; self-purchase void.

**Money (§13).** `wallet_enabled` and `commission_on_goods_invoices` are off: wallet API answers `404 wallet_disabled`, top-ups refused, `CommissionEngine` is a no-op; old wallet rows stay readable for admins. Platform fees are `service_invoices` (`SINV-`): one per captured subscription payment, and a documentation fee only when `fees.documentation_fee_amount` is set and the goods invoice was completed after the supplier's `free_until` (= first activation + 6 months). Consumer cart/checkout is refused by `LegacyShopGate` while `consumer_checkout_enabled` is off.

**Nafith (§10.2).** `NafithPromissoryService` + `NafithClient` (HTTP skeleton, off until `NAFITH_ENABLED` and credentials). Supplier signatory, credit invoice only, amount = the invoice's outstanding amount to the halala, Article 87 elements checked before sending; failure creates nothing. When the API is off the UI shows the external link (`NAFITH_FALLBACK_URL`) and records the instrument number Nafith issued. The contract-level PDF upload is closed (`promissory_pdf_path_removed`).

**Mobile endpoints** (`/api/v2`)
- Late payment: `GET late_payment_notices`, `GET late_payment_notices/{notice_id}`, `GET invoices/{invoice_id}/late_payment`, `POST invoices/{invoice_id}/late_payment_notices {kind: first|second}`, `PATCH relationships/{relationship_id}/supply/status {supply_status: active}`.
- Dispute pack: `GET|POST dispute_packs {scope_type: purchase_order|invoice|relationship, scope_id}`, `GET dispute_packs/{dispute_pack_id}`, `GET dispute_packs/{dispute_pack_id}/file` (ZIP).
- Marketer: `GET|POST marketer`, `GET marketer/assignments`, `PATCH marketer/assignments/{assignment_id}/status {status: active}`, `GET marketer/commissions`; supplier: `GET|POST marketer_assignments`, `PATCH marketer_assignments/{assignment_id}/status {status: ended}`, `POST marketer_assignments/{assignment_id}/purchase_orders {purchase_order_id}`, `GET marketer_commissions`.
- Nafith: `GET|POST invoices/{invoice_id}/promissory_notes`.
- Service invoices: `GET service_invoices` (with the free period), `GET service_invoices/{service_invoice_id}`.
