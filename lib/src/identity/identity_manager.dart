import 'dart:math';
import '../core/error_handler.dart';
import '../storage/local_storage.dart';

/// Manages resolution, validation, and persistent generation of tester identities.
///
/// NOTE: Generated anonymous tester identifiers represent unique app installations,
/// not necessarily individual human users or physical hardware units.
class IdentityManager {
  final LocalStorage localStorage;
  final TrackerErrorHandler errorHandler;

  static final RegExp _validTesterIdRegex =
      RegExp(r'^[a-zA-Z0-9._%+@\-]{1,128}$');

  IdentityManager({
    required this.localStorage,
    required this.errorHandler,
  });

  /// Validates an explicit developer-provided tester ID (such as an email or alphanumeric ID).
  ///
  /// Returns `true` if the ID is 1-128 characters long, contains only safe
  /// characters (alphanumeric, underscores, hyphens, periods, plus, at-sign),
  /// and is not a reserved Firestore segment (`.` or `..` or starting with `__`).
  static bool isValidTesterId(String? testerId) {
    if (testerId == null) return false;
    final trimmed = testerId.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..' || trimmed.startsWith('__')) {
      return false;
    }
    return _validTesterIdRegex.hasMatch(trimmed);
  }

  /// Resolves the active tester ID.
  ///
  /// 1. If [explicitTesterId] is provided, trims and validates it.
  ///    If invalid, logs a diagnostic warning and falls back to an anonymous installation ID.
  /// 2. If [explicitTesterId] is null/empty, retrieves the persistent installation ID
  ///    from local storage or generates a new cryptographically secure installation ID.
  Future<String> resolveTesterId(String? explicitTesterId) async {
    return await errorHandler.runGuarded<String>(() async {
          // 1. Explicit ID validation
          if (explicitTesterId != null && explicitTesterId.trim().isNotEmpty) {
            final trimmed = explicitTesterId.trim();
            if (isValidTesterId(trimmed)) {
              errorHandler.log(
                  'Using explicit developer-provided tester ID: "$trimmed"');
              return trimmed;
            } else {
              errorHandler.log(
                'Invalid explicit tester ID "$explicitTesterId". Must match safe identifier pattern (alphanumeric, _, -, ., @, + up to 128 chars). '
                'Falling back to persistent anonymous installation ID.',
              );
            }
          }

          // 2. Persistent anonymous installation ID
          final existingId = localStorage.getPersistentTesterId();
          if (existingId != null && isValidTesterId(existingId)) {
            errorHandler
                .log('Reusing persistent anonymous tester ID: "$existingId"');
            return existingId;
          }

          // 3. Generate new secure anonymous installation ID
          final generatedId = generateAnonymousInstallationId();
          errorHandler
              .log('Generated new anonymous installation ID: "$generatedId"');
          await localStorage.savePersistentTesterId(generatedId);
          return generatedId;
        },
            operationName: 'IdentityManager.resolveTesterId',
            fallbackValue: generateAnonymousInstallationId()) ??
        generateAnonymousInstallationId();
  }

  /// Generates a cryptographically secure anonymous installation identifier.
  ///
  /// Format: `tt_<timestampHex>_<randomHex>` (e.g. `tt_1926b01a_4f8e219c3b8a`).
  /// Uses [Random.secure] and avoids hardware, location, or personal identifiers.
  static String generateAnonymousInstallationId() {
    final timestampHex =
        DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = Random.secure();
    final randomValues = List<int>.generate(6, (_) => random.nextInt(256));
    final randomHex =
        randomValues.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'tt_${timestampHex}_$randomHex';
  }
}
