import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/error_handler.dart';
import '../identity/device_info_helper.dart';
import '../models/session_data.dart';
import '../models/tester_data.dart';

/// Manages Firestore read and write operations for TesterTrack.
class FirestoreRepository {
  final FirebaseFirestore firestore;
  final TrackerErrorHandler errorHandler;

  FirestoreRepository({
    required this.firestore,
    required this.errorHandler,
  });

  /// Document reference for a tester profile.
  DocumentReference<Map<String, dynamic>> _testerDoc(String testerId) {
    return firestore
        .collection(TrackerConstants.collectionTesters)
        .doc(testerId);
  }

  /// Document reference for a specific session subdocument.
  DocumentReference<Map<String, dynamic>> _sessionDoc(
      String testerId, String sessionId) {
    return _testerDoc(testerId)
        .collection(TrackerConstants.collectionSessions)
        .doc(sessionId);
  }

  /// Synchronizes or creates the tester profile document idempotently.
  ///
  /// - If the document does not exist, creates it with initial metadata.
  /// - If the document already exists, updates mutable metadata (`lastSeen`, `osVersion`,
  ///   `appVersion`, `deviceModel`, `updatedAt`) without overwriting `authUid`, `firstSeen`,
  ///   or existing session/activity counters.
  Future<TesterData?> syncTesterProfile({
    required String testerId,
    required String authUid,
    required AppEnvironmentInfo envInfo,
  }) async {
    return await errorHandler.runGuarded<TesterData?>(() async {
      final docRef = _testerDoc(testerId);
      final docSnap = await docRef.get();
      final nowUtc = DateTime.now().toUtc();

      if (!docSnap.exists || docSnap.data() == null) {
        // Create new tester document
        final newTester = TesterData(
          testerId: testerId,
          authUid: authUid,
          platform: envInfo.platform,
          deviceModel: envInfo.deviceModel,
          osVersion: envInfo.osVersion,
          appVersion: envInfo.appVersion,
          firstSeen: nowUtc,
          lastSeen: nowUtc,
          sessionCount: 0,
          totalUsageSeconds: 0,
          activeDaysCount: 0,
          recentActiveDates: const [],
        );

        final data = newTester.toMap();
        data['updatedAt'] = FieldValue.serverTimestamp();

        await docRef.set(data, SetOptions(merge: false));
        errorHandler.log('Created new tester document: testers/$testerId');
        return newTester;
      } else {
        // Document exists: update metadata while preserving immutable authUid and aggregates
        final existingData = docSnap.data()!;
        final existingTester = TesterData.fromMap(existingData);

        // Immutability check: if document already has a different authUid, log warning
        if (existingTester.authUid.isNotEmpty &&
            existingTester.authUid != authUid) {
          errorHandler.log(
            'Warning: Tester document $testerId has existing authUid "${existingTester.authUid}", '
            'current authUid is "$authUid". Existing authUid will be preserved.',
          );
        }

        final updatedData = <String, dynamic>{
          'lastSeen': nowUtc.toIso8601String(),
          'platform': envInfo.platform,
          'deviceModel': envInfo.deviceModel,
          'osVersion': envInfo.osVersion,
          'appVersion': envInfo.appVersion,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await docRef.update(updatedData);
        errorHandler.log('Updated existing tester document: testers/$testerId');

        return existingTester.copyWith(
          lastSeen: nowUtc,
          platform: envInfo.platform,
          deviceModel: envInfo.deviceModel,
          osVersion: envInfo.osVersion,
          appVersion: envInfo.appVersion,
        );
      }
    },
        operationName: 'FirestoreRepository.syncTesterProfile',
        fallbackValue: null);
  }

  /// Fetches the tester profile document if it exists.
  Future<TesterData?> getTesterProfile(String testerId) async {
    return await errorHandler.runGuarded<TesterData?>(() async {
      final docSnap = await _testerDoc(testerId).get();
      if (!docSnap.exists || docSnap.data() == null) return null;
      return TesterData.fromMap(docSnap.data()!);
    },
        operationName: 'FirestoreRepository.getTesterProfile',
        fallbackValue: null);
  }

  /// Creates a new in-progress session document in Firestore.
  ///
  /// Idempotent: If the document already exists, leaves it untouched.
  Future<bool> createSession(SessionData session) async {
    return await errorHandler.runGuarded<bool>(() async {
          final docRef = _sessionDoc(session.testerId, session.sessionId);
          final docSnap = await docRef.get();
          if (docSnap.exists) {
            errorHandler.log(
                'Session ${session.sessionId} already exists in Firestore.');
            return true;
          }

          final data = session.toMap();
          data['updatedAt'] = FieldValue.serverTimestamp();

          await docRef.set(data);
          errorHandler.log(
              'Created session document: testers/${session.testerId}/sessions/${session.sessionId}');
          return true;
        },
            operationName: 'FirestoreRepository.createSession',
            fallbackValue: false) ??
        false;
  }

  /// Synchronizes in-progress session duration to Firestore.
  ///
  /// Uses absolute duration value to prevent duplicate counting during retries.
  Future<bool> updateSessionProgress({
    required String testerId,
    required String sessionId,
    required int durationSeconds,
  }) async {
    return await errorHandler.runGuarded<bool>(() async {
          final docRef = _sessionDoc(testerId, sessionId);
          await docRef.update({
            'durationSeconds': durationSeconds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          errorHandler.log(
              'Synced session progress for $sessionId (duration: ${durationSeconds}s)');
          return true;
        },
            operationName: 'FirestoreRepository.updateSessionProgress',
            fallbackValue: false) ??
        false;
  }

  /// Finalizes an active session with its final observed end time and duration.
  ///
  /// Idempotent: Safely marks [isFinalized] true and updates the tester profile aggregates.
  Future<bool> finalizeSession({
    required String testerId,
    required String sessionId,
    required DateTime endedAt,
    required int durationSeconds,
    required String activeDate,
  }) async {
    return await errorHandler.runGuarded<bool>(() async {
          final docRef = _sessionDoc(testerId, sessionId);
          final sessionSnap = await docRef.get();

          if (!sessionSnap.exists || sessionSnap.data() == null) {
            errorHandler.log(
                'Cannot finalize session $sessionId: document not found in Firestore.');
            return false;
          }

          final existingSession = SessionData.fromMap(sessionSnap.data()!);
          if (existingSession.isFinalized) {
            errorHandler
                .log('Session $sessionId is already finalized. Skipping.');
            return true;
          }

          await docRef.update({
            'isFinalized': true,
            'endedAt': endedAt.toUtc().toIso8601String(),
            'durationSeconds': durationSeconds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          errorHandler.log(
              'Finalized session $sessionId (final duration: ${durationSeconds}s)');

          // Update tester summary aggregates idempotently
          await _updateTesterAggregatesOnSessionFinalized(
            testerId: testerId,
            sessionDurationSeconds: durationSeconds,
            activeDate: activeDate,
            endedAt: endedAt,
          );

          return true;
        },
            operationName: 'FirestoreRepository.finalizeSession',
            fallbackValue: false) ??
        false;
  }

  /// Updates tester summary aggregates upon session finalization.
  Future<void> _updateTesterAggregatesOnSessionFinalized({
    required String testerId,
    required int sessionDurationSeconds,
    required String activeDate,
    required DateTime endedAt,
  }) async {
    try {
      final testerRef = _testerDoc(testerId);
      final docSnap = await testerRef.get();
      if (!docSnap.exists || docSnap.data() == null) return;

      final tester = TesterData.fromMap(docSnap.data()!);

      // Bounded recent active dates (capped at maxRecentActiveDates, e.g. 30)
      final datesSet = <String>{...tester.recentActiveDates, activeDate};
      final updatedDates = datesSet.toList()..sort();
      if (updatedDates.length > TrackerConstants.maxRecentActiveDates) {
        updatedDates.removeRange(
            0, updatedDates.length - TrackerConstants.maxRecentActiveDates);
      }

      await testerRef.update({
        'lastSeen': endedAt.toUtc().toIso8601String(),
        'sessionCount': tester.sessionCount + 1,
        'totalUsageSeconds': tester.totalUsageSeconds + sessionDurationSeconds,
        'activeDaysCount': datesSet.length,
        'recentActiveDates': updatedDates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      errorHandler.log('Updated tester aggregates for $testerId.');
    } catch (e) {
      errorHandler.log('Failed to update tester aggregates: $e');
    }
  }

  /// Fetches a specific session document.
  Future<SessionData?> getSession(String testerId, String sessionId) async {
    return await errorHandler.runGuarded<SessionData?>(() async {
      final docSnap = await _sessionDoc(testerId, sessionId).get();
      if (!docSnap.exists || docSnap.data() == null) return null;
      return SessionData.fromMap(docSnap.data()!);
    }, operationName: 'FirestoreRepository.getSession', fallbackValue: null);
  }
}
