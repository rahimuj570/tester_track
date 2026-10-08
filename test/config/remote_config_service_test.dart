import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/config/remote_config_service.dart';
import 'package:tester_track/src/core/constants.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/identity/device_info_helper.dart';
import 'package:tester_track/src/models/remote_config_data.dart';
import 'package:tester_track/src/storage/firestore_repository.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;
  late FirestoreRepository firestoreRepository;
  late RemoteConfigService configService;

  const envInfo = AppEnvironmentInfo(
    platform: 'android',
    deviceModel: 'Pixel 7',
    osVersion: 'Android 14',
    appVersion: '1.5.0',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    errorHandler = TrackerErrorHandler(debugLogging: false);
    localStorage = LocalStorage(errorHandler: errorHandler);
    await localStorage.init();
    firestoreRepository = FirestoreRepository(
      firestore: fakeFirestore,
      errorHandler: errorHandler,
    );
    configService = RemoteConfigService(
      localStorage: localStorage,
      firestoreRepository: firestoreRepository,
      errorHandler: errorHandler,
      envInfo: envInfo,
    );
  });

  tearDown(() {
    configService.dispose();
  });

  group('RemoteConfigService', () {
    test('init loads default config when cache is empty', () async {
      await configService.init();
      expect(
          configService.activeConfig, equals(RemoteConfigData.defaultConfig));
      expect(configService.cachedConfig, isNull);
      expect(configService.isTrackingPermitted(), isTrue);
    });

    test('init loads cached config from local storage', () async {
      const cached = RemoteConfigData(
        enabled: false,
        syncIntervalSeconds: 600,
      );
      await localStorage.setString(
        TrackerConstants.prefsCachedConfigKey,
        cached.toJson(),
      );

      await configService.init();
      expect(configService.activeConfig.enabled, isFalse);
      expect(configService.activeConfig.syncIntervalSeconds, equals(600));
      expect(configService.cachedConfig, isNotNull);
      expect(configService.isTrackingPermitted(), isFalse);
    });

    test(
        'fetchAndApplyConfig fetches from Firestore, caches, and updates active config',
        () async {
      // Seed Firestore with config/global
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'enabled': true,
        'minAppVersion': '1.0.0',
        'syncIntervalSeconds': 300,
      });

      final result = await configService.fetchAndApplyConfig();

      expect(result.enabled, isTrue);
      expect(result.minAppVersion, equals('1.0.0'));
      expect(result.syncIntervalSeconds, equals(300));
      expect(configService.activeConfig, equals(result));

      // Check persisted cache
      final cachedJson =
          localStorage.getString(TrackerConstants.prefsCachedConfigKey);
      expect(cachedJson, isNotNull);
      final cachedObj = RemoteConfigData.fromJson(cachedJson!);
      expect(cachedObj.syncIntervalSeconds, equals(300));
    });

    test(
        'fetchAndApplyConfig falls back to cached config when remote fetch returns null',
        () async {
      // 1. Setup local cache
      const cached = RemoteConfigData(
        enabled: false,
        syncIntervalSeconds: 450,
      );
      await localStorage.setString(
        TrackerConstants.prefsCachedConfigKey,
        cached.toJson(),
      );
      await configService.init();

      // 2. Firestore is empty (fetch returns null)
      final applied = await configService.fetchAndApplyConfig();

      // Must remain disabled according to cache
      expect(applied.enabled, isFalse);
      expect(applied.syncIntervalSeconds, equals(450));
      expect(configService.isTrackingPermitted(), isFalse);
    });

    test(
        'fetchAndApplyConfig falls back to default config when remote fetch fails and no cache exists',
        () async {
      // No cache, Firestore empty
      final applied = await configService.fetchAndApplyConfig();
      expect(applied.enabled, isTrue);
      expect(configService.isTrackingPermitted(), isTrue);
    });

    test(
        'cached config with past expiresAt is evaluated as expired using current device clock',
        () async {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final cached = RemoteConfigData(
        enabled: true,
        expiresAt: past,
      );
      await localStorage.setString(
        TrackerConstants.prefsCachedConfigKey,
        cached.toJson(),
      );

      await configService.init();

      // Despite enabled=true, expiresAt is in the past -> tracking is disabled
      expect(configService.isTrackingPermitted(), isFalse);
    });

    test(
        'getEffectiveSyncInterval respects remote override within 60..3600s or falls back to local default',
        () async {
      const defaultDuration = Duration(minutes: 5);

      // Default (no remote override)
      expect(
        configService.getEffectiveSyncInterval(defaultDuration),
        equals(defaultDuration),
      );

      // Set valid remote override (600s)
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'enabled': true,
        'syncIntervalSeconds': 600,
      });

      await configService.fetchAndApplyConfig();
      expect(
        configService.getEffectiveSyncInterval(defaultDuration),
        equals(const Duration(seconds: 600)),
      );
    });

    test('no cached config + missing enabled defaults to enabled=true',
        () async {
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'minAppVersion': '1.0.0',
      });

      final result = await configService.fetchAndApplyConfig();
      expect(result.enabled, isTrue);
      expect(configService.isTrackingPermitted(), isTrue);
    });

    test(
        'valid cached config (enabled=false) + malformed remote enabled retains enabled=false',
        () async {
      // 1. Initial cached config is disabled
      const cached = RemoteConfigData(
        enabled: false,
        syncIntervalSeconds: 300,
      );
      await localStorage.setString(
        TrackerConstants.prefsCachedConfigKey,
        cached.toJson(),
      );
      await configService.init();
      expect(configService.activeConfig.enabled, isFalse);

      // 2. Remote Firestore has malformed enabled field (e.g. string instead of bool)
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'enabled': 'invalid_string_value',
      });

      final result = await configService.fetchAndApplyConfig();
      // Crucial: Must retain enabled=false from fallback, NOT accidentally become true!
      expect(result.enabled, isFalse);
      expect(configService.isTrackingPermitted(), isFalse);
    });

    test(
        'valid cached config (enabled=false) + missing remote enabled retains enabled=false',
        () async {
      const cached = RemoteConfigData(
        enabled: false,
      );
      await localStorage.setString(
        TrackerConstants.prefsCachedConfigKey,
        cached.toJson(),
      );
      await configService.init();

      // Remote Firestore doc is present but missing the 'enabled' key
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'syncIntervalSeconds': 600,
      });

      final result = await configService.fetchAndApplyConfig();
      expect(result.enabled, isFalse);
      expect(configService.isTrackingPermitted(), isFalse);
    });

    test('no cached config + malformed enabled defaults to enabled=true',
        () async {
      await fakeFirestore
          .collection(TrackerConstants.collectionConfig)
          .doc(TrackerConstants.documentGlobal)
          .set({
        'enabled': 'not_a_bool',
      });

      final result = await configService.fetchAndApplyConfig();
      expect(result.enabled, isTrue);
      expect(configService.isTrackingPermitted(), isTrue);
    });
  });
}
