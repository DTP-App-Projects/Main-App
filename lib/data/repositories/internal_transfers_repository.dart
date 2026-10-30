import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/auth_context.dart';
import '../../core/network/coerce.dart';
import '../../core/network/paged.dart';
import '../api_paths.dart';
import '../models/fleet/internal_transfer.dart';
import 'account_repository.dart' show TransferLineInput;

/// «النقل الداخلي»: stock between the organization's own branches.
///
/// Like the fleet endpoints these read `organization_id` from the request
/// (query on GET, body otherwise). Permissions: `internal_transfers.view`,
/// `.manage` (create / cancel / edit lines) and `.approve`.
class InternalTransfersRepository {
  final ApiClient _client;
  final AuthContext _context;

  InternalTransfersRepository(this._client, this._context);

  Map<String, dynamic> get _org => {'organization_id': ?_context.organizationId};

  /// A Laravel paginator of raw rows.
  Future<ApiResult<Paged<InternalTransfer>>> transfers({
    String? status,
    int? sourceBranchId,
    int? destinationBranchId,
    int page = 1,
    int limit = 15,
  }) => _client.get<Paged<InternalTransfer>>(
    ApiPaths.internalTransfers,
    query: {
      ..._org,
      'status': ?status,
      'source_branch_id': ?sourceBranchId,
      'destination_branch_id': ?destinationBranchId,
      ...PageParams.limit(page, size: limit),
    },
    parse: (body) => Paged.fromJson(asMap(body), InternalTransfer.fromJson),
  );

  Future<ApiResult<TransferFormOptions>> formOptions() => _client.get<TransferFormOptions>(
    ApiPaths.internalTransferFormOptions,
    query: _org,
    parse: (body) => TransferFormOptions.fromJson(asMap(body)),
  );

  /// [approveNow] needs `internal_transfers.approve` (else `403
  /// permission_denied`).
  Future<ApiResult<InternalTransfer>> create({
    required int sourceBranchId,
    required int destinationBranchId,
    String? priority,
    DateTime? requiredByDate,
    String? notes,
    bool approveNow = false,
    required List<TransferLineInput> lines,
  }) => _client.post<InternalTransfer>(
    ApiPaths.internalTransfers,
    body: {
      ..._org,
      'source_branch_id': sourceBranchId,
      'destination_branch_id': destinationBranchId,
      'priority': ?priority,
      if (requiredByDate != null) 'required_by_date': _day(requiredByDate),
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      if (approveNow) 'approve_now': true,
      'lines': lines.map((l) => l.toJson()).toList(),
    },
    parse: (body) => InternalTransfer.fromJson(asMap(asMap(body)['internal_transfer'])),
  );

  Future<ApiResult<InternalTransfer>> transfer(int id) => _client.get<InternalTransfer>(
    ApiPaths.internalTransfer(id),
    query: _org,
    parse: (body) => InternalTransfer.fromJson(asMap(asMap(body)['internal_transfer'])),
  );

  /// `approved` (needs `.approve`), `canceled` (needs `.manage`; [reason] is
  /// stored as the cancellation reason) or `closed`.
  Future<ApiResult<InternalTransfer>> changeStatus(int id, String status, {String? reason}) =>
      _client.patch<InternalTransfer>(
        ApiPaths.internalTransferStatus(id),
        body: {
          ..._org,
          'status': status,
          if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
        },
        parse: (body) => InternalTransfer.fromJson(asMap(asMap(body)['internal_transfer'])),
      );

  /// Only while `draft` (else `422 line_add_failed {error: transfer_not_editable}`).
  /// The answer is the bare line; callers re-read the transfer.
  Future<ApiResult<void>> addLine(int id, {required int skuId, required double requestedQty}) =>
      _client.post<void>(
        ApiPaths.internalTransferLines(id),
        body: {..._org, 'sku_id': skuId, 'requested_qty': requestedQty},
      );

  Future<ApiResult<void>> deleteLine(int id, int lineId) =>
      _client.delete<void>(ApiPaths.internalTransferLine(id, lineId), body: _org);

  static const changeableStatuses = ['approved', 'canceled', 'closed'];

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
