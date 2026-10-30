# API REST migration map

All API routes were converted from POST-only RPC style to REST verbs on 2026-09-03, before any client shipped. This file is the old → new map for the mobile and web clients.

## Rules that changed

- Ids that used to be in the body are now in the path: `POST /v2/purchase_order/show {purchase_order_id}` → `GET /v2/purchase_orders/{purchase_order_id}`.
- Reads are `GET`. Filters (`status`, `limit`, `before_id`, `contract_id`, …) go in the query string. Arrays use `sku_ids[]=1&sku_ids[]=2`.
- Status transitions are `PATCH …/status` with `status` (and optional `note`) in the body.
- Deletes are `DELETE`. A body is still allowed for optional fields such as `reason`.
- `user_id` no longer needs to be sent. It is derived from the `Authorization: Bearer <jwt>` header (or the legacy `jwt:` header). Sending it is still accepted.
- `organization_id` can be sent as the `X-Organization-Id` header instead of a body/query field. Omitted, it falls back to the user's primary organization as before.
- Fleet-company panel sessions can be sent as `X-Fleet-Company-Id` and `X-Fleet-Session-Token` headers.
- Multipart uploads stay `POST` (PHP only parses multipart on POST): profile image, product images, pack subscription receipt, order payment receipt, search-request attachments, organization logo/cover, onboarding documents, generic uploads.
- Response bodies are unchanged. The `msg`/`bag` validation shape is unchanged.
- The driver OTP aliases under `/driver/otp/*` were removed; use `/driver/stops/{stop_id}/otp/*`.

Server side, `App\Http\Middleware\ResolveApiRequestContext` merges path ids and header context into the request input, so controllers still validate the same field names.

## Route map


### v1 marketplace

| Old | New | Controller |
|---|---|---|
| `GET /api/countries` | `GET /api/countries` | `SettingController@get_countries` |
| `GET /api/abouts` | `GET /api/abouts` | `SettingController@get_abouts` |
| `GET /api/terms` | `GET /api/terms` | `SettingController@get_terms` |
| `GET /api/support` | `GET /api/support` | `SettingController@get_support` |
| `POST /api/auth/update_token` | `PUT /api/auth/device_token` | `AuthController@update_token` |
| `POST /api/auth/register` | `POST /api/auth/register` | `AuthController@register` |
| `POST /api/auth/login` | `POST /api/auth/login` | `AuthController@login` |
| `POST /api/auth/update` | `POST /api/auth/profile` | `AuthController@update` |
| `POST /api/auth/update_password` | `PATCH /api/auth/password` | `AuthController@update_password` |
| `POST /api/auth/city/update` | `PATCH /api/auth/city` | `AuthController@update_city` |
| `POST /api/auth/send_reset` | `POST /api/auth/password/forgot` | `AuthController@send_reset` |
| `POST /api/auth/check_reset` | `POST /api/auth/password/verify_code` | `AuthController@check_reset` |
| `POST /api/auth/password_reset` | `POST /api/auth/password/reset` | `AuthController@password_reset` |
| `POST /api/auth/addresses` | `GET /api/auth/addresses` | `AuthController@get_addresses` |
| `POST /api/auth/address/store` | `POST /api/auth/addresses` | `AuthController@store_address` |
| `POST /api/auth/address/update` | `PATCH /api/auth/addresses/{address_id}` | `AuthController@update_address` |
| `POST /api/auth/address/delete` | `DELETE /api/auth/addresses/{address_id}` | `AuthController@destroy_address` |
| `POST /api/auth/contact_us` | `POST /api/contact_us` | `AuthController@contact_us` |
| `POST /api/auth/search_request` | `POST /api/search_requests` | `AuthController@search_request` |
| `POST /api/auth/notifications` | `GET /api/auth/notifications` | `AuthController@notifications` |
| `POST /api/auth/notification/delete` | `DELETE /api/auth/notifications/{notification_id}` | `AuthController@destroy_notification` |
| `POST /api/auth/user/profile` | `GET /api/sellers/{seller_id}` | `AuthController@profile` |
| `POST /api/home` | `GET /api/home` | `HomeController@index` |
| `POST /api/search` | `GET /api/search` | `HomeController@search` |
| `POST /api/categories` | `GET /api/categories` | `HomeController@categories` |
| `POST /api/category/products` | `GET /api/categories/{cat_id}/products` | `HomeController@category_products` |
| `POST /api/all_products` | `GET /api/products` | `HomeController@all_products` |
| `POST /api/packs` | `GET /api/packs` | `PackController@index` |
| `POST /api/pack/subscribe` | `POST /api/packs/{pack_id}/subscribe` | `PackController@subscribe` |
| `POST /api/favorites` | `GET /api/favorites` | `FavoriteController@index` |
| `POST /api/favorite/handle` | `POST /api/favorites/{product_id}/toggle` | `FavoriteController@handle` |
| `POST /api/product/show` | `GET /api/products/{product_id}` | `ProductController@show` |
| `POST /api/product/store` | `POST /api/products` | `ProductController@store` |
| `POST /api/cart/index` | `GET /api/cart` | `CartController@index` |
| `POST /api/cart/store` | `POST /api/cart` | `CartController@store` |
| `POST /api/cart/delete` | `DELETE /api/cart/{cart_id}` | `CartController@destroy` |
| `POST /api/cart/checkout` | `POST /api/cart/checkout` | `CartController@checkout` |
| `POST /api/orders/index` | `GET /api/orders` | `OrderController@index` |
| `POST /api/order/show` | `GET /api/orders/{order_id}` | `OrderController@show` |
| `POST /api/order/update` | `POST /api/orders/{order_id}/receipt` | `OrderController@update` |
| `POST /api/order/change_status` | `PATCH /api/orders/{order_id}/status` | `OrderController@change_status` |
| `POST /api/chat` | `GET /api/chat` | `ChatController@index` |
| `POST /api/chat/room` | `GET /api/chat/{with_id}` | `ChatController@show` |
| `POST /api/chat/store` | `POST /api/chat` | `ChatController@store` |

### v2 bootstrap

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/bootstrap` | `GET /api/v2/bootstrap` | `V2\BootstrapController@index` |

### v2 organizations

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/organizations` | `GET /api/v2/organizations` | `V2\OrganizationController@index` |

