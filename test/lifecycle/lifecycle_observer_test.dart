import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/core/tracker_options.dart';
import 'package:tester_track/src/identity/device_info_helper.dart';
import 'package:tester_track/src/lifecycle/app_lifecycle_observer.dart';
import 'package:tester_track/src/session/session_manager.dart';
import 'package:tester_track/src/storage/firestore_repository.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;
  late FirestoreRepository repository;
  late SessionManager sessionManager;
  late AppLifecycleObserver observer;

  const envInfo = AppEnvironmentInfo(
    platform: 'android',
    deviceModel: 'Pixel 7',
    osVersion: 'Android 14',
    appVersion: '1.0.0 (1)',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final fakeFirestore = FakeFirebaseFirestore();
    errorHandler = TrackerErrorHandler(debugLogging: false);
    localStorage = LocalStorage(errorHandler: errorHandler);
    await localStorage.init();

    repository = FirestoreRepository(
      firestore: fakeFirestore,
      errorHandler: errorHandler,
    );

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
      options: const TesterTrackOptions(
        inactivityDebounce: Duration(milliseconds: 50),
      ),
    );

    observer = AppLifecycleObserver(
      sessionManager: sessionManager,
      errorHandler: errorHandler,
    );
  });

  tearDown(() {
    observer.detach();
    sessionManager.dispose();
  });

  group('AppLifecycleObserver', () {
    test('attach and detach manage observer lifecycle safely', () {
      expect(observer.isAttached, isFalse);

      observer.attach();
      expect(observer.isAttached, isTrue);

      // Repeated attach is safe
      observer.attach();
      expect(observer.isAttached, isTrue);

      observer.detach();
      expect(observer.isAttached, isFalse);

      // Repeated detach is safe
      observer.detach();
      expect(observer.isAttached, isFalse);
    });

    test('lifecycle state changes forward correctly to session manager',
        () async {
      observer.attach();

      // 1. Resumed state starts session
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sessionManager.isTracking, isTrue);

      // 2. Inactive / Paused state triggers debounce
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(
          sessionManager.isTracking, isTrue); // still tracking during debounce

      // 3. Wait for debounce to expire
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(sessionManager.isTracking, isFalse); // finalized after debounce
    });
  });
}
