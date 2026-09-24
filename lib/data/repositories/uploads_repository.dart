import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/network/coerce.dart';
import '../api_paths.dart';
import '../models/onboarding/org_document.dart';

/// The **two-step upload**, which is how every v2 field named `proof_file`,
/// `file_path`, `*_photo_path`, `image_url` or `receipt_file` works:
///
/// 1. `POST /v2/uploads` (multipart) → `{file: {path, url}}`
/// 2. send `file.path` as a **string** in the JSON body of the real call
///
/// Onboarding documents are the exception — they take the file directly.
class UploadsRepository {
  final ApiClient _client;

  UploadsRepository(this._client);

  /// [module] and [fieldKey] are ≤ 100 chars and tell the backend where the
  /// file belongs (`goods_receipts` / `proof_file`).
  Future<ApiResult<UploadedFile>> upload({
    required String filePath,
    String? module,
    String? fieldKey,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'attachment': await MultipartFile.fromFile(filePath),
      'module': ?module,
      'field_key': ?fieldKey,
    });

    return _client.multipart<UploadedFile>(
      ApiPaths.uploads,
      form: form,
      onSendProgress: onProgress,
      parse: (body) => UploadedFile.fromJson(asMap(asMap(body)['file'])),
    );
  }
}

class UploadedFile {
  /// The **relative storage path**. This is what goes in the next request.
  final String path;

  /// An absolute URL, for showing the file back to the user.
  final String url;

  const UploadedFile({required this.path, required this.url});

  factory UploadedFile.fromJson(Map<String, dynamic> j) => UploadedFile(
        path: asStr(j['path']),
        url: asStr(j['url']),
      );

  bool get isValid => path.isNotEmpty;
}

/// Client-side limits, applied before the round trip. Same rules as the
/// onboarding documents endpoint.
typedef UploadLimits = UploadRules;
