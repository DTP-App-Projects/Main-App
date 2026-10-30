import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error/api_failure_ui.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/services/remote_services/service_locator.dart';

/// Opens a server PDF (receipt, invoice, credit note, return note, …) in the
/// in-app viewer, with share and save in the app bar.
Future<void> openDocumentPdf(
  BuildContext context, {
  required String path,
  required String title,
  required String fileName,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DocumentPdfView(path: path, title: title, fileName: fileName),
    ));

/// Downloads a non-viewable file (the dispute-pack ZIP) and offers to share
/// or save it. Shows a snackbar on failure.
Future<void> shareOrSaveFile(
  BuildContext context, {
  required String path,
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text('files.downloading'.tr())));
  final result = await getIt<ApiClient>().bytes(path);
  messenger.hideCurrentSnackBar();
  if (result is! Ok<Uint8List>) {
    messenger.showSnackBar(SnackBar(content: Text(result.failureMessage ?? 'errors.generic'.tr())));
    return;
  }
  if (!context.mounted) return;
  await showAppSheet<void>(
    context: context,
    title: fileName,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.primary(
          label: 'files.share'.tr(),
          icon: Icons.ios_share_rounded,
          onPressed: () async {
            Navigator.of(sheet).pop();
            await FileActions.share(result.data, fileName);
          },
        ),
        const SizedBox(height: AppTokens.space3),
        AppButton.outline(
          label: 'files.save'.tr(),
          icon: Icons.download_rounded,
          onPressed: () async {
            Navigator.of(sheet).pop();
            final saved = await FileActions.save(result.data, fileName);
            messenger.showSnackBar(SnackBar(
              content: Text(saved ? 'files.saved'.tr() : 'files.save_failed'.tr()),
            ));
          },
        ),
      ],
    ),
  );
}

/// Share and save, shared by the viewer and the ZIP sheet.
class FileActions {
  FileActions._();

  /// Writes to the temp directory first: the share sheet needs a real file
  /// for the receiving app to read the name and type.
  static Future<void> share(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], title: fileName));
  }

  /// The system "save as" dialog, so the file lands where the user can find
  /// it (Downloads, Files) rather than in the app's private storage.
  static Future<bool> save(Uint8List bytes, String fileName) async {
    try {
      final saved = await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
      return saved != null;
    } catch (_) {
      return false;
    }
  }
}

class DocumentPdfView extends StatefulWidget {
  final String path;
  final String title;
  final String fileName;

  const DocumentPdfView({super.key, required this.path, required this.title, required this.fileName});

  @override
  State<DocumentPdfView> createState() => _DocumentPdfViewState();
}

class _DocumentPdfViewState extends State<DocumentPdfView> {
  ApiResult<Uint8List>? _result;
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _result = null);
    final result = await getIt<ApiClient>().bytes(widget.path);
    if (!mounted) return;
    _controller?.dispose();
    _controller = result is Ok<Uint8List>
        ? PdfControllerPinch(document: PdfDocument.openData(result.data))
        : null;
    setState(() => _result = result);
  }

  Uint8List? get _bytes {
    final result = _result;
    return result is Ok<Uint8List> ? result.data : null;
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await FileActions.save(bytes, widget.fileName);
    messenger.showSnackBar(SnackBar(content: Text(saved ? 'files.saved'.tr() : 'files.save_failed'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'files.share'.tr(),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: bytes == null ? null : () => FileActions.share(bytes, widget.fileName),
          ),
          IconButton(
            tooltip: 'files.save'.tr(),
            icon: const Icon(Icons.download_rounded),
            onPressed: bytes == null ? null : _save,
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (result == null) return const DetailSkeleton();
        if (result is! Ok<Uint8List>) {
          if (result.isOffline) return AppOfflineState(onRetry: _load);
          return AppErrorState(message: result.failureMessage ?? 'errors.generic'.tr(), onRetry: _load);
        }
        // PDF pages are laid out by the document, never mirrored for RTL.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: PdfViewPinch(controller: _controller!),
        );
      }),
    );
  }
}
