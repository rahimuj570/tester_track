import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/config/remote_config_service.dart';
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
  late RemoteConfigService configService;
  late SessionManager sessionManager;

  const envInfo = AppEnvironmentInfo(
    platform: 'android',
    deviceModel: 'Pixel 7',
    osVersion: 'Android 14',
    appVersion: '1.0.0 (1)',
  );

  const options = TesterTrackOptions(
    debugLogging: false,
    localHeartbeatInterval: Duration(milliseconds: 20),
    firestoreSyncInterval: Duration(milliseconds: 50),
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

    // Initial tester doc in Firestore
    await repository.syncTesterProfile(
      testerId: 'T001',
      authUid: 'anon_uid_123',
      envInfo: envInfo,
    );

    configService = RemoteConfigService(
      localStorage: localStorage,
      firestoreRepository: repository,
      errorHandler: errorHandler,
      envInfo: envInfo,
    );
    await configService.init();

    sessionManager = SessionManager(
      testerId: 'T001',
      authUid: 'anon_uid_123',
      envInfo: envInfo,
      localStorage: localStorage,
      firestoreRepository: repository,
      errorHandler: errorHandler,
      options: options,
      initialTrackingPermitted: configService.isTrackingPermitted(),
      initialFirestoreSyncInterval:
          configService.getEffectiveSyncInterval(options.firestoreSyncInterval),
    );
  });

  tearDown(() {
    configService.dispose();
    sessionManager.dispose();
  });

  group('Remote Re-Enable End-to-End Integration Flow', () {
    test(
        'Complete lifecycle: enabled -> active session -> remote disable -> finalized -> remote re-enable -> fresh session',
        () async {
      // 1. Initial State: Tracking enabled, app in foreground
      await sessionManager.startSession();
      expect(sessionManager.isTracking, isTrue);
      final firstSessionId = sessionManager.currentSession!.sessionId;
      expect(firstSessionId.startsWith('sess_T001_'), isTrue);

      // Verify session exists in Firestore and is not finalized
      final firstDocInitial =
          await repository.getSession('T001', firstSessionId);
      expect(firstDocInitial, isNotNull);
      expect(firstDocInitial!.isFinalized, isFalse);

      // 2. Developer remotely sets enabled = false in Firebase
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({'enabled': false});

      // 3. Config refresh occurs (independent of session timers)
      final updatedConfig = await configService.fetchAndApplyConfig();
      expect(updatedConfig.enabled, isFalse);
      expect(configService.isTrackingPermitted(), isFalse);

      // Notify SessionManager of permission update
      await sessionManager.setTrackingPermitted(false);

      // 4. Verify SessionManager immediately finalized the session
      expect(sessionManager.isTracking, isFalse);
      expect(sessionManager.currentSession, isNull);
      expect(sessionManager.isTrackingPermitted, isFalse);

      // Verify first session is permanently finalized in Firestore
      final firstDocFinalized =
          await repository.getSession('T001', firstSessionId);
      expect(firstDocFinalized!.isFinalized, isTrue);
      expect(firstDocFinalized.endedAt, isNotNull);

      // Verify local active session is cleared
      expect(
        localStorage.getString(TrackerConstants.prefsActiveSessionKey),
        isNull,
      );

      // 5. While tracking is disabled, attempt to call startSession / onAppResume
      await sessionManager.startSession();
      expect(sessionManager.isTracking, isFalse); // Stays disabled!

      sessionManager.onAppResume();
      expect(sessionManager.isTracking, isFalse); // Stays disabled!

      // 6. Developer remotely re-enables tracking in Firebase: enabled = true
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({'enabled': true});

      // 7. Next config refresh detects enabled = true
      final reenabledConfig = await configService.fetchAndApplyConfig();
      expect(reenabledConfig.enabled, isTrue);
      expect(configService.isTrackingPermitted(), isTrue);

      // Apply re-enabled permission (app is in foreground)
      await sessionManager.setTrackingPermitted(true);

      // 8. Verify a fresh session is started automatically
      expect(sessionManager.isTracking, isTrue);
      expect(sessionManager.isTrackingPermitted, isTrue);
      expect(sessionManager.currentSession, isNotNull);

      final secondSessionId = sessionManager.currentSession!.sessionId;
      expect(secondSessionId, isNot(equals(firstSessionId)));

      // 9. Verify first session document was NOT modified / reopened
      final firstDocRecheck =
          await repository.getSession('T001', firstSessionId);
      expect(firstDocRecheck!.isFinalized, isTrue);

      // 10. Verify second session document exists in Firestore and is active
      final secondDoc = await repository.getSession('T001', secondSessionId);
      expect(secondDoc, isNotNull);
      expect(secondDoc!.sessionId, equals(secondSessionId));
      expect(secondDoc.isFinalized, isFalse);
    });
  });
}
