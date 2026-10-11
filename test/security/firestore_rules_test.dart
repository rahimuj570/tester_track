import 'package:flutter_test/flutter_test.dart';

/// Evaluates the logic of Firestore Security Rules modeled in `firestore.rules`.
class SecurityRulesEvaluator {
  final Map<String, dynamic>?
      auth; // null, or { 'uid': '...', 'token': { 'firebase': { 'sign_in_provider': '...' } } }

  SecurityRulesEvaluator({this.auth});

  static const Set<String> developerAllowlist = {
    'dev_owner_uid_1',
    'dev_user_123',
    'dev_uid_google_123',
    'dev_123',
    'dev_user_1',
  };

  bool isDeveloper() {
    if (auth == null) return false;
    final token = auth!['token'] as Map<String, dynamic>?;
    final firebase = token?['firebase'] as Map<String, dynamic>?;
    final provider = firebase?['sign_in_provider'] as String?;
    final uid = auth!['uid'] as String?;
    return provider != null &&
        provider != 'anonymous' &&
        uid != null &&
        developerAllowlist.contains(uid);
  }

  bool isAnonymousTester() {
    if (auth == null) return false;
    final token = auth!['token'] as Map<String, dynamic>?;
    final firebase = token?['firebase'] as Map<String, dynamic>?;
    final provider = firebase?['sign_in_provider'] as String?;
    return provider == 'anonymous';
  }

  // match /config/global
  bool canReadConfig() => auth != null;
  bool canWriteConfig() => isDeveloper();

  // match /testers/{testerId}
  bool canCreateTester({
    required String testerId,
    required Map<String, dynamic> requestResourceData,
  }) {
    if (!isAnonymousTester()) return false;
    final authUid = auth!['uid'];
    return requestResourceData['authUid'] == authUid &&
        requestResourceData['testerId'] == testerId;
  }

  bool canUpdateTester({
    required String testerId,
    required Map<String, dynamic> resourceData,
    required Map<String, dynamic> requestResourceData,
  }) {
    if (!isAnonymousTester()) return false;
    final authUid = auth!['uid'];
    return resourceData['authUid'] == authUid &&
        requestResourceData['authUid'] == resourceData['authUid'] &&
        requestResourceData['testerId'] == resourceData['testerId'];
  }

  bool canReadTester({
    required String testerId,
    required Map<String, dynamic> resourceData,
  }) {
    if (isDeveloper()) return true;
    if (auth == null) return false;
    return resourceData['authUid'] == auth!['uid'];
  }

  bool canDeleteTester() => false;

  // match /testers/{testerId}/sessions/{sessionId}
  bool canCreateSession({
    required String testerId,
    required String sessionId,
    required Map<String, dynamic> requestResourceData,
    Map<String, dynamic>? parentTesterDoc,
  }) {
    if (!isAnonymousTester()) return false;
    final authUid = auth!['uid'];
    final matchesAuth = requestResourceData['authUid'] == authUid &&
        requestResourceData['testerId'] == testerId &&
        requestResourceData['sessionId'] == sessionId;
    if (!matchesAuth) return false;
    if (parentTesterDoc != null && parentTesterDoc['authUid'] != authUid) {
      return false;
    }
    return true;
  }

  bool canUpdateSession({
    required String testerId,
    required String sessionId,
    required Map<String, dynamic> resourceData,
    required Map<String, dynamic> requestResourceData,
  }) {
    if (!isAnonymousTester()) return false;
    final authUid = auth!['uid'];
    return resourceData['authUid'] == authUid &&
        requestResourceData['authUid'] == resourceData['authUid'] &&
        requestResourceData['testerId'] == resourceData['testerId'] &&
        requestResourceData['sessionId'] == resourceData['sessionId'];
  }

  bool canReadSession({
    required String testerId,
    required Map<String, dynamic> resourceData,
  }) {
    if (isDeveloper()) return true;
    if (auth == null) return false;
    return resourceData['authUid'] == auth!['uid'];
  }

