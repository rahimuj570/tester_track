import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_config.dart';
import '../models/remote_config_form_model.dart';
import '../models/session_view_model.dart';
import '../models/tester_view_model.dart';
import 'firebase_manager.dart';

/// Handles Firestore read operations and remote-config updates for the dashboard.
class DashboardFirestoreService {
  final FirebaseManager _firebaseManager;

  DashboardFirestoreService(this._firebaseManager);

  /// Checks if the currently authenticated user is authorized under Firestore Security Rules.
  /// Returns `true` if authorized, or throws a descriptive exception if permission is denied.
  Future<bool> checkAuthorization(FirebaseProjectConfig config) async {
    final firestore = await _firebaseManager.getFirestore(config);
    try {
      // Try to read config/global first (readable by any authenticated user)
      await firestore.collection('config').doc('global').get();
      // Try to list testers collection (only readable by allowlisted developer)
      await firestore.collection('testers').limit(1).get();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  /// Fetches all registered testers from `testers` collection with active in-progress metrics.
  Future<List<TesterViewModel>> fetchTesters(
    FirebaseProjectConfig config, {
    int limit = 200,
  }) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final snapshot = await firestore
        .collection('testers')
        .orderBy('lastSeen', descending: true)
        .limit(limit)
        .get();

    final testers = snapshot.docs
        .map((doc) => TesterViewModel.fromMap(doc.id, doc.data()))
        .toList();

    final nowUtc = DateTime.now().toUtc();
    final nowLocal = DateTime.now();
    final todayUtcStr =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}';
    final todayLocalStr =
        '${nowLocal.year.toString().padLeft(4, '0')}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';
    final todayDates = {todayUtcStr, todayLocalStr}.toList();
    final startOfTodayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final startOfTodayLocal =
        DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    // Query in-progress & today sessions for each tester to calculate live and daily metrics
    // (Uses direct subcollection queries to avoid collectionGroup index/rules restrictions)
    final enrichedTesters = await Future.wait(
      testers.map((t) => _enrichTester(
            firestore,
            t,
            todayDates,
            startOfTodayUtc,
            startOfTodayLocal,
            todayUtcStr,
            todayLocalStr,
          )),
    );

    return enrichedTesters;
  }

  /// Fetches a single tester document with in-progress and today's metrics.
  Future<TesterViewModel?> fetchTester(
    FirebaseProjectConfig config,
    String testerId,
  ) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final doc = await firestore.collection('testers').doc(testerId).get();
    if (!doc.exists || doc.data() == null) return null;
    final baseTester = TesterViewModel.fromMap(doc.id, doc.data()!);

