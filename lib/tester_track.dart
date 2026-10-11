import 'package:firebase_core/firebase_core.dart';
import 'src/config/remote_config_service.dart';
import 'src/core/constants.dart';
import 'src/core/error_handler.dart';
import 'src/core/tracker_options.dart';
import 'src/firebase/firebase_service.dart';
import 'src/identity/device_info_helper.dart';
import 'src/identity/identity_manager.dart';
import 'src/lifecycle/app_lifecycle_observer.dart';
import 'src/models/remote_config_data.dart';
import 'src/session/session_manager.dart';
import 'src/storage/firestore_repository.dart';
import 'src/storage/local_storage.dart';

export 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
export 'src/core/tracker_options.dart';

/// The primary interface for TesterTrack.
class TesterTrack {
  TesterTrack._();

  static final TesterTrack _instance = TesterTrack._();

  /// The global singleton instance of [TesterTrack].
  static TesterTrack get instance => _instance;

  TrackerErrorHandler _errorHandler = TrackerErrorHandler();
  TrackerFirebaseService? _firebaseService;
  LocalStorage? _localStorage;
  IdentityManager? _identityManager;
  DeviceInfoHelper? _deviceInfoHelper;
  FirestoreRepository? _firestoreRepository;
  RemoteConfigService? _remoteConfigService;
  SessionManager? _sessionManager;
  AppLifecycleObserver? _lifecycleObserver;
  TesterTrackOptions _options = const TesterTrackOptions();

  bool _isInitialized = false;
  String? _testerId;
  String? _authUid;

  /// Whether TesterTrack has been successfully initialized.
  bool get isInitialized => _isInitialized;

  /// The active options configured during initialization.
  TesterTrackOptions get options => _options;

  /// The active tester identifier (either developer-provided or auto-generated).
  String? get testerId => _testerId;

  /// Whether session activity is actively being tracked in the foreground.
  bool get isTracking => _sessionManager?.isTracking ?? false;

