import 'dart:async';
import 'package:flutter/foundation.dart';

/// Central error handler and safe async executor for TesterTrack.
///
/// Guarantees that internal tracking errors, timeouts, or network failures
/// never throw uncaught exceptions or crash the host application.
class TrackerErrorHandler {
  final bool debugLogging;
  bool _isCircuitBroken = false;

  TrackerErrorHandler({this.debugLogging = false});

  /// Whether the circuit breaker is active (e.g. fatal Firebase configuration / project deleted).
  bool get isCircuitBroken => _isCircuitBroken;

  /// Activates the circuit breaker to prevent repeated futile network attempts.
  void tripCircuitBreaker(String reason) {
    _isCircuitBroken = true;
    log('Circuit breaker tripped: $reason');
  }

  /// Logs a message to [debugPrint] only if [debugLogging] is enabled.
  void log(String message) {
    if (debugLogging) {
      debugPrint('[TesterTrack] $message');
    }
  }

  /// Safely executes an asynchronous operation without throwing to the host app.
  Future<T?> runGuarded<T>(
    Future<T> Function() action, {
    String? operationName,
    T? fallbackValue,
  }) async {
    if (_isCircuitBroken) {
      log('Skipping operation "${operationName ?? 'unnamed'}" because circuit breaker is active.');
      return fallbackValue;
    }

    try {
      return await action();
    } catch (error, stackTrace) {
      log('Error during "${operationName ?? 'unnamed'}": $error\n$stackTrace');
      return fallbackValue;
    }
  }

  /// Safely executes a synchronous operation without throwing to the host app.
  T? runGuardedSync<T>(
    T Function() action, {
    String? operationName,
    T? fallbackValue,
  }) {
    if (_isCircuitBroken) {
      log('Skipping sync operation "${operationName ?? 'unnamed'}" because circuit breaker is active.');
      return fallbackValue;
    }

    try {
      return action();
    } catch (error, stackTrace) {
      log('Error during "${operationName ?? 'unnamed'}": $error\n$stackTrace');
      return fallbackValue;
    }
  }
}
