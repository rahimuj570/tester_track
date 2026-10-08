import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Representation of the remote tracking configuration document from `config/global`.
@immutable
class RemoteConfigData {
  /// Minimum allowed remote sync interval (60 seconds).
  static const int minSyncIntervalSeconds = 60;

  /// Maximum allowed remote sync interval (3600 seconds / 1 hour).
  static const int maxSyncIntervalSeconds = 3600;

  /// Whether tracking is enabled globally.
  final bool enabled;

  /// Optional expiration timestamp after which tracking is automatically disabled.
  final DateTime? expiresAt;

  /// Optional minimum required host app version string (e.g. "1.5.0").
  final String? minAppVersion;

  /// Optional remote override for the Firestore synchronization interval in seconds (60..3600).
  final int? syncIntervalSeconds;

  /// Server timestamp when configuration was last updated (informational).
  final DateTime? updatedAt;

  const RemoteConfigData({
    this.enabled = true,
    this.expiresAt,
    this.minAppVersion,
    this.syncIntervalSeconds,
    this.updatedAt,
  });

  /// Default configuration when remote document is unavailable or offline.
  static const RemoteConfigData defaultConfig = RemoteConfigData(
    enabled: true,
    expiresAt: null,
    minAppVersion: null,
    syncIntervalSeconds: null,
    updatedAt: null,
  );

  /// Evaluates whether tracking is permitted right now based on [enabled], [expiresAt],
  /// and [installedAppVersion].
  ///
  /// Precedence:
  /// 1. `enabled == false` -> DISABLED
  /// 2. `now >= expiresAt` -> DISABLED
  /// 3. `installedAppVersion < minAppVersion` -> DISABLED
  /// 4. Otherwise -> ENABLED
  bool isTrackingPermitted({
    DateTime? now,
    String? installedAppVersion,
  }) {
    // 1. Explicit remote kill-switch
    if (!enabled) return false;

    // 2. Expiration check (based on device clock)
    final current = now ?? DateTime.now().toUtc();
    if (expiresAt != null) {
      if (current.isAfter(expiresAt!) || current.isAtSameMomentAs(expiresAt!)) {
        return false;
      }
    }

    // 3. Minimum app version check
    if (minAppVersion != null &&
        minAppVersion!.trim().isNotEmpty &&
        installedAppVersion != null &&
        installedAppVersion.trim().isNotEmpty) {
      if (!isAppVersionSupported(
        installedVersion: installedAppVersion,
        minAppVersion: minAppVersion,
      )) {
        return false;
      }
    }

    return true;
  }

  /// Compares [installedVersion] against [minAppVersion].
  ///
  /// Supports semantic version format `X.Y.Z` or `X.Y` (ignoring build number e.g. `1.0.0 (1)` or `1.0.0+1`).
  /// If either version string is malformed, safely returns `true` so tracking is not blocked.
  static bool isAppVersionSupported({
    required String installedVersion,
    String? minAppVersion,
  }) {
    if (minAppVersion == null || minAppVersion.trim().isEmpty) {
      return true;
    }

    final cleanInstalled = _extractVersionNumbers(installedVersion);
    final cleanMin = _extractVersionNumbers(minAppVersion);

    // If parsing fails for either version, ignore version constraint safely
    if (cleanInstalled == null || cleanMin == null) {
      return true;
    }

    final maxLen = cleanInstalled.length > cleanMin.length
        ? cleanInstalled.length
        : cleanMin.length;

    for (var i = 0; i < maxLen; i++) {
      final instPart = i < cleanInstalled.length ? cleanInstalled[i] : 0;
      final minPart = i < cleanMin.length ? cleanMin[i] : 0;

      if (instPart < minPart) {
        return false;
      } else if (instPart > minPart) {
        return true;
      }
    }

    return true; // Exactly equal
  }

