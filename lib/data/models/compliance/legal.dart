import '../../../core/i18n/money.dart';
import '../../../core/network/coerce.dart';

/// Stream A: complaints, signatories, the registration lock, platform fees.
/// Verified on staging 2026-10-05.

/// `complaint_tickets` — with the 15-day response deadline (`due_at`).
class ComplaintTicket {
  final int id;
  final String ticketNo;
  final String category;
  final String categoryLabel;
  final String subject;

  /// `open`, `answered`, `closed`, …
  final String status;
  final String statusLabel;

  /// `on_track`, `due_soon`, `overdue`, … with the server's label.
  final String sla;
  final String slaLabel;

  /// UTC. The response deadline (15 days from opening).
  final DateTime? dueAt;
  final DateTime? answeredAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final bool unread;

  /// Detail only.
  final String body;
  final List<TicketAttachment> attachments;
  final List<TicketMessage> messages;

  const ComplaintTicket({
    required this.id,
    this.ticketNo = '',
    this.category = '',
    this.categoryLabel = '',
    this.subject = '',
    this.status = '',
    this.statusLabel = '',
    this.sla = '',
    this.slaLabel = '',
    this.dueAt,
    this.answeredAt,
    this.closedAt,
    this.createdAt,
    this.lastActivityAt,
    this.unread = false,
    this.body = '',
    this.attachments = const [],
    this.messages = const [],
  });

  bool get isClosed => status == 'closed';

  factory ComplaintTicket.fromJson(Map<String, dynamic> j) => ComplaintTicket(
    id: asInt(j['ticket_id']),
    ticketNo: asStr(j['ticket_no']),
    category: asStr(j['category']),
    categoryLabel: unwrap(j['category_label']),
    subject: unwrap(j['subject']),
    status: asStr(j['status']),
    statusLabel: unwrap(j['status_label']),
    sla: asStr(j['sla']),
    slaLabel: unwrap(j['sla_label']),
    dueAt: asUtcDate(j['due_at']),
    answeredAt: asUtcDate(j['answered_at']),
    closedAt: asUtcDate(j['closed_at']),
    createdAt: asUtcDate(j['created_at']),
    lastActivityAt: asUtcDate(j['last_activity_at']),
    unread: asBool(j['unread']),
    body: unwrap(j['body']),
    attachments: asList(j['attachments'], TicketAttachment.fromJson),
    messages: asList(j['messages'], TicketMessage.fromJson),
  );
}

class TicketMessage {
  final int id;

  /// `user` or `admin`.
  final String author;
  final String body;
  final bool isAnswer;
  final DateTime? createdAt;
  final List<TicketAttachment> attachments;

  const TicketMessage({
    required this.id,
    this.author = '',
    this.body = '',
    this.isAnswer = false,
    this.createdAt,
    this.attachments = const [],
  });

  bool get isMine => author == 'user';

  factory TicketMessage.fromJson(Map<String, dynamic> j) => TicketMessage(
    id: asInt(j['message_id']),
    author: asStr(j['author']),
    body: unwrap(j['body']),
    isAnswer: asBool(j['is_answer']),
    createdAt: asUtcDate(j['created_at']),
    attachments: asList(j['attachments'], TicketAttachment.fromJson),
  );
}

/// `{name, size, mime, url}`; `url` is the authenticated
/// `complaint_tickets/{id}/attachment?message=&i=` route.
class TicketAttachment {
  final String name;
  final int size;
  final String mime;
  final String url;

  const TicketAttachment({required this.name, this.size = 0, this.mime = '', this.url = ''});

  bool get isImage => mime.startsWith('image/');
  bool get isPdf => mime == 'application/pdf';

  factory TicketAttachment.fromJson(Map<String, dynamic> j) => TicketAttachment(
    name: asStr(j['name']),
    size: asInt(j['size']),
    mime: asStr(j['mime']),
    url: asStr(j['url']),
  );
}

class ComplaintCategory {
  final String key;
  final String label;

