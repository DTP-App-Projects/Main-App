import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/onboarding/org_document.dart';
import '../../data/repositories/uploads_repository.dart';
import '../error/api_failure_ui.dart';
import '../network/api_result.dart';
import '../utils/services/remote_services/service_locator.dart';
import '../utils/theme/tokens.dart';
import 'app_buttons.dart';
import 'form_fields.dart';

/// Picks a file, uploads it through `/v2/uploads`, and hands back the **path**
/// the real request needs.
///
/// Everything happens here so the calling form never holds a `File`: by the
/// time it submits, it has a string.
class ProofFileField extends StatefulWidget {
  final String label;

  /// Where the backend should file it — `goods_receipts`, `collections`, …
  final String module;

  final String fieldKey;

  /// The uploaded path, or `null` when nothing is attached.
  final ValueChanged<String?> onUploaded;

  final String? error;

  const ProofFileField({
    super.key,
    required this.label,
    required this.module,
    required this.fieldKey,
    required this.onUploaded,
    this.error,
  });

  @override
  State<ProofFileField> createState() => _ProofFileFieldState();
}

class _ProofFileFieldState extends State<ProofFileField> {
  String? _localName;
  String? _uploadedPath;
  String? _message;
  bool _busy = false;
  double _progress = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: UploadRules.allowedExtensions,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path != null) await _upload(path);
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null) await _upload(photo.path);
  }

  /// Validate before the round trip: an oversized file should fail instantly,
  /// not after a minute of uploading.
  Future<void> _upload(String path) async {
    if (!UploadRules.isAllowedExtension(path)) {
      setState(() => _message = 'document.bad_type'
          .tr(namedArgs: {'types': UploadRules.allowedExtensions.join(', ')}));
      return;
    }
    if (File(path).lengthSync() > UploadRules.maxBytes) {
      setState(() => _message = 'document.too_large'.tr());
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _progress = 0;
      _localName = path.split(RegExp(r'[\\/]')).last;
    });

    final result = await getIt<UploadsRepository>().upload(
      filePath: path,
      module: widget.module,
      fieldKey: widget.fieldKey,
      onProgress: (sent, total) {
        if (total > 0 && mounted) setState(() => _progress = sent / total);
      },
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result case Ok(:final data) when data.isValid) {
        _uploadedPath = data.path;
        _message = null;
      } else {
        _uploadedPath = null;
        _localName = null;
        _message = result.failureMessage ?? 'errors.generic'.tr();
      }
    });
    widget.onUploaded(_uploadedPath);
  }

  void _clear() {
    setState(() {
      _uploadedPath = null;
      _localName = null;
      _message = null;
    });
    widget.onUploaded(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final error = widget.error ?? _message;
    final uploaded = _uploadedPath != null;

    return AppFieldShell(
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_localName != null)
            Container(
              margin: const EdgeInsetsDirectional.only(bottom: AppTokens.space2),
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppTokens.space3,
                AppTokens.space2,
                AppTokens.space1,
                AppTokens.space2,
              ),
              decoration: BoxDecoration(
                color: uploaded ? t.primaryTint : t.inputFill,
                borderRadius: AppTokens.mdRadius,
                border: Border.all(color: uploaded ? t.primaryTint : t.inputBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    size: 20,
                    color: uploaded ? t.primary : t.textTertiary,
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Expanded(
                    child: Text(
                      _localName!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (!_busy)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: t.textSecondary),
                      onPressed: _clear,
                      tooltip: 'common.cancel'.tr(),
                    ),
                ],
              ),
            ),
          if (_busy) ...[
            ClipRRect(
              borderRadius: AppTokens.fullRadius,
              child: LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            ),
            const SizedBox(height: 6),
            Text('document.uploading'.tr(), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.space2),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  label: 'document.choose_file'.tr(),
                  icon: Icons.folder_open_rounded,
                  height: 48,
                  onPressed: _busy ? null : _pickFile,
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: AppButton.outline(
                  label: 'document.take_photo'.tr(),
                  icon: Icons.photo_camera_outlined,
                  height: 48,
                  onPressed: _busy ? null : _takePhoto,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: theme.textTheme.labelSmall?.copyWith(color: t.fieldError)),
          ],
        ],
      ),
    );
  }
}
