import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/models/remote_config_data.dart';
import 'package:tester_track/src/models/session_data.dart';
import 'package:tester_track/src/models/tester_data.dart';

void main() {
  group('RemoteConfigData', () {
    test('defaultConfig allows tracking', () {
      const config = RemoteConfigData.defaultConfig;
      expect(config.enabled, isTrue);
      expect(config.expiresAt, isNull);
      expect(config.isTrackingPermitted(), isTrue);
    });

    test('isTrackingPermitted respects enabled flag', () {
      const config = RemoteConfigData(enabled: false);
      expect(config.isTrackingPermitted(), isFalse);
    });

    test('isTrackingPermitted respects expiresAt in the past vs future', () {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final future = DateTime.now().toUtc().add(const Duration(hours: 1));

      final expiredConfig = RemoteConfigData(enabled: true, expiresAt: past);
      expect(expiredConfig.isTrackingPermitted(), isFalse);

      final activeConfig = RemoteConfigData(enabled: true, expiresAt: future);
      expect(activeConfig.isTrackingPermitted(), isTrue);
    });

    test('serialization and deserialization roundtrip', () {
      final expiry = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final original = RemoteConfigData(
        enabled: true,
        expiresAt: expiry,
        minAppVersion: '1.2.0',
        syncIntervalSeconds: 300,
      );

      final map = original.toMap();
      final restored = RemoteConfigData.fromMap(map);

      expect(restored.enabled, equals(original.enabled));
      expect(restored.expiresAt, equals(original.expiresAt));
      expect(restored.minAppVersion, equals('1.2.0'));
      expect(restored.syncIntervalSeconds, equals(300));
      expect(restored, equals(original));
    });
  });

  group('TesterData', () {
    test('serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 10, 7, 12, 0, 0);
      final data = TesterData(
        testerId: 'T001',
        authUid: 'uid_123',
        platform: 'android',
        deviceModel: 'Pixel 7 Pro',
        osVersion: 'Android 14',
        appVersion: '1.0.0 (1)',
        firstSeen: now,
        lastSeen: now,
        sessionCount: 5,
        totalUsageSeconds: 1200,
        activeDaysCount: 3,
        recentActiveDates: const ['2026-10-05', '2026-10-06', '2026-10-07'],
      );

      final map = data.toMap();
      final restored = TesterData.fromMap(map);

      expect(restored.testerId, equals('T001'));
      expect(restored.authUid, equals('uid_123'));
      expect(restored.sessionCount, equals(5));
      expect(restored.activeDaysCount, equals(3));
      expect(restored.recentActiveDates,
          equals(['2026-10-05', '2026-10-06', '2026-10-07']));
    });
  });

  group('SessionData', () {
    test('serialization and deserialization roundtrip', () {
      final started = DateTime.utc(2026, 10, 7, 12, 0, 0);
      final ended = DateTime.utc(2026, 10, 7, 12, 10, 0);
      final session = SessionData(
        sessionId: 'sess_T001_12345',
        testerId: 'T001',
        authUid: 'uid_123',
        startedAt: started,
        endedAt: ended,
        durationSeconds: 600,
        activeDate: '2026-10-07',
        appVersion: '1.0.0 (1)',
        platform: 'android',
        isFinalized: true,
      );

      final map = session.toMap();
      final restored = SessionData.fromMap(map);

      expect(restored.sessionId, equals('sess_T001_12345'));
      expect(restored.durationSeconds, equals(600));
      expect(restored.isFinalized, isTrue);
      expect(restored.endedAt, equals(ended));
    });
  });
}