  const ComplaintCategory({required this.key, required this.label});

  factory ComplaintCategory.fromJson(Map<String, dynamic> j) =>
      ComplaintCategory(key: asStr(j['key']), label: unwrap(j['label']));
}

/// `GET /signatories`: the members, who may sign, and the registration lock.
class SignatoriesInfo {
  final RegistrationData organization;

  /// Owner only: add and remove signatories.
  final bool canManage;
  final List<Signatory> members;

  const SignatoriesInfo({
    required this.organization,
    this.canManage = false,
    this.members = const [],
  });

  int get signatoryCount => members.where((m) => m.isSignatory).length;

  factory SignatoriesInfo.fromJson(Map<String, dynamic> j) => SignatoriesInfo(
    organization: RegistrationData.fromJson(asMap(j['organization'])),
    canManage: asBool(j['can_manage']),
    members: asList(j['data'], Signatory.fromJson),
  );
}

class Signatory {
  final int membershipId;
  final int userId;
  final String name;
  final String jobTitle;
  final bool isOwner;
  final bool isSignatory;
  final bool hasAuthorizationDocument;

  const Signatory({
    required this.membershipId,
    this.userId = 0,
    this.name = '',
    this.jobTitle = '',
    this.isOwner = false,
    this.isSignatory = false,
    this.hasAuthorizationDocument = false,
  });

  factory Signatory.fromJson(Map<String, dynamic> j) => Signatory(
    membershipId: asInt(j['membership_id']),
    userId: asInt(j['user_id']),
    name: unwrap(j['name']),
    jobTitle: unwrap(j['job_title']),
    isOwner: asBool(j['is_owner']),
    isSignatory: asBool(j['is_authorized_signatory']),
    hasAuthorizationDocument: asBool(j['has_authorization_document']),
  );
}

/// The frozen registration fields (§3): read-only for members once the
/// organization is active; changed through the platform admin.
class RegistrationData {
  final int organizationId;
  final String legalNameAr;

  /// Numeric on the wire; text here so no digit is lost.
  final String commercialRegNo;
  final String vatNo;
  final String activityType;
  final String activityTypeLabel;
  final bool registrationLocked;
  final bool crVerified;

  const RegistrationData({
    this.organizationId = 0,
    this.legalNameAr = '',
    this.commercialRegNo = '',
    this.vatNo = '',
    this.activityType = '',
    this.activityTypeLabel = '',
    this.registrationLocked = false,
    this.crVerified = false,
  });

  factory RegistrationData.fromJson(Map<String, dynamic> j) => RegistrationData(
    organizationId: asInt(j['organization_id']),
    legalNameAr: unwrap(j['legal_name_ar']),
    commercialRegNo: asStr(j['commercial_reg_no']),
    vatNo: asStr(j['vat_no']),
    activityType: asStr(j['activity_type']),
    activityTypeLabel: unwrap(j['activity_type_label']),
    registrationLocked: asBool(j['registration_locked']),
    crVerified: asBool(j['cr_verified']),
  );
}

/// `GET /service_invoices` header: the free period after activation (3 months,
/// extended once by 3 more when the [extension] target is met in time).
class FreePeriod {
  final DateTime? activatedAt;
  final DateTime? freeUntil;
  final bool inFreePeriod;
  final int months;
  final FreePeriodExtension extension;

  const FreePeriod({
    this.activatedAt,
    this.freeUntil,
    this.inFreePeriod = false,
    this.months = 0,
    this.extension = const FreePeriodExtension(),
  });

  /// Whole days left, counted up (a period ending in 3 hours has 1 day left).
  int daysLeft(DateTime now) {
    final until = freeUntil;
    if (until == null || !until.isAfter(now)) return 0;
    return (until.difference(now).inHours / 24).ceil();
  }

