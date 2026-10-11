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

    // Query in-progress sessions for each tester to calculate live counts
    // (Uses direct subcollection queries to avoid collectionGroup index/rules restrictions)
    final enrichedTesters = await Future.wait(
      testers.map((t) async {
        try {
          final inProgressSnap = await firestore
              .collection('testers')
              .doc(t.testerId)
              .collection('sessions')
              .where('isFinalized', isEqualTo: false)
              .get();

          final count = inProgressSnap.docs.length;
          var dur = 0;
          for (final doc in inProgressSnap.docs) {
            dur += (doc.data()['durationSeconds'] as num?)?.toInt() ?? 0;
          }

          if (count > 0 || dur > 0) {
            return t.copyWith(
              inProgressSessionCount: count,
              inProgressUsageSeconds: dur,
            );
          }
          return t;
        } catch (_) {
          return t;
        }
      }),
    );

    return enrichedTesters;
  }

  /// Fetches a single tester document with in-progress metrics.
  Future<TesterViewModel?> fetchTester(
    FirebaseProjectConfig config,
    String testerId,
  ) async {
    final firestore = await _firebaseManager.getFirestore(config);
    final doc = await firestore.collection('testers').doc(testerId).get();
    if (!doc.exists || doc.data() == null) return null;
    final baseTester = TesterViewModel.fromMap(doc.id, doc.data()!);

    try {
      final inProgressSnap = await firestore
          .collection('testers')
          .doc(testerId)
          .collection('sessions')
          .where('isFinalized', isEqualTo: false)
          .get();

      final inProgressCount = inProgressSnap.docs.length;
      var inProgressDur = 0;
      for (final sDoc in inProgressSnap.docs) {
        inProgressDur += (sDoc.data()['durationSeconds'] as num?)?.toInt() ?? 0;
      }

      return baseTester.copyWith(
        inProgressSessionCount: inProgressCount,
        inProgressUsageSeconds: inProgressDur,
      );
    } catch (_) {
      return baseTester;
    }
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