### v2 organization

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/organization/show` | `GET /api/v2/organization` | `V2\OrganizationController@show` |
| `POST /api/v2/organization/update` | `PATCH /api/v2/organization` | `V2\OrganizationController@update` |
| `POST /api/v2/organization/branch/store` | `POST /api/v2/organization/branches` | `V2\OrganizationController@storeBranch` |
| `POST /api/v2/organization/branch/update` | `PATCH /api/v2/organization/branches/{branch_id}` | `V2\OrganizationController@updateBranch` |
| `POST /api/v2/organization/posts` | `GET /api/v2/organization/posts` | `V2\OrganizationPostController@index` |
| `POST /api/v2/organization/post/store` | `POST /api/v2/organization/posts` | `V2\OrganizationPostController@store` |
| `POST /api/v2/organization/post/delete` | `DELETE /api/v2/organization/posts/{post_id}` | `V2\OrganizationPostController@destroy` |
| `POST /api/v2/organization/post/like` | `POST /api/v2/organization/posts/{post_id}/like` | `V2\OrganizationPostController@toggleLike` |
| `POST /api/v2/organization/post/comments` | `GET /api/v2/organization/posts/{post_id}/comments` | `V2\OrganizationPostController@comments` |
| `POST /api/v2/organization/post/comment/store` | `POST /api/v2/organization/posts/{post_id}/comments` | `V2\OrganizationPostController@commentStore` |
| `POST /api/v2/organization/post/comment/delete` | `DELETE /api/v2/organization/comments/{comment_id}` | `V2\OrganizationPostController@commentDestroy` |
| `POST /api/v2/organization/upload_logo` | `POST /api/v2/organization/logo` | `V2\OrganizationProfileImageController@uploadLogo` |
| `POST /api/v2/organization/upload_cover` | `POST /api/v2/organization/cover` | `V2\OrganizationProfileImageController@uploadCover` |
| `POST /api/v2/organization/update_bio` | `PATCH /api/v2/organization/bio` | `V2\OrganizationProfileImageController@updateBio` |

### v2 relationships

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/relationships` | `GET /api/v2/relationships` | `V2\RelationshipController@index` |

### v2 relationship

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/relationship/show` | `GET /api/v2/relationships/{relationship_id}` | `V2\RelationshipController@show` |
| `POST /api/v2/relationship/store` | `POST /api/v2/relationships` | `V2\RelationshipController@store` |
| `POST /api/v2/relationship/change_status` | `PATCH /api/v2/relationships/{relationship_id}/status` | `V2\RelationshipController@changeStatus` |

### v2 credit

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/credit/show` | `GET /api/v2/relationships/{relationship_id}/credit` | `V2\CreditController@show` |
| `POST /api/v2/credit/profile/update` | `PUT /api/v2/relationships/{relationship_id}/credit` | `V2\CreditController@updateProfile` |

### v2 catalog

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/catalog/suppliers` | `GET /api/v2/catalog/suppliers` | `V2\CatalogController@suppliers` |
| `POST /api/v2/catalog/products` | `GET /api/v2/catalog/products` | `V2\CatalogController@index` |
| `POST /api/v2/catalog/product/show` | `GET /api/v2/catalog/products/{product_id}` | `V2\CatalogController@show` |
| `POST /api/v2/catalog/supplier/show` | `GET /api/v2/catalog/suppliers/{supplier_organization_id}` | `V2\CatalogController@supplierShow` |
| `POST /api/v2/catalog/sku/rules/save` | `PUT /api/v2/catalog/products/{product_id}/skus/{sku_id}/rules` | `V2\CatalogController@saveSkuRules` |

### v2 pricing

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/pricing/payment_terms` | `GET /api/v2/pricing/payment_terms` | `V2\PricingController@paymentTerms` |
| `POST /api/v2/pricing/price_lists` | `GET /api/v2/pricing/price_lists` | `V2\PricingController@priceLists` |
| `POST /api/v2/pricing/price_list/store` | `POST /api/v2/pricing/price_lists` | `V2\PricingController@storePriceList` |
| `POST /api/v2/pricing/price_item/store` | `POST /api/v2/pricing/price_items` | `V2\PricingController@storePriceItem` |
| `POST /api/v2/pricing/resolve` | `GET /api/v2/pricing/resolve` | `V2\PricingController@resolve` |

### v2 purchase drafts

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/purchase_drafts` | `GET /api/v2/purchase_drafts` | `V2\PurchaseDraftController@index` |

### v2 purchase draft

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/purchase_draft/store` | `POST /api/v2/purchase_drafts` | `V2\PurchaseDraftController@store` |
| `POST /api/v2/purchase_draft/show` | `GET /api/v2/purchase_drafts/{draft_id}` | `V2\PurchaseDraftController@show` |
| `POST /api/v2/purchase_draft/line/store` | `POST /api/v2/purchase_drafts/{draft_id}/lines` | `V2\PurchaseDraftController@storeLine` |
| `POST /api/v2/purchase_draft/line/delete` | `DELETE /api/v2/purchase_drafts/{draft_id}/lines/{line_id}` | `V2\PurchaseDraftController@destroyLine` |
| `POST /api/v2/purchase_draft/submit` | `POST /api/v2/purchase_drafts/{draft_id}/submit` | `V2\PurchaseDraftController@submit` |

### v2 purchase orders

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/purchase_orders` | `GET /api/v2/purchase_orders` | `V2\PurchaseOrderController@index` |

### v2 purchase order

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/purchase_order/show` | `GET /api/v2/purchase_orders/{purchase_order_id}` | `V2\PurchaseOrderController@show` |
| `POST /api/v2/purchase_order/timeline` | `GET /api/v2/purchase_orders/{purchase_order_id}/timeline` | `V2\PurchaseOrderController@timeline` |
| `POST /api/v2/purchase_order/change_status` | `PATCH /api/v2/purchase_orders/{purchase_order_id}/status` | `V2\PurchaseOrderController@changeStatus` |

### v2 delivery notes

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/delivery_notes` | `GET /api/v2/delivery_notes` | `V2\DeliveryNoteController@index` |

### v2 delivery note

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/delivery_note/show` | `GET /api/v2/delivery_notes/{delivery_note_id}` | `V2\DeliveryNoteController@show` |
| `POST /api/v2/delivery_note/store` | `POST /api/v2/delivery_notes` | `V2\DeliveryNoteController@store` |
| `POST /api/v2/delivery_note/change_status` | `PATCH /api/v2/delivery_notes/{delivery_note_id}/status` | `V2\DeliveryNoteController@changeStatus` |
| `POST /api/v2/delivery_note/seals/apply` | `POST /api/v2/delivery_notes/{delivery_note_id}/seals` | `V2\DeliveryNoteController@applySeals` |

