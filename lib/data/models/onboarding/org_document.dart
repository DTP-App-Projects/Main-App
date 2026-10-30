import '../../../core/network/coerce.dart';

/// A compliance document attached to the organization (commercial
/// registration, VAT certificate, …).
///
/// Unlike most v2 file fields, this one is a **direct multipart POST** — there
/// is no upload-then-send-the-path round trip here.
class OrgDocument {
  final int id;

  /// A key from `config/b2b_documents.php`, e.g. `commercial_registration`.
  final String documentType;

  /// Relative storage path, not a URL.
  final String filePath;

  /// Absolute URL when the server resolves one.
  final String fileUrl;

  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String notes;
  final String status;

  const OrgDocument({
    required this.id,
    required this.documentType,
    required this.filePath,
    required this.fileUrl,
    required this.issuedAt,
    required this.expiresAt,
    required this.notes,
    required this.status,
  });

  factory OrgDocument.fromJson(Map<String, dynamic> j) => OrgDocument(
        id: asInt(j['id']),
        documentType: asStr(j['document_type'] ?? j['type']),
        filePath: asStr(j['file_path'] ?? j['path']),
        fileUrl: asStr(j['file_url'] ?? j['url']),
        issuedAt: asDate(j['issued_at']),
        expiresAt: asDate(j['expires_at']),
        notes: unwrap(j['notes']),
        status: asStr(j['status']),
      );

  bool get hasFile => filePath.isNotEmpty || fileUrl.isNotEmpty;

  /// Expiry is what a reviewer rejects on, so it is surfaced rather than
  /// buried in a details row.
  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }
}

/// Client-side upload rules, applied **before** the round trip.
///
/// The documented limits are the generic `/v2/uploads` ones; the onboarding
/// endpoint's own mime list is not published, so this is the conservative
/// superset rather than a guess at something narrower.
class UploadRules {
  UploadRules._();

  /// `POST /onboarding/documents` is stricter than the generic uploads:
  /// images (HEIC included), PDF and spreadsheets, at most 8 MB.
  static const documentMaxBytes = 8 * 1024 * 1024;

  static const documentExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'pdf',
    'xls',
    'xlsx',
    'csv',
  ];

  static bool isAllowedDocument(String path) => documentExtensions.contains(extensionOf(path));

  static const maxBytes = 10 * 1024 * 1024;

  static const allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'csv',
    'txt',
  ];

  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  }

  static bool isAllowedExtension(String path) =>
      allowedExtensions.contains(extensionOf(path));
}
