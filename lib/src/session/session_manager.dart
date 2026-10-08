import 'dart:async';
import '../core/constants.dart';
import '../core/error_handler.dart';
import '../core/tracker_options.dart';
import '../identity/device_info_helper.dart';
import '../models/session_data.dart';
import '../storage/firestore_repository.dart';
import '../storage/local_storage.dart';
import 'session_state.dart';

/// Coordinates session lifecycle, local 15-second heartbeats, 5-minute Firestore syncs,
/// and crash recovery.
class SessionManager {
  final String testerId;
  final String authUid;
  final AppEnvironmentInfo envInfo;
  final LocalStorage localStorage;
  final FirestoreRepository firestoreRepository;
  final TrackerErrorHandler errorHandler;
  final TesterTrackOptions options;

  SessionState? _currentSession;
  Timer? _localHeartbeatTimer;
  Timer? _firestoreSyncTimer;
  Timer? _inactivityDebounceTimer;
  bool _isTracking = false;

  SessionManager({
    required this.testerId,
    required this.authUid,
    required this.envInfo,
    required this.localStorage,
    required this.firestoreRepository,
    required this.errorHandler,
    required this.options,
  });

  /// Whether a foreground tracking session is actively in progress.
  bool get isTracking => _isTracking;

  /// The active in-memory session state if tracking.
  SessionState? get currentSession => _currentSession;

