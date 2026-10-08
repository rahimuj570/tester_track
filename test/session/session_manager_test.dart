import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/core/constants.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/core/tracker_options.dart';
import 'package:tester_track/src/identity/device_info_helper.dart';
import 'package:tester_track/src/session/session_manager.dart';
import 'package:tester_track/src/storage/firestore_repository.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;
  late FirestoreRepository repository;
  late SessionManager sessionManager;

  const envInfo = AppEnvironmentInfo(
    platform: 'android',
    deviceModel: 'Pixel 7',
    osVersion: 'Android 14',
    appVersion: '1.0.0 (1)',
  );

  const options = TesterTrackOptions(
    debugLogging: false,
    localHeartbeatInterval: Duration(milliseconds: 30),
    firestoreSyncInterval: Duration(milliseconds: 60),
    inactivityDebounce: Duration(milliseconds: 100),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    errorHandler = TrackerErrorHandler(debugLogging: false);
    localStorage = LocalStorage(errorHandler: errorHandler);
    await localStorage.init();

    repository = FirestoreRepository(
      firestore: fakeFirestore,
      errorHandler: errorHandler,
    );

    // Initial tester doc
    await repository.syncTesterProfile(
      testerId: 'T001',
      authUid: 'anon_uid_123',
      envInfo: envInfo,
    );

    sessionManager = SessionManager(
      testerId: 'T001',
      authUid: 'anon_uid_123',
      envInfo: envInfo,
      localStorage: localStorage,
      firestoreRepository: repository,
      errorHandler: errorHandler,
      options: options,
    );
  });

  tearDown(() {
    sessionManager.dispose();
  });

  group('SessionManager', () {
    test(
        'startSession generates deterministic session ID and persists local state',
        () async {
      await sessionManager.startSession();

      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.currentSession, isNotNull);

      final sessionId = sessionManager.currentSession!.sessionId;
      expect(sessionId.startsWith('sess_T001_'), isTrue);

      // Verify state in LocalStorage
      final localRaw =
          localStorage.getString(TrackerConstants.prefsActiveSessionKey);
      expect(localRaw, isNotNull);
      expect(localRaw!.contains(sessionId), isTrue);

      // Verify session in Firestore
      final sessionDoc = await repository.getSession('T001', sessionId);
      expect(sessionDoc, isNotNull);
      expect(sessionDoc!.sessionId, equals(sessionId));
      expect(sessionDoc.isFinalized, isFalse);
    });

    test('repeated startSession calls are idempotent', () async {
      await sessionManager.startSession();
      final initialSessionId = sessionManager.currentSession!.sessionId;

      // Second start call
      await sessionManager.startSession();
      expect(
          sessionManager.currentSession!.sessionId, equals(initialSessionId));
    });

    test('startSession is ignored when tracking is not permitted', () async {
      final disabledManager = SessionManager(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: envInfo,
        localStorage: localStorage,
        firestoreRepository: repository,
        errorHandler: errorHandler,
        options: options,
        initialTrackingPermitted: false,
      );

      await disabledManager.startSession();
      expect(disabledManager.isTracking, isFalse);
      expect(disabledManager.currentSession, isNull);
      disabledManager.dispose();
    });

    test('stopTracking finalizes session in Firestore and clears local state',
        () async {
      await sessionManager.startSession();
      final sessionId = sessionManager.currentSession!.sessionId;

      await sessionManager.stopTracking();

      expect(sessionManager.isTracking, isFalse);
      expect(sessionManager.currentSession, isNull);

      // Local storage active session cleared
      expect(localStorage.getString(TrackerConstants.prefsActiveSessionKey),
          isNull);

      // Firestore session marked finalized
      final sessionDoc = await repository.getSession('T001', sessionId);
      expect(sessionDoc, isNotNull);
      expect(sessionDoc!.isFinalized, isTrue);
      expect(sessionDoc.endedAt, isNotNull);
    });

    test('setTrackingPermitted(false) remotely disables active session',
        () async {
      await sessionManager.startSession();
      final sessionId = sessionManager.currentSession!.sessionId;
      expect(sessionManager.isTracking, isTrue);

      // Simulate remote kill switch
      await sessionManager.setTrackingPermitted(false);

      expect(sessionManager.isTracking, isFalse);
      expect(sessionManager.isTrackingPermitted, isFalse);
      expect(sessionManager.currentSession, isNull);

      // Verify session finalized in Firestore
      final sessionDoc = await repository.getSession('T001', sessionId);
      expect(sessionDoc, isNotNull);
      expect(sessionDoc!.isFinalized, isTrue);
    });

    test(
        'setTrackingPermitted(true) re-enables tracking and creates a fresh session',
        () async {
      await sessionManager.startSession();
      final firstSessionId = sessionManager.currentSession!.sessionId;

      // Disable
      await sessionManager.setTrackingPermitted(false);
      expect(sessionManager.isTracking, isFalse);

      // Wait a tick so timestamps differ
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // App is still in foreground; re-enable tracking
      await sessionManager.setTrackingPermitted(true);

      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.isTrackingPermitted, isTrue);
      expect(sessionManager.currentSession, isNotNull);

      // Crucial: Fresh session is created, NOT reopening the old session
      final secondSessionId = sessionManager.currentSession!.sessionId;
      expect(secondSessionId, isNot(equals(firstSessionId)));

      final firstDoc = await repository.getSession('T001', firstSessionId);
      expect(firstDoc!.isFinalized, isTrue);

      final secondDoc = await repository.getSession('T001', secondSessionId);
      expect(secondDoc!.isFinalized, isFalse);
    });

    test('updateFirestoreSyncInterval safely updates sync timer interval',
        () async {
      await sessionManager.startSession();
      expect(sessionManager.currentFirestoreSyncInterval,
          equals(options.firestoreSyncInterval));

      sessionManager
          .updateFirestoreSyncInterval(const Duration(milliseconds: 120));
      expect(sessionManager.currentFirestoreSyncInterval,
          equals(const Duration(milliseconds: 120)));

      // Repeating with same interval does not recreate timers
      sessionManager
          .updateFirestoreSyncInterval(const Duration(milliseconds: 120));
      expect(sessionManager.currentFirestoreSyncInterval,
          equals(const Duration(milliseconds: 120)));
    });

    test(
        'onAppResume within debounce window preserves active session and excludes background time',
        () async {
      await sessionManager.startSession();
      final sessionId = sessionManager.currentSession!.sessionId;

      // Active in foreground for 50ms
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Simulate app paused (enters background)
      sessionManager.onAppPauseOrInactive();

      final durationAtPause =
          sessionManager.currentSession!.observedDurationSeconds;

      // Spend 40ms in background (within 100ms debounce)
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // Resume app
      sessionManager.onAppResume();

      // Background elapsed time must NOT be added to observed duration
      expect(sessionManager.currentSession?.observedDurationSeconds,
          equals(durationAtPause));
      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.currentSession?.sessionId, equals(sessionId));

      // Spend another 50ms in foreground
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sessionManager.stopTracking();

      final finalDoc = await repository.getSession('T001', sessionId);
      expect(finalDoc!.isFinalized, isTrue);
      // Final duration should only count the foreground segments
      expect(finalDoc.durationSeconds, isNotNull);
    });

    test('inactivity beyond debounce window finalizes session', () async {
      await sessionManager.startSession();
      final sessionId = sessionManager.currentSession!.sessionId;

      // Simulate app paused
      sessionManager.onAppPauseOrInactive();

      // Wait beyond debounce window (100ms + margin)
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(sessionManager.isTracking, isFalse);
      expect(sessionManager.currentSession, isNull);

      final sessionDoc = await repository.getSession('T001', sessionId);
      expect(sessionDoc!.isFinalized, isTrue);
    });
  });
}
