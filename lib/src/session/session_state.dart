import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Immutable model representing the local in-flight or recovery session state.
@immutable
class SessionState {
  final String sessionId;
  final String testerId;
  final String authUid;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;
  final int accumulatedDurationSeconds;
  final String appVersion;
  final String platform;
  final bool isFinalized;

  const SessionState({
    required this.sessionId,
    required this.testerId,
    required this.authUid,
    required this.startedAt,
    required this.lastHeartbeatAt,
    required this.accumulatedDurationSeconds,
    required this.appVersion,
    required this.platform,
    required this.isFinalized,
  });

  /// The observed active foreground duration in seconds.
  ///
  /// CRITICAL: Interrupted or backgrounded sessions must NEVER count time spent while
  /// the app was in the background or process terminated.
  int get observedDurationSeconds =>
      accumulatedDurationSeconds >= 0 ? accumulatedDurationSeconds : 0;

  /// ISO calendar date string in UTC (e.g. "2026-10-08").
  String get activeDate {
    return startedAt.toUtc().toIso8601String().split('T').first;
  }

  SessionState copyWith({
    String? sessionId,
    String? testerId,
    String? authUid,
    DateTime? startedAt,
    DateTime? lastHeartbeatAt,
    int? accumulatedDurationSeconds,
    String? appVersion,
    String? platform,
    bool? isFinalized,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      testerId: testerId ?? this.testerId,
      authUid: authUid ?? this.authUid,
      startedAt: startedAt ?? this.startedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      accumulatedDurationSeconds:
          accumulatedDurationSeconds ?? this.accumulatedDurationSeconds,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      isFinalized: isFinalized ?? this.isFinalized,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'testerId': testerId,
      'authUid': authUid,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'lastHeartbeatAt': lastHeartbeatAt.toUtc().toIso8601String(),
      'accumulatedDurationSeconds': accumulatedDurationSeconds,
      'appVersion': appVersion,
      'platform': platform,
      'isFinalized': isFinalized,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory SessionState.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is String) return DateTime.tryParse(val)?.toUtc() ?? fallback;
      return fallback;
    }

    final now = DateTime.now().toUtc();
    final started = parseDate(map['startedAt'], now);
    final lastHb = parseDate(map['lastHeartbeatAt'], started);

    // Fallback: if older payload didn't store accumulatedDurationSeconds, calculate from heartbeat
    final int rawDuration =
        (map['accumulatedDurationSeconds'] as num?)?.toInt() ??
            lastHb.difference(started).inSeconds;

    return SessionState(
      sessionId: map['sessionId'] as String? ?? '',
      testerId: map['testerId'] as String? ?? '',
      authUid: map['authUid'] as String? ?? '',
      startedAt: started,
      lastHeartbeatAt: lastHb,
      accumulatedDurationSeconds: rawDuration >= 0 ? rawDuration : 0,
      appVersion: map['appVersion'] as String? ?? 'unknown',
      platform: map['platform'] as String? ?? 'unknown',
      isFinalized: map['isFinalized'] as bool? ?? false,
    );
  }

  factory SessionState.fromJson(String jsonStr) {
    return SessionState.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          testerId == other.testerId &&
          authUid == other.authUid &&
          startedAt == other.startedAt &&
          lastHeartbeatAt == other.lastHeartbeatAt &&
          accumulatedDurationSeconds == other.accumulatedDurationSeconds &&
          appVersion == other.appVersion &&
          platform == other.platform &&
          isFinalized == other.isFinalized;

  @override
  int get hashCode =>
      sessionId.hashCode ^
      testerId.hashCode ^
      authUid.hashCode ^
      startedAt.hashCode ^
      lastHeartbeatAt.hashCode ^
      accumulatedDurationSeconds.hashCode ^
      appVersion.hashCode ^
      platform.hashCode ^
      isFinalized.hashCode;
}