  /// Recovers an interrupted or crashed session from local storage upon app startup.
  ///
  /// CRITICAL: Interrupted session duration is calculated STRICTLY between
  /// [startedAt] and [lastHeartbeatAt]. It NEVER counts time while the process was dead.
  Future<void> recoverInterruptedSession() async {
    await errorHandler.runGuarded<void>(() async {
      final raw =
          localStorage.getString(TrackerConstants.prefsActiveSessionKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      errorHandler.log(
          'Found unfinalized session in local storage. Initiating crash recovery...');
      SessionState? recoveredState;
      try {
        recoveredState = SessionState.fromJson(raw);
      } catch (e) {
        errorHandler.log('Failed to parse unfinalized session state: $e');
        await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
        return;
      }

      if (!recoveredState.isFinalized) {
        final duration = recoveredState.observedDurationSeconds;
        errorHandler.log(
          'Recovering session ${recoveredState.sessionId}: started at ${recoveredState.startedAt}, '
          'last heartbeat at ${recoveredState.lastHeartbeatAt}. Recovered duration: ${duration}s.',
        );

        await firestoreRepository.finalizeSession(
          testerId: recoveredState.testerId,
          sessionId: recoveredState.sessionId,
          endedAt: recoveredState.lastHeartbeatAt,
          durationSeconds: duration,
          activeDate: recoveredState.activeDate,
        );
      }

      await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
      errorHandler.log('Interrupted session recovery completed.');
    }, operationName: 'SessionManager.recoverInterruptedSession');
  }

  /// Starts a new session or continues tracking.
  ///
  /// Idempotent: repeated calls when already tracking do nothing.
  Future<void> startSession() async {
    await errorHandler.runGuarded<void>(() async {
      _cancelInactivityDebounce();

      if (_isTracking && _currentSession != null) {
        errorHandler.log(
            'Session ${_currentSession!.sessionId} is already active. Ignoring start.');
        return;
      }

      final now = DateTime.now().toUtc();
      final sessionId = 'sess_${testerId}_${now.millisecondsSinceEpoch}';

      _currentSession = SessionState(
        sessionId: sessionId,
        testerId: testerId,
        authUid: authUid,
        startedAt: now,
        lastHeartbeatAt: now,
        appVersion: envInfo.appVersion,
        platform: envInfo.platform,
        isFinalized: false,
      );

      _isTracking = true;

      // 1. Persist local state immediately for crash recovery
      await _persistLocalSessionState();

      // 2. Create session in Firestore
      final sessionData = SessionData(
        sessionId: sessionId,
        testerId: testerId,
        authUid: authUid,
        startedAt: now,
        endedAt: null,
        durationSeconds: 0,
        activeDate: _currentSession!.activeDate,
        appVersion: envInfo.appVersion,
        platform: envInfo.platform,
        isFinalized: false,
      );
      await firestoreRepository.createSession(sessionData);

      // 3. Start local heartbeat timer (15s, 0 Firestore writes)
      _startLocalHeartbeatTimer();

      // 4. Start periodic Firestore sync timer (5 minutes)
      _startFirestoreSyncTimer();

      errorHandler.log('Started session $sessionId.');
    }, operationName: 'SessionManager.startSession');
  }

  /// Handles app entering background or inactive state with a configurable debounce period.
  void onAppPauseOrInactive() {
    errorHandler.runGuardedSync(() {
      if (!_isTracking || _currentSession == null) {
        return;
      }
      if (_inactivityDebounceTimer != null &&
          _inactivityDebounceTimer!.isActive) {
        return;
      }

      errorHandler.log(
        'App paused/inactive. Starting debounce timer (${options.inactivityDebounce.inSeconds}s)...',
      );

      _inactivityDebounceTimer = Timer(options.inactivityDebounce, () {
        errorHandler.log('Inactivity debounce expired. Finalizing session.');
        unawaited(_finalizeCurrentSession());
      });
    }, operationName: 'SessionManager.onAppPauseOrInactive');
  }

  /// Handles app entering foreground.
  void onAppResume() {
    errorHandler.runGuardedSync(() {
      if (_inactivityDebounceTimer != null &&
          _inactivityDebounceTimer!.isActive) {
        _inactivityDebounceTimer!.cancel();
        _inactivityDebounceTimer = null;
        _updateLocalHeartbeatTimestamp();
        errorHandler.log(
          'App resumed within debounce window. Keeping existing session ${_currentSession?.sessionId} active.',
        );
        return;
      }

      if (!_isTracking || _currentSession == null) {
        unawaited(startSession());
      }
    }, operationName: 'SessionManager.onAppResume');
  }

  /// Stops tracking and finalizes the active session.
  ///
  /// Idempotent: repeated calls do nothing.
  Future<void> stopTracking() async {
    await errorHandler.runGuarded<void>(() async {
      _cancelInactivityDebounce();
      await _finalizeCurrentSession();
    }, operationName: 'SessionManager.stopTracking');
  }

  /// Finalizes the current session in Firestore and clears local state.
  Future<void> _finalizeCurrentSession() async {
    _cancelTimers();

    final session = _currentSession;
    if (session == null) {
      _isTracking = false;
      return;
    }

    final duration = session.observedDurationSeconds;
    final endedAt = session.lastHeartbeatAt;

    errorHandler.log(
      'Finalizing session ${session.sessionId}: ended at $endedAt, duration: ${duration}s.',
    );

    await firestoreRepository.finalizeSession(
      testerId: session.testerId,
      sessionId: session.sessionId,
      endedAt: endedAt,
      durationSeconds: duration,
      activeDate: session.activeDate,
    );

    await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
    _currentSession = null;
    _isTracking = false;
  }

  /// Starts the local-only heartbeat timer (default: 15s).
  void _startLocalHeartbeatTimer() {
    _localHeartbeatTimer?.cancel();
    _localHeartbeatTimer = Timer.periodic(options.localHeartbeatInterval, (_) {
      _updateLocalHeartbeatTimestamp();
    });
  }

  /// Updates the local heartbeat timestamp and persists to local storage (0 Firestore writes).
  void _updateLocalHeartbeatTimestamp() {
    errorHandler.runGuardedSync(() {
      if (_currentSession == null) {
        return;
      }
      _currentSession = _currentSession!.copyWith(
        lastHeartbeatAt: DateTime.now().toUtc(),
      );
      unawaited(_persistLocalSessionState());
    }, operationName: 'SessionManager._updateLocalHeartbeatTimestamp');
  }

  /// Starts the periodic Firestore sync timer (default: 5 minutes).
  void _startFirestoreSyncTimer() {
    _firestoreSyncTimer?.cancel();
    _firestoreSyncTimer = Timer.periodic(options.firestoreSyncInterval, (_) {
      errorHandler.runGuardedSync(() {
        if (_currentSession == null) {
          return;
        }
        final duration = _currentSession!.observedDurationSeconds;
        unawaited(firestoreRepository.updateSessionProgress(
          testerId: _currentSession!.testerId,
          sessionId: _currentSession!.sessionId,
          durationSeconds: duration,
        ));
      }, operationName: 'SessionManager.periodicSync');
    });
  }

  Future<void> _persistLocalSessionState() async {
    if (_currentSession == null) {
      return;
    }
    await localStorage.setString(
      TrackerConstants.prefsActiveSessionKey,
      _currentSession!.toJson(),
    );
  }

  void _cancelInactivityDebounce() {
    _inactivityDebounceTimer?.cancel();
    _inactivityDebounceTimer = null;
  }

  void _cancelTimers() {
    _localHeartbeatTimer?.cancel();
    _localHeartbeatTimer = null;
    _firestoreSyncTimer?.cancel();
    _firestoreSyncTimer = null;
    _cancelInactivityDebounce();
  }

  /// Disposes all timers and listeners.
  void dispose() {
    _cancelTimers();
  }
}
