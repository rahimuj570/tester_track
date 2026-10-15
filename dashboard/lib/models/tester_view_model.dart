import 'dart:math';
import 'package:flutter/foundation.dart';

/// ViewModel representing a tester document (`testers/{testerId}`).
@immutable
class TesterViewModel {
  final String testerId;
  final String authUid;
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int sessionCount;
  final int totalUsageSeconds;
  final int activeDaysCount;
  final List<String> recentActiveDates;
  final int inProgressSessionCount;
  final int inProgressUsageSeconds;
  final int activeSessionCount;
  final int activeUsageSeconds;
  final int staleSessionCount;
  final int staleUsageSeconds;
  final bool isUsedToday;
  final int todayUsageSeconds;
  final int todaySessionsCount;

  const TesterViewModel({
    required this.testerId,
    required this.authUid,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.firstSeen,
    required this.lastSeen,
    required this.sessionCount,
    required this.totalUsageSeconds,
    required this.activeDaysCount,
    required this.recentActiveDates,
    this.inProgressSessionCount = 0,
    this.inProgressUsageSeconds = 0,
    this.activeSessionCount = 0,
    this.activeUsageSeconds = 0,
    this.staleSessionCount = 0,
    this.staleUsageSeconds = 0,
    this.isUsedToday = false,
    this.todayUsageSeconds = 0,
    this.todaySessionsCount = 0,
  });

  /// Whether the tester has an active session with fresh heartbeat right now.
  bool get isCurrentlyActive => activeSessionCount > 0;

  /// Whether the tester has unfinalized sessions whose heartbeats have expired.
  bool get hasStaleSessions => staleSessionCount > 0;

  /// Total recorded sessions including finalized and in-progress.
  int get totalRecordedSessions => sessionCount + inProgressSessionCount;

  /// Total observed usage seconds including finalized and in-progress.
  int get totalObservedUsageSeconds =>
      totalUsageSeconds + inProgressUsageSeconds;

  /// Formatted total observed usage time (finalized + in-progress).
  String get formattedTotalUsageTime {
    final secs = totalObservedUsageSeconds;
    if (secs < 60) return '${secs}s';
    final minutes = secs ~/ 60;
    if (minutes < 60) {
      final remSec = secs % 60;
      return remSec > 0 ? '${minutes}m ${remSec}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }

  /// Formatted total usage time (finalized only).
  String get formattedUsageTime {
    if (totalUsageSeconds < 60) {
      return '${totalUsageSeconds}s';
    }
    final minutes = totalUsageSeconds ~/ 60;
    if (minutes < 60) {
      final remSec = totalUsageSeconds % 60;
      return remSec > 0 ? '${minutes}m ${remSec}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }

  /// Formatted today's foreground usage time.
  String get formattedTodayUsageTime {
    if (todayUsageSeconds <= 0) return '0s';
    final secs = todayUsageSeconds;
    if (secs < 60) return '${secs}s';
    final minutes = secs ~/ 60;
    if (minutes < 60) {
      final remSec = secs % 60;
      return remSec > 0 ? '${minutes}m ${remSec}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }

  /// Whether the tester was active within the given days threshold (e.g. 14 days).
  bool isActiveWithin(int days) {
    final threshold = DateTime.now().toUtc().subtract(Duration(days: days));
    return lastSeen.isAfter(threshold);
  }

  factory TesterViewModel.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is String) return DateTime.tryParse(val)?.toUtc() ?? fallback;
      if (val != null) {
        try {
          return (val.toDate() as DateTime).toUtc();
        } catch (_) {}
      }
      return fallback;
    }

    final now = DateTime.now().toUtc();
    final nowLocal = DateTime.now();
    final parsedLastSeen = parseDate(map['lastSeen'], now);
    final rawDates = map['recentActiveDates'];
    final parsedDates = rawDates is List
        ? rawDates.map((dynamic e) => e.toString()).toList()
        : <String>[];

    final todayUtcStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayLocalStr =
        '${nowLocal.year.toString().padLeft(4, '0')}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';
    final isTodayInitial = parsedDates.contains(todayUtcStr) ||
        parsedDates.contains(todayLocalStr) ||
        (parsedLastSeen.toLocal().year == nowLocal.year &&
            parsedLastSeen.toLocal().month == nowLocal.month &&
            parsedLastSeen.toLocal().day == nowLocal.day);

    return TesterViewModel(
      testerId: map['testerId'] as String? ?? docId,
      authUid: map['authUid'] as String? ?? '',
      platform: map['platform'] as String? ?? 'unknown',
      deviceModel: map['deviceModel'] as String? ?? 'unknown',
      osVersion: map['osVersion'] as String? ?? 'unknown',
      appVersion: map['appVersion'] as String? ?? 'unknown',
      firstSeen: parseDate(map['firstSeen'], now),
      lastSeen: parsedLastSeen,
      sessionCount: (map['sessionCount'] as num?)?.toInt() ?? 0,
      totalUsageSeconds: (map['totalUsageSeconds'] as num?)?.toInt() ?? 0,
      activeDaysCount: max(
        (map['activeDaysCount'] as num?)?.toInt() ?? 0,
        max(
          {...parsedDates, if (isTodayInitial) todayLocalStr}.length,
          (((map['sessionCount'] as num?)?.toInt() ?? 0) > 0 ||
                  isTodayInitial ||
                  parsedDates.isNotEmpty)
              ? 1
              : 0,
        ),
      ),
      recentActiveDates:
          {...parsedDates, if (isTodayInitial) todayLocalStr}.toList()..sort(),
      isUsedToday: isTodayInitial,
      todayUsageSeconds: (map['todayUsageSeconds'] as num?)?.toInt() ?? 0,
      todaySessionsCount: (map['todaySessionsCount'] as num?)?.toInt() ?? 0,
    );
  }

  TesterViewModel copyWith({
    String? testerId,
    String? authUid,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? sessionCount,
    int? totalUsageSeconds,
    int? activeDaysCount,
    List<String>? recentActiveDates,
    int? inProgressSessionCount,
    int? inProgressUsageSeconds,
    int? activeSessionCount,
    int? activeUsageSeconds,
    int? staleSessionCount,
    int? staleUsageSeconds,
    bool? isUsedToday,
    int? todayUsageSeconds,
    int? todaySessionsCount,
  }) {
    return TesterViewModel(
      testerId: testerId ?? this.testerId,
      authUid: authUid ?? this.authUid,
      platform: platform ?? this.platform,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      sessionCount: sessionCount ?? this.sessionCount,
      totalUsageSeconds: totalUsageSeconds ?? this.totalUsageSeconds,
      activeDaysCount: activeDaysCount ?? this.activeDaysCount,
      recentActiveDates: recentActiveDates ?? this.recentActiveDates,
      inProgressSessionCount:
          inProgressSessionCount ?? this.inProgressSessionCount,
      inProgressUsageSeconds:
          inProgressUsageSeconds ?? this.inProgressUsageSeconds,
      activeSessionCount: activeSessionCount ?? this.activeSessionCount,
      activeUsageSeconds: activeUsageSeconds ?? this.activeUsageSeconds,
      staleSessionCount: staleSessionCount ?? this.staleSessionCount,
      staleUsageSeconds: staleUsageSeconds ?? this.staleUsageSeconds,
      isUsedToday: isUsedToday ?? this.isUsedToday,
      todayUsageSeconds: todayUsageSeconds ?? this.todayUsageSeconds,
      todaySessionsCount: todaySessionsCount ?? this.todaySessionsCount,
    );
  }
}
