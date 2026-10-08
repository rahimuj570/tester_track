import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/models/remote_config_data.dart';
import 'package:tester_track/src/models/session_data.dart';
import 'package:tester_track/src/models/tester_data.dart';

void main() {
  group('RemoteConfigData Model', () {
    test('defaultConfig allows tracking with default bounds', () {
      const config = RemoteConfigData.defaultConfig;
      expect(config.enabled, isTrue);
      expect(config.expiresAt, isNull);
      expect(config.minAppVersion, isNull);
      expect(config.syncIntervalSeconds, isNull);
      expect(config.isTrackingPermitted(), isTrue);
    });

    test('isTrackingPermitted respects enabled flag', () {
      const config = RemoteConfigData(enabled: false);
      expect(config.isTrackingPermitted(), isFalse);
    });

    test('isTrackingPermitted respects expiresAt in the past vs future', () {
      final now = DateTime.utc(2026, 10, 8, 12, 0, 0);
      final past = now.subtract(const Duration(hours: 1));
      final future = now.add(const Duration(hours: 1));

      final expiredConfig = RemoteConfigData(enabled: true, expiresAt: past);
      expect(expiredConfig.isTrackingPermitted(now: now), isFalse);

      final exactExpiryConfig = RemoteConfigData(enabled: true, expiresAt: now);
      expect(exactExpiryConfig.isTrackingPermitted(now: now), isFalse);

      final activeConfig = RemoteConfigData(enabled: true, expiresAt: future);
      expect(activeConfig.isTrackingPermitted(now: now), isTrue);
    });

    test('isTrackingPermitted evaluates minimum app version correctly', () {
      const config = RemoteConfigData(
        enabled: true,
        minAppVersion: '1.5.0',
      );

      // Older version -> disabled
      expect(
        config.isTrackingPermitted(installedAppVersion: '1.4.0'),
        isFalse,
      );
      expect(
        config.isTrackingPermitted(installedAppVersion: '1.4.9 (10)'),
        isFalse,
      );
      expect(
        config.isTrackingPermitted(installedAppVersion: '0.9.0'),
        isFalse,
      );

      // Exact match -> enabled
      expect(
        config.isTrackingPermitted(installedAppVersion: '1.5.0'),
        isTrue,
      );
      expect(
        config.isTrackingPermitted(installedAppVersion: '1.5.0+10'),
        isTrue,
      );

      // Newer version -> enabled
      expect(
        config.isTrackingPermitted(installedAppVersion: '1.5.1'),
        isTrue,
      );
      expect(
        config.isTrackingPermitted(installedAppVersion: '2.0.0'),
        isTrue,
      );
    });

    test('isAppVersionSupported safely handles malformed version strings', () {
      // If either version is invalid / unparseable, does not disable tracking
      expect(
        RemoteConfigData.isAppVersionSupported(
          installedVersion: 'not_a_version',
          minAppVersion: '1.5.0',
        ),
        isTrue,
      );

      expect(
        RemoteConfigData.isAppVersionSupported(
          installedVersion: '1.5.0',
          minAppVersion: 'malformed_min_version',
        ),
        isTrue,
      );
    });

    test('Precedence: enabled=false takes precedence over minVersion & expiry',
        () {
      final config = RemoteConfigData(
        enabled: false,
        expiresAt: DateTime.utc(2030, 1, 1),
        minAppVersion: '1.0.0',
      );
      expect(
        config.isTrackingPermitted(
          now: DateTime.utc(2026, 1, 1),
          installedAppVersion: '2.0.0',
        ),
        isFalse,
      );
    });

    test('fromMap validates and clamps syncIntervalSeconds to 60..3600', () {
      // Valid interval within bounds
      final valid =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 600});
      expect(valid.syncIntervalSeconds, equals(600));

      final minValid =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 60});
      expect(minValid.syncIntervalSeconds, equals(60));

      final maxValid =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 3600});
      expect(maxValid.syncIntervalSeconds, equals(3600));

      // Below lower bound (< 60) -> ignored (null)
      final tooSmall =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 30});
      expect(tooSmall.syncIntervalSeconds, isNull);

      final negative =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': -500});
      expect(negative.syncIntervalSeconds, isNull);

      // Above upper bound (> 3600) -> ignored (null)
      final tooLarge =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 7200});
      expect(tooLarge.syncIntervalSeconds, isNull);

      // Malformed string type -> ignored (null)
      final stringVal =
          RemoteConfigData.fromMap(const {'syncIntervalSeconds': 'hello'});
      expect(stringVal.syncIntervalSeconds, isNull);
    });

    test('fromMap safely handles missing or malformed fields without throwing',
        () {
      const malformedMap = {
        'enabled': 'not_a_boolean',
        'expiresAt': 12345678,
        'minAppVersion': 42,
        'syncIntervalSeconds': [100],
      };

      final config = RemoteConfigData.fromMap(malformedMap);
      expect(config.enabled, isTrue); // Default true
      expect(config.expiresAt, isNull);
      expect(config.minAppVersion, isNull);
      expect(config.syncIntervalSeconds, isNull);
    });

    test('serialization and deserialization roundtrip (JSON & Map)', () {
      final expiry = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final original = RemoteConfigData(
        enabled: true,
        expiresAt: expiry,
        minAppVersion: '1.2.0',
        syncIntervalSeconds: 300,
        updatedAt: DateTime.utc(2026, 10, 8, 10, 0, 0),
      );

      final jsonStr = original.toJson();
      final restored = RemoteConfigData.fromJson(jsonStr);

      expect(restored.enabled, equals(original.enabled));
      expect(restored.expiresAt, equals(original.expiresAt));
      expect(restored.minAppVersion, equals('1.2.0'));
      expect(restored.syncIntervalSeconds, equals(300));
      expect(restored.updatedAt, equals(original.updatedAt));
      expect(restored, equals(original));
    });
  });

  group('TesterData Model', () {
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

  group('SessionData Model', () {
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