### v2 goods receipts

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/goods_receipts` | `GET /api/v2/goods_receipts` | `V2\GoodsReceiptController@index` |

### v2 goods receipt

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/goods_receipt/show` | `GET /api/v2/goods_receipts/{goods_receipt_id}` | `V2\GoodsReceiptController@show` |
| `POST /api/v2/goods_receipt/store` | `POST /api/v2/goods_receipts` | `V2\GoodsReceiptController@store` |
| `POST /api/v2/goods_receipt/dispute` | `POST /api/v2/goods_receipts/{goods_receipt_id}/dispute` | `V2\GoodsReceiptController@dispute` |

### v2 invoices

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/invoices` | `GET /api/v2/invoices` | `V2\InvoiceController@index` |

### v2 invoice

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/invoice/show` | `GET /api/v2/invoices/{invoice_id}` | `V2\InvoiceController@show` |
| `POST /api/v2/invoice/issue` | `POST /api/v2/invoices` | `V2\InvoiceController@issue` |
| `POST /api/v2/invoice/issue_proforma` | `POST /api/v2/invoices/proforma` | `V2\InvoiceController@issueProforma` |
| `POST /api/v2/invoice/due_schedule/update` | `PATCH /api/v2/invoices/due_schedules/{due_schedule_id}` | `V2\InvoiceController@updateDueSchedule` |

### v2 collections

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/collections` | `GET /api/v2/collections` | `V2\CollectionController@index` |

### v2 collection

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/collection/show` | `GET /api/v2/collections/{collection_receipt_id}` | `V2\CollectionController@show` |
| `POST /api/v2/collection/store` | `POST /api/v2/collections` | `V2\CollectionController@store` |
| `POST /api/v2/collection/claim` | `POST /api/v2/collections/claim` | `V2\CollectionController@claim` |
| `POST /api/v2/collection/change_status` | `PATCH /api/v2/collections/{collection_receipt_id}/status` | `V2\CollectionController@changeStatus` |

### v2 adjustments

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/adjustments` | `GET /api/v2/adjustments` | `V2\AdjustmentController@index` |

### v2 adjustment

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/adjustment/show` | `GET /api/v2/adjustments/{adjustment_note_id}` | `V2\AdjustmentController@show` |
| `POST /api/v2/adjustment/store` | `POST /api/v2/adjustments` | `V2\AdjustmentController@store` |
| `POST /api/v2/adjustment/change_status` | `PATCH /api/v2/adjustments/{adjustment_note_id}/status` | `V2\AdjustmentController@changeStatus` |

### v2 post invoice returns

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/post_invoice_returns` | `GET /api/v2/post_invoice_returns` | `V2\PostInvoiceReturnController@index` |

### v2 post invoice return

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/post_invoice_return/show` | `GET /api/v2/post_invoice_returns/{post_invoice_return_id}` | `V2\PostInvoiceReturnController@show` |
| `POST /api/v2/post_invoice_return/store` | `POST /api/v2/post_invoice_returns` | `V2\PostInvoiceReturnController@store` |
| `POST /api/v2/post_invoice_return/change_status` | `PATCH /api/v2/post_invoice_returns/{post_invoice_return_id}/status` | `V2\PostInvoiceReturnController@changeStatus` |

### v2 ops

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/ops/panel` | `GET /api/v2/ops/panel` | `V2\OpsPanelController@index` |
| `POST /api/v2/ops/quick_actions` | `GET /api/v2/ops/quick_actions` | `V2\OpsPanelController@actions` |
| `POST /api/v2/ops/documents` | `GET /api/v2/ops/documents` | `V2\OpsPanelController@documents` |

### v2 supplier

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/supplier/follow` | `POST /api/v2/suppliers/{supplier_organization_id}/follow` | `V2\SupplierFollowController@follow` |
| `POST /api/v2/supplier/unfollow` | `DELETE /api/v2/suppliers/{supplier_organization_id}/follow` | `V2\SupplierFollowController@unfollow` |
| `POST /api/v2/supplier/follow_status` | `GET /api/v2/suppliers/{supplier_organization_id}/follow` | `V2\SupplierFollowController@status` |
| `POST /api/v2/supplier/following` | `GET /api/v2/suppliers/following` | `V2\SupplierFollowController@following` |
| `POST /api/v2/supplier/public_catalog` | `GET /api/v2/suppliers/{supplier_organization_id}/public_catalog` | `V2\LookupController@supplierPublicCatalog` |

### v2 ratings

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/ratings` | `GET /api/v2/ratings` | `V2\RatingController@index` |

### v2 rating

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/rating/aggregate` | `GET /api/v2/ratings/aggregate` | `V2\RatingController@aggregate` |
| `POST /api/v2/rating/store` | `POST /api/v2/ratings` | `V2\RatingController@store` |
| `POST /api/v2/rating/suggest_classification` | `GET /api/v2/ratings/suggest_classification` | `V2\RatingController@suggestClassification` |

### v2 subscription

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/subscription/plans` | `GET /api/v2/subscription/plans` | `V2\SubscriptionController@plans` |
| `POST /api/v2/subscription/current` | `GET /api/v2/subscription/current` | `V2\SubscriptionController@current` |
| `POST /api/v2/subscription/billing_mode` | `PUT /api/v2/subscription/billing_mode` | `V2\SubscriptionController@chooseBillingMode` |
| `POST /api/v2/subscription/start_trial` | `POST /api/v2/subscription/trial` | `V2\SubscriptionController@startTrial` |

### v2 admin

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/admin/subscription/assign` | `POST /api/v2/admin/subscriptions` | `V2\SubscriptionController@assign` |
| `POST /api/v2/admin/subscription/cancel` | `POST /api/v2/admin/subscriptions/{subscription_id}/cancel` | `V2\SubscriptionController@cancel` |