    final nowUtc = DateTime.now().toUtc();
    final nowLocal = DateTime.now();
    final todayUtcStr =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}';
    final todayLocalStr =
        '${nowLocal.year.toString().padLeft(4, '0')}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';
    final todayDates = {todayUtcStr, todayLocalStr}.toList();
    final startOfTodayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final startOfTodayLocal =
        DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    return await _enrichTester(
      firestore,
      baseTester,
      todayDates,
      startOfTodayUtc,
      startOfTodayLocal,
      todayUtcStr,
      todayLocalStr,
    );
  }

  /// Helper to calculate live in-progress and daily usage metrics for a tester.
  Future<TesterViewModel> _enrichTester(
    FirebaseFirestore firestore,
    TesterViewModel t,
    List<String> todayDates,
    DateTime startOfTodayUtc,
    DateTime startOfTodayLocal,
    String todayUtcStr,
    String todayLocalStr,
  ) async {
    try {
      final inProgressFuture = firestore
          .collection('testers')
          .doc(t.testerId)
          .collection('sessions')
          .where('isFinalized', isEqualTo: false)
          .get();

      final todayFuture = firestore
          .collection('testers')
          .doc(t.testerId)
          .collection('sessions')
          .where('activeDate', whereIn: todayDates)
          .get();

      final results = await Future.wait([inProgressFuture, todayFuture]);
      final inProgressSnap = results[0];
      final todaySnap = results[1];

      final Map<String, Map<String, dynamic>> todayDocs = {};
      for (final doc in todaySnap.docs) {
        todayDocs[doc.id] = doc.data();
      }

      for (final doc in inProgressSnap.docs) {
        final data = doc.data();
        final activeDate = data['activeDate'] as String? ?? '';
        var isToday = todayDates.contains(activeDate);
        if (!isToday && data['startedAt'] != null) {
          try {
            final dynamic rawStarted = data['startedAt'];
            final started = rawStarted is String
                ? DateTime.tryParse(rawStarted)?.toUtc()
                : (rawStarted?.toDate() as DateTime?)?.toUtc();
            if (started != null &&
                (started.isAfter(startOfTodayUtc) ||
                    started.isAtSameMomentAs(startOfTodayUtc))) {
              isToday = true;
            }
          } catch (_) {}
        }
        if (isToday) {
          todayDocs[doc.id] = data;
        }
      }

      final nowUtc = DateTime.now().toUtc();
      var activeCount = 0;
      var activeDur = 0;
      var staleCount = 0;
      var staleDur = 0;

      for (final doc in inProgressSnap.docs) {
        final data = doc.data();
        final dur = (data['durationSeconds'] as num?)?.toInt() ?? 0;

        DateTime? parseTime(dynamic val) {
          if (val is String) return DateTime.tryParse(val)?.toUtc();
          if (val != null) {
            try {
              return (val.toDate() as DateTime).toUtc();
            } catch (_) {}
          }
          return null;
        }

        final updated = parseTime(data['updatedAt']);
        final started = parseTime(data['startedAt']) ?? nowUtc;
        final lastActive = updated ?? started.add(Duration(seconds: dur));
        final isRecent =
            nowUtc.difference(lastActive) <= SessionViewModel.defaultActiveTimeout;

        if (isRecent) {
          activeCount++;
          activeDur += dur;
        } else {
          staleCount++;
          staleDur += dur;
        }
      }

      final todayCount = todayDocs.length;
      var todayDur = 0;
      for (final data in todayDocs.values) {
        todayDur += (data['durationSeconds'] as num?)?.toInt() ?? 0;
      }

      final hasLastSeenToday = t.lastSeen.isAfter(startOfTodayLocal) ||
          t.lastSeen.toUtc().isAfter(startOfTodayUtc);
      final hasRecentDateToday = t.recentActiveDates.contains(todayUtcStr) ||
          t.recentActiveDates.contains(todayLocalStr);
      final isUsedToday = todayCount > 0 ||
          todayDur > 0 ||
          hasRecentDateToday ||
          hasLastSeenToday;

      // Recover missing or 'unknown' platform/device metadata from session documents if needed
      var recPlatform = t.platform;
      var recDeviceModel = t.deviceModel;
      var recOsVersion = t.osVersion;
      var recAppVersion = t.appVersion;

      bool isUnknownVal(String v) =>
          v.trim().isEmpty || v.trim().toLowerCase() == 'unknown';

      if (isUnknownVal(recPlatform) ||
          isUnknownVal(recDeviceModel) ||
          isUnknownVal(recOsVersion) ||
          isUnknownVal(recAppVersion)) {
        final candidateDocs = <Map<String, dynamic>>[
          ...todayDocs.values,
          for (final doc in inProgressSnap.docs) doc.data(),
        ];

        // If candidates are empty or still missing fields, query recent sessions for this tester
        if (candidateDocs.isEmpty ||
            (isUnknownVal(recPlatform) &&
                isUnknownVal(recDeviceModel) &&
                isUnknownVal(recAppVersion))) {
          try {
            final recentSnap = await firestore
                .collection('testers')
                .doc(t.testerId)
                .collection('sessions')
                .orderBy('startedAt', descending: true)
                .limit(3)
                .get();
            for (final doc in recentSnap.docs) {
              candidateDocs.add(doc.data());
            }
          } catch (_) {}
        }

        for (final data in candidateDocs) {
          final p = data['platform']?.toString();
          final m = data['deviceModel']?.toString();
          final os = data['osVersion']?.toString();
          final v = data['appVersion']?.toString();

          if (isUnknownVal(recPlatform) && p != null && !isUnknownVal(p)) {
            recPlatform = p;
          }
          if (isUnknownVal(recDeviceModel) && m != null && !isUnknownVal(m)) {
            recDeviceModel = m;
          }
          if (isUnknownVal(recOsVersion) && os != null && !isUnknownVal(os)) {
            recOsVersion = os;
          }
          if (isUnknownVal(recAppVersion) && v != null && !isUnknownVal(v)) {
            recAppVersion = v;
          }
        }

        // Friendly device model fallback if model was not recorded but platform is known
        if (isUnknownVal(recDeviceModel) && !isUnknownVal(recPlatform)) {
          final pLower = recPlatform.toLowerCase();
          if (pLower.contains('android')) {
            recDeviceModel = 'Android Device';
          } else if (pLower.contains('ios') ||
              pLower.contains('iphone') ||
              pLower.contains('ipad')) {
            recDeviceModel = 'iOS Device';
          } else if (pLower.contains('web')) {
            recDeviceModel = 'Web Client';
          } else if (pLower.contains('windows')) {
            recDeviceModel = 'Windows PC';
          } else if (pLower.contains('macos') || pLower.contains('mac')) {
            recDeviceModel = 'Mac';
          }
        }

        // Heal the Firestore document in the background if we recovered missing metadata
        final hasRecoveredChanges =
            (!isUnknownVal(recPlatform) && recPlatform != t.platform) ||
                (!isUnknownVal(recDeviceModel) &&
                    recDeviceModel != t.deviceModel) ||
                (!isUnknownVal(recAppVersion) && recAppVersion != t.appVersion);

        if (hasRecoveredChanges) {
          try {
            firestore.collection('testers').doc(t.testerId).set({
              if (!isUnknownVal(recPlatform)) 'platform': recPlatform,
              if (!isUnknownVal(recDeviceModel)) 'deviceModel': recDeviceModel,
              if (!isUnknownVal(recOsVersion)) 'osVersion': recOsVersion,
              if (!isUnknownVal(recAppVersion)) 'appVersion': recAppVersion,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).ignore();
          } catch (_) {}
        }
      }

      return t.copyWith(
        platform: recPlatform,
        deviceModel: recDeviceModel,
        osVersion: recOsVersion,
        appVersion: recAppVersion,
        inProgressSessionCount: activeCount + staleCount,
        inProgressUsageSeconds: activeDur + staleDur,
        activeSessionCount: activeCount,
        activeUsageSeconds: activeDur,
        staleSessionCount: staleCount,
        staleUsageSeconds: staleDur,
        todaySessionsCount: todayCount,
        todayUsageSeconds: todayDur,
        isUsedToday: isUsedToday,
      );
    } catch (_) {
      return t;
    }
  }

  /// Updates metadata for a specific tester profile document.
  Future<bool> updateTesterMetadata(
    FirebaseProjectConfig config, {
    required String testerId,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
  }) async {
    try {
      final firestore = await _firebaseManager.getFirestore(config);
      final updateData = <String, dynamic>{
        if (platform != null && platform.trim().isNotEmpty)
          'platform': platform.trim(),
        if (deviceModel != null && deviceModel.trim().isNotEmpty)
          'deviceModel': deviceModel.trim(),
        if (osVersion != null && osVersion.trim().isNotEmpty)
          'osVersion': osVersion.trim(),
        if (appVersion != null && appVersion.trim().isNotEmpty)
          'appVersion': appVersion.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (updateData.isNotEmpty) {
        await firestore
            .collection('testers')
            .doc(testerId)
            .set(updateData, SetOptions(merge: true));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically finalizes unfinalized sessions whose heartbeat is older than [timeout]
  /// for a specific tester or across all testers, updating cumulative totals.
  Future<int> autoFinalizeStaleSessions(
    FirebaseProjectConfig config, {
    String? testerId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final nowUtc = DateTime.now().toUtc();
    var finalizedCount = 0;

    final testerIds = <String>[];
    if (testerId != null) {
      testerIds.add(testerId);
    } else {
      final testersSnap = await firestore.collection('testers').get();
      for (final d in testersSnap.docs) {
        testerIds.add(d.id);
      }
    }

    DateTime? parseTime(dynamic val) {
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      if (val != null) {
        try {
          return (val.toDate() as DateTime).toUtc();
        } catch (_) {}
      }
      return null;
    }

    for (final id in testerIds) {
      try {
        final unfinalizedSnap = await firestore
            .collection('testers')
            .doc(id)
            .collection('sessions')
            .where('isFinalized', isEqualTo: false)
            .get();

        for (final sDoc in unfinalizedSnap.docs) {
          final data = sDoc.data();
          final dur = (data['durationSeconds'] as num?)?.toInt() ?? 0;
          final updated = parseTime(data['updatedAt']);
          final started = parseTime(data['startedAt']) ?? nowUtc;
          final lastActive = updated ?? started.add(Duration(seconds: dur));

          if (nowUtc.difference(lastActive) > timeout) {
            final activeDate = data['activeDate'] as String? ??
                '${started.year.toString().padLeft(4, '0')}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')}';
            await finalizeSession(
              config,
              testerId: id,
              sessionId: sDoc.id,
              endedAt: lastActive,
              durationSeconds: dur,
              activeDate: activeDate,
            );
            finalizedCount++;
          }
        }
      } catch (_) {}
    }

    return finalizedCount;
  }

  /// Fetches sessions recorded for a specific tester from `testers/{testerId}/sessions`.
  Future<List<SessionViewModel>> fetchSessions(
    FirebaseProjectConfig config,
    String testerId, {
    int limit = 100,
  }) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final snapshot = await firestore
        .collection('testers')
        .doc(testerId)
        .collection('sessions')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SessionViewModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Fetches remote configuration from `config/global`.
  Future<RemoteConfigFormModel> fetchRemoteConfig(
    FirebaseProjectConfig config,
  ) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final doc = await firestore.collection('config').doc('global').get();
    if (!doc.exists || doc.data() == null) {
      return RemoteConfigFormModel.empty;
    }
    return RemoteConfigFormModel.fromMap(doc.data());
  }

  /// Updates remote configuration document `config/global`.
  Future<void> updateRemoteConfig(
    FirebaseProjectConfig config,
    RemoteConfigFormModel model,
  ) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final data = model.toFirestoreMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await firestore.collection('config').doc('global').set(
          data,
          SetOptions(merge: true),
        );
  }

  /// Finalizes an in-progress session and updates the tester aggregates in Firestore.
  Future<void> finalizeSession(
    FirebaseProjectConfig config, {
    required String testerId,
    required String sessionId,
    required DateTime endedAt,
    required int durationSeconds,
    required String activeDate,
  }) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final sessionRef = firestore
        .collection('testers')
        .doc(testerId)
        .collection('sessions')
        .doc(sessionId);
    final testerRef = firestore.collection('testers').doc(testerId);

    await firestore.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists) return;
      final sessionData = sessionSnap.data();
      if (sessionData != null && sessionData['isFinalized'] == true) {
        return; // Already finalized
      }

      final testerSnap = await transaction.get(testerRef);

      transaction.update(sessionRef, {
        'isFinalized': true,
        'endedAt': endedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (testerSnap.exists && testerSnap.data() != null) {
        final currentCount =
            (testerSnap.data()?['sessionCount'] as num?)?.toInt() ?? 0;
        final currentUsage =
            (testerSnap.data()?['totalUsageSeconds'] as num?)?.toInt() ?? 0;
        final rawDates =
            testerSnap.data()?['recentActiveDates'] as List<dynamic>? ?? [];
        final datesSet = <String>{
          ...rawDates.map((e) => e.toString()),
          activeDate,
        };
        final updatedDates = datesSet.toList()..sort();
        if (updatedDates.length > 30) {
          updatedDates.removeRange(0, updatedDates.length - 30);
        }

        transaction.update(testerRef, {
          'sessionCount': currentCount + 1,
          'totalUsageSeconds': currentUsage + durationSeconds,
          'activeDaysCount': datesSet.length,
          'recentActiveDates': updatedDates,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
