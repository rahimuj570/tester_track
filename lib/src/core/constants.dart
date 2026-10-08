/// Internal constants used across TesterTrack.
class TrackerConstants {
  TrackerConstants._();

  /// Named Firebase App identifier to isolate TesterTrack from the host app's default Firebase App.
  static const String namedFirebaseAppName = 'tester_track';

  /// Firestore collection and document names.
  static const String collectionConfig = 'config';
  static const String documentGlobal = 'global';
  static const String collectionTesters = 'testers';
  static const String collectionSessions = 'sessions';

  /// Local storage (SharedPreferences) keys.
  static const String prefsTesterIdKey = 'tt_persistent_tester_id';
  static const String prefsActiveSessionKey = 'tt_active_session_state';
  static const String prefsCachedConfigKey = 'tt_cached_remote_config';

  /// Default durations and intervals.
  static const Duration defaultLocalHeartbeatInterval = Duration(seconds: 15);
  static const Duration defaultFirestoreSyncInterval = Duration(minutes: 5);
  static const Duration defaultInactivityDebounce = Duration(seconds: 15);
  static const Duration remoteConfigTimeout = Duration(seconds: 4);

  /// Maximum number of recent active calendar dates stored in tester document.
  static const int maxRecentActiveDates = 30;
}