  factory FreePeriod.fromJson(Map<String, dynamic> j) => FreePeriod(
    activatedAt: asUtcDate(j['account_activated_at']),
    freeUntil: asUtcDate(j['free_until']),
    inFreePeriod: asBool(j['in_free_period']),
    months: asInt(j['months']),
    extension: FreePeriodExtension.fromJson(asMap(j['extension'])),
  );
}

/// Progress toward the one-time extension: 20 frozen goods invoices **or**
/// 100,000 SAR ex-VAT within the first 3 months.
class FreePeriodExtension {
  final int invoices;
  final int invoicesTarget;
  final Money gmvExVat;
  final Money gmvTarget;

  /// `null`, `invoices` or `gmv` — which target was reached.
  final String? criterionMet;

  /// The end-of-period review already ran.
  final bool reviewed;

  /// The extension was granted.
  final bool extended;

  const FreePeriodExtension({
    this.invoices = 0,
    this.invoicesTarget = 0,
    this.gmvExVat = Money.zero,
    this.gmvTarget = Money.zero,
    this.criterionMet,
    this.reviewed = false,
    this.extended = false,
  });

  /// Older servers send no `extension` block; nothing to show then.
  bool get hasTargets => invoicesTarget > 0 || !gmvTarget.isZero;

  /// The target is met and the review that grants it is still to come.
  bool get pendingExtension => criterionMet != null && !reviewed && !extended;

  double get invoicesProgress =>
      invoicesTarget <= 0 ? 0 : (invoices / invoicesTarget).clamp(0, 1).toDouble();

  double get gmvProgress => gmvTarget.minorUnits <= 0
      ? 0
      : (gmvExVat.minorUnits / gmvTarget.minorUnits).clamp(0, 1).toDouble();

  factory FreePeriodExtension.fromJson(Map<String, dynamic> j) {
    final met = asStr(j['criterion_met']);
    return FreePeriodExtension(
      invoices: asInt(j['invoices']),
      invoicesTarget: asInt(j['invoices_target']),
      gmvExVat: Money.parse(j['gmv_ex_vat']),
      gmvTarget: Money.parse(j['gmv_target']),
      criterionMet: met.isEmpty ? null : met,
      reviewed: asBool(j['reviewed']),
      extended: asBool(j['extended']),
    );
  }
}

/// A platform service invoice (`SINV-`): a subscription, documentation or
/// advertising fee, or a month of 1% platform fees (`platform_fee`). Due 7
/// days after issue; while one is overdue, new orders are refused.
class ServiceInvoice {
  final int id;
  final String number;

  /// `subscription`, `documentation`, `advertising`, `platform_fee`, …
  final String kind;

  /// The server's name for [kind]; shown as is.
  final String kindLabel;
  final String status;
  final String statusLabel;

  /// Money comes as 2-decimal strings: kept exact.
  final Money total;
  final String currencyCode;
  final DateTime? issuedAt;

  /// The billing month, `YYYY-MM`. Empty on older invoices.
  final String period;

  /// Issue + 7 days. Null on older invoices.
  final DateTime? dueAt;

  /// `issued` and past [dueAt] — the server's verdict, not recomputed.
  final bool isOverdue;

  const ServiceInvoice({
    required this.id,
    this.number = '',
    this.kind = '',
    this.kindLabel = '',
    this.status = '',
    this.statusLabel = '',
    this.total = Money.zero,
    this.currencyCode = 'SAR',
    this.issuedAt,
    this.period = '',
    this.dueAt,
    this.isOverdue = false,
  });

  factory ServiceInvoice.fromJson(Map<String, dynamic> j) {
    final currency = asStr(j['currency_code']).isEmpty ? 'SAR' : asStr(j['currency_code']);
    return ServiceInvoice(
      id: asInt(j['id'] ?? j['service_invoice_id']),
      number: asStr(j['invoice_no'] ?? j['service_invoice_no'] ?? j['number']),
      kind: asStr(j['kind'] ?? j['fee_type']),
      kindLabel: unwrap(j['kind_label']),
      status: asStr(j['status']),
      statusLabel: unwrap(j['status_label']),
      total: Money.parse(j['grand_total'] ?? j['total'] ?? j['amount'], currency: currency),
      currencyCode: currency,
      issuedAt: asUtcDate(j['issued_at'] ?? j['created_at']),
      period: asStr(j['period']),
      dueAt: asUtcDate(j['due_at']),
      isOverdue: asBool(j['is_overdue']),
    );
  }
}

