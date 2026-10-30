import '../../../../../core/utils/services/local_services/cache_helper.dart';
import '../../../../../core/utils/services/local_services/cache_keys.dart';

/// Which profiles have had their channels **saved** from this app.
///
/// The server cannot tell us: the bootstrap's `channel_codes` mixes the saved
/// channels with ones guessed from the sectors, while `profile/submit` checks
/// only the saved ones. Sign-up saves an empty list. So a profile's channels
/// count as done only after a `PUT /onboarding/profile` that carried a
/// non-empty `channel_codes` succeeded — remembered here, per profile id.
class SavedChannels {
  SavedChannels._();

  static bool contains(int profileId) =>
      CacheHelper.getData(key: CacheKeys.channelsSavedFor(profileId)) == true;

  static Future<void> mark(int profileId) =>
      CacheHelper.saveData(key: CacheKeys.channelsSavedFor(profileId), value: true);

  /// The ids among [profileIds] that have been saved.
  static Set<int> among(Iterable<int?> profileIds) =>
      {for (final id in profileIds) if (id != null && id > 0 && contains(id)) id};
}