### v2 wallet

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/wallet/show` | `GET /api/v2/wallet` | `V2\WalletController@show` |
| `POST /api/v2/wallet/transactions` | `GET /api/v2/wallet/transactions` | `V2\WalletController@transactions` |
| `POST /api/v2/wallet/topup_request` | `POST /api/v2/wallet/topup_requests` | `V2\WalletController@topupRequest` |
| `POST /api/v2/wallet/topup_methods` | `GET /api/v2/wallet/topup_methods` | `V2\WalletController@topupMethods` |

### v2 platform

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/platform/flags` | `GET /api/v2/platform/flags` | `V2\PlatformSettingsController@publicFlags` |

### v2 vehicle

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/vehicle/maintenance` | `GET /api/v2/vehicles/{vehicle_id}/maintenance` | `V2\VehicleOpsController@maintenanceIndex` |
| `POST /api/v2/vehicle/maintenance/store` | `POST /api/v2/vehicles/{vehicle_id}/maintenance` | `V2\VehicleOpsController@maintenanceStore` |
| `POST /api/v2/vehicle/maintenance/change_status` | `PATCH /api/v2/vehicles/maintenance/{maintenance_record_id}/status` | `V2\VehicleOpsController@maintenanceChangeStatus` |
| `POST /api/v2/vehicle/fuel_logs` | `GET /api/v2/vehicles/{vehicle_id}/fuel_logs` | `V2\VehicleOpsController@fuelIndex` |
| `POST /api/v2/vehicle/fuel_log/store` | `POST /api/v2/vehicles/{vehicle_id}/fuel_logs` | `V2\VehicleOpsController@fuelStore` |
| `POST /api/v2/vehicle/alerts` | `GET /api/v2/vehicles/alerts` | `V2\VehicleOpsController@alertsIndex` |
| `POST /api/v2/vehicle/alerts/scan` | `POST /api/v2/vehicles/alerts/scan` | `V2\VehicleOpsController@alertsScan` |
| `POST /api/v2/vehicle/alert/acknowledge` | `POST /api/v2/vehicles/alerts/{vehicle_alert_id}/acknowledge` | `V2\VehicleOpsController@alertsAcknowledge` |

### v2 fleet company

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/fleet_company/login` | `POST /api/v2/fleet_company/login` | `V2\FleetCompanyController@login` |
| `POST /api/v2/fleet_company/logout` | `POST /api/v2/fleet_company/logout` | `V2\FleetCompanyController@logout` |
| `POST /api/v2/fleet_company/dashboard` | `GET /api/v2/fleet_company/dashboard` | `V2\FleetCompanyController@dashboard` |
| `POST /api/v2/fleet_company/drivers` | `GET /api/v2/fleet_company/drivers` | `V2\FleetCompanyController@drivers` |
| `POST /api/v2/fleet_company/vehicles` | `GET /api/v2/fleet_company/vehicles` | `V2\FleetCompanyController@vehicles` |
| `POST /api/v2/fleet_company/assignments` | `GET /api/v2/fleet_company/assignments` | `V2\FleetCompanyController@assignments` |
| `POST /api/v2/fleet_company/vehicle_alerts` | `GET /api/v2/fleet_company/vehicle_alerts` | `V2\FleetCompanyController@vehicleAlerts` |

### v2 contracts

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/contracts` | `GET /api/v2/contracts` | `V2\ContractController@index` |

### v2 contract

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/contract/show` | `GET /api/v2/contracts/{contract_id}` | `V2\ContractController@show` |
| `POST /api/v2/contract/store` | `POST /api/v2/contracts` | `V2\ContractController@store` |
| `POST /api/v2/contract/change_status` | `PATCH /api/v2/contracts/{contract_id}/status` | `V2\ContractController@changeStatus` |
| `POST /api/v2/contract/approval/action` | `POST /api/v2/contracts/{contract_id}/approvals/{contract_approval_id}` | `V2\ContractController@approvalAction` |

### v2 consignment shipments

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/consignment_shipments` | `GET /api/v2/consignment_shipments` | `V2\ConsignmentShipmentController@index` |

### v2 consignment shipment

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/consignment_shipment/show` | `GET /api/v2/consignment_shipments/{consignment_shipment_id}` | `V2\ConsignmentShipmentController@show` |
| `POST /api/v2/consignment_shipment/store` | `POST /api/v2/consignment_shipments` | `V2\ConsignmentShipmentController@store` |
| `POST /api/v2/consignment_shipment/change_status` | `PATCH /api/v2/consignment_shipments/{consignment_shipment_id}/status` | `V2\ConsignmentShipmentController@changeStatus` |

### v2 sales reports

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/sales_reports` | `GET /api/v2/sales_reports` | `V2\SalesReportController@index` |

### v2 sales report

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/sales_report/show` | `GET /api/v2/sales_reports/{sales_report_id}` | `V2\SalesReportController@show` |
| `POST /api/v2/sales_report/store` | `POST /api/v2/sales_reports` | `V2\SalesReportController@store` |
| `POST /api/v2/sales_report/change_status` | `PATCH /api/v2/sales_reports/{sales_report_id}/status` | `V2\SalesReportController@changeStatus` |

### v2 stock counts

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/stock_counts` | `GET /api/v2/stock_counts` | `V2\StockCountController@index` |

### v2 stock count

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/stock_count/show` | `GET /api/v2/stock_counts/{stock_count_id}` | `V2\StockCountController@show` |
| `POST /api/v2/stock_count/store` | `POST /api/v2/stock_counts` | `V2\StockCountController@store` |
| `POST /api/v2/stock_count/change_status` | `PATCH /api/v2/stock_counts/{stock_count_id}/status` | `V2\StockCountController@changeStatus` |

### v2 shelf adjustments

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/shelf_adjustments` | `GET /api/v2/shelf_adjustments` | `V2\ShelfAdjustmentController@index` |

### v2 shelf adjustment

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/shelf_adjustment/show` | `GET /api/v2/shelf_adjustments/{shelf_adjustment_id}` | `V2\ShelfAdjustmentController@show` |
| `POST /api/v2/shelf_adjustment/store` | `POST /api/v2/shelf_adjustments` | `V2\ShelfAdjustmentController@store` |
| `POST /api/v2/shelf_adjustment/change_status` | `PATCH /api/v2/shelf_adjustments/{shelf_adjustment_id}/status` | `V2\ShelfAdjustmentController@changeStatus` |
| `POST /api/v2/shelf_adjustment/previous_count` | `GET /api/v2/shelf_adjustments/previous_count` | `V2\ShelfAdjustmentController@previousCount` |

