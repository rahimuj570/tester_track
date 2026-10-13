import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/error_handler.dart';

/// Lightweight data holder for non-invasive device & app environment metadata.
@immutable
class AppEnvironmentInfo {
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String appVersion;

  const AppEnvironmentInfo({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
  });

  static const AppEnvironmentInfo fallback = AppEnvironmentInfo(
    platform: 'unknown',
    deviceModel: 'unknown',
    osVersion: 'unknown',
    appVersion: 'unknown',
  );
}

/// Helper to safely retrieve non-invasive platform, device, and package metadata.
class DeviceInfoHelper {
  final TrackerErrorHandler errorHandler;
  final DeviceInfoPlugin _deviceInfo;

  DeviceInfoHelper({
    required this.errorHandler,
    DeviceInfoPlugin? deviceInfo,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// Retrieves non-invasive device and application metadata safely.
  Future<AppEnvironmentInfo> getEnvironmentInfo() async {
    return await errorHandler.runGuarded<AppEnvironmentInfo>(() async {
          String platform = 'unknown';
          String deviceModel = 'unknown';
          String osVersion = 'unknown';
          String appVersion = 'unknown';

          // 1. App version info
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            final version = packageInfo.version.trim();
            final build = packageInfo.buildNumber.trim();
            appVersion = build.isNotEmpty ? '$version ($build)' : version;
            if (appVersion.isEmpty) appVersion = 'unknown';
          } catch (e) {
            errorHandler.log('PackageInfo error: $e');
          }

          // 2. Platform & OS / Device info
          try {
            if (kIsWeb) {
              platform = 'web';
              final webInfo = await _deviceInfo.webBrowserInfo;
              deviceModel = webInfo.browserName.name.isNotEmpty
                  ? webInfo.browserName.name
                  : 'Web Browser';
              osVersion = webInfo.userAgent ?? 'web';
            } else if (Platform.isAndroid) {
              platform = 'android';
              final androidInfo = await _deviceInfo.androidInfo;
              final manufacturer = androidInfo.manufacturer.trim();
              final model = androidInfo.model.trim();
              if (manufacturer.isNotEmpty && model.isNotEmpty) {
                deviceModel = model.toLowerCase().startsWith(manufacturer.toLowerCase())
                    ? model
                    : '$manufacturer $model';
              } else if (model.isNotEmpty) {
                deviceModel = model;
              } else if (manufacturer.isNotEmpty) {
                deviceModel = manufacturer;
              } else {
                deviceModel = 'Android Device';
              }
              osVersion =
                  'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
            } else if (Platform.isIOS) {
              platform = 'ios';
              final iosInfo = await _deviceInfo.iosInfo;
              final model = iosInfo.utsname.machine.trim();
              final name = iosInfo.name.trim();
              deviceModel = model.isNotEmpty
                  ? model
                  : (name.isNotEmpty ? name : 'iOS Device');
              osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
            } else if (Platform.isMacOS) {
              platform = 'macos';
              final macInfo = await _deviceInfo.macOsInfo;
              deviceModel = macInfo.model.trim().isNotEmpty
                  ? macInfo.model.trim()
                  : 'Mac';
              osVersion =
                  '${macInfo.osRelease} (macOS ${macInfo.majorVersion}.${macInfo.minorVersion})';
            } else if (Platform.isWindows) {
              platform = 'windows';
              final winInfo = await _deviceInfo.windowsInfo;
              deviceModel = winInfo.productName.trim().isNotEmpty
                  ? winInfo.productName.trim()
                  : 'Windows PC';
              osVersion =
                  'Windows ${winInfo.majorVersion}.${winInfo.minorVersion} (Build ${winInfo.buildNumber})';
            } else if (Platform.isLinux) {
              platform = 'linux';
              final linuxInfo = await _deviceInfo.linuxInfo;
              deviceModel = linuxInfo.prettyName.trim().isNotEmpty
                  ? linuxInfo.prettyName.trim()
                  : 'Linux Device';
              osVersion = linuxInfo.versionId ?? 'linux';
            }
          } catch (e) {
            errorHandler.log('DeviceInfo error: $e');
          }

          return AppEnvironmentInfo(
            platform: platform,
            deviceModel: deviceModel,
            osVersion: osVersion,
            appVersion: appVersion,
          );
        },
            operationName: 'DeviceInfoHelper.getEnvironmentInfo',
            fallbackValue: AppEnvironmentInfo.fallback) ??
        AppEnvironmentInfo.fallback;
  }
}
