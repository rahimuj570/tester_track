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
  });
}