### v2 shelf

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/shelf/contracts` | `GET /api/v2/shelf/contracts` | `V2\ShelfPanelController@contracts` |
| `POST /api/v2/shelf/contract/visits` | `GET /api/v2/shelf/contracts/{contract_id}/visits` | `V2\ShelfPanelController@contractVisits` |
| `POST /api/v2/shelf/contract/invoices` | `GET /api/v2/shelf/contracts/{contract_id}/invoices` | `V2\ShelfPanelController@contractInvoices` |
| `POST /api/v2/shelf/visit/show` | `GET /api/v2/shelf/visits/{visit_id}` | `V2\ShelfPanelController@visitShow` |

### v2 settlements

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/settlements` | `GET /api/v2/settlements` | `V2\SettlementController@index` |

### v2 settlement

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/settlement/show` | `GET /api/v2/settlements/{settlement_run_id}` | `V2\SettlementController@show` |
| `POST /api/v2/settlement/store` | `POST /api/v2/settlements` | `V2\SettlementController@store` |
| `POST /api/v2/settlement/change_status` | `PATCH /api/v2/settlements/{settlement_run_id}/status` | `V2\SettlementController@changeStatus` |

### v2 payout

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/payout/show` | `GET /api/v2/payouts/{payout_id}` | `V2\SettlementController@showPayout` |
| `POST /api/v2/payout/store` | `POST /api/v2/settlements/{settlement_run_id}/payouts` | `V2\SettlementController@storePayout` |
| `POST /api/v2/payout/change_status` | `PATCH /api/v2/payouts/{payout_id}/status` | `V2\SettlementController@changePayoutStatus` |

### v2 dashboard

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/dashboard/overview` | `GET /api/v2/dashboard/overview` | `V2\DashboardController@overview` |
| `POST /api/v2/dashboard/aging` | `GET /api/v2/dashboard/aging` | `V2\DashboardController@aging` |
| `POST /api/v2/dashboard/risk_shelf` | `GET /api/v2/dashboard/risk_shelf` | `V2\DashboardController@riskShelf` |

### v2 lookups

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/lookups/suppliers` | `GET /api/v2/lookups/suppliers` | `V2\LookupController@suppliers` |
| `POST /api/v2/lookups/traders` | `GET /api/v2/lookups/traders` | `V2\LookupController@traders` |
| `POST /api/v2/lookups/relationships` | `GET /api/v2/lookups/relationships` | `V2\LookupController@relationships` |
| `POST /api/v2/lookups/contracts` | `GET /api/v2/lookups/contracts` | `V2\LookupController@contracts` |
| `POST /api/v2/lookups/payment_terms` | `GET /api/v2/lookups/payment_terms` | `V2\LookupController@paymentTerms` |
| `POST /api/v2/lookups/branches` | `GET /api/v2/lookups/branches` | `V2\LookupController@branches` |
| `POST /api/v2/lookups/bank_accounts` | `GET /api/v2/lookups/bank_accounts` | `V2\LookupController@bankAccounts` |
| `POST /api/v2/lookups/products` | `GET /api/v2/lookups/products` | `V2\LookupController@products` |
| `POST /api/v2/lookups/skus` | `GET /api/v2/lookups/skus` | `V2\LookupController@skus` |
| `POST /api/v2/lookups/purchase_orders` | `GET /api/v2/lookups/purchase_orders` | `V2\LookupController@purchaseOrders` |
| `POST /api/v2/lookups/delivery_notes` | `GET /api/v2/lookups/delivery_notes` | `V2\LookupController@deliveryNotes` |
| `POST /api/v2/lookups/invoices` | `GET /api/v2/lookups/invoices` | `V2\LookupController@invoices` |
| `POST /api/v2/lookups/settlements` | `GET /api/v2/lookups/settlements` | `V2\LookupController@settlements` |
| `POST /api/v2/lookups/business_sectors` | `GET /api/v2/lookups/business_sectors` | `V2\LookupController@businessSectors` |

### v2 uploads

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/uploads/mobile_attachment` | `POST /api/v2/uploads` | `V2\UploadController@mobileAttachment` |

### v2 onboarding

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/onboarding/bootstrap` | `GET /api/v2/onboarding/bootstrap` | `V2\OnboardingController@bootstrap` |
| `POST /api/v2/onboarding/organization/save` | `PUT /api/v2/onboarding/organization` | `V2\OnboardingController@saveOrganization` |
| `POST /api/v2/onboarding/profile/save` | `PUT /api/v2/onboarding/profile` | `V2\OnboardingController@saveProfile` |
| `POST /api/v2/onboarding/branch/store` | `POST /api/v2/onboarding/branches` | `V2\OnboardingController@storeBranch` |
| `POST /api/v2/onboarding/bank/store` | `POST /api/v2/onboarding/bank_accounts` | `V2\OnboardingController@storeBankAccount` |
| `POST /api/v2/onboarding/document/store` | `POST /api/v2/onboarding/documents` | `V2\OnboardingController@storeDocument` |
| `POST /api/v2/onboarding/profile/submit` | `POST /api/v2/onboarding/profile/submit` | `V2\OnboardingController@submitProfile` |
| `POST /api/v2/onboarding/register-owner` | `POST /api/v2/onboarding/register_owner` | `V2\OnboardingController@registerOwner` |

### v2 action center

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/action_center` | `GET /api/v2/action_center` | `V2\ActionCenterController@index` |
| `POST /api/v2/action_center/mark_read` | `POST /api/v2/action_center/mark_read` | `V2\ActionCenterController@markRead` |

### v2 approvals

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/approvals` | `GET /api/v2/approvals` | `V2\ApprovalInboxController@index` |

### v2 approval

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/approval/purchase_order/action` | `POST /api/v2/approvals/purchase_orders/{purchase_order_approval_id}` | `V2\ApprovalInboxController@purchaseOrderAction` |

### v2 document flow

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/document_flow/show` | `GET /api/v2/document_flow/{entity_type}/{entity_id}` | `V2\DocumentFlowController@show` |
| `POST /api/v2/document_flow/timeline` | `GET /api/v2/document_flow/{entity_type}/{entity_id}/timeline` | `V2\DocumentFlowController@timeline` |

### v2 health

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/health/launch_readiness` | `GET /api/v2/health/launch_readiness` | `V2\HealthController@launchReadiness` |
| `POST /api/v2/health/reconciliation` | `GET /api/v2/health/reconciliation` | `V2\HealthController@reconciliation` |

### v2 mobile

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/mobile/web_bridge` | `POST /api/v2/mobile/web_bridge` | `V2\MobileBridgeController@webBridge` |

