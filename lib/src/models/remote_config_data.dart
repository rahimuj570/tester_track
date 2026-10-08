import 'package:flutter/foundation.dart';

/// Representation of the remote tracking configuration document from `config/global`.
@immutable
class RemoteConfigData {
  /// Whether tracking is enabled globally.
  final bool enabled;

  /// Optional expiration timestamp after which tracking is automatically disabled.
  final DateTime? expiresAt;

  /// Optional minimum required host app version string.
  final String? minAppVersion;

  /// Configurable sync interval in seconds.
  final int? syncIntervalSeconds;

  const RemoteConfigData({
    this.enabled = true,
    this.expiresAt,
    this.minAppVersion,
    this.syncIntervalSeconds,
  });

  /// Default configuration when remote document is unavailable or offline.
  static const RemoteConfigData defaultConfig = RemoteConfigData(
    enabled: true,
    expiresAt: null,
    minAppVersion: null,
    syncIntervalSeconds: null,
  );

  /// Evaluates whether tracking is permitted right now based on [enabled] and [expiresAt].
  bool isTrackingPermitted({DateTime? now}) {
    if (!enabled) return false;
    final current = now ?? DateTime.now().toUtc();
    if (expiresAt != null && current.isAfter(expiresAt!)) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'minAppVersion': minAppVersion,
      'syncIntervalSeconds': syncIntervalSeconds,
    };
  }

  factory RemoteConfigData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return RemoteConfigData.defaultConfig;

    DateTime? parsedExpiry;
    final dynamic rawExpiresAt = map['expiresAt'];
    if (rawExpiresAt is String) {
      parsedExpiry = DateTime.tryParse(rawExpiresAt)?.toUtc();
    } else if (rawExpiresAt != null) {
      // Handles Firestore Timestamp if present without hard dependency
      try {
        parsedExpiry = (rawExpiresAt.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    return RemoteConfigData(
      enabled: map['enabled'] as bool? ?? true,
      expiresAt: parsedExpiry,
      minAppVersion: map['minAppVersion'] as String?,
      syncIntervalSeconds: (map['syncIntervalSeconds'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteConfigData &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          expiresAt == other.expiresAt &&
          minAppVersion == other.minAppVersion &&
          syncIntervalSeconds == other.syncIntervalSeconds;

  @override
  int get hashCode =>
      enabled.hashCode ^
      expiresAt.hashCode ^
      minAppVersion.hashCode ^
      syncIntervalSeconds.hashCode;
}
