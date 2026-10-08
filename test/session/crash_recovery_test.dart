import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/core/constants.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/core/tracker_options.dart';
import 'package:tester_track/src/identity/device_info_helper.dart';
import 'package:tester_track/src/models/session_data.dart';
import 'package:tester_track/src/session/session_manager.dart';
import 'package:tester_track/src/session/session_state.dart';
import 'package:tester_track/src/storage/firestore_repository.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;
  late FirestoreRepository repository;

  const envInfo = AppEnvironmentInfo(
    platform: 'android',
    deviceModel: 'Pixel 7',
    osVersion: 'Android 14',
    appVersion: '1.0.0 (1)',
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
  });

  group('Crash Recovery', () {
    test(
        'recovers interrupted session using strictly lastHeartbeatAt and NOT startup time',
        () async {
      // Simulate session started at 10:00:00, last heartbeat at 10:04:45 (285s duration)
      // Process killed immediately after, and app restarts much later at 14:00:00
      final started = DateTime.utc(2026, 10, 8, 10, 0, 0);
      final lastHeartbeat = DateTime.utc(2026, 10, 8, 10, 4, 45);

      const sessionId = 'sess_T001_1728381600000';

      // 1. Create in-progress session document in Firestore
      await repository.createSession(
        SessionData(
          sessionId: sessionId,
          testerId: 'T001',
          authUid: 'anon_uid_123',
          startedAt: started,
          endedAt: null,
          durationSeconds: 0,
          activeDate: '2026-10-08',
          appVersion: '1.0.0 (1)',
          platform: 'android',
          isFinalized: false,
        ),
      );

      // 2. Persist in-flight state in LocalStorage (as if app crashed unexpectedly)
      final crashedState = SessionState(
        sessionId: sessionId,
        testerId: 'T001',
        authUid: 'anon_uid_123',
        startedAt: started,
        lastHeartbeatAt: lastHeartbeat,
        appVersion: '1.0.0 (1)',
        platform: 'android',
        isFinalized: false,
      );
      await localStorage.setString(
        TrackerConstants.prefsActiveSessionKey,
        crashedState.toJson(),
      );

      // 3. New app startup creates new SessionManager and calls recoverInterruptedSession
      final newSessionManager = SessionManager(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: envInfo,
        localStorage: localStorage,
        firestoreRepository: repository,
        errorHandler: errorHandler,
        options: const TesterTrackOptions(),
      );

      await newSessionManager.recoverInterruptedSession();

      // 4. Verify that the recovered session in Firestore has exact duration 285s
      final finalizedSession = await repository.getSession('T001', sessionId);
      expect(finalizedSession, isNotNull);
      expect(finalizedSession!.isFinalized, isTrue);
      expect(finalizedSession.durationSeconds, equals(285));
      expect(finalizedSession.endedAt, equals(lastHeartbeat));

      // Verify local active session state was cleaned up
      expect(localStorage.getString(TrackerConstants.prefsActiveSessionKey),
          isNull);

      // 5. Repeated recovery call is idempotent
      await newSessionManager.recoverInterruptedSession();
      final recheckedSession = await repository.getSession('T001', sessionId);
      expect(recheckedSession!.durationSeconds, equals(285));
    });
  });
}
