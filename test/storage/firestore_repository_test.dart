import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/core/constants.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/identity/device_info_helper.dart';
import 'package:tester_track/src/models/session_data.dart';
import 'package:tester_track/src/storage/firestore_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late TrackerErrorHandler errorHandler;
  late FirestoreRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    errorHandler = TrackerErrorHandler(debugLogging: false);
    repository = FirestoreRepository(
      firestore: fakeFirestore,
      errorHandler: errorHandler,
    );
  });

  group('FirestoreRepository', () {
    const envInfo = AppEnvironmentInfo(
      platform: 'android',
      deviceModel: 'Pixel 7',
      osVersion: 'Android 14',
      appVersion: '1.0.0 (1)',
    );

    test(
        'syncTesterProfile creates initial tester document with default counters',
        () async {
      final tester = await repository.syncTesterProfile(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: envInfo,
      );

      expect(tester, isNotNull);
      expect(tester!.testerId, equals('T001'));
      expect(tester.authUid, equals('anon_uid_123'));
      expect(tester.sessionCount, equals(0));
      expect(tester.totalUsageSeconds, equals(0));
      expect(tester.activeDaysCount, equals(0));
      expect(tester.recentActiveDates, isEmpty);

      // Verify Firestore document directly
      final docSnap = await fakeFirestore
          .collection(TrackerConstants.collectionTesters)
          .doc('T001')
          .get();

      expect(docSnap.exists, isTrue);
      final data = docSnap.data()!;
      expect(data['testerId'], equals('T001'));
      expect(data['authUid'], equals('anon_uid_123'));
      expect(data['platform'], equals('android'));
      expect(data['deviceModel'], equals('Pixel 7'));
    });

    test(
        'syncTesterProfile updates mutable metadata without resetting counters or firstSeen',
        () async {
      // 1. Initial creation
      final initial = await repository.syncTesterProfile(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: envInfo,
      );
      final initialFirstSeen = initial!.firstSeen;

      // Simulate some existing session count in Firestore
      await fakeFirestore
          .collection(TrackerConstants.collectionTesters)
          .doc('T001')
          .update({
        'sessionCount': 5,
        'totalUsageSeconds': 1500,
        'activeDaysCount': 2,
        'recentActiveDates': ['2026-10-06', '2026-10-07'],
      });

      // 2. Second sync with updated app version & device
      const updatedEnvInfo = AppEnvironmentInfo(
        platform: 'android',
        deviceModel: 'Pixel 7 Pro',
        osVersion: 'Android 15',
        appVersion: '1.1.0 (2)',
      );

      final updated = await repository.syncTesterProfile(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: updatedEnvInfo,
      );

      expect(updated, isNotNull);
      expect(updated!.deviceModel, equals('Pixel 7 Pro'));
      expect(updated.appVersion, equals('1.1.0 (2)'));
      expect(updated.sessionCount, equals(5));
      expect(updated.totalUsageSeconds, equals(1500));
      expect(updated.activeDaysCount, equals(2));

      // Verify Firestore state
      final docSnap = await fakeFirestore
          .collection(TrackerConstants.collectionTesters)
          .doc('T001')
          .get();

      final data = docSnap.data()!;
      expect(data['appVersion'], equals('1.1.0 (2)'));
      expect(data['deviceModel'], equals('Pixel 7 Pro'));
      expect(data['firstSeen'], equals(initialFirstSeen.toIso8601String()));
      expect(data['sessionCount'], equals(5));
    });

    test('getTesterProfile retrieves existing profile or returns null',
        () async {
      expect(await repository.getTesterProfile('non_existent'), isNull);

      await repository.syncTesterProfile(
        testerId: 'T002',
        authUid: 'anon_uid_456',
        envInfo: envInfo,
      );

      final retrieved = await repository.getTesterProfile('T002');
      expect(retrieved, isNotNull);
      expect(retrieved!.testerId, equals('T002'));
    });

    test('createSession, updateSessionProgress, and finalizeSession lifecycle',
        () async {
      final started = DateTime.utc(2026, 10, 8, 10, 0, 0);
      final ended = DateTime.utc(2026, 10, 8, 10, 10, 0);

      // Create initial tester document first
      await repository.syncTesterProfile(
        testerId: 'T001',
        authUid: 'anon_uid_123',
        envInfo: envInfo,
      );

      final session = SessionData(
        sessionId: 'sess_T001_123',
        testerId: 'T001',
        authUid: 'anon_uid_123',
        startedAt: started,
        endedAt: null,
        durationSeconds: 0,
        activeDate: '2026-10-08',
        appVersion: '1.0.0 (1)',
        platform: 'android',
        isFinalized: false,
      );

      // 1. Create session
      final created = await repository.createSession(session);
      expect(created, isTrue);

      final fetched = await repository.getSession('T001', 'sess_T001_123');
      expect(fetched, isNotNull);
      expect(fetched!.isFinalized, isFalse);
      expect(fetched.durationSeconds, equals(0));

      // 2. Update progress
      final updated = await repository.updateSessionProgress(
        testerId: 'T001',
        sessionId: 'sess_T001_123',
        durationSeconds: 300,
      );
      expect(updated, isTrue);

      final progressDoc = await repository.getSession('T001', 'sess_T001_123');
      expect(progressDoc!.durationSeconds, equals(300));

      // 3. Finalize session atomically
      final finalized = await repository.finalizeSession(
        testerId: 'T001',
        sessionId: 'sess_T001_123',
        endedAt: ended,
        durationSeconds: 600,
        activeDate: '2026-10-08',
      );
      expect(finalized, isTrue);

      final finalizedDoc = await repository.getSession('T001', 'sess_T001_123');
      expect(finalizedDoc!.isFinalized, isTrue);
      expect(finalizedDoc.durationSeconds, equals(600));
      expect(finalizedDoc.endedAt, equals(ended));

      // 4. Verify tester aggregates updated atomically
      final testerDoc = await repository.getTesterProfile('T001');
      expect(testerDoc, isNotNull);
      expect(testerDoc!.sessionCount, equals(1));
      expect(testerDoc.totalUsageSeconds, equals(600));
      expect(testerDoc.recentActiveDates, contains('2026-10-08'));

      // 5. Idempotent retry: finalizeSession called again must NOT double-count aggregates
      final retryFinalized = await repository.finalizeSession(
        testerId: 'T001',
        sessionId: 'sess_T001_123',
        endedAt: ended,
        durationSeconds: 600,
        activeDate: '2026-10-08',
      );
      expect(retryFinalized, isTrue);

      final recheckedTesterDoc = await repository.getTesterProfile('T001');
      expect(recheckedTesterDoc!.sessionCount, equals(1)); // Still 1, NOT 2!
      expect(recheckedTesterDoc.totalUsageSeconds,
          equals(600)); // Still 600, NOT 1200!
    });

    test(
        'concurrent finalizeSession calls produce exactly one aggregate update',
        () async {
      final started = DateTime.utc(2026, 10, 8, 11, 0, 0);
      final ended = DateTime.utc(2026, 10, 8, 11, 15, 0);

      await repository.syncTesterProfile(
        testerId: 'T003',
        authUid: 'anon_uid_789',
        envInfo: envInfo,
      );

      final session = SessionData(
        sessionId: 'sess_T003_999',
        testerId: 'T003',
        authUid: 'anon_uid_789',
        startedAt: started,
        endedAt: null,
        durationSeconds: 0,
        activeDate: '2026-10-08',
        appVersion: '1.0.0 (1)',
        platform: 'android',
        isFinalized: false,
      );

      await repository.createSession(session);

      // Fire 3 simultaneous concurrent finalizeSession calls
      final results = await Future.wait([
        repository.finalizeSession(
          testerId: 'T003',
          sessionId: 'sess_T003_999',
          endedAt: ended,
          durationSeconds: 900,
          activeDate: '2026-10-08',
        ),
        repository.finalizeSession(
          testerId: 'T003',
          sessionId: 'sess_T003_999',
          endedAt: ended,
          durationSeconds: 900,
          activeDate: '2026-10-08',
        ),
        repository.finalizeSession(
          testerId: 'T003',
          sessionId: 'sess_T003_999',
          endedAt: ended,
          durationSeconds: 900,
          activeDate: '2026-10-08',
        ),
      ]);

      expect(results.every((r) => r == true), isTrue);

      // Verify that aggregate counts were incremented exactly ONCE
      final testerDoc = await repository.getTesterProfile('T003');
      expect(testerDoc, isNotNull);
      expect(testerDoc!.sessionCount, equals(1)); // Exactly 1, not 3
      expect(testerDoc.totalUsageSeconds, equals(900)); // Exactly 900, not 2700
    });
  });
}
