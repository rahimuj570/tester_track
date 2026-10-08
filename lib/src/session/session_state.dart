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
  final String appVersion;
  final String platform;
  final bool isFinalized;

  const SessionState({
    required this.sessionId,
    required this.testerId,
    required this.authUid,
    required this.startedAt,
    required this.lastHeartbeatAt,
    required this.appVersion,
    required this.platform,
    required this.isFinalized,
  });

  /// Calculates the observed active duration up to [lastHeartbeatAt].
  ///
  /// CRITICAL: Interrupted or crashed sessions must NEVER count time spent while
  /// the app was terminated. Duration is measured strictly between [startedAt]
  /// and [lastHeartbeatAt].
  int get observedDurationSeconds {
    final diff = lastHeartbeatAt.difference(startedAt).inSeconds;
    return diff >= 0 ? diff : 0;
  }

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
    return SessionState(
      sessionId: map['sessionId'] as String? ?? '',
      testerId: map['testerId'] as String? ?? '',
      authUid: map['authUid'] as String? ?? '',
      startedAt: parseDate(map['startedAt'], now),
      lastHeartbeatAt: parseDate(map['lastHeartbeatAt'], now),
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
      appVersion.hashCode ^
      platform.hashCode ^
      isFinalized.hashCode;
}
