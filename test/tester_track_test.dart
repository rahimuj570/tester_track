import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/tester_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TesterTrack Public API', () {
    test('initial state before initialize', () {
      final tracker = TesterTrack.instance;
      expect(tracker.isInitialized, isFalse);
      expect(tracker.isTracking, isFalse);
    });

    test('TesterTrackOptions has correct defaults', () {
      const options = TesterTrackOptions();
      expect(options.debugLogging, isFalse);
      expect(
          options.localHeartbeatInterval, equals(const Duration(seconds: 15)));
      expect(options.firestoreSyncInterval, equals(const Duration(minutes: 5)));
      expect(options.inactivityDebounce, equals(const Duration(seconds: 15)));
      expect(options.sessionTimeout, equals(const Duration(minutes: 30)));
    });

    test('startTracking does not throw even when not initialized', () {
      final tracker = TesterTrack.instance;
      expect(() => tracker.startTracking(), returnsNormally);
      expect(tracker.isTracking, isFalse);
    });

    test('stopTracking does not throw', () {
      final tracker = TesterTrack.instance;
      expect(() => tracker.stopTracking(), returnsNormally);
      expect(tracker.isTracking, isFalse);
    });

    test('setTesterId and resetTesterId do not throw when not initialized', () async {
      final tracker = TesterTrack.instance;
      final result1 = await tracker.setTesterId('alex@example.com');
      expect(result1, isFalse);
      final result2 = await tracker.resetTesterId();
      expect(result2, isFalse);
    });

    test('initialize returns false gracefully without throwing when Firebase is invalid or unavailable', () async {
      final tracker = TesterTrack.instance;
      final success = await TesterTrack.initialize(
        firebaseOptions: const FirebaseOptions(
          apiKey: 'invalid_key',
          appId: 'invalid_app',
          messagingSenderId: '123',
          projectId: 'deleted-project-123',
        ),
      );

      expect(success, isFalse);
      expect(tracker.isInitialized, isFalse);
      expect(tracker.isTracking, isFalse);
    });
  });
}
