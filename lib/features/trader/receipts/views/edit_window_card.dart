import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../data/models/trade/delivery_note.dart';
import '../../../../data/repositories/shipments_repository.dart';

/// The trader's window to correct what was received (`/delivery_notes/{id}/
/// edit_window`): a countdown while it is open, «تصحيح الكميات», and
/// «إنهاء المهلة» to make the quantities final early. Renders nothing once
/// the window is closed — or when the server has none for this shipment.
class ReceiptEditWindowCard extends StatefulWidget {
  final GoodsReceipt receipt;

  /// Re-reads the receipt after a correction or a close.
  final Future<void> Function() onChanged;

  const ReceiptEditWindowCard({super.key, required this.receipt, required this.onChanged});

  @override
  State<ReceiptEditWindowCard> createState() => _ReceiptEditWindowCardState();
}

class _ReceiptEditWindowCardState extends State<ReceiptEditWindowCard> {
  ShipmentsRepository get _repo => getIt<ShipmentsRepository>();

  EditWindow _window = EditWindow.closed;
  Timer? _ticker;
  bool _busy = false;
  String? _message;

  int get _deliveryNoteId => widget.receipt.deliveryNoteId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_deliveryNoteId == 0) return;
    final result = await _repo.editWindow(_deliveryNoteId);
    if (!mounted) return;
    setState(() => _window = result.dataOrNull ?? EditWindow.closed);
    _ticker?.cancel();
    // A once-a-second repaint of one line of text — no requests.
    if (_window.isOpenAt(DateTime.now()) && _window.endsAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_window.isOpenAt(DateTime.now())) _ticker?.cancel();
      });
    }
  }

  Future<void> _after(ApiResult<void> result) async {
    final ok = result is Ok<void> || result is NoContent<void>;
    setState(() {
      _busy = false;
      _message = ok ? null : result.failureMessage;
    });
    if (!ok) return;
    await _load();
    await widget.onChanged();
  }

  Future<void> _adjust() async {
    final adjustments = await showAppSheet<List<ReceiptAdjustment>>(
      context: context,
      title: 'edit_window.adjust'.tr(),
      subtitle: 'edit_window.adjust_hint'.tr(),
      builder: (_) => _AdjustForm(lines: widget.receipt.lines),
    );
    if (adjustments == null || adjustments.isEmpty || !mounted) return;
    setState(() => _busy = true);
    await _after(
      await _repo.adjustReceipt(deliveryNoteId: _deliveryNoteId, adjustments: adjustments),
    );
  }

  Future<void> _close() async {
    final ok = await showAppConfirm(
      context,
      title: 'edit_window.close_title'.tr(),
      body: 'edit_window.close_body'.tr(),
      confirmLabel: 'edit_window.close'.tr(),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await _after(await _repo.closeEditWindow(_deliveryNoteId));
  }

  static String _remaining(Duration left) {
    String two(int v) => v.toString().padLeft(2, '0');
    final hours = left.inHours;
    return '${two(hours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!_window.isOpenAt(now)) return const SizedBox.shrink();
    final end = _window.endsAt;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppTokens.space3),
      child: AppBanner(
        tone: AppTone.info,
        icon: Icons.timer_outlined,
        margin: EdgeInsetsDirectional.zero,
        title: 'edit_window.title'.tr(),
        message: end == null
            ? 'edit_window.open'.tr()
            : 'edit_window.remaining'.tr(namedArgs: {'time': _remaining(end.difference(now))}),
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormMessage(message: _message),
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    label: 'edit_window.adjust'.tr(),
                    height: 40,
                    busy: _busy,
                    onPressed: _busy || widget.receipt.lines.isEmpty ? null : _adjust,
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: AppButton.outline(
                    label: 'edit_window.close'.tr(),
                    height: 40,
                    onPressed: _busy ? null : _close,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Received / rejected per receipt line, pre-filled with what is recorded.
/// Pops only the lines that changed.
class _AdjustForm extends StatefulWidget {
  final List<GoodsReceiptLine> lines;

  const _AdjustForm({required this.lines});

  @override
  State<_AdjustForm> createState() => _AdjustFormState();
}

class _AdjustFormState extends State<_AdjustForm> {
  late final _received = {
    for (final l in widget.lines) l.id: TextEditingController(text: _format(l.receivedQty)),
  };
  late final _rejected = {
    for (final l in widget.lines) l.id: TextEditingController(text: _format(l.rejectedQty)),
  };

  static String _format(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  void dispose() {
    for (final c in [..._received.values, ..._rejected.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <ReceiptAdjustment>[];
    for (final line in widget.lines) {
      final received = double.tryParse(_received[line.id]!.text.trim());
      final rejected = double.tryParse(_rejected[line.id]!.text.trim());
      final receivedChanged = received != null && received != line.receivedQty;
      final rejectedChanged = rejected != null && rejected != line.rejectedQty;
      if (!receivedChanged && !rejectedChanged) continue;
      out.add(
        ReceiptAdjustment(
          lineId: line.id,
          receivedQty: receivedChanged ? received : null,
          rejectedQty: rejectedChanged ? rejected : null,
        ),
      );
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in widget.lines) ...[
          Text(line.skuName, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              Expanded(
                child: AppField(
                  controller: _received[line.id]!,
                  label: 'edit_window.received'.tr(),
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: AppField(
                  controller: _rejected[line.id]!,
                  label: 'edit_window.rejected'.tr(),
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppTokens.space2),
        AppButton.primary(label: 'edit_window.save'.tr(), onPressed: _submit),
      ],
    );
  }
}
