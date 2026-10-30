/// Every persisted key in one place.
///
/// The `jwt` lives in secure storage; everything here is non-sensitive
/// preference/context data in `SharedPreferences`.
class CacheKeys {
  CacheKeys._();

  /// Secure storage.
  static const jwt = 'tajer_jwt';

  /// Preferences.
  static const userId = 'tajer_user_id';
  static const organizationId = 'tajer_organization_id';
  static const language = 'lang';
  static const deviceToken = 'deviceToken';
  static const bootstrapCache = 'tajer_bootstrap_cache';

  /// Last workspace choice is remembered **per organization** — a hybrid org
  /// and a trader-only org in the same account must not fight over one slot.
  static String workspaceFor(int organizationId) => 'tajer_workspace_$organizationId';

  /// The server palette is cached per organization *and* per workspace — the
  /// two sides of a hybrid org have different themes.
  static String themeFor(int organizationId, String workspace) =>
      'tajer_theme_${organizationId}_$workspace';

  /// Set once this app has saved a profile's channels (see `SavedChannels`).
  static String channelsSavedFor(int profileId) => 'tajer_channels_saved_$profileId';
}

/// Kept for the pieces of the old shell that only ever needed the language.
class CacheKeysManger {
  CacheKeysManger._();

  static String getUserLanguage() => _language;
  static String _language = 'ar';

  /// Set once at start-up and whenever the user changes the app language.
  static void setLanguage(String value) => _language = value.isEmpty ? 'ar' : value;
}
