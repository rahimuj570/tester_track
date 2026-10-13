import 'package:flutter/foundation.dart';

/// ViewModel representing a recorded session subdocument (`testers/{testerId}/sessions/{sessionId}`).
@immutable
class SessionViewModel {
  final String sessionId;
  final String testerId;
  final String authUid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String activeDate;
  final String appVersion;
  final String platform;
  final String deviceModel;
  final String osVersion;
  final bool isFinalized;
  final DateTime? updatedAt;

  const SessionViewModel({
    required this.sessionId,
    required this.testerId,
    required this.authUid,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.activeDate,
    required this.appVersion,
    required this.platform,
    this.deviceModel = 'unknown',
    this.osVersion = 'unknown',
    required this.isFinalized,
    this.updatedAt,
  });

  /// The most recent activity timestamp for this session.
  /// Falls back to `startedAt + durationSeconds` if `updatedAt` is null.
  DateTime get lastActiveAt {
    if (updatedAt != null) return updatedAt!;
    return startedAt.add(Duration(seconds: durationSeconds));
  }

  /// Default threshold beyond which an unfinalized session is considered stale.
  static const Duration defaultActiveTimeout = Duration(minutes: 2);

  /// Whether this session has active heartbeat within [timeout] (default 2 mins).
  bool isCurrentlyActive({
    Duration timeout = defaultActiveTimeout,
    DateTime? now,
  }) {
    if (isFinalized) return false;
    final currentTime = (now ?? DateTime.now()).toUtc();
    return currentTime.difference(lastActiveAt) <= timeout;
  }

  /// User-friendly status label: "Active Now" if recently active, else "Completed".
  String get statusText => isCurrentlyActive() ? 'Active Now' : 'Completed';

  /// Whether this session is unfinalized but has timed out (stale / closed / interrupted).
  bool isStale({
    Duration timeout = defaultActiveTimeout,
    DateTime? now,
  }) {
    return !isFinalized && !isCurrentlyActive(timeout: timeout, now: now);
  }

  /// Formatted duration string (e.g. "12m 30s" or "45s").
  String get formattedDuration {
    if (durationSeconds < 60) {
      return '${durationSeconds}s';
    }
    final minutes = durationSeconds ~/ 60;
    final remSec = durationSeconds % 60;
    if (minutes < 60) {
      return remSec > 0 ? '${minutes}m ${remSec}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }

  factory SessionViewModel.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is String) return DateTime.tryParse(val)?.toUtc() ?? fallback;
      if (val != null) {
        try {
          return (val.toDate() as DateTime).toUtc();
        } catch (_) {}
      }
      return fallback;
    }

    final started = parseDate(map['startedAt'], DateTime.now().toUtc());
    final dynamic rawEnded = map['endedAt'];
    DateTime? ended;
    if (rawEnded is String) {
      ended = DateTime.tryParse(rawEnded)?.toUtc();
    } else if (rawEnded != null) {
      try {
        ended = (rawEnded.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    final dynamic rawUpdated = map['updatedAt'];
    DateTime? updated;
    if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated)?.toUtc();
    } else if (rawUpdated != null) {
      try {
        updated = (rawUpdated.toDate() as DateTime).toUtc();
      } catch (_) {}
    }

    return SessionViewModel(
      sessionId: map['sessionId'] as String? ?? docId,
      testerId: map['testerId'] as String? ?? '',
      authUid: map['authUid'] as String? ?? '',
      startedAt: started,
      endedAt: ended,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      activeDate: map['activeDate'] as String? ?? '',
      appVersion: map['appVersion'] as String? ?? 'unknown',
      platform: map['platform'] as String? ?? 'unknown',
      deviceModel: map['deviceModel'] as String? ?? 'unknown',
      osVersion: map['osVersion'] as String? ?? 'unknown',
      isFinalized: map['isFinalized'] as bool? ?? false,
      updatedAt: updated,
    );
  }
}
