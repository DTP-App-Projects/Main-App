import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/i18n/app_dates.dart';
import '../../../../../core/ui/ui.dart';
import '../../../../../core/utils/services/remote_services/service_locator.dart';
import '../../../../../data/models/onboarding/org_document.dart';
import '../../../../../data/repositories/onboarding_repository.dart';
import '../view_models/onboarding_form_cubits.dart';
import 'widgets/collection_scaffold.dart';
import '../view_models/onboarding_cubit.dart';

/// `POST /api/v2/onboarding/documents` — **direct multipart**, not the
/// two-step `/v2/uploads` pattern the rest of v2 uses for file fields.
///
/// A commercial registration is usually a PDF and sometimes a phone photo, so
/// both a file browser and the camera are offered.
class DocumentsView extends StatelessWidget {
  const DocumentsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DocumentsCubit(getIt<OnboardingRepository>())..load(),
        child: const _DocumentsBody(),
      );
}

class _DocumentsBody extends StatelessWidget {
  const _DocumentsBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DocumentsCubit>();
    final locale = context.locale.toString();

    return CollectionScaffold<OrgDocument>(
      title: 'document.title'.tr(),
      subtitle: 'document.subtitle'.tr(),
      emptyMessage: 'document.empty'.tr(),
      addLabel: 'document.add'.tr(),
      state: cubit.state,
      onRetry: cubit.load,
      onAdd: () => _openEditor(context, null),
      changeKind: OnboardingStepKind.documents,
      emptyIcon: Icons.description_outlined,
      itemBuilder: (document) => CollectionTile(
        icon: Icons.description_outlined,
        title: _typeLabel(document.documentType),
        subtitle: document.expiresAt == null
            ? document.notes
            : '${'document.expires_at'.tr()}: '
                '${AppDates.date(document.expiresAt, locale)}',
        trailing: document.isExpired ? 'document.expired'.tr() : null,
        // An expired registration is the one thing on this screen that has to
        // catch the eye; the row's margin mark is how every other list in the
        // app says so.
        status: document.isExpired ? 'overdue' : '',
        onTap: () => _openEditor(context, document),
      ),
    );
  }

  /// `commercial_registration` is the only type key published anywhere, so it
  /// gets proper copy and everything else is shown as the raw code rather
  /// than a label we would have to invent.
  static String _typeLabel(String code) => code == _DocumentForm.knownType
      ? 'document.type_commercial_registration'.tr()
      : code;

  void _openEditor(BuildContext context, OrgDocument? document) {
    final cubit = context.read<DocumentsCubit>();
    cubit.resetForm();

    showEditorSheet(
      context: context,
      title: document == null ? 'document.add'.tr() : 'document.edit'.tr(),
      fields: (_) => [
        BlocProvider.value(value: cubit, child: _DocumentForm(document: document)),
      ],
    );
  }
}

class _DocumentForm extends StatefulWidget {
  /// The one document type key confirmed by the API collection.
  static const knownType = 'commercial_registration';

  final OrgDocument? document;

  const _DocumentForm({required this.document});

  @override
  State<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<_DocumentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _typeCode = TextEditingController(text: widget.document?.documentType ?? '');
  late final _notes = TextEditingController(text: widget.document?.notes ?? '');

  late bool _otherType = widget.document != null &&
      widget.document!.documentType.isNotEmpty &&
      widget.document!.documentType != _DocumentForm.knownType;

  late DateTime? _issuedAt = widget.document?.issuedAt;
  late DateTime? _expiresAt = widget.document?.expiresAt;

  String? _filePath;
  String? _fileError;

