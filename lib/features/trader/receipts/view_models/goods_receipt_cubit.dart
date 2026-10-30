import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/form_status.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/repositories/shipments_repository.dart';

/// One editable row of the receipt.
@immutable
class ReceiptLineDraft {
  final DeliveryLine line;
  final double receivedQty;
  final double rejectedQty;
  final String rejectionReason;

  /// Of the not-accepted quantity, how much is defective; the rest is a
  /// shortage (guide Part 11.1).
  final double defectQty;
  final String defectNote;

  const ReceiptLineDraft({
    required this.line,
    required this.receivedQty,
    this.rejectedQty = 0,
    this.rejectionReason = '',
    this.defectQty = 0,
    this.defectNote = '',
  });

  double get shortageQty {
    final shortage = rejectedQty - defectQty;
    return shortage < 0 ? 0 : shortage;
  }

  /// «سجّل ملاحظة العيب للكمية المعيبة».
  bool get needsDefectNote => defectQty > 0 && defectNote.trim().isEmpty;

  /// Defective cannot exceed what was not accepted.
  bool get defectTooHigh => defectQty > rejectedQty + 1e-6;

  /// The driver handed over `shipped_qty`; anything the trader does not
  /// account for is what produces `qty_mismatch_with_driver`.
  double get unaccounted => line.shippedQty - receivedQty - rejectedQty;

  bool get balances => unaccounted.abs() < 1e-6;

  /// A rejection with no reason is the thing a supplier will dispute back.
  bool get needsReason => rejectedQty > 0 && rejectionReason.trim().isEmpty;

  bool get isIncomplete => needsReason || needsDefectNote || defectTooHigh;

  ReceiptLineDraft copyWith({
    double? receivedQty,
    double? rejectedQty,
    String? rejectionReason,
    double? defectQty,
    String? defectNote,
  }) =>
      ReceiptLineDraft(
        line: line,
        receivedQty: receivedQty ?? this.receivedQty,
        rejectedQty: rejectedQty ?? this.rejectedQty,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        defectQty: defectQty ?? this.defectQty,
        defectNote: defectNote ?? this.defectNote,
      );
}

@immutable
class GoodsReceiptState {
  final bool loading;
  final DeliveryNote? note;
  final String? errorMessage;
  final bool offline;

  final List<ReceiptLineDraft> lines;
  final String? proofPath;
  final String notes;

  /// «اسم المستلم لدى التاجر».
  final String receiverName;

  final SubmitState action;

  /// Set once the receipt exists, which is when disputing becomes possible.
  final GoodsReceipt? created;

  const GoodsReceiptState({
    this.loading = true,
    this.note,
    this.errorMessage,
    this.offline = false,
    this.lines = const [],
    this.proofPath,
    this.notes = '',
    this.receiverName = '',
    this.action = const SubmitState(),
    this.created,
  });

  bool get hasMismatch => lines.any((line) => !line.balances);

  /// Anything that blocks the submit: a line's missing reason or defect
  /// note, or the receiver's name.
  bool get missingReason => lines.any((line) => line.isIncomplete) || receiverName.trim().isEmpty;

  GoodsReceiptState copyWith({
    bool? loading,
    DeliveryNote? note,
    String? errorMessage,
    bool? offline,
    List<ReceiptLineDraft>? lines,
    String? proofPath,
    String? notes,
    String? receiverName,
    SubmitState? action,
    GoodsReceipt? created,
    bool clearError = false,
    bool clearProof = false,
  }) =>
      GoodsReceiptState(
        receiverName: receiverName ?? this.receiverName,
        loading: loading ?? this.loading,
        note: note ?? this.note,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        offline: offline ?? this.offline,
        lines: lines ?? this.lines,
        proofPath: clearProof ? null : (proofPath ?? this.proofPath),
        notes: notes ?? this.notes,
        action: action ?? this.action,
        created: created ?? this.created,
      );
}

/// Confirm what actually arrived.
///
/// The trader counts per line; the server compares the total against what the
/// driver handed over and raises `qty_mismatch_with_driver`. A dispute is a
/// separate, throttled call with its own window.
class GoodsReceiptCubit extends Cubit<GoodsReceiptState> {
  final ShipmentsRepository _repo;
  final int deliveryNoteId;

  GoodsReceiptCubit(this._repo, this.deliveryNoteId) : super(const GoodsReceiptState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, offline: false));

    final result = await _repo.deliveryNote(deliveryNoteId);
    if (result case Ok(:final data)) {
      emit(state.copyWith(
        loading: false,
        note: data,
        // Start from "everything arrived": the common case is one tap.
        lines: [
          for (final line in data.lines)
            ReceiptLineDraft(line: line, receivedQty: line.shippedQty),
        ],
      ));
      return;
    }
    emit(state.copyWith(
      loading: false,
      offline: result.isOffline,
      errorMessage: result.failureMessage,
    ));
  }

  void updateLine(
    int lineId, {
    double? received,
    double? rejected,
    String? reason,
    double? defect,
    String? defectNote,
  }) {
    emit(state.copyWith(
      lines: [
        for (final draft in state.lines)
          draft.line.id == lineId
              ? draft.copyWith(
                  receivedQty: received,
                  rejectedQty: rejected,
                  rejectionReason: reason,
                  defectQty: defect,
                  defectNote: defectNote,
                )
              : draft,
      ],
    ));
  }

  void setReceiverName(String value) => emit(state.copyWith(receiverName: value));

  void setProof(String? path) =>
      emit(path == null ? state.copyWith(clearProof: true) : state.copyWith(proofPath: path));

  void setNotes(String value) => emit(state.copyWith(notes: value));

  /// Not auto-retried — a second receipt against the same delivery is a real
  /// problem, not a harmless duplicate.
  Future<GoodsReceipt?> submit() async {
    if (state.action.isSubmitting || state.lines.isEmpty) return null;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.createGoodsReceipt(
      deliveryNoteId: deliveryNoteId,
      proofFile: state.proofPath,
      notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
      receiverName: state.receiverName.trim().isEmpty ? null : state.receiverName.trim(),
      lines: [
        for (final draft in state.lines)
          GoodsReceiptLineInput(
            deliveryNoteLineId: draft.line.id,
            skuId: draft.line.skuId,
            receivedQty: draft.receivedQty,
            rejectedQty: draft.rejectedQty,
            rejectionReason:
                draft.rejectionReason.trim().isEmpty ? null : draft.rejectionReason.trim(),
            shortageQty: draft.shortageQty,
            defectQty: draft.defectQty,
            defectNote: draft.defectNote.trim().isEmpty ? null : draft.defectNote.trim(),
          ),
      ],
    );

    if (result case Ok(:final data)) {
      emit(state.copyWith(
        created: data,
        action: const SubmitState(status: FormStatus.success),
      ));
      return data;
    }
    emit(state.copyWith(action: result.failureState));
    return null;
  }

  /// `reason` is 10–1000 characters, throttled to 6/minute, and a
  /// `410 goods_receipt_edit_window_closed` is a final answer rather than a
  /// transient failure.
  Future<bool> dispute(String reason) async {
    final receipt = state.created;
    if (receipt == null || state.action.isSubmitting) return false;
    emit(state.copyWith(action: const SubmitState(status: FormStatus.submitting)));

    final result = await _repo.dispute(id: receipt.id, reason: reason);
    final ok = result is Ok<void> || result is NoContent<void>;
    emit(state.copyWith(action: result.failureState));
    return ok;
  }

  static const minDisputeLength = 10;
  static const maxDisputeLength = 1000;
}
