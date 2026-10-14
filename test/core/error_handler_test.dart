import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/core/error_handler.dart';

void main() {
  group('TrackerErrorHandler', () {
    test('runGuarded handles successful future cleanly', () async {
      final handler = TrackerErrorHandler(debugLogging: false);
      final result = await handler.runGuarded<int>(() async => 42);
      expect(result, equals(42));
    });

    test('runGuarded catches exceptions and returns fallback without throwing',
        () async {
      final handler = TrackerErrorHandler(debugLogging: false);
      final result = await handler.runGuarded<String>(
        () async => throw Exception('Simulated network crash'),
        operationName: 'testOperation',
        fallbackValue: 'safe_fallback',
      );
      expect(result, equals('safe_fallback'));
    });

    test('circuit breaker suppresses subsequent operations', () async {
      final handler = TrackerErrorHandler(debugLogging: false);
      expect(handler.isCircuitBroken, isFalse);

      handler.tripCircuitBreaker('Firestore unreachable');
      expect(handler.isCircuitBroken, isTrue);

      bool executed = false;
      final result = await handler.runGuarded<String>(
        () async {
          executed = true;
          return 'done';
        },
        fallbackValue: 'fallback',
      );

      expect(executed, isFalse);
      expect(result, equals('fallback'));
    });

    test('runGuardedSync catches synchronous exceptions without throwing', () {
      final handler = TrackerErrorHandler(debugLogging: false);
      final result = handler.runGuardedSync<int>(
        () => throw StateError('Sync failure'),
        fallbackValue: -1,
      );
      expect(result, equals(-1));
    });

    test('isFatalFirebaseError correctly identifies deleted/invalid project errors', () {
      expect(TrackerErrorHandler.isFatalFirebaseError(
        'An internal error has occurred. [ API key not valid. Please pass a valid API key. ]',
      ), isTrue);
      expect(TrackerErrorHandler.isFatalFirebaseError(
        'Status{code=PERMISSION_DENIED, description=Permission denied on resource project my-proj., cause=null}',
      ), isTrue);
      expect(TrackerErrorHandler.isFatalFirebaseError('project-not-found'), isTrue);
      expect(TrackerErrorHandler.isFatalFirebaseError('app-deleted'), isTrue);
      expect(TrackerErrorHandler.isFatalFirebaseError('admin-restricted-operation'), isTrue);

      // Transient errors should not be flagged as fatal
      expect(TrackerErrorHandler.isFatalFirebaseError('network-request-failed'), isFalse);
      expect(TrackerErrorHandler.isFatalFirebaseError('unavailable'), isFalse);
      expect(TrackerErrorHandler.isFatalFirebaseError('deadline-exceeded'), isFalse);
    });

    test('runGuarded automatically trips circuit breaker on fatal Firebase error', () async {
      final handler = TrackerErrorHandler(debugLogging: false);
      expect(handler.isCircuitBroken, isFalse);

      final result = await handler.runGuarded<String>(
        () async => throw Exception('API key not valid. Please pass a valid API key.'),
        operationName: 'FirebaseAuth.signInAnonymously',
        fallbackValue: 'fallback',
      );

      expect(result, equals('fallback'));
      expect(handler.isCircuitBroken, isTrue);

      // Next call should be skipped
      bool nextExecuted = false;
      await handler.runGuarded<void>(() async {
        nextExecuted = true;
      });
      expect(nextExecuted, isFalse);
    });
  });
}
