import 'package:firebase_core/firebase_core.dart';
import 'src/core/constants.dart';
import 'src/core/error_handler.dart';
import 'src/core/tracker_options.dart';
import 'src/firebase/firebase_service.dart';
import 'src/identity/device_info_helper.dart';
import 'src/identity/identity_manager.dart';
import 'src/lifecycle/app_lifecycle_observer.dart';
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

          // 6. Synchronize initial tester profile in Firestore
          tracker._firestoreRepository = FirestoreRepository(
            firestore: tracker._firebaseService!.firestore,
            errorHandler: tracker._errorHandler,
          );

          if (tracker._authUid != null && tracker._testerId != null) {
            await tracker._firestoreRepository!.syncTesterProfile(
              testerId: tracker._testerId!,
              authUid: tracker._authUid!,
              envInfo: envInfo,
            );
          }

          // 7. Initialize session manager & recover any interrupted session
          tracker._sessionManager = SessionManager(
            testerId: tracker._testerId ?? 'unknown',
            authUid: tracker._authUid ?? 'unknown',
            envInfo: envInfo,
            localStorage: tracker._localStorage!,
            firestoreRepository: tracker._firestoreRepository!,
            errorHandler: tracker._errorHandler,
            options: tracker._options,
          );

          // Recover previously interrupted crash state
          await tracker._sessionManager!.recoverInterruptedSession();

          // 8. Attach app lifecycle observer
          tracker._lifecycleObserver = AppLifecycleObserver(
            sessionManager: tracker._sessionManager!,
            errorHandler: tracker._errorHandler,
          );
          tracker._lifecycleObserver!.attach();

          // 9. Start initial foreground session
          await tracker._sessionManager!.startSession();

          tracker._isInitialized = true;
          tracker._errorHandler.log(
              'TesterTrack initialized successfully. (TesterId: ${tracker._testerId})');
          return true;
        }, operationName: 'TesterTrack.initialize', fallbackValue: false) ??
        false;
  }

  /// Manually starts activity tracking.
  void startTracking() {
    _errorHandler.runGuardedSync(() {
      if (!_isInitialized || _sessionManager == null) {
        _errorHandler
            .log('Cannot start tracking: TesterTrack is not initialized.');
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
}