/// `GET /complaint_tickets`: the rows plus the response window and the
/// category list the create form offers.
class ComplaintList {
  final List<ComplaintTicket> tickets;
  final int currentPage;
  final int lastPage;
  final int total;

  /// 15 — shown as the promised response time.
  final int responseDays;
  final List<ComplaintCategory> categories;

  const ComplaintList({
    this.tickets = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.responseDays = 15,
    this.categories = const [],
  });

  bool get hasMore => currentPage < lastPage;

  factory ComplaintList.fromJson(Map<String, dynamic> j) => ComplaintList(
    tickets: asList(j['data'], ComplaintTicket.fromJson),
    currentPage: asInt(j['current_page']) == 0 ? 1 : asInt(j['current_page']),
    lastPage: asInt(j['last_page']) == 0 ? 1 : asInt(j['last_page']),
    total: asInt(j['total']),
    responseDays: asInt(j['response_days']) == 0 ? 15 : asInt(j['response_days']),
    categories: asList(j['categories'], ComplaintCategory.fromJson),
  );
}

/// `GET /service_invoices`: `{free_period, platform_fee_rate,
/// new_orders_restricted, wallet_enabled, commission_on_goods_invoices,
/// service_invoices: (paginator)}`.
class ServiceInvoices {
  final FreePeriod freePeriod;

  /// Percent of a frozen goods invoice, ex-VAT (`1.0`).
  final double platformFeeRate;

  /// This organization has an overdue service invoice: new orders are
  /// refused until it is paid. Existing orders and downloads are unaffected.
  final bool newOrdersRestricted;
  final bool walletEnabled;
  final List<ServiceInvoice> invoices;
  final int currentPage;
  final int lastPage;
  final int total;

  const ServiceInvoices({
    this.freePeriod = const FreePeriod(),
    this.platformFeeRate = 0,
    this.newOrdersRestricted = false,
    this.walletEnabled = false,
    this.invoices = const [],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  bool get hasMore => currentPage < lastPage;

  ServiceInvoice? get firstOverdue => invoices.where((s) => s.isOverdue).firstOrNull;

  /// `1.0` → `1`, `1.5` → `1.5`.
  String get platformFeeRateLabel => platformFeeRate == platformFeeRate.roundToDouble()
      ? platformFeeRate.toInt().toString()
      : platformFeeRate.toString();

  /// The next page appended to this one; the header is the newest read.
  ServiceInvoices append(ServiceInvoices next) => ServiceInvoices(
    freePeriod: next.freePeriod,
    platformFeeRate: next.platformFeeRate,
    newOrdersRestricted: next.newOrdersRestricted,
    walletEnabled: next.walletEnabled,
    invoices: [...invoices, ...next.invoices],
    currentPage: next.currentPage,
    lastPage: next.lastPage,
    total: next.total,
  );

  factory ServiceInvoices.fromJson(Map<String, dynamic> j) {
    final page = asMap(j['service_invoices']);
    return ServiceInvoices(
      freePeriod: FreePeriod.fromJson(asMap(j['free_period'])),
      platformFeeRate: asNum(j['platform_fee_rate']),
      newOrdersRestricted: asBool(j['new_orders_restricted']),
      walletEnabled: asBool(j['wallet_enabled']),
      invoices: asList(page['data'], ServiceInvoice.fromJson),
      currentPage: asInt(page['current_page']) == 0 ? 1 : asInt(page['current_page']),
      lastPage: asInt(page['last_page']) == 0 ? 1 : asInt(page['last_page']),
      total: asInt(page['total']),
    );
  }
}
