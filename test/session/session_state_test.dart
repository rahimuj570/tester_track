import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/session/session_state.dart';

void main() {
  group('SessionState', () {
    test('observedDurationSeconds returns accumulatedDurationSeconds', () {
      final started = DateTime.utc(2026, 10, 8, 10, 0, 0);
      final lastHeartbeat = DateTime.utc(2026, 10, 8, 10, 4, 45);

      final state = SessionState(
        sessionId: 'sess_T001_1728381600000',
        testerId: 'T001',
        authUid: 'uid_123',
        startedAt: started,
        lastHeartbeatAt: lastHeartbeat,
        accumulatedDurationSeconds: 285,
        appVersion: '1.0.0 (1)',
        platform: 'android',
        isFinalized: false,
      );

      // Duration must be exact 285s
      expect(state.observedDurationSeconds, equals(285));
      expect(state.activeDate, equals('2026-10-08'));
    });

    test('observedDurationSeconds clamps negative values to 0', () {
      final started = DateTime.utc(2026, 10, 8, 10, 0, 0);

      final state = SessionState(
        sessionId: 'sess_T001_123',
        testerId: 'T001',
        authUid: 'uid_123',
        startedAt: started,
        lastHeartbeatAt: started,
        accumulatedDurationSeconds: -10,
        appVersion: '1.0.0',
        platform: 'android',
        isFinalized: false,
      );

      expect(state.observedDurationSeconds, equals(0));
    });

    test('json serialization and deserialization roundtrip', () {
      final started = DateTime.utc(2026, 10, 8, 9, 30, 0);
      final lastHeartbeat = DateTime.utc(2026, 10, 8, 9, 45, 15);

      final original = SessionState(
        sessionId: 'sess_T001_1728381600000',
        testerId: 'T001',
        authUid: 'uid_123',
        startedAt: started,
        lastHeartbeatAt: lastHeartbeat,
        accumulatedDurationSeconds: 915,
        appVersion: '1.2.0 (42)',
        platform: 'ios',
        isFinalized: false,
      );

      final jsonStr = original.toJson();
      final restored = SessionState.fromJson(jsonStr);

      expect(restored, equals(original));
      expect(restored.sessionId, equals('sess_T001_1728381600000'));
      expect(restored.observedDurationSeconds, equals(915));
      expect(restored.activeDate, equals('2026-10-08'));
    });
  });
}
