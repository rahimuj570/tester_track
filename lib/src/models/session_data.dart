import 'package:flutter/foundation.dart';

/// Immutable model representing a recorded session in Firestore (`testers/{testerId}/sessions/{sessionId}`).
@immutable
class SessionData {
  final String sessionId;
  final String testerId;
  final String authUid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String activeDate;
  final String appVersion;
  final String platform;
  final bool isFinalized;

  const SessionData({
    required this.sessionId,
    required this.testerId,
    required this.authUid,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.activeDate,
    required this.appVersion,
    required this.platform,
    required this.isFinalized,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'testerId': testerId,
      'authUid': authUid,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt?.toUtc().toIso8601String(),
      'durationSeconds': durationSeconds,
      'activeDate': activeDate,
      'appVersion': appVersion,
      'platform': platform,
      'isFinalized': isFinalized,
    };
  }

  factory SessionData.fromMap(Map<String, dynamic> map) {
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

    return SessionData(
      sessionId: map['sessionId'] as String? ?? '',
      testerId: map['testerId'] as String? ?? '',
      authUid: map['authUid'] as String? ?? '',
      startedAt: started,
      endedAt: ended,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      activeDate: map['activeDate'] as String? ?? '',
      appVersion: map['appVersion'] as String? ?? 'unknown',
      platform: map['platform'] as String? ?? 'unknown',
      isFinalized: map['isFinalized'] as bool? ?? false,
    );
  }

  SessionData copyWith({
    String? sessionId,
    String? testerId,
    String? authUid,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? activeDate,
    String? appVersion,
    String? platform,
    bool? isFinalized,
  }) {
    return SessionData(
      sessionId: sessionId ?? this.sessionId,
      testerId: testerId ?? this.testerId,
      authUid: authUid ?? this.authUid,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      activeDate: activeDate ?? this.activeDate,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      isFinalized: isFinalized ?? this.isFinalized,
    );
  }
}
