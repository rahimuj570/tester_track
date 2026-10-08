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
    localHeartbeatInterval: Duration(milliseconds: 50),
    firestoreSyncInterval: Duration(milliseconds: 100),
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

    test('onAppResume within debounce window preserves active session',
        () async {
      await sessionManager.startSession();
      final sessionId = sessionManager.currentSession!.sessionId;

      // Simulate app paused
      sessionManager.onAppPauseOrInactive();

      // Immediately resume before debounce expires (within 50ms)
      await Future<void>.delayed(const Duration(milliseconds: 30));
      sessionManager.onAppResume();

      // Session should remain active
      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.currentSession?.sessionId, equals(sessionId));

      // Wait beyond debounce window to verify it wasn't finalized
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.currentSession?.sessionId, equals(sessionId));
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