### v2 fleet

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/fleet/drivers` | `GET /api/v2/fleet/drivers` | `V2\FleetController@drivers` |
| `POST /api/v2/fleet/driver/store` | `POST /api/v2/fleet/drivers` | `V2\FleetController@driverStore` |
| `POST /api/v2/fleet/driver/show` | `GET /api/v2/fleet/drivers/{driver_id}` | `V2\FleetController@driverShow` |
| `POST /api/v2/fleet/driver/change_status` | `PATCH /api/v2/fleet/drivers/{driver_id}/status` | `V2\FleetController@driverChangeStatus` |
| `POST /api/v2/fleet/vehicles` | `GET /api/v2/fleet/vehicles` | `V2\FleetController@vehicles` |
| `POST /api/v2/fleet/vehicle/store` | `POST /api/v2/fleet/vehicles` | `V2\FleetController@vehicleStore` |
| `POST /api/v2/fleet/vehicle/change_status` | `PATCH /api/v2/fleet/vehicles/{vehicle_id}/status` | `V2\FleetController@vehicleChangeStatus` |
| `POST /api/v2/fleet/companies` | `GET /api/v2/fleet/companies` | `V2\FleetController@companies` |
| `POST /api/v2/fleet/company/store` | `POST /api/v2/fleet/companies` | `V2\FleetController@companyStore` |
| `POST /api/v2/fleet/assignments` | `GET /api/v2/fleet/assignments` | `V2\FleetController@assignments` |
| `POST /api/v2/fleet/assignment/store` | `POST /api/v2/fleet/assignments` | `V2\FleetController@assignmentStore` |
| `POST /api/v2/fleet/performance/driver/{id}` | `GET /api/v2/fleet/performance/drivers/{id}` | `V2\DriverPerformanceController@driver` |
| `POST /api/v2/fleet/performance/summary` | `GET /api/v2/fleet/performance/summary` | `V2\DriverPerformanceController@summary` |

### v2 routes

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/routes` | `GET /api/v2/routes` | `V2\RouteController@index` |

