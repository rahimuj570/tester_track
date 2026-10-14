import 'dart:async';
import 'dart:math';
import '../core/constants.dart';
import '../core/error_handler.dart';
import '../core/tracker_options.dart';
import '../identity/device_info_helper.dart';
import '../models/session_data.dart';
import '../storage/firestore_repository.dart';
import '../storage/local_storage.dart';
import 'session_state.dart';

/// Coordinates session lifecycle, local 15-second heartbeats, 5-minute Firestore syncs,
/// crash recovery, and remote configuration enable/disable compliance.
///
/// Guarantees that background wall-clock time is NEVER counted towards active session duration.
class SessionManager {
  final String testerId;
  final String authUid;
  final AppEnvironmentInfo envInfo;
  final LocalStorage localStorage;
  final FirestoreRepository firestoreRepository;
  final TrackerErrorHandler errorHandler;
  final TesterTrackOptions options;

  SessionState? _currentSession;
  DateTime? _lastActiveTime;
  Timer? _localHeartbeatTimer;
  Timer? _firestoreSyncTimer;
  Timer? _inactivityDebounceTimer;
  bool _isTracking = false;
  bool _isInForeground = false;
  bool _isTrackingPermitted;
  Duration _currentFirestoreSyncInterval;
  int _syncedDurationSeconds = 0;

  SessionManager({
    required this.testerId,
    required this.authUid,
    required this.envInfo,
    required this.localStorage,
    required this.firestoreRepository,
    required this.errorHandler,
    required this.options,
    bool initialTrackingPermitted = true,
    Duration? initialFirestoreSyncInterval,
  })  : _isTrackingPermitted = initialTrackingPermitted,
        _currentFirestoreSyncInterval =
            initialFirestoreSyncInterval ?? options.firestoreSyncInterval;

  /// Whether a foreground tracking session is actively in progress.
  bool get isTracking => _isTracking;

  /// Whether tracking is permitted by remote configuration.
  bool get isTrackingPermitted => _isTrackingPermitted;

  /// The current active sync interval.
  Duration get currentFirestoreSyncInterval => _currentFirestoreSyncInterval;

  /// The effective session inactivity timeout window.
  ///
  /// Uses [options.sessionTimeout] unless overridden by custom [options.inactivityDebounce].
  Duration get effectiveTimeout =>
      options.sessionTimeout != TrackerConstants.defaultSessionTimeout
          ? options.sessionTimeout
          : (options.inactivityDebounce !=
                  TrackerConstants.defaultInactivityDebounce
              ? options.inactivityDebounce
              : options.sessionTimeout);

  /// The active in-memory session state if tracking.
  SessionState? get currentSession => _currentSession;

  /// Updates whether remote configuration permits tracking.
  ///
  /// - If [permitted] is `false`: Immediately finalizes the active session (if any)
  ///   using observed foreground duration, stops all timers, and blocks new tracking.
  /// - If [permitted] is `true`: If the app is currently in the foreground, starts
  ///   a fresh tracking session.
  Future<void> setTrackingPermitted(bool permitted) async {
    await errorHandler.runGuarded<void>(() async {
      if (errorHandler.isCircuitBroken) return;
      if (_isTrackingPermitted == permitted) return;
      _isTrackingPermitted = permitted;
      errorHandler.log(
        'SessionManager tracking permission updated to: $permitted',
      );

      if (!permitted) {
        _cancelInactivityDebounce();
        await _finalizeCurrentSession();
      } else {
        if (_isInForeground && !_isTracking) {
          await startSession();
        }
      }
    }, operationName: 'SessionManager.setTrackingPermitted');
  }

  /// Updates the periodic Firestore sync interval.
  ///
  /// If the active interval changes while tracking, cancels the existing timer
  /// and restarts it with the new interval, preventing duplicate timers.
  void updateFirestoreSyncInterval(Duration newInterval) {
    errorHandler.runGuardedSync(() {
      if (_currentFirestoreSyncInterval == newInterval) return;
      errorHandler.log(
        'Updating Firestore sync interval: ${_currentFirestoreSyncInterval.inSeconds}s -> ${newInterval.inSeconds}s',
      );
      _currentFirestoreSyncInterval = newInterval;
      if (_isTracking && _currentSession != null) {
        _startFirestoreSyncTimer();
      }
    }, operationName: 'SessionManager.updateFirestoreSyncInterval');
  }