  /// Initializes the TesterTrack engine.
  ///
  /// Safe to call on application launch. Will never throw uncaught exceptions or block the UI.
  /// Returns `true` if initialization succeeded, or `false` if an unrecoverable failure occurred.
  static Future<bool> initialize({
    required FirebaseOptions firebaseOptions,
    String? testerId,
    TesterTrackOptions options = const TesterTrackOptions(),
  }) async {
    final tracker = TesterTrack.instance;
    tracker._options = options;
    tracker._errorHandler =
        TrackerErrorHandler(debugLogging: options.debugLogging);

    return await tracker._errorHandler.runGuarded<bool>(() async {
          tracker._errorHandler.log('Initializing TesterTrack...');

          // Clean up any previous timers/observers if re-initializing
          if (tracker._sessionManager != null &&
              tracker._sessionManager!.isTracking) {
            await tracker._sessionManager!.stopTracking();
          }
          tracker._lifecycleObserver?.detach();
          tracker._remoteConfigService?.dispose();
          tracker._sessionManager?.dispose();

          // 1. Initialize local storage
          tracker._localStorage =
              LocalStorage(errorHandler: tracker._errorHandler);
          await tracker._localStorage!.init();

          // 2. Resolve tester identity
          tracker._identityManager = IdentityManager(
            localStorage: tracker._localStorage!,
            errorHandler: tracker._errorHandler,
          );
          tracker._testerId =
              await tracker._identityManager!.resolveTesterId(testerId);

          // 3. Initialize secondary named Firebase App
          tracker._firebaseService =
              TrackerFirebaseService(errorHandler: tracker._errorHandler);
          final firebaseInitSuccess =
              await tracker._firebaseService!.initialize(
            firebaseOptions: firebaseOptions,
            appName: TrackerConstants.namedFirebaseAppName,
          );

          if (!firebaseInitSuccess) {
            tracker._errorHandler
                .log('Failed to initialize secondary Firebase app.');
            return false;
          }

          // 4. Anonymous Authentication on named app
          await tracker._firebaseService!.signInAnonymously();
          tracker._authUid = tracker._firebaseService!.currentAuthUid;

          // 5. Gather device & environment info
          tracker._deviceInfoHelper =
              DeviceInfoHelper(errorHandler: tracker._errorHandler);
          final envInfo = await tracker._deviceInfoHelper!.getEnvironmentInfo();

          // 6. Initialize Firestore repository
          tracker._firestoreRepository = FirestoreRepository(
            firestore: tracker._firebaseService!.firestore,
            errorHandler: tracker._errorHandler,
          );

          // 7. Initialize RemoteConfigService (loads cache, fetches remote config)
          tracker._remoteConfigService = RemoteConfigService(
            localStorage: tracker._localStorage!,
            firestoreRepository: tracker._firestoreRepository!,
            errorHandler: tracker._errorHandler,
            envInfo: envInfo,
          );
          await tracker._remoteConfigService!.init();
          await tracker._remoteConfigService!.fetchAndApplyConfig();

          // Evaluate whether tracking is currently allowed & calculate effective sync interval
          final isPermitted =
              tracker._remoteConfigService!.isTrackingPermitted();
          final effectiveSyncInterval = tracker._remoteConfigService!
              .getEffectiveSyncInterval(tracker._options.firestoreSyncInterval);

          // 8. Synchronize initial tester profile in Firestore
          if (tracker._authUid != null && tracker._testerId != null) {
            await tracker._firestoreRepository!.syncTesterProfile(
              testerId: tracker._testerId!,
              authUid: tracker._authUid!,
              envInfo: envInfo,
            );
          }

          // 9. Initialize session manager & recover any interrupted session
          tracker._sessionManager = SessionManager(
            testerId: tracker._testerId ?? 'unknown',
            authUid: tracker._authUid ?? 'unknown',
            envInfo: envInfo,
            localStorage: tracker._localStorage!,
            firestoreRepository: tracker._firestoreRepository!,
            errorHandler: tracker._errorHandler,
            options: tracker._options,
            initialTrackingPermitted: isPermitted,
            initialFirestoreSyncInterval: effectiveSyncInterval,
          );

          // Recover previously interrupted crash state
          await tracker._sessionManager!.recoverInterruptedSession();

          // 10. Start periodic remote config refresh (every 5 minutes)
          tracker._remoteConfigService!.startPeriodicRefresh(
            (newConfig, permitted) {
              tracker._handleConfigChange(newConfig, permitted);
            },
          );

          // 11. Attach app lifecycle observer with throttled onResumed config refresh
          tracker._lifecycleObserver = AppLifecycleObserver(
            sessionManager: tracker._sessionManager!,
            errorHandler: tracker._errorHandler,
            onResumed: () {
              tracker._remoteConfigService?.refreshOnResumeThrottled(
                (newConfig, permitted) {
                  tracker._handleConfigChange(newConfig, permitted);
                },
              );
            },
          );
          tracker._lifecycleObserver!.attach();

          // 12. Start initial foreground session if tracking is permitted
          if (isPermitted) {
            await tracker._sessionManager!.startSession();
          } else {
            tracker._errorHandler.log(
              'Initial tracking not permitted by remote configuration (enabled=${tracker._remoteConfigService?.activeConfig.enabled}).',
            );
          }

          tracker._isInitialized = true;
          tracker._errorHandler.log(
              'TesterTrack initialized successfully. (TesterId: ${tracker._testerId})');
          return true;
        }, operationName: 'TesterTrack.initialize', fallbackValue: false) ??
        false;
  }

  void _handleConfigChange(RemoteConfigData newConfig, bool isPermitted) {
    _errorHandler.runGuardedSync(() {
      if (_sessionManager == null || _remoteConfigService == null) return;

      // Update tracking permission (finalizes active session if false, starts if true & in foreground)
      _sessionManager!.setTrackingPermitted(isPermitted);

      // Update Firestore sync interval if remote override is active
      final effectiveInterval = _remoteConfigService!
          .getEffectiveSyncInterval(_options.firestoreSyncInterval);
      _sessionManager!.updateFirestoreSyncInterval(effectiveInterval);
    }, operationName: 'TesterTrack._handleConfigChange');
  }

