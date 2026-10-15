import 'dart:math';
import 'package:flutter/foundation.dart';

/// Immutable model representing a tester profile in Firestore (`testers/{testerId}`).
@immutable
class TesterData {
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

  const TesterData({
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
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'testerId': testerId,
      'authUid': authUid,
      'platform': platform,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'firstSeen': firstSeen.toUtc().toIso8601String(),
      'lastSeen': lastSeen.toUtc().toIso8601String(),
      'sessionCount': sessionCount,
      'totalUsageSeconds': totalUsageSeconds,
      'activeDaysCount': activeDaysCount,
      'recentActiveDates': recentActiveDates,
    };
  }

  factory TesterData.fromMap(Map<String, dynamic> map) {
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
    final rawDates = map['recentActiveDates'];
    final parsedDates = rawDates is List
        ? rawDates.map((dynamic e) => e.toString()).toList()
        : <String>[];

    return TesterData(
      testerId: map['testerId'] as String? ?? '',
      authUid: map['authUid'] as String? ?? '',
      platform: map['platform'] as String? ?? 'unknown',
      deviceModel: map['deviceModel'] as String? ?? 'unknown',
      osVersion: map['osVersion'] as String? ?? 'unknown',
      appVersion: map['appVersion'] as String? ?? 'unknown',
      firstSeen: parseDate(map['firstSeen'], now),
      lastSeen: parseDate(map['lastSeen'], now),
      sessionCount: (map['sessionCount'] as num?)?.toInt() ?? 0,
      totalUsageSeconds: (map['totalUsageSeconds'] as num?)?.toInt() ?? 0,
      activeDaysCount: max(
        (map['activeDaysCount'] as num?)?.toInt() ?? 0,
        max(
            parsedDates.length,
            (((map['sessionCount'] as num?)?.toInt() ?? 0) > 0 ||
                    parsedDates.isNotEmpty)
                ? 1
                : 0),
      ),
      recentActiveDates: parsedDates,
    );
  }

  TesterData copyWith({
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
  }) {
    return TesterData(
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
    );
  }
}
