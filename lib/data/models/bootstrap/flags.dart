import '../../../core/network/coerce.dart';

/// Feature and platform flags arrive as flat maps of booleans (plus a few
/// numbers). A map wrapper beats fifteen named getters that rot when the
/// backend adds one.
class Flags {
  final Map<String, dynamic> raw;

  const Flags(this.raw);

  static const empty = Flags({});

  factory Flags.fromJson(dynamic json) => Flags(asMap(json));

  bool isEnabled(String key) => asBool(raw[key]);

  num number(String key) => asNum(raw[key]);

  String text(String key) => asStr(raw[key]);

  bool has(String key) => raw.containsKey(key);
}

/// Named accessors for the flags Phase 1 actually branches on.
extension FeatureFlagX on Flags {
  bool get singleAppWorkspaces => isEnabled('single_app_workspaces');
  bool get creditStrictMode => isEnabled('credit_strict_mode');
  bool get legacyOrdersReadOnly => isEnabled('legacy_orders_read_only');
}

extension PlatformFlagX on Flags {
  bool get nafathEnabled => isEnabled('nafath_enabled');
  bool get paymentGatewayEnabled => isEnabled('payment_gateway_enabled');
  bool get applePayEnabled => isEnabled('apple_pay_enabled');
  bool get bankTransferEnabled => isEnabled('bank_transfer_enabled');
  bool get creditModuleEnabled => isEnabled('credit_module_enabled');
}

/// `GET /v2/platform/flags` answers `{flags, defaults}` — the live server
/// splits the numeric settings out of `flags`, unlike the bootstrap payload
/// where they sit inline. Both shapes fold into this one type.
class PlatformFlagsResponse {
  final Flags flags;
  final Flags defaults;

  const PlatformFlagsResponse({required this.flags, required this.defaults});

  factory PlatformFlagsResponse.fromJson(Map<String, dynamic> j) => PlatformFlagsResponse(
        flags: Flags.fromJson(j['flags'] ?? j),
        defaults: Flags.fromJson(j['defaults']),
      );

  num get commissionRate =>
      defaults.has('commission_rate') ? defaults.number('commission_rate') : flags.number('default_commission_rate');

  num get trialDays =>
      defaults.has('trial_days') ? defaults.number('trial_days') : flags.number('default_trial_days');
}