  /// Manually starts activity tracking.
  void startTracking() {
    _errorHandler.runGuardedSync(() {
      if (!_isInitialized || _sessionManager == null) {
        _errorHandler
            .log('Cannot start tracking: TesterTrack is not initialized.');
        return;
      }
      final isPermitted = _remoteConfigService?.isTrackingPermitted() ?? true;
      if (!isPermitted) {
        _errorHandler.log(
          'Cannot start tracking: tracking is disabled by remote configuration.',
        );
        return;
      }
      _sessionManager!.startSession();
      _errorHandler.log('Tracking started.');
    }, operationName: 'TesterTrack.startTracking');
  }

  /// Manually stops activity tracking.
  void stopTracking() {
    _errorHandler.runGuardedSync(() {
      if (_sessionManager != null) {
        _sessionManager!.stopTracking();
      }
      _errorHandler.log('Tracking stopped.');
    }, operationName: 'TesterTrack.stopTracking');
  }

  /// Sets or updates the tester identity at runtime (e.g. after the user logs in with their email).
  ///
  /// Finalizes any active session under the previous tester ID, syncs the new tester profile
  /// to Firestore, and starts a fresh tracking session under the new identity.
  /// Returns `true` if the identity was successfully updated, or `false` on failure.
  Future<bool> setTesterId(String newTesterId) async {
    return await _errorHandler.runGuarded<bool>(() async {
          if (!_isInitialized) {
            _errorHandler
                .log('Cannot set tester ID: TesterTrack is not initialized.');
            return false;
          }

          final trimmed = newTesterId.trim();
          if (!IdentityManager.isValidTesterId(trimmed)) {
            _errorHandler.log('Cannot set invalid tester ID: "$newTesterId"');
            return false;
          }

          if (_testerId == trimmed) {
            _errorHandler
                .log('Tester ID is already "$trimmed", no update needed.');
            return true;
          }

          // 1. Finalize active session under previous identity
          if (_sessionManager != null && _sessionManager!.isTracking) {
            await _sessionManager!.stopTracking();
          }

          // 2. Persist new tester ID
          _testerId = trimmed;
          await _localStorage?.savePersistentTesterId(trimmed);

          // 3. Sync tester profile for new identity
          if (_authUid != null &&
              _deviceInfoHelper != null &&
              _firestoreRepository != null) {
            final envInfo = await _deviceInfoHelper!.getEnvironmentInfo();
            await _firestoreRepository!.syncTesterProfile(
              testerId: _testerId!,
              authUid: _authUid!,
              envInfo: envInfo,
            );
          }

          // 4. Rebuild session manager & lifecycle observer with new identity
          if (_remoteConfigService != null &&
              _deviceInfoHelper != null &&
              _firestoreRepository != null &&
              _localStorage != null) {
            final envInfo = await _deviceInfoHelper!.getEnvironmentInfo();
            final isPermitted = _remoteConfigService!.isTrackingPermitted();
            final effectiveSyncInterval = _remoteConfigService!
                .getEffectiveSyncInterval(_options.firestoreSyncInterval);

            _sessionManager?.dispose();
            _sessionManager = SessionManager(
              testerId: _testerId!,
              authUid: _authUid ?? 'unknown',
              envInfo: envInfo,
              localStorage: _localStorage!,
              firestoreRepository: _firestoreRepository!,
              errorHandler: _errorHandler,
              options: _options,
              initialTrackingPermitted: isPermitted,
              initialFirestoreSyncInterval: effectiveSyncInterval,
            );

            _lifecycleObserver?.detach();
            _lifecycleObserver = AppLifecycleObserver(
              sessionManager: _sessionManager!,
              errorHandler: _errorHandler,
              onResumed: () {
                _remoteConfigService?.refreshOnResumeThrottled(
                  (newConfig, permitted) {
                    _handleConfigChange(newConfig, permitted);
                  },
                );
              },
            );
            _lifecycleObserver!.attach();

            if (isPermitted) {
              await _sessionManager!.startSession();
            }
          }

          _errorHandler.log(
              'TesterTrack identity successfully updated to: "$_testerId"');
          return true;
        }, operationName: 'TesterTrack.setTesterId', fallbackValue: false) ??
        false;
  }

  /// Clears the explicit tester identity and resets back to a fresh anonymous installation ID.
  /// Typically called when the tester logs out of the host application.
  Future<bool> resetTesterId() async {
    final anonymousId = IdentityManager.generateAnonymousInstallationId();
    return await setTesterId(anonymousId);
  }
}