  bool canDeleteSession() => false;
}

void main() {
  group('Firestore Security Rules Logic', () {
    final anonTester1 = SecurityRulesEvaluator(
      auth: {
        'uid': 'anon_uid_1',
        'token': {
          'firebase': {'sign_in_provider': 'anonymous'}
        }
      },
    );

    final anonTester2 = SecurityRulesEvaluator(
      auth: {
        'uid': 'anon_uid_2',
        'token': {
          'firebase': {'sign_in_provider': 'anonymous'}
        }
      },
    );

    final developer = SecurityRulesEvaluator(
      auth: {
        'uid': 'dev_uid_google_123',
        'token': {
          'firebase': {'sign_in_provider': 'google.com'}
        }
      },
    );

    final unauthenticated = SecurityRulesEvaluator(auth: null);

    test('A. Anonymous tester can create its own tester document', () {
      final canCreate = anonTester1.canCreateTester(
        testerId: 'T001',
        requestResourceData: {
          'testerId': 'T001',
          'authUid': 'anon_uid_1',
          'platform': 'android',
        },
      );
      expect(canCreate, isTrue);
    });

    test(
        'B. Anonymous tester cannot create another tester document or mismatch authUid',
        () {
      // Mismatched authUid
      final spoofAuth = anonTester1.canCreateTester(
        testerId: 'T001',
        requestResourceData: {
          'testerId': 'T001',
          'authUid': 'victim_uid',
        },
      );
      expect(spoofAuth, isFalse);

      // Mismatched testerId in path vs payload
      final mismatchTesterId = anonTester1.canCreateTester(
        testerId: 'T001',
        requestResourceData: {
          'testerId': 'T002',
          'authUid': 'anon_uid_1',
        },
      );
      expect(mismatchTesterId, isFalse);
    });

    test(
        'C. Anonymous tester can update allowed fields of its own tester document',
        () {
      final canUpdate = anonTester1.canUpdateTester(
        testerId: 'T001',
        resourceData: {
          'testerId': 'T001',
          'authUid': 'anon_uid_1',
          'appVersion': '1.0.0',
        },
        requestResourceData: {
          'testerId': 'T001',
          'authUid': 'anon_uid_1',
          'appVersion': '1.1.0',
        },
      );
      expect(canUpdate, isTrue);
    });

    test('D. Anonymous tester cannot change authUid or testerId during update',
        () {
      final changeAuthUid = anonTester1.canUpdateTester(
        testerId: 'T001',
        resourceData: {
          'testerId': 'T001',
          'authUid': 'anon_uid_1',
        },
        requestResourceData: {
          'testerId': 'T001',
          'authUid': 'hacked_auth_uid',
        },
      );
      expect(changeAuthUid, isFalse);

      final changeTesterId = anonTester1.canUpdateTester(
        testerId: 'T001',
        resourceData: {
          'testerId': 'T001',
          'authUid': 'anon_uid_1',
        },
        requestResourceData: {
          'testerId': 'T002_TAMPERED',
          'authUid': 'anon_uid_1',
        },
      );
      expect(changeTesterId, isFalse);
    });

    test('E. Anonymous tester cannot read another tester document', () {
      final docTester1 = {'testerId': 'T001', 'authUid': 'anon_uid_1'};

      // Own read
      expect(
          anonTester1.canReadTester(testerId: 'T001', resourceData: docTester1),
          isTrue);

      // Other tester read
      expect(
          anonTester2.canReadTester(testerId: 'T001', resourceData: docTester1),
          isFalse);

      // Unauthenticated read
      expect(
          unauthenticated.canReadTester(
              testerId: 'T001', resourceData: docTester1),
          isFalse);
    });

    test('G. Anonymous tester can create and access only its own session path',
        () {
      final canCreateSession = anonTester1.canCreateSession(
        testerId: 'T001',
        sessionId: 'sess_1',
        requestResourceData: {
          'testerId': 'T001',
          'sessionId': 'sess_1',
          'authUid': 'anon_uid_1',
          'durationSeconds': 120,
        },
      );
      expect(canCreateSession, isTrue);

      final sessionDoc = {
        'testerId': 'T001',
        'sessionId': 'sess_1',
        'authUid': 'anon_uid_1',
      };
      expect(
          anonTester1.canReadSession(
              testerId: 'T001', resourceData: sessionDoc),
          isTrue);
    });

    test('H. Cross-tester session creation/read/update is rejected', () {
      final parentTester1Doc = {'testerId': 'T001', 'authUid': 'anon_uid_1'};

      // Tester 2 tries to write to Tester 1's session
      final crossCreate = anonTester2.canCreateSession(
        testerId: 'T001',
        sessionId: 'sess_1',
        parentTesterDoc: parentTester1Doc,
        requestResourceData: {
          'testerId': 'T001',
          'sessionId': 'sess_1',
          'authUid': 'anon_uid_2',
        },
      );
      expect(crossCreate, isFalse);

      final sessionDocTester1 = {
        'testerId': 'T001',
        'sessionId': 'sess_1',
        'authUid': 'anon_uid_1',
      };
      expect(
          anonTester2.canReadSession(
              testerId: 'T001', resourceData: sessionDocTester1),
          isFalse);
      expect(
        anonTester2.canUpdateSession(
          testerId: 'T001',
          sessionId: 'sess_1',
          resourceData: sessionDocTester1,
          requestResourceData: sessionDocTester1,
        ),
        isFalse,
      );
    });

    test(
        'I. Developer access: read all, write config/global, no delete/tampering',
        () {
      final testerDoc = {'testerId': 'T001', 'authUid': 'anon_uid_1'};
      final sessionDoc = {
        'testerId': 'T001',
        'sessionId': 'sess_1',
        'authUid': 'anon_uid_1'
      };

      // Developer can read tester and session
      expect(developer.canReadTester(testerId: 'T001', resourceData: testerDoc),
          isTrue);
      expect(
          developer.canReadSession(testerId: 'T001', resourceData: sessionDoc),
          isTrue);

      // Developer can write config/global
      expect(developer.canWriteConfig(), isTrue);
      expect(anonTester1.canWriteConfig(), isFalse);

      // Developer cannot create or update tester or session
      expect(
        developer.canCreateTester(
          testerId: 'T001',
          requestResourceData: {
            'testerId': 'T001',
            'authUid': 'dev_uid_google_123'
          },
        ),
        isFalse,
      );
      expect(
        developer.canUpdateTester(
          testerId: 'T001',
          resourceData: testerDoc,
          requestResourceData: testerDoc,
        ),
        isFalse,
      );

      // Developer cannot delete tester or session in MVP
      expect(developer.canDeleteTester(), isFalse);
      expect(developer.canDeleteSession(), isFalse);
    });

    test('J. Signed-in user NOT on allowlist is denied developer access', () {
      final nonAllowlistedUser = SecurityRulesEvaluator(
        auth: {
          'uid': 'stranger_uid_not_on_list',
          'token': {
            'firebase': {'sign_in_provider': 'google.com'}
          }
        },
      );

      final testerDoc = {'testerId': 'T001', 'authUid': 'anon_uid_1'};
      final sessionDoc = {
        'testerId': 'T001',
        'sessionId': 'sess_1',
        'authUid': 'anon_uid_1'
      };

      // Non-allowlisted user cannot read others' tester/session docs or write config
      expect(
        nonAllowlistedUser.canReadTester(
          testerId: 'T001',
          resourceData: testerDoc,
        ),
        isFalse,
      );
      expect(
        nonAllowlistedUser.canReadSession(
          testerId: 'T001',
          resourceData: sessionDoc,
        ),
        isFalse,
      );
      expect(nonAllowlistedUser.canWriteConfig(), isFalse);
      expect(nonAllowlistedUser.canReadConfig(), isTrue);
    });
  });
}
