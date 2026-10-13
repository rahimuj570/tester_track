import 'constants.dart';

/// Configuration options for the [TesterTrack] engine.
class TesterTrackOptions {
  /// Whether to print internal diagnostic logs via [debugPrint].
  ///
  /// Defaults to `false`. Always keep `false` in production releases.
  final bool debugLogging;

  /// In-memory heartbeat interval for local timestamp tracking.
  ///
  /// This runs locally and generates zero Firestore network writes.
  /// Defaults to 15 seconds.
  final Duration localHeartbeatInterval;

  /// Interval to sync in-progress session duration to Firestore if the app
  /// remains continuously active in the foreground.
  ///
  /// Defaults to 5 minutes (300 seconds) to optimize Firebase cost.
  final Duration firestoreSyncInterval;

  /// Grace period before finalizing an inactive session.
  ///
  /// Prevents session fragmentation when the user temporarily switches apps
  /// or responds to system permission dialogues. Defaults to 15 seconds.
  final Duration inactivityDebounce;

  /// Inactivity duration threshold after which returning to the app starts a brand new session.
  ///
  /// If the user resumes the app within this duration, the existing session is continued
  /// (excluding background idle time from duration).
  /// Defaults to 30 minutes (industry standard, like Google Analytics / GA4).
  final Duration sessionTimeout;

  const TesterTrackOptions({
    this.debugLogging = false,
    this.localHeartbeatInterval =
        TrackerConstants.defaultLocalHeartbeatInterval,
    this.firestoreSyncInterval = TrackerConstants.defaultFirestoreSyncInterval,
    this.inactivityDebounce = TrackerConstants.defaultInactivityDebounce,
    this.sessionTimeout = TrackerConstants.defaultSessionTimeout,
  });
}
