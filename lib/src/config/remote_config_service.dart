import 'dart:async';
import '../core/constants.dart';
import '../core/error_handler.dart';
import '../identity/device_info_helper.dart';
import '../models/remote_config_data.dart';
import '../storage/firestore_repository.dart';
import '../storage/local_storage.dart';

/// Service responsible for fetching, caching, validating, and periodically refreshing
/// remote configuration (`config/global`) from the developer's Firebase project.
class RemoteConfigService {
  /// Default interval for refreshing remote configuration (5 minutes).
  static const Duration defaultRefreshInterval = Duration(minutes: 5);

  final LocalStorage localStorage;
  final FirestoreRepository firestoreRepository;
  final TrackerErrorHandler errorHandler;
  final AppEnvironmentInfo envInfo;

  RemoteConfigData _activeConfig = RemoteConfigData.defaultConfig;
  RemoteConfigData? _cachedConfig;
  DateTime? _lastFetchTime;
  Timer? _periodicRefreshTimer;

  RemoteConfigService({
    required this.localStorage,
    required this.firestoreRepository,
    required this.errorHandler,
    required this.envInfo,
  });

  /// The currently active in-memory configuration.
  RemoteConfigData get activeConfig => _activeConfig;

  /// The cached configuration loaded from local storage (if any).
  RemoteConfigData? get cachedConfig => _cachedConfig;

  /// Timestamp of the last successful or attempted remote fetch.
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Initializes the service by loading locally cached configuration from storage.
  Future<void> init() async {
    await errorHandler.runGuarded<void>(() async {
      final raw = localStorage.getString(TrackerConstants.prefsCachedConfigKey);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          _cachedConfig = RemoteConfigData.fromJson(raw);
          _activeConfig = _cachedConfig!;
          errorHandler.log(
              'Loaded cached remote configuration: ${_activeConfig.toMap()}');
        } catch (e) {
          errorHandler.log('Failed to parse cached remote config: $e');
          _activeConfig = RemoteConfigData.defaultConfig;
        }
      } else {
        _activeConfig = RemoteConfigData.defaultConfig;
      }
    }, operationName: 'RemoteConfigService.init');
  }

  /// Evaluates whether tracking is currently allowed based on the active config,
  /// current device time (for expiration), and installed app version.
  bool isTrackingPermitted({DateTime? now}) {
    return _activeConfig.isTrackingPermitted(
      now: now ?? DateTime.now().toUtc(),
      installedAppVersion: envInfo.appVersion,
    );
  }

  /// Calculates the effective Firestore session sync interval.
  ///
  /// Returns the valid remote override if present (bounded to 60..3600s),
  /// otherwise falls back to [defaultInterval].
  Duration getEffectiveSyncInterval(Duration defaultInterval) {
    if (_activeConfig.syncIntervalSeconds != null) {
      return Duration(seconds: _activeConfig.syncIntervalSeconds!);
    }
    return defaultInterval;
  }

  /// Fetches remote configuration from Firestore, updates the local cache,
  /// and applies the newly fetched configuration.
  ///
  /// If the fetch fails (offline, missing doc, permissions), falls back to
  /// the cached configuration if available, or default configuration.
  Future<RemoteConfigData> fetchAndApplyConfig() async {
    return await errorHandler.runGuarded<RemoteConfigData>(() async {
          _lastFetchTime = DateTime.now().toUtc();
          errorHandler
              .log('Fetching remote configuration from config/global...');

          final fetched = await firestoreRepository.fetchRemoteConfig(
            fallback: _cachedConfig,
          );

          if (fetched != null) {
            _activeConfig = fetched;
            _cachedConfig = fetched;

            // Persist to local cache
            await localStorage.setString(
              TrackerConstants.prefsCachedConfigKey,
              fetched.toJson(),
            );

            errorHandler.log(
                'Applied and cached remote configuration: ${fetched.toMap()}');
            return _activeConfig;
          } else {
            // Fetch failed or document not found
            if (_cachedConfig != null) {
              errorHandler.log(
                'Remote config fetch returned null. Using last known cached config.',
              );
              _activeConfig = _cachedConfig!;
            } else {
              errorHandler.log(
                'Remote config fetch returned null and no cache found. Using default config.',
              );
              _activeConfig = RemoteConfigData.defaultConfig;
            }
            return _activeConfig;
          }
        },
            operationName: 'RemoteConfigService.fetchAndApplyConfig',
            fallbackValue: _activeConfig) ??
        _activeConfig;
  }

  /// Starts a periodic background timer to refresh configuration every 5 minutes.
  void startPeriodicRefresh(
    void Function(RemoteConfigData newConfig, bool isPermitted)
        onConfigChanged, {
    Duration refreshInterval = defaultRefreshInterval,
  }) {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(refreshInterval, (_) async {
      if (errorHandler.isCircuitBroken) {
        dispose();
        return;
      }
      await errorHandler.runGuarded<void>(() async {
        final previousConfig = _activeConfig;
        final previousPermitted = isTrackingPermitted();

        final newConfig = await fetchAndApplyConfig();
        final newPermitted = isTrackingPermitted();

        if (newConfig != previousConfig || newPermitted != previousPermitted) {
          errorHandler.log(
            'Remote configuration changed during periodic refresh: '
            'permitted=$newPermitted (was $previousPermitted), config=${newConfig.toMap()}',
          );
          onConfigChanged(newConfig, newPermitted);
        }
      }, operationName: 'RemoteConfigService.periodicRefresh');
    });
  }

  /// Throttled refresh check when application resumes from background.
  ///
  /// Only performs a network fetch if at least 5 minutes have elapsed since the last fetch.
  Future<void> refreshOnResumeThrottled(
    void Function(RemoteConfigData newConfig, bool isPermitted)
        onConfigChanged, {
    Duration throttleDuration = defaultRefreshInterval,
  }) async {
    await errorHandler.runGuarded<void>(() async {
      if (errorHandler.isCircuitBroken) return;

      final now = DateTime.now().toUtc();
      if (_lastFetchTime != null &&
          now.difference(_lastFetchTime!) < throttleDuration) {
        errorHandler.log(
          'Skipping config refresh on resume: fetched recently (${now.difference(_lastFetchTime!).inSeconds}s ago).',
        );
        return;
      }

      final previousConfig = _activeConfig;
      final previousPermitted = isTrackingPermitted();

      final newConfig = await fetchAndApplyConfig();
      final newPermitted = isTrackingPermitted();

      if (newConfig != previousConfig || newPermitted != previousPermitted) {
        errorHandler.log(
          'Remote configuration changed on app resume: '
          'permitted=$newPermitted (was $previousPermitted), config=${newConfig.toMap()}',
        );
        onConfigChanged(newConfig, newPermitted);
      }
    }, operationName: 'RemoteConfigService.refreshOnResumeThrottled');
  }

  /// Disposes background timers and resources.
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }
}
