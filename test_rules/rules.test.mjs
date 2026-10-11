import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
} from 'firebase/firestore';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PROJECT_ID = 'tester-track-emulator-test';
const rules = readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8');

describe('Firestore Security Rules Real Emulator Suite', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules,
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  function getAnonTesterContext(uid = 'anon_tester_1') {
    return testEnv.authenticatedContext(uid, {
      provider_id: 'anonymous',
      firebase: { sign_in_provider: 'anonymous' },
    });
  }

  // Allowlisted developer UIDs configured in firestore.rules: 'dev_owner_uid_1', 'dev_user_123', 'dev_123', 'dev_user_1'
  function getAllowlistedDeveloperContext(uid = 'dev_user_123') {
    return testEnv.authenticatedContext(uid, {
      provider_id: 'google.com',
      firebase: { sign_in_provider: 'google.com' },
    });
  }

  // Signed-in non-anonymous user NOT on the allowlist
  function getNonAllowlistedUserContext(uid = 'unauthorized_stranger_999') {
    return testEnv.authenticatedContext(uid, {
      provider_id: 'google.com',
      firebase: { sign_in_provider: 'google.com' },
    });
  }

  function getUnauthenticatedContext() {
    return testEnv.unauthenticatedContext();
  }

  describe('1. Global Remote Configuration (config/global)', () => {
    it('allows all authenticated users (anonymous testers, allowlisted developers, non-allowlisted users) to read config', async () => {
      // Seed config using admin context
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'config/global'), {
          enabled: true,
          minAppVersion: '1.0.0',
          syncIntervalSeconds: 300,
        });
      });

      const anonDb = getAnonTesterContext('anon_tester_1').firestore();
      await assertSucceeds(getDoc(doc(anonDb, 'config/global')));

      const devDb = getAllowlistedDeveloperContext('dev_user_1').firestore();
      await assertSucceeds(getDoc(doc(devDb, 'config/global')));

      const nonAllowlistedDb = getNonAllowlistedUserContext('stranger_999').firestore();
      await assertSucceeds(getDoc(doc(nonAllowlistedDb, 'config/global')));
    });

    it('denies unauthenticated users from reading config', async () => {
      const unauthDb = getUnauthenticatedContext().firestore();
      await assertFails(getDoc(doc(unauthDb, 'config/global')));
    });

    it('allows allowlisted developer to write/update remote configuration', async () => {
      const devDb = getAllowlistedDeveloperContext('dev_user_1').firestore();
      await assertSucceeds(
        setDoc(doc(devDb, 'config/global'), {
          enabled: false,
          syncIntervalSeconds: 600,
        })
      );
    });

    it('denies signed-in but non-allowlisted user from writing remote configuration', async () => {
      const strangerDb = getNonAllowlistedUserContext('stranger_999').firestore();
      await assertFails(
        setDoc(doc(strangerDb, 'config/global'), {
          enabled: false,
          syncIntervalSeconds: 600,
        })
      );
    });

    it('denies anonymous tester from writing/updating remote configuration', async () => {
      const anonDb = getAnonTesterContext('anon_tester_1').firestore();
      await assertFails(
        setDoc(doc(anonDb, 'config/global'), {
          enabled: false,
          syncIntervalSeconds: 600,
        })
      );
    });

    it('denies unauthenticated user from writing remote configuration', async () => {
      const unauthDb = getUnauthenticatedContext().firestore();
      await assertFails(
        setDoc(doc(unauthDb, 'config/global'), {
          enabled: false,
        })
      );
    });
  });

  describe('2. Anonymous Tester Profile (testers/{testerId})', () => {
    it('allows anonymous tester to create their own tester document matching authUid and testerId', async () => {
      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertSucceeds(
        setDoc(doc(anonDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          platform: 'android',
          deviceModel: 'Pixel 7',
          osVersion: 'Android 14',
          appVersion: '1.0.0',
          firstSeen: new Date().toISOString(),
          lastSeen: new Date().toISOString(),
          sessionCount: 0,
          totalUsageSeconds: 0,
          activeDaysCount: 0,
          recentActiveDates: [],
        })
      );
    });

    it('denies tester from creating document where authUid does not match request.auth.uid', async () => {
      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertFails(
        setDoc(doc(anonDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'victim_anon_uid_200',
          platform: 'android',
        })
      );
    });

    it('denies tester from creating document where testerId in payload does not match document ID in path', async () => {
      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertFails(
        setDoc(doc(anonDb, 'testers/T100'), {
          testerId: 'T999_MISMATCH',
          authUid: 'anon_uid_100',
          platform: 'android',
        })
      );
    });

    it('allows tester to read their own tester document', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          platform: 'android',
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertSucceeds(getDoc(doc(anonDb, 'testers/T100')));
    });

    it('denies tester from reading another tester document', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          platform: 'android',
        });
      });

      const otherAnonDb = getAnonTesterContext('anon_uid_200').firestore();
      await assertFails(getDoc(doc(otherAnonDb, 'testers/T100')));
    });

    it('denies anonymous tester from enumerating/querying all testers', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), { testerId: 'T100', authUid: 'anon_uid_100' });
        await setDoc(doc(adminDb, 'testers/T200'), { testerId: 'T200', authUid: 'anon_uid_200' });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertFails(getDocs(collection(anonDb, 'testers')));
    });

    it('allows tester to update mutable fields of their own tester document', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          appVersion: '1.0.0',
          lastSeen: '2026-10-01T00:00:00.000Z',
          sessionCount: 1,
          totalUsageSeconds: 120,
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertSucceeds(
        updateDoc(doc(anonDb, 'testers/T100'), {
          appVersion: '1.1.0',
          lastSeen: '2026-10-02T00:00:00.000Z',
          sessionCount: 2,
          totalUsageSeconds: 240,
        })
      );
    });

    it('denies tester from changing immutable authUid or testerId during update', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          appVersion: '1.0.0',
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      // Try to change authUid
      await assertFails(
        updateDoc(doc(anonDb, 'testers/T100'), {
          authUid: 'hacked_auth_uid',
        })
      );

      // Try to change testerId
      await assertFails(
        updateDoc(doc(anonDb, 'testers/T100'), {
          testerId: 'T999_TAMPERED',
        })
      );
    });

    it('denies anonymous tester and developer from deleting tester documents', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertFails(deleteDoc(doc(anonDb, 'testers/T100')));

      const devDb = getAllowlistedDeveloperContext('dev_user_1').firestore();
      await assertFails(deleteDoc(doc(devDb, 'testers/T100')));
    });
  });

  describe('3. Sessions (testers/{testerId}/sessions/{sessionId})', () => {
    beforeEach(async () => {
      // Seed parent tester doc
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          platform: 'android',
        });
        await setDoc(doc(adminDb, 'testers/T200'), {
          testerId: 'T200',
          authUid: 'anon_uid_200',
          platform: 'ios',
        });
      });
    });

    it('allows tester to create session under their own tester doc with matching authUid, testerId, and sessionId', async () => {
      const anonDb = getAnonTesterContext('anon_uid_100').firestore();
      await assertSucceeds(
        setDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          sessionId: 'sess_1',
          testerId: 'T100',
          authUid: 'anon_uid_100',
          startedAt: new Date().toISOString(),
          endedAt: null,
          durationSeconds: 0,
          activeDate: '2026-10-10',
          appVersion: '1.0.0',
          platform: 'android',
          isFinalized: false,
        })
      );
    });

    it('denies session creation under a parent tester doc owned by a different authUid', async () => {
      const anonDb200 = getAnonTesterContext('anon_uid_200').firestore();
      // Tester 200 attempts to create session under T100 (owned by 100)
      await assertFails(
        setDoc(doc(anonDb200, 'testers/T100/sessions/sess_hijack'), {
          sessionId: 'sess_hijack',
          testerId: 'T100',
          authUid: 'anon_uid_200',
          startedAt: new Date().toISOString(),
          durationSeconds: 0,
          isFinalized: false,
        })
      );
    });

    it('denies session creation under a nonexistent parent tester doc', async () => {
      const anonDb999 = getAnonTesterContext('anon_uid_999').firestore();
      await assertFails(
        setDoc(doc(anonDb999, 'testers/T999_NONEXISTENT/sessions/sess_1'), {
          sessionId: 'sess_1',
          testerId: 'T999_NONEXISTENT',
          authUid: 'anon_uid_999',
          startedAt: new Date().toISOString(),
          durationSeconds: 0,
          isFinalized: false,
        })
      );
    });

    it('allows tester to read their own session and update progress / finalize session', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100/sessions/sess_1'), {
          sessionId: 'sess_1',
          testerId: 'T100',
          authUid: 'anon_uid_100',
          durationSeconds: 0,
          isFinalized: false,
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();

      // Read own session
      await assertSucceeds(getDoc(doc(anonDb, 'testers/T100/sessions/sess_1')));

      // Update progress
      await assertSucceeds(
        updateDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          durationSeconds: 60,
        })
      );

      // Finalize session
      await assertSucceeds(
        updateDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          durationSeconds: 180,
          isFinalized: true,
          endedAt: new Date().toISOString(),
        })
      );
    });

    it('denies cross-tester session read, update, or delete', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100/sessions/sess_1'), {
          sessionId: 'sess_1',
          testerId: 'T100',
          authUid: 'anon_uid_100',
          durationSeconds: 10,
          isFinalized: false,
        });
      });

      const otherAnonDb = getAnonTesterContext('anon_uid_200').firestore();

      // Read
      await assertFails(getDoc(doc(otherAnonDb, 'testers/T100/sessions/sess_1')));

      // Update
      await assertFails(
        updateDoc(doc(otherAnonDb, 'testers/T100/sessions/sess_1'), {
          durationSeconds: 9999,
        })
      );

      // Delete
      await assertFails(deleteDoc(doc(otherAnonDb, 'testers/T100/sessions/sess_1')));
    });

    it('denies changing immutable session fields (sessionId, testerId, authUid) during update', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100/sessions/sess_1'), {
          sessionId: 'sess_1',
          testerId: 'T100',
          authUid: 'anon_uid_100',
          durationSeconds: 10,
          isFinalized: false,
        });
      });

      const anonDb = getAnonTesterContext('anon_uid_100').firestore();

      await assertFails(
        updateDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          sessionId: 'sess_2_TAMPERED',
        })
      );

      await assertFails(
        updateDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          authUid: 'different_auth_uid',
        })
      );

      await assertFails(
        updateDoc(doc(anonDb, 'testers/T100/sessions/sess_1'), {
          testerId: 'T200_TAMPERED',
        })
      );
    });
  });

  describe('4. Developer Dashboard Access & Owner Authorization', () => {
    beforeEach(async () => {
      // Seed testers and sessions
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), {
          testerId: 'T100',
          authUid: 'anon_uid_100',
          sessionCount: 5,
        });
        await setDoc(doc(adminDb, 'testers/T200'), {
          testerId: 'T200',
          authUid: 'anon_uid_200',
          sessionCount: 3,
        });
        await setDoc(doc(adminDb, 'testers/T100/sessions/s1'), {
          sessionId: 's1',
          testerId: 'T100',
          authUid: 'anon_uid_100',
          durationSeconds: 300,
        });
      });
    });

    it('allows allowlisted developer to read any tester document and enumerate all testers', async () => {
      const devDb = getAllowlistedDeveloperContext('dev_123').firestore();

      // Read single tester
      await assertSucceeds(getDoc(doc(devDb, 'testers/T100')));
      await assertSucceeds(getDoc(doc(devDb, 'testers/T200')));

      // Enumerate / list all testers collection
      await assertSucceeds(getDocs(collection(devDb, 'testers')));
    });

    it('allows allowlisted developer to read any session document', async () => {
      const devDb = getAllowlistedDeveloperContext('dev_123').firestore();
      await assertSucceeds(getDoc(doc(devDb, 'testers/T100/sessions/s1')));
      await assertSucceeds(getDocs(collection(devDb, 'testers/T100/sessions')));
    });

    it('denies signed-in non-allowlisted user from reading tester/session data or enumerating testers', async () => {
      const strangerDb = getNonAllowlistedUserContext('unauthorized_stranger_999').firestore();

      // Read single tester doc
      await assertFails(getDoc(doc(strangerDb, 'testers/T100')));
      await assertFails(getDoc(doc(strangerDb, 'testers/T200')));

      // List all testers
      await assertFails(getDocs(collection(strangerDb, 'testers')));

      // Read session
      await assertFails(getDoc(doc(strangerDb, 'testers/T100/sessions/s1')));
      await assertFails(getDocs(collection(strangerDb, 'testers/T100/sessions')));
    });

    it('denies allowlisted developer from creating, modifying, or deleting tester documents (viewer role)', async () => {
      const devDb = getAllowlistedDeveloperContext('dev_123').firestore();

      // Create tester doc
      await assertFails(
        setDoc(doc(devDb, 'testers/T_DEV'), {
          testerId: 'T_DEV',
          authUid: 'dev_123',
        })
      );

      // Modify tester doc
      await assertFails(
        updateDoc(doc(devDb, 'testers/T100'), {
          sessionCount: 999,
        })
      );

      // Delete tester doc
      await assertFails(deleteDoc(doc(devDb, 'testers/T100')));
    });

    it('denies allowlisted developer from creating, modifying, or deleting session documents', async () => {
      const devDb = getAllowlistedDeveloperContext('dev_123').firestore();

      // Create session
      await assertFails(
        setDoc(doc(devDb, 'testers/T100/sessions/s_dev'), {
          sessionId: 's_dev',
          testerId: 'T100',
          authUid: 'dev_123',
        })
      );

      // Modify session
      await assertFails(
        updateDoc(doc(devDb, 'testers/T100/sessions/s1'), {
          durationSeconds: 0,
        })
      );

      // Delete session
      await assertFails(deleteDoc(doc(devDb, 'testers/T100/sessions/s1')));
    });
  });

  describe('5. Unauthenticated & Invalid Access', () => {
    it('denies unauthenticated access to testers and sessions', async () => {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        await setDoc(doc(adminDb, 'testers/T100'), { testerId: 'T100', authUid: 'anon_100' });
        await setDoc(doc(adminDb, 'testers/T100/sessions/s1'), { sessionId: 's1', authUid: 'anon_100' });
      });

      const unauthDb = getUnauthenticatedContext().firestore();

      await assertFails(getDoc(doc(unauthDb, 'testers/T100')));
      await assertFails(getDoc(doc(unauthDb, 'testers/T100/sessions/s1')));
      await assertFails(getDocs(collection(unauthDb, 'testers')));
    });

    it('denies access to arbitrary unmapped root collections', async () => {
      const anonDb = getAnonTesterContext('anon_1').firestore();
      const devDb = getAllowlistedDeveloperContext('dev_1').firestore();

      await assertFails(getDoc(doc(anonDb, 'secrets/key')));
      await assertFails(setDoc(doc(anonDb, 'secrets/key'), { val: 1 }));
      await assertFails(getDoc(doc(devDb, 'secrets/key')));
      await assertFails(setDoc(doc(devDb, 'secrets/key'), { val: 1 }));
    });
  });
});