  /// Extracts integer components from a version string (e.g., "1.2.3 (4)" -> [1, 2, 3]).
  static List<int>? _extractVersionNumbers(String versionStr) {
    try {
      // Strip everything after '+' or ' ' or '(' (build metadata)
      var clean = versionStr.trim();
      final spaceIdx = clean.indexOf(' ');
      if (spaceIdx != -1) clean = clean.substring(0, spaceIdx);
      final plusIdx = clean.indexOf('+');
      if (plusIdx != -1) clean = clean.substring(0, plusIdx);
      final parenIdx = clean.indexOf('(');
      if (parenIdx != -1) clean = clean.substring(0, parenIdx);

      final parts = clean.split('.');
      if (parts.isEmpty) return null;

      final numbers = <int>[];
      for (final p in parts) {
        final n = int.tryParse(p.trim());
        if (n == null || n < 0) {
          return null; // Non-numeric or invalid segment
        }
        numbers.add(n);
      }
      return numbers;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'minAppVersion': minAppVersion,
      'syncIntervalSeconds': syncIntervalSeconds,
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory RemoteConfigData.fromJson(String jsonStr,
      {RemoteConfigData? fallback}) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>?;
      return RemoteConfigData.fromMap(map, fallback: fallback);
    } catch (_) {
      return fallback ?? RemoteConfigData.defaultConfig;
    }
  }

  factory RemoteConfigData.fromMap(Map<String, dynamic>? map,
      {RemoteConfigData? fallback}) {
    if (map == null) return fallback ?? RemoteConfigData.defaultConfig;

    // 1. enabled (retains fallback.enabled if missing/malformed, or defaults to true)
    bool parsedEnabled = fallback?.enabled ?? true;
    final dynamic rawEnabled = map['enabled'];
    if (rawEnabled is bool) {
      parsedEnabled = rawEnabled;
    }

    // 2. expiresAt
    DateTime? parsedExpiry = fallback?.expiresAt;
    final dynamic rawExpiresAt = map['expiresAt'];
    if (rawExpiresAt is String) {
      parsedExpiry = DateTime.tryParse(rawExpiresAt)?.toUtc();
    } else if (rawExpiresAt != null) {
      try {
        parsedExpiry = (rawExpiresAt.toDate() as DateTime).toUtc();
      } catch (_) {}
    } else if (map.containsKey('expiresAt') && rawExpiresAt == null) {
      parsedExpiry = null;
    }

    // 3. minAppVersion
    String? parsedMinVersion = fallback?.minAppVersion;
    final dynamic rawMinVersion = map['minAppVersion'];
    if (rawMinVersion is String) {
      parsedMinVersion =
          rawMinVersion.trim().isEmpty ? null : rawMinVersion.trim();
    } else if (map.containsKey('minAppVersion') && rawMinVersion == null) {
      parsedMinVersion = null;
    }

    // 4. syncIntervalSeconds (bounded to minSyncIntervalSeconds..maxSyncIntervalSeconds)
    int? parsedSyncInterval = fallback?.syncIntervalSeconds;
    final dynamic rawSyncInterval = map['syncIntervalSeconds'];
    if (rawSyncInterval is num) {
      final intVal = rawSyncInterval.toInt();
      if (intVal >= minSyncIntervalSeconds &&
          intVal <= maxSyncIntervalSeconds) {
        parsedSyncInterval = intVal;
      }
    } else if (map.containsKey('syncIntervalSeconds') &&
        rawSyncInterval == null) {
      parsedSyncInterval = null;
    }

    // 5. updatedAt
    DateTime? parsedUpdatedAt = fallback?.updatedAt;
    final dynamic rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    } else if (rawUpdatedAt != null) {
      try {
        parsedUpdatedAt = (rawUpdatedAt.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    return RemoteConfigData(
      enabled: parsedEnabled,
      expiresAt: parsedExpiry,
      minAppVersion: parsedMinVersion,
      syncIntervalSeconds: parsedSyncInterval,
      updatedAt: parsedUpdatedAt,
    );
  }

  RemoteConfigData copyWith({
    bool? enabled,
    DateTime? expiresAt,
    String? minAppVersion,
    int? syncIntervalSeconds,
    DateTime? updatedAt,
  }) {
    return RemoteConfigData(
      enabled: enabled ?? this.enabled,
      expiresAt: expiresAt ?? this.expiresAt,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      syncIntervalSeconds: syncIntervalSeconds ?? this.syncIntervalSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
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
