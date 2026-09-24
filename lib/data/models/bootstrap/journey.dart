import '../../../core/network/coerce.dart';

/// `organizations[].journey` — drives the onboarding wizard and the
/// read-only review-status screen.
class Journey {
  final String state;
  final String stateLabel;
  final int profilesReady;
  final int profilesPending;
  final bool hybridReady;
  final String nextBestAction;
  final ProfileJourney trader;
  final ProfileJourney supplier;

  /// Last five events, newest first as the server sends them.
  final List<JourneyEvent> timeline;

  const Journey({
    required this.state,
    required this.stateLabel,
    required this.profilesReady,
    required this.profilesPending,
    required this.hybridReady,
    required this.nextBestAction,
    required this.trader,
    required this.supplier,
    required this.timeline,
  });

  static const empty = Journey(
    state: '',
    stateLabel: '',
    profilesReady: 0,
    profilesPending: 0,
    hybridReady: false,
    nextBestAction: '',
    trader: ProfileJourney.empty,
    supplier: ProfileJourney.empty,
    timeline: [],
  );

  factory Journey.fromJson(Map<String, dynamic> j) => Journey(
        state: asStr(j['state']),
        stateLabel: unwrap(j['state_label']),
        profilesReady: asInt(j['profiles_ready']),
        profilesPending: asInt(j['profiles_pending']),
        hybridReady: asBool(j['hybrid_ready']),
        nextBestAction: unwrap(j['next_best_action']),
        trader: ProfileJourney.fromJson(asMap(j['trader'])),
        supplier: ProfileJourney.fromJson(asMap(j['supplier'])),
        timeline: asList(j['timeline'], JourneyEvent.fromJson),
      );

  bool get isComplete => profilesReady > 0 && profilesPending == 0;
}

class ProfileJourney {
  final String status;
  final int score;
  final List<String> missing;

  const ProfileJourney({required this.status, required this.score, required this.missing});

  static const empty = ProfileJourney(status: '', score: 0, missing: []);

  factory ProfileJourney.fromJson(Map<String, dynamic> j) => ProfileJourney(
        status: asStr(j['status']),
        score: asInt(j['score']),
        missing: asStrList(j['missing']),
      );

  bool get isActive => status == 'active';
}

class JourneyEvent {
  final DateTime? date;
  final String title;
  final String status;
  final String text;

  const JourneyEvent({
    required this.date,
    required this.title,
    required this.status,
    required this.text,
  });

  factory JourneyEvent.fromJson(Map<String, dynamic> j) => JourneyEvent(
        date: asDate(j['date']),
        title: unwrap(j['title']),
        status: asStr(j['status']),
        text: unwrap(j['text']),
      );
}