### v2 route

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/route/store` | `POST /api/v2/routes` | `V2\RouteController@store` |
| `POST /api/v2/route/show` | `GET /api/v2/routes/{route_id}` | `V2\RouteController@show` |
| `POST /api/v2/route/change_status` | `PATCH /api/v2/routes/{route_id}/status` | `V2\RouteController@changeStatus` |
| `POST /api/v2/route/stop/reorder` | `PUT /api/v2/routes/{route_id}/stops/order` | `V2\RouteController@reorderStops` |
| `POST /api/v2/route/stop/reassign` | `POST /api/v2/routes/stops/{stop_id}/reassign` | `V2\RouteController@reassignStop` |
| `POST /api/v2/route/pending_tasks` | `GET /api/v2/routes/pending_tasks` | `V2\RouteController@pendingTasks` |

### v2 driver

**Push token at login (2026-09-17).** The `token` field that `POST /api/auth/login` and `POST /api/auth/register` already require is the FCM device token; `fcm_token` is accepted as an alias and wins when both are sent. It is now also stored in `push_tokens`, which is what every B2B push (route assigned, stop added, ...) reads, so drivers no longer need to call `POST /api/v2/push/register` separately. Optional extra fields on the same login body: `platform` (`android` | `ios` | `web`, guessed from the User-Agent when absent), `app_variant` (defaults to `driver` for driver accounts), `locale` (`ar` | `en`, falls back to `Accept-Language` then `users.lang`), `device_id`, `device_model`, `os_version`. `PUT /api/auth/device_token` does the same when called with a bearer token. A push-side failure never fails the login.

Driver accounts are created from the fleet portal with `type: "seller"`, because `users.type` only allows `seller`/`buyer`. To tell a driver apart, read `user.is_driver` in the `POST /api/auth/login`, `POST /api/auth/register` and `POST /api/auth/profile` responses: it is `true` when the account has a fleet driver record, which is the same check the `/api/v2/driver/*` endpoints use (they answer `403 not_a_driver` otherwise).

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/driver/profile` | `GET /api/v2/driver/profile` | `V2\DriverAppController@profile` |
| `POST /api/v2/driver/today_route` | `GET /api/v2/driver/today_route` | `V2\DriverAppController@todayRoute` |
| `POST /api/v2/driver/route/start` | `POST /api/v2/driver/routes/{route_id}/start` | `V2\DriverAppController@startRoute` |
| `POST /api/v2/driver/route/complete` | `POST /api/v2/driver/routes/{route_id}/complete` | `V2\DriverAppController@completeRoute` |
| `POST /api/v2/driver/stop/arrive` | `POST /api/v2/driver/stops/{stop_id}/arrive` | `V2\DriverAppController@arriveAtStop` |
| `POST /api/v2/driver/stop/pickup` | `POST /api/v2/driver/stops/{stop_id}/pickup` | `V2\DriverAppController@confirmPickup` |
| `POST /api/v2/driver/stop/deliver` | `POST /api/v2/driver/stops/{stop_id}/deliver` | `V2\DriverAppController@confirmDelivery` |
| `POST /api/v2/driver/stop/skip` | `POST /api/v2/driver/stops/{stop_id}/skip` | `V2\DriverAppController@skipStop` |
| `POST /api/v2/driver/stop/en_route` | `POST /api/v2/driver/stops/{stop_id}/en_route` | `V2\DriverAppController@markStopEnRoute` |
| `POST /api/v2/driver/proof/upload` | `POST /api/v2/driver/stops/{stop_id}/proof` | `V2\DriverAppController@uploadProof` |
| `POST /api/v2/driver/location/update` | `POST /api/v2/driver/location` | `V2\DriverAppController@updateLocation` |
| `POST /api/v2/driver/incident/report` | `POST /api/v2/driver/incidents` | `V2\DriverAppController@reportIncident` |
| `POST /api/v2/driver/history` | `GET /api/v2/driver/history` | `V2\DriverAppController@history` |
| `POST /api/v2/driver/end_of_day_summary` | `GET /api/v2/driver/end_of_day_summary` | `V2\DriverAppController@endOfDaySummary` |
| `POST /api/v2/driver/otp/resend` | `POST /api/v2/driver/stops/{stop_id}/otp/resend` | `V2\DriverAppController@resendOtp` |
| `POST /api/v2/driver/otp/verify` | `POST /api/v2/driver/stops/{stop_id}/otp/verify` | `V2\DriverAppController@verifyOtp` |
| `POST /api/v2/driver/sync/batch` | `POST /api/v2/driver/sync/batch` | `V2\DriverAppController@syncBatch` |
| `POST /api/v2/driver/profile/update` | `PATCH /api/v2/driver/profile` | `V2\DriverAppController@updateProfile` |
| `POST /api/v2/driver/available_vehicles` | `GET /api/v2/driver/vehicles/available` | `V2\DriverAppController@availableVehicles` |
| `POST /api/v2/driver/assign_vehicle` | `PUT /api/v2/driver/vehicle` | `V2\DriverAppController@assignVehicle` |
| `POST /api/v2/driver/notifications` | `GET /api/v2/driver/notifications` | `V2\DriverAppController@notifications` |
| `POST /api/v2/driver/notifications/read` | `PATCH /api/v2/driver/notifications/{id}/read` | `V2\DriverAppController@notificationsMarkRead` |
| `POST /api/v2/driver/notifications/read_all` | `PATCH /api/v2/driver/notifications/read_all` | `V2\DriverAppController@notificationsMarkAllRead` |
| `POST /api/v2/driver/earnings` | `GET /api/v2/driver/earnings` | `V2\DriverAppController@earnings` |
| `POST /api/v2/driver/stop/otp/verify` | `POST /api/v2/driver/stops/{stop_id}/otp/verify` | `V2\DriverAppController@verifyOtp` |
| `POST /api/v2/driver/stop/otp/resend` | `POST /api/v2/driver/stops/{stop_id}/otp/resend` | `V2\DriverAppController@resendOtp` |
| `POST /api/v2/driver/stop/barcode/verify` | `POST /api/v2/driver/stops/{stop_id}/barcode/verify` | `V2\DriverAppController@stopBarcodeVerify` |
| `POST /api/v2/driver/stop/seal/submit` | `POST /api/v2/driver/stops/{stop_id}/seals` | `V2\DriverAppController@stopSealSubmit` |
| `POST /api/v2/driver/stop/partial_reject` | `POST /api/v2/driver/stops/{stop_id}/partial_reject` | `V2\DriverAppController@stopPartialReject` |
| `POST /api/v2/driver/terms/accept` | `POST /api/v2/driver/terms/accept` | `V2\DriverAppController@acceptTerms` |
| `POST /api/v2/driver/language` | `PUT /api/v2/driver/language` | `V2\DriverAppController@setLanguage` |
| `POST /api/v2/driver/stop/receipt_status` | `GET /api/v2/driver/stops/{stop_id}/receipt_status` | `V2\DriverAppController@stopReceiptStatus` |
| `POST /api/v2/driver/uploads/attachment` | `POST /api/v2/driver/uploads` | `V2\UploadController@driverAttachment` |
| `POST /api/v2/driver/training/curriculum` | `GET /api/v2/driver/training/curriculum` | `V2\DriverTrainingController@curriculum` |
| `POST /api/v2/driver/training/module` | `GET /api/v2/driver/training/modules/{id}` | `V2\DriverTrainingController@module` |
| `POST /api/v2/driver/training/start` | `POST /api/v2/driver/training/modules/{id}/start` | `V2\DriverTrainingController@start` |
| `POST /api/v2/driver/training/submit` | `POST /api/v2/driver/training/modules/{id}/submit` | `V2\DriverTrainingController@submit` |
| `POST /api/v2/driver/training/certificate` | `GET /api/v2/driver/training/certificate` | `V2\DriverTrainingController@certificate` |
| `POST /api/v2/driver/performance` | `GET /api/v2/driver/performance` | `V2\DriverPerformanceController@self` |

### v2 internal transfers

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/internal_transfers` | `GET /api/v2/internal_transfers` | `V2\InternalTransferController@index` |

### v2 internal transfer

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/internal_transfer/store` | `POST /api/v2/internal_transfers` | `V2\InternalTransferController@store` |
| `POST /api/v2/internal_transfer/show` | `GET /api/v2/internal_transfers/{internal_transfer_id}` | `V2\InternalTransferController@show` |
| `POST /api/v2/internal_transfer/change_status` | `PATCH /api/v2/internal_transfers/{internal_transfer_id}/status` | `V2\InternalTransferController@changeStatus` |
| `POST /api/v2/internal_transfer/line/store` | `POST /api/v2/internal_transfers/{internal_transfer_id}/lines` | `V2\InternalTransferController@lineStore` |
| `POST /api/v2/internal_transfer/line/delete` | `DELETE /api/v2/internal_transfers/{internal_transfer_id}/lines/{line_id}` | `V2\InternalTransferController@lineDelete` |

### v2 tracking

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/tracking/live` | `GET /api/v2/tracking/live` | `V2\TrackingController@live` |
| `POST /api/v2/tracking/driver/trail` | `GET /api/v2/tracking/drivers/{driver_id}/trail` | `V2\TrackingController@driverTrail` |
| `POST /api/v2/tracking/route/status` | `GET /api/v2/tracking/routes/{route_id}/status` | `V2\TrackingController@routeStatus` |

### v2 delivery

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/delivery/tracking/status` | `GET /api/v2/delivery_notes/{delivery_note_id}/tracking` | `V2\DeliveryTrackingController@deliveryStatus` |
| `POST /api/v2/delivery/tracking/notifications` | `GET /api/v2/delivery/tracking/notifications` | `V2\DeliveryTrackingController@tradingNotifications` |
| — (new) | `GET /api/v2/notifications` | `V2\NotificationController@index` — bell list for trader/supplier apps, see `docs/notifications-api.md` |
| — (new) | `PATCH /api/v2/notifications/read_all` | `V2\NotificationController@markAllRead` |
| — (new) | `PATCH /api/v2/notifications/{notification_id}/read` | `V2\NotificationController@markRead` |
| `POST /api/v2/delivery/tracking/supplier_fleet` | `GET /api/v2/delivery/tracking/supplier_fleet` | `V2\DeliveryTrackingController@supplierFleetStatus` |
| `POST /api/v2/delivery/edit_window/status` | `GET /api/v2/delivery_notes/{delivery_note_id}/edit_window` | `V2\TraderEditController@status` |
| `POST /api/v2/delivery/edit_window/adjust` | `POST /api/v2/delivery_notes/{delivery_note_id}/edit_window/adjust` | `V2\TraderEditController@adjust` |
| `POST /api/v2/delivery/edit_window/close` | `POST /api/v2/delivery_notes/{delivery_note_id}/edit_window/close` | `V2\TraderEditController@close` |

### v2 biometric

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/biometric/challenge` | `POST /api/v2/biometric/challenge` | `V2\BiometricController@challenge` |
| `POST /api/v2/biometric/verify` | `POST /api/v2/biometric/verify` | `V2\BiometricController@verify` |
| `POST /api/v2/biometric/enroll` | `POST /api/v2/biometric/credentials` | `V2\BiometricController@enroll` |
| `POST /api/v2/biometric/list` | `GET /api/v2/biometric/credentials` | `V2\BiometricController@list` |
| `POST /api/v2/biometric/revoke` | `DELETE /api/v2/biometric/credentials/{credential_id}` | `V2\BiometricController@revoke` |

### v2 incident

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/incident/acknowledge` | `POST /api/v2/incidents/{incident_id}/acknowledge` | `V2\IncidentController@acknowledge` |
| `POST /api/v2/incident/investigate` | `POST /api/v2/incidents/{incident_id}/investigate` | `V2\IncidentController@investigate` |
| `POST /api/v2/incident/resolve` | `POST /api/v2/incidents/{incident_id}/resolve` | `V2\IncidentController@resolve` |
| `POST /api/v2/incident/reopen` | `POST /api/v2/incidents/{incident_id}/reopen` | `V2\IncidentController@reopen` |
| `POST /api/v2/incident/age` | `GET /api/v2/incidents/{incident_id}/age` | `V2\IncidentController@age` |

### v2 push

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/push/register` | `POST /api/v2/push/register` | `V2\PushController@register` |
| `POST /api/v2/push/unregister` | `POST /api/v2/push/unregister` | `V2\PushController@unregister` |
| `POST /api/v2/push/test` | `POST /api/v2/push/test` | `V2\PushController@test` |

### v2 b2b

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/b2b/owner-console/bootstrap` | `GET /api/v2/b2b/owner-console/bootstrap` | `V2\OnboardingController@bootstrap` |
| `POST /api/v2/b2b/owner-console/organization/save` | `PUT /api/v2/b2b/owner-console/organization` | `V2\OnboardingController@saveOrganization` |
| `POST /api/v2/b2b/owner-console/profile/save` | `PUT /api/v2/b2b/owner-console/profile` | `V2\OnboardingController@saveProfile` |
| `POST /api/v2/b2b/owner-console/branches` | `GET /api/v2/b2b/owner-console/branches` | `V2\OnboardingController@branches` |
| `POST /api/v2/b2b/owner-console/branch/save` | `POST /api/v2/b2b/owner-console/branches` | `V2\OnboardingController@storeBranch` |
| `POST /api/v2/b2b/owner-console/employees` | `GET /api/v2/b2b/owner-console/employees` | `V2\OnboardingController@employees` |
| `POST /api/v2/b2b/owner-console/employee/save` | `POST /api/v2/b2b/owner-console/employees` | `V2\OnboardingController@saveEmployee` |
| `POST /api/v2/b2b/owner-console/documents` | `GET /api/v2/b2b/owner-console/documents` | `V2\OnboardingController@documents` |
| `POST /api/v2/b2b/owner-console/document/save` | `POST /api/v2/b2b/owner-console/documents` | `V2\OnboardingController@storeDocument` |
| `POST /api/v2/b2b/owner-console/bank-accounts` | `GET /api/v2/b2b/owner-console/bank_accounts` | `V2\OnboardingController@bankAccounts` |
| `POST /api/v2/b2b/owner-console/bank-account/save` | `POST /api/v2/b2b/owner-console/bank_accounts` | `V2\OnboardingController@storeBankAccount` |
| `POST /api/v2/b2b/owner-console/request-workspace` | `POST /api/v2/b2b/owner-console/request_workspace` | `V2\OnboardingController@requestWorkspace` |
| `POST /api/v2/b2b/owner-console/submit-for-review` | `POST /api/v2/b2b/owner-console/submit_for_review` | `V2\OnboardingController@submitForReview` |
| `POST /api/v2/b2b/owner-console/profile/submit` | `POST /api/v2/b2b/owner-console/profile/submit` | `V2\OnboardingController@submitProfile` |
| `POST /api/v2/b2b/owner-console/register-owner` | `POST /api/v2/b2b/owner-console/register_owner` | `V2\OnboardingController@registerOwner` |

### v2 nafath

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/nafath/initiate` | `POST /api/v2/nafath/initiate` | `V2\NafathController@initiate` |
| `POST /api/v2/nafath/status` | `GET /api/v2/nafath/transactions/{transaction_id}` | `V2\NafathController@status` |
| `POST /api/v2/nafath/cancel` | `POST /api/v2/nafath/transactions/{transaction_id}/cancel` | `V2\NafathController@cancel` |

### v2 payment

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/payment/hyperpay/checkout` | `POST /api/v2/payment/hyperpay/checkout` | `V2\HyperPayController@createCheckout` |
| `POST /api/v2/payment/hyperpay/status` | `GET /api/v2/payment/hyperpay/status` | `V2\HyperPayController@checkStatus` |
| `POST /api/v2/payment/hyperpay/webhook` | `POST /api/v2/payment/hyperpay/webhook` | `V2\HyperPayController@webhook` |
| `POST /api/v2/payment/apple_pay/validate_merchant` | `POST /api/v2/payment/apple_pay/validate_merchant` | `V2\ApplePayController@validateMerchant` |
| `POST /api/v2/payment/apple_pay/process` | `POST /api/v2/payment/apple_pay/process` | `V2\ApplePayController@process` |

### v2 account

| Old | New | Controller |
|---|---|---|
| `POST /api/v2/account/deletion-request` | `POST /api/v2/account/deletion_request` | `V2\AccountDeletionController@submit` |
| `POST /api/v2/account/deletion-request/me` | `GET /api/v2/account/deletion_request` | `V2\AccountDeletionController@me` |
| `POST /api/v2/account/deletion-request/cancel` | `DELETE /api/v2/account/deletion_request` | `V2\AccountDeletionController@cancel` |