  /// Recovers an interrupted or crashed session from local storage upon app startup.
  ///
  /// CRITICAL: Interrupted session duration is calculated STRICTLY from observed
  /// foreground duration ([accumulatedDurationSeconds]). It NEVER counts time while the process was dead.
  Future<void> recoverInterruptedSession() async {
    await errorHandler.runGuarded<void>(() async {
      final raw =
          localStorage.getString(TrackerConstants.prefsActiveSessionKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      errorHandler.log(
          'Found stored session in local storage. Checking session timeout...');
      SessionState? recoveredState;
      try {
        recoveredState = SessionState.fromJson(raw);
      } catch (e) {
        errorHandler.log('Failed to parse stored session state: $e');
        await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
        return;
      }

      if (!recoveredState.isFinalized) {
        final now = DateTime.now().toUtc();
        final inactivity = now.difference(recoveredState.lastHeartbeatAt);

        // Resume if within session timeout window
        if (inactivity <= effectiveTimeout) {
          errorHandler.log(
            'Recovered active session ${recoveredState.sessionId} within timeout window '
            '(${inactivity.inMinutes}m <= ${effectiveTimeout.inMinutes}m). Resuming session.',
          );
          _currentSession = recoveredState.copyWith(
            lastHeartbeatAt: now,
          );
          _syncedDurationSeconds = recoveredState.syncedDurationSeconds;
          _lastActiveTime = now;
          _isInForeground = true;
          _isTracking = true;
          await _persistLocalSessionState();
          _startLocalHeartbeatTimer();
          _startFirestoreSyncTimer();
          return;
        }

        final duration = recoveredState.observedDurationSeconds;
        errorHandler.log(
          'Recovering session ${recoveredState.sessionId}: started at ${recoveredState.startedAt}, '
          'last heartbeat at ${recoveredState.lastHeartbeatAt}. Recovered duration: ${duration}s.',
        );

        final success = await firestoreRepository.finalizeSession(
          testerId: recoveredState.testerId,
          sessionId: recoveredState.sessionId,
          endedAt: recoveredState.lastHeartbeatAt,
          durationSeconds: duration,
          activeDate: recoveredState.activeDate,
        );

        // Safe clearing: only clear local recovery state if Firestore finalization succeeded
        if (success) {
          await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
          errorHandler
              .log('Interrupted session recovery completed successfully.');
        } else {
          errorHandler.log(
              'Crash recovery write failed. Retaining local state for next attempt.');
        }
      } else {
        await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
      }
    }, operationName: 'SessionManager.recoverInterruptedSession');
  }

  /// Starts a new session or continues tracking.
  ///
  /// Idempotent: repeated calls when already tracking do nothing.
  /// Does not start a session if remote tracking is disabled.
  Future<void> startSession() async {
    await errorHandler.runGuarded<void>(() async {
      _cancelInactivityDebounce();

      if (errorHandler.isCircuitBroken) {
        errorHandler.log(
            'Tracking is disabled: circuit breaker is active.');
        return;
      }

      if (!_isTrackingPermitted) {
        errorHandler.log(
            'Tracking is disabled by remote configuration. startSession ignored.');
        return;
      }

      if (_isTracking && _currentSession != null) {
        errorHandler.log(
            'Session ${_currentSession!.sessionId} is already active. Ignoring start.');
        return;
      }

      final now = DateTime.now().toUtc();
      final sessionId = 'sess_${testerId}_${now.millisecondsSinceEpoch}';

      _lastActiveTime = now;
      _isInForeground = true;
      _syncedDurationSeconds = 0;

      _currentSession = SessionState(
        sessionId: sessionId,
        testerId: testerId,
        authUid: authUid,
        startedAt: now,
        lastHeartbeatAt: now,
        accumulatedDurationSeconds: 0,
        syncedDurationSeconds: 0,
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
        deviceModel: envInfo.deviceModel,
        osVersion: envInfo.osVersion,
        isFinalized: false,
      );
      await firestoreRepository.createSession(sessionData);

      // 3. Start local heartbeat timer (15s, 0 Firestore writes)
      _startLocalHeartbeatTimer();

      // 4. Start periodic Firestore sync timer
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

      final wasInForeground = _isInForeground;
      _isInForeground = false;

      // Accumulate foreground time up to this exact moment only if coming from foreground
      if (wasInForeground) {
        _accumulateActiveForegroundTime();
        if (_currentSession != null) {
          final duration = _currentSession!.observedDurationSeconds;
          final delta = max(0, duration - _syncedDurationSeconds);
          if (delta > 0) {
            _syncedDurationSeconds = duration;
            _currentSession = _currentSession!.copyWith(
              syncedDurationSeconds: _syncedDurationSeconds,
            );
            errorHandler.log(
              'App paused: instantly syncing foreground progress (${duration}s, delta: +${delta}s) to Firestore.',
            );
            unawaited(firestoreRepository.syncSessionProgress(
              testerId: _currentSession!.testerId,
              sessionId: _currentSession!.sessionId,
              durationSeconds: duration,
              deltaSeconds: delta,
              endedAt: _currentSession!.lastHeartbeatAt,
              activeDate: _currentSession!.activeDate,
            ));
          }
          unawaited(_persistLocalSessionState());
        }
      }

      if (_inactivityDebounceTimer != null &&
          _inactivityDebounceTimer!.isActive) {
        return;
      }

      errorHandler.log(
        'App paused/inactive. Session kept alive for ${effectiveTimeout.inMinutes > 0 ? '${effectiveTimeout.inMinutes}m' : '${effectiveTimeout.inSeconds}s'}. Background time excluded.',
      );

      _inactivityDebounceTimer = Timer(effectiveTimeout, () {
        errorHandler.log('Inactivity timeout expired in background. Finalizing session.');
        unawaited(_finalizeCurrentSession());
      });
    }, operationName: 'SessionManager.onAppPauseOrInactive');
  }

  /// Handles host application engine detachment / termination.
  ///
  /// Flushes current active duration to Firestore, persists local state with latest timestamp,
  /// and stops background tracking timers without clearing local storage so that returning
  /// within [sessionTimeout] can resume the session.
  void onAppDetached() {
    errorHandler.runGuardedSync(() {
      _cancelInactivityDebounce();
      _cancelTimers();

      if (_isInForeground) {
        _accumulateActiveForegroundTime();
      }
      _isInForeground = false;
      _isTracking = false;

      final session = _currentSession;
      if (session != null) {
        final duration = session.observedDurationSeconds;
        final delta = max(0, duration - _syncedDurationSeconds);
        _syncedDurationSeconds = duration;
        _currentSession = session.copyWith(
          syncedDurationSeconds: _syncedDurationSeconds,
        );
        unawaited(firestoreRepository.syncSessionProgress(
          testerId: session.testerId,
          sessionId: session.sessionId,
          durationSeconds: duration,
          deltaSeconds: delta,
          endedAt: session.lastHeartbeatAt,
          activeDate: session.activeDate,
        ));
        unawaited(_persistLocalSessionState());
        _currentSession = null;
      }
    }, operationName: 'SessionManager.onAppDetached');
  }

  /// Handles app entering foreground.
  void onAppResume() {
    errorHandler.runGuardedSync(() {
      _isInForeground = true;

      if (!_isTrackingPermitted) {
        errorHandler
            .log('App resumed, but tracking is disabled by remote config.');
        return;
      }

      final now = DateTime.now().toUtc();

      if (_currentSession != null) {
        final elapsed = now.difference(_currentSession!.lastHeartbeatAt);
        if (elapsed > effectiveTimeout) {
          _cancelInactivityDebounce();
          errorHandler.log(
            'App resumed after session timeout (${elapsed.inSeconds}s > ${effectiveTimeout.inSeconds}s). Finalizing previous session and starting fresh.',
          );
          unawaited(() async {
            await _finalizeCurrentSession();
            await startSession();
          }());
          return;
        }

        _cancelInactivityDebounce();
        _lastActiveTime = now;
        _currentSession = _currentSession!.copyWith(
          lastHeartbeatAt: now,
        );
        unawaited(_persistLocalSessionState());
        _isTracking = true;
        _startLocalHeartbeatTimer();
        _startFirestoreSyncTimer();

        errorHandler.log(
          'App resumed within session timeout (${effectiveTimeout.inMinutes > 0 ? '${effectiveTimeout.inMinutes}m' : '${effectiveTimeout.inSeconds}s'}). Keeping existing session ${_currentSession?.sessionId} active. Background interval excluded.',
        );
        return;
      }

      // No in-memory session (e.g. cold restart or process killed)
      unawaited(() async {
        await recoverInterruptedSession();
        if (_currentSession == null) {
          await startSession();
        }
      }());
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

  /// Finalizes the current session in Firestore and clears local state if successful.
  Future<void> _finalizeCurrentSession() async {
    _cancelTimers();

    final session = _currentSession;
    if (session == null) {
      _isTracking = false;
      return;
    }

    if (_isInForeground) {
      _accumulateActiveForegroundTime();
    }

    final duration = _currentSession!.observedDurationSeconds;
    final endedAt = _currentSession!.lastHeartbeatAt;

    errorHandler.log(
      'Finalizing session ${session.sessionId}: ended at $endedAt, duration: ${duration}s.',
    );

    final success = await firestoreRepository.finalizeSession(
      testerId: session.testerId,
      sessionId: session.sessionId,
      endedAt: endedAt,
      durationSeconds: duration,
      activeDate: session.activeDate,
    );

    // Only clear local recovery state if finalization succeeded in Firestore
    if (success) {
      await localStorage.remove(TrackerConstants.prefsActiveSessionKey);
    } else {
      errorHandler.log(
        'Finalize write failed or offline. Preserving local session state for recovery.',
      );
    }

    _currentSession = null;
    _isTracking = false;
  }

  /// Accumulates observed active foreground time into [_currentSession].
  void _accumulateActiveForegroundTime() {
    if (_currentSession == null || _lastActiveTime == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final elapsedSeconds = max(0, now.difference(_lastActiveTime!).inSeconds);

    if (elapsedSeconds > 0) {
      _lastActiveTime = _lastActiveTime!.add(Duration(seconds: elapsedSeconds));
      _currentSession = _currentSession!.copyWith(
        lastHeartbeatAt: now,
        accumulatedDurationSeconds:
            _currentSession!.accumulatedDurationSeconds + elapsedSeconds,
      );
      unawaited(_persistLocalSessionState());
    } else {
      _currentSession = _currentSession!.copyWith(
        lastHeartbeatAt: now,
      );
    }
  }

  /// Starts the local-only heartbeat timer (default: 15s).
  void _startLocalHeartbeatTimer() {
    _localHeartbeatTimer?.cancel();
    _localHeartbeatTimer = Timer.periodic(options.localHeartbeatInterval, (_) {
      if (errorHandler.isCircuitBroken) {
        _cancelTimers();
        return;
      }
      errorHandler.runGuardedSync(() {
        if (!_isInForeground || _currentSession == null) {
          return;
        }
        _accumulateActiveForegroundTime();
      }, operationName: 'SessionManager._localHeartbeat');
    });
  }

  /// Starts the periodic Firestore sync timer using [_currentFirestoreSyncInterval].
  /// Guarantees that any prior timer is cancelled before starting a new one.
  void _startFirestoreSyncTimer() {
    _firestoreSyncTimer?.cancel();
    _firestoreSyncTimer = Timer.periodic(_currentFirestoreSyncInterval, (_) {
      if (errorHandler.isCircuitBroken) {
        _cancelTimers();
        return;
      }
      errorHandler.runGuardedSync(() {
        if (_currentSession == null) {
          return;
        }
        if (_isInForeground) {
          _accumulateActiveForegroundTime();
        }
        final duration = _currentSession!.observedDurationSeconds;
        final delta = max(0, duration - _syncedDurationSeconds);
        _syncedDurationSeconds = duration;
        _currentSession = _currentSession!.copyWith(
          syncedDurationSeconds: _syncedDurationSeconds,
        );
        unawaited(firestoreRepository.syncSessionProgress(
          testerId: _currentSession!.testerId,
          sessionId: _currentSession!.sessionId,
          durationSeconds: duration,
          deltaSeconds: delta,
          endedAt: _currentSession!.lastHeartbeatAt,
          activeDate: _currentSession!.activeDate,
        ));
        unawaited(_persistLocalSessionState());
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