  @override
  void dispose() {
    _typeCode.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _documentType =>
      _otherType ? _typeCode.text.trim() : _DocumentForm.knownType;

  /// Validate before the round trip: a 12 MB photo should fail instantly, not
  /// after a minute of uploading.
  bool _acceptFile(String path) {
    if (!UploadRules.isAllowedExtension(path)) {
      setState(() => _fileError = 'document.bad_type'
          .tr(namedArgs: {'types': UploadRules.allowedExtensions.join(', ')}));
      return false;
    }
    if (File(path).lengthSync() > UploadRules.maxBytes) {
      setState(() => _fileError = 'document.too_large'.tr());
      return false;
    }
    setState(() {
      _filePath = path;
      _fileError = null;
    });
    return true;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: UploadRules.allowedExtensions,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path != null) _acceptFile(path);
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null) _acceptFile(photo.path);
  }

  Future<void> _pickDate({required bool issued}) async {
    final now = DateTime.now();
    final initial = (issued ? _issuedAt : _expiresAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    setState(() {
      if (issued) {
        _issuedAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // A new document needs a file; an edit may just change the dates.
    if (_filePath == null && !(widget.document?.hasFile ?? false)) {
      setState(() => _fileError = 'document.no_file'.tr());
      return;
    }
    // The server enforces `expires_at >= issued_at`; say so before it does.
    if (_issuedAt != null && _expiresAt != null && _expiresAt!.isBefore(_issuedAt!)) {
      setState(() => _fileError = 'validation.expires_after_issued'.tr());
      return;
    }

    final saved = await context.read<DocumentsCubit>().save(
          documentId: widget.document?.id,
          documentType: _documentType,
          filePath: _filePath,
          issuedAt: _issuedAt,
          expiresAt: _expiresAt,
          notes: _notes.text,
        );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final submit = context.watch<DocumentsCubit>().state.submit;
    final hasExistingFile = widget.document?.hasFile ?? false;

    // `_fileError` carries both the file problems and the date-order rule;
    // each is also shown beside the field it concerns.
    final dateOrderMessage = 'validation.expires_after_issued'.tr();
    final dateOrderError = _fileError == dateOrderMessage ? _fileError : null;
    final fileError = dateOrderError == null ? _fileError : null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormMessage(message: submit.message),
          FormMessage(message: _fileError),

          CodePicker(
            label: 'document.type'.tr(),
            value: _otherType ? 'other' : _DocumentForm.knownType,
            codes: const [_DocumentForm.knownType, 'other'],
            labelOf: (code) => code == 'other'
                ? 'document.type_other'.tr()
                : 'document.type_commercial_registration'.tr(),
            error: submit.fieldError('document_type'),
            onChanged: (value) => setState(() => _otherType = value == 'other'),
          ),
          if (_otherType)
            AppField(
              controller: _typeCode,
              label: 'document.type_code'.tr(),
              required: true,
              helper: 'document.type_code_hint'.tr(),
              textDirection: TextDirection.ltr,
              validator: AppValidators.required,
            ),

          _FileCard(
            fileName: _filePath ?? (hasExistingFile ? widget.document!.filePath : null),
            localPath: _filePath,
            required: !hasExistingFile,
            error: fileError,
            onPickFile: _pickFile,
            onTakePhoto: _takePhoto,
          ),

          AppDateField(
            label: 'document.issued_at'.tr(),
            value: _issuedAt,
            error: submit.fieldError('issued_at'),
            onTap: () => _pickDate(issued: true),
            onClear: () => setState(() => _issuedAt = null),
          ),
          AppDateField(
            label: 'document.expires_at'.tr(),
            value: _expiresAt,
            error: dateOrderError ?? submit.fieldError('expires_at'),
            onTap: () => _pickDate(issued: false),
            onClear: () => setState(() => _expiresAt = null),
          ),

          AppField(
            controller: _notes,
            label: 'document.notes'.tr(),
            maxLines: 2,
            textInputAction: TextInputAction.done,
            serverError: submit.fieldError('notes'),
          ),

          if (submit.isSubmitting)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: AppTokens.fullRadius,
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: t.primary,
                      backgroundColor: t.primaryTint,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    'document.uploading'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppTokens.space2),
          SubmitButton(
            busy: submit.isSubmitting,
            label: 'common.save'.tr(),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// The attached file as a small card: its icon, its name (and size when it
/// was picked on this device), then the choose / replace and camera actions.
class _FileCard extends StatelessWidget {
  final String? fileName;

  /// A file picked on this device, so its size can be read.
  final String? localPath;
  final bool required;
  final String? error;
  final VoidCallback onPickFile;
  final VoidCallback onTakePhoto;

  const _FileCard({
    required this.fileName,
    required this.localPath,
    required this.required,
    required this.error,
    required this.onPickFile,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final name = fileName?.split(RegExp(r'[\\/]')).last;
    final size = _sizeOf(localPath);
    final hasError = error != null && error!.isNotEmpty;

    return AppFieldShell(
      label: 'document.file'.tr(),
      required: required,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            radius: AppTokens.lgRadius,
            padding: const EdgeInsetsDirectional.all(AppTokens.space4),
            color: t.inputFill,
            borderColor: hasError ? t.fieldError : t.inputBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIconCircle(
                      name == null ? Icons.upload_file_outlined : _iconFor(name),
                      tone: name == null ? AppTone.neutral : AppTone.brand,
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name ?? 'document.no_file'.tr(),
                            style: name == null
                                ? theme.textTheme.bodyMedium?.copyWith(color: t.textTertiary)
                                : theme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (size != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              size,
                              style: theme.textTheme.bodySmall,
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        label: name == null
                            ? 'document.choose_file'.tr()
                            : 'document.replace_file'.tr(),
                        icon: Icons.folder_open_rounded,
                        height: 48,
                        onPressed: onPickFile,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space3),
                    Expanded(
                      child: AppButton.outline(
                        label: 'document.take_photo'.tr(),
                        icon: Icons.photo_camera_outlined,
                        height: 48,
                        onPressed: onTakePhoto,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: t.fieldError),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// "1.4 MB" for a file on this device; `null` for one already on the server.
  static String? _sizeOf(String? path) {
    if (path == null) return null;
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } on FileSystemException {
      return null;
    }
  }
}
