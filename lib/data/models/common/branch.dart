import '../../../core/network/coerce.dart';

class Branch {
  final int id;
  final String type;
  final String nameAr;
  final String nameEn;
  final String addressText;
  final int? countryId;
  final int? cityId;
  final String contactName;
  final String contactPhone;
  final bool isDefault;
  final String status;

  const Branch({
    required this.id,
    required this.type,
    required this.nameAr,
    required this.nameEn,
    required this.addressText,
    required this.countryId,
    required this.cityId,
    required this.contactName,
    required this.contactPhone,
    required this.isDefault,
    required this.status,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: asInt(j['id']),
        type: asStr(j['type'] ?? j['branch_type']),
        nameAr: unwrap(j['name_ar']),
        nameEn: unwrap(j['name_en']),
        addressText: unwrap(j['address_text']),
        countryId: asIntOrNull(j['country_id']),
        cityId: asIntOrNull(j['city_id']),
        contactName: unwrap(j['contact_name']),
        contactPhone: unwrap(j['contact_phone']),
        isDefault: asBool(j['is_default']),
        status: asStr(j['status']),
      );

  String displayName(String locale) =>
      pickLocalized(locale: locale, ar: nameAr, en: nameEn);
}
