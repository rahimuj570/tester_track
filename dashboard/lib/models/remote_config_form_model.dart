import 'package:flutter/foundation.dart';

/// Model representing the remote configuration document `config/global` for dashboard forms.
@immutable
class RemoteConfigFormModel {
  final bool enabled;
  final DateTime? expiresAt;
  final String? minAppVersion;
  final int? syncIntervalSeconds;
  final DateTime? updatedAt;

  const RemoteConfigFormModel({
    this.enabled = true,
    this.expiresAt,
    this.minAppVersion,
    this.syncIntervalSeconds,
    this.updatedAt,
  });

  static const RemoteConfigFormModel empty = RemoteConfigFormModel(
    enabled: true,
    expiresAt: null,
    minAppVersion: null,
    syncIntervalSeconds: null,
    updatedAt: null,
  );

  RemoteConfigFormModel copyWith({
    bool? enabled,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? minAppVersion,
    bool clearMinAppVersion = false,
    int? syncIntervalSeconds,
    bool clearSyncInterval = false,
    DateTime? updatedAt,
  }) {
    return RemoteConfigFormModel(
      enabled: enabled ?? this.enabled,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      minAppVersion:
          clearMinAppVersion ? null : (minAppVersion ?? this.minAppVersion),
      syncIntervalSeconds: clearSyncInterval
          ? null
          : (syncIntervalSeconds ?? this.syncIntervalSeconds),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'minAppVersion': minAppVersion?.trim().isNotEmpty == true
          ? minAppVersion!.trim()
          : null,
      'syncIntervalSeconds': syncIntervalSeconds,
    };
  }

  factory RemoteConfigFormModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return RemoteConfigFormModel.empty;

    bool parsedEnabled = true;
    final rawEnabled = map['enabled'];
    if (rawEnabled is bool) parsedEnabled = rawEnabled;

    DateTime? parsedExpiry;
    final rawExpiresAt = map['expiresAt'];
    if (rawExpiresAt is String) {
      parsedExpiry = DateTime.tryParse(rawExpiresAt)?.toUtc();
    } else if (rawExpiresAt != null) {
      try {
        parsedExpiry = (rawExpiresAt.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    String? parsedMinVersion;
    final rawMinVersion = map['minAppVersion'];
    if (rawMinVersion is String && rawMinVersion.trim().isNotEmpty) {
      parsedMinVersion = rawMinVersion.trim();
    }

    int? parsedSyncInterval;
    final rawSyncInterval = map['syncIntervalSeconds'];
    if (rawSyncInterval is num) {
      final intVal = rawSyncInterval.toInt();
      if (intVal >= 60 && intVal <= 3600) {
        parsedSyncInterval = intVal;
      }
    }

    DateTime? parsedUpdatedAt;
    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    } else if (rawUpdatedAt != null) {
      try {
        parsedUpdatedAt = (rawUpdatedAt.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    return RemoteConfigFormModel(
      enabled: parsedEnabled,
      expiresAt: parsedExpiry,
      minAppVersion: parsedMinVersion,
      syncIntervalSeconds: parsedSyncInterval,
      updatedAt: parsedUpdatedAt,
    );
  }
}
