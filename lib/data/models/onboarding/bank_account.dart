import '../../../core/network/coerce.dart';

/// An organization's bank account.
///
/// `iban` and `account_number` are the textbook `JSON_NUMERIC_CHECK` victims:
/// an all-digit account number comes back as a **number**, and an IBAN that
/// happens to be all digits loses any leading zero. Both are read as strings
/// and never as numbers.
class BankAccount {
  final int id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String iban;
  final String swiftCode;
  final String currencyCode;
  final String rawDetails;
  final String status;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.iban,
    required this.swiftCode,
    required this.currencyCode,
    required this.rawDetails,
    required this.status,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: asInt(j['id']),
        bankName: unwrap(j['bank_name']),
        accountName: unwrap(j['account_name']),
        accountNumber: asStr(j['account_number']),
        iban: asStr(j['iban']),
        swiftCode: asStr(j['swift_code']),
        currencyCode: asStr(j['currency_code']),
        rawDetails: unwrap(j['raw_details']),
        status: asStr(j['status']),
      );

  /// `SA44 2000 0001 …` — grouping is display only; the stored value is raw.
  String get maskedIban {
    if (iban.length < 8) return iban;
    return '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 4)}';
  }
}
