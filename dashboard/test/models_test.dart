import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track_dashboard/models/remote_config_form_model.dart';
import 'package:tester_track_dashboard/models/session_view_model.dart';
import 'package:tester_track_dashboard/models/tester_view_model.dart';

void main() {
  group('Dashboard ViewModels Tests', () {
    test('TesterViewModel formattedUsageTime and isActiveWithin logic', () {
      final now = DateTime.now().toUtc();

      final testerActive = TesterViewModel(
        testerId: 'T001',
        authUid: 'uid_1',
        platform: 'android',
        deviceModel: 'Pixel 7',
        osVersion: 'Android 14',
        appVersion: '1.0.0',
        firstSeen: now.subtract(const Duration(days: 20)),
        lastSeen: now.subtract(const Duration(days: 2)),
        sessionCount: 15,
        totalUsageSeconds: 3750, // 1h 2m 30s
        activeDaysCount: 8,
        recentActiveDates: const ['2026-10-01', '2026-10-08'],
      );

      expect(testerActive.formattedUsageTime, equals('1h 2m'));
      expect(testerActive.isActiveWithin(14), isTrue);
      expect(testerActive.isActiveWithin(1), isFalse);

      final testerToday = testerActive.copyWith(
        isUsedToday: true,
        todayUsageSeconds: 735, // 12m 15s
        todaySessionsCount: 2,
      );
      expect(testerToday.isUsedToday, isTrue);
      expect(testerToday.todayUsageSeconds, equals(735));
      expect(testerToday.todaySessionsCount, equals(2));
      expect(testerToday.formattedTodayUsageTime, equals('12m 15s'));

      final testerShort = TesterViewModel(
        testerId: 'T002',
        authUid: 'uid_2',
        platform: 'ios',
        deviceModel: 'iPhone 15',
        osVersion: 'iOS 17',
        appVersion: '1.0.0',
        firstSeen: now.subtract(const Duration(days: 30)),
        lastSeen: now.subtract(const Duration(days: 25)),
        sessionCount: 1,
        totalUsageSeconds: 45,
        activeDaysCount: 1,
        recentActiveDates: const ['2026-09-15'],
      );

      expect(testerShort.formattedUsageTime, equals('45s'));
      expect(testerShort.formattedTodayUsageTime, equals('0s'));
      expect(testerShort.isUsedToday, isFalse);
      expect(testerShort.isActiveWithin(14), isFalse);
    });

    test('SessionViewModel formattedDuration and parsing', () {
      final now = DateTime.now().toUtc();

      final session = SessionViewModel(
        sessionId: 'sess_123',
        testerId: 'T001',
        authUid: 'uid_1',
        startedAt: now.subtract(const Duration(minutes: 10)),
        endedAt: now,
        durationSeconds: 600,
        activeDate: '2026-10-10',
        appVersion: '1.0.0',
        platform: 'android',
        isFinalized: true,
      );

      expect(session.formattedDuration, equals('10m'));

      final parsed = SessionViewModel.fromMap('sess_456', {
        'sessionId': 'sess_456',
        'testerId': 'T002',
        'authUid': 'uid_2',
        'startedAt': now.toIso8601String(),
        'durationSeconds': 125,
        'activeDate': '2026-10-10',
        'appVersion': '1.0.0',
        'platform': 'ios',
        'isFinalized': false,
      });

      expect(parsed.sessionId, equals('sess_456'));
      expect(parsed.durationSeconds, equals(125));
      expect(parsed.formattedDuration, equals('2m 5s'));
      expect(parsed.isFinalized, isFalse);
    });

    test('RemoteConfigFormModel serialization and copyWith', () {
      const model = RemoteConfigFormModel(
        enabled: true,
        minAppVersion: '1.5.0',
        syncIntervalSeconds: 600,
      );

      final firestoreMap = model.toFirestoreMap();
      expect(firestoreMap['enabled'], isTrue);
      expect(firestoreMap['minAppVersion'], equals('1.5.0'));
      expect(firestoreMap['syncIntervalSeconds'], equals(600));

      final updated = model.copyWith(
        enabled: false,
        clearMinAppVersion: true,
      );
      expect(updated.enabled, isFalse);
      expect(updated.minAppVersion, isNull);
      expect(updated.syncIntervalSeconds, equals(600));
    });
  });
}
