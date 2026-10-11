import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/identity/identity_manager.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;
  late IdentityManager identityManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    errorHandler = TrackerErrorHandler(debugLogging: false);
    localStorage = LocalStorage(errorHandler: errorHandler);
    await localStorage.init();
    identityManager = IdentityManager(
      localStorage: localStorage,
      errorHandler: errorHandler,
    );
  });

  group('IdentityManager', () {
    test('isValidTesterId validates valid and invalid IDs', () {
      expect(IdentityManager.isValidTesterId('T001'), isTrue);
      expect(IdentityManager.isValidTesterId('tester_42'), isTrue);
      expect(IdentityManager.isValidTesterId('alpha-beta_123'), isTrue);
      expect(IdentityManager.isValidTesterId('alex.smith@company.com'), isTrue);
      expect(IdentityManager.isValidTesterId('tester+tag@domain.co.uk'), isTrue);
      expect(IdentityManager.isValidTesterId('a' * 128), isTrue);

      // Invalid
      expect(IdentityManager.isValidTesterId(null), isFalse);
      expect(IdentityManager.isValidTesterId(''), isFalse);
      expect(IdentityManager.isValidTesterId('.'), isFalse);
      expect(IdentityManager.isValidTesterId('..'), isFalse);
      expect(IdentityManager.isValidTesterId('__reserved'), isFalse);
      expect(
          IdentityManager.isValidTesterId('invalid id with spaces'), isFalse);
      expect(IdentityManager.isValidTesterId('invalid/slash'), isFalse);
      expect(IdentityManager.isValidTesterId('a' * 129), isFalse);
    });

    test('resolveTesterId uses valid explicit developer-provided ID', () async {
      final id = await identityManager.resolveTesterId('  T001_Alpha  ');
      expect(id, equals('T001_Alpha'));
    });

    test(
        'resolveTesterId rejects invalid explicit ID and falls back to persistent anonymous ID',
        () async {
      final id =
          await identityManager.resolveTesterId('invalid id with spaces!');
      expect(id.startsWith('tt_'), isTrue);
      expect(IdentityManager.isValidTesterId(id), isTrue);
    });

    test(
        'resolveTesterId generates and persists anonymous installation ID when omitted',
        () async {
      final id1 = await identityManager.resolveTesterId(null);
      expect(id1.startsWith('tt_'), isTrue);
      expect(IdentityManager.isValidTesterId(id1), isTrue);

      // Subsequent call returns exact same persisted ID
      final id2 = await identityManager.resolveTesterId(null);
      expect(id2, equals(id1));

      // New IdentityManager instance also loads same persisted ID
      final newIdentityManager = IdentityManager(
        localStorage: localStorage,
        errorHandler: errorHandler,
      );
      final id3 = await newIdentityManager.resolveTesterId(null);
      expect(id3, equals(id1));
    });

    test(
        'generateAnonymousInstallationId creates correct format without hardware IDs',
        () {
      final id = IdentityManager.generateAnonymousInstallationId();
      expect(id.startsWith('tt_'), isTrue);
      final parts = id.split('_');
      expect(parts.length, equals(3));
      // Timestamp hex part
      expect(int.tryParse(parts[1], radix: 16), isNotNull);
      // Random hex part (12 hex chars = 6 bytes)
      expect(parts[2].length, equals(12));
    });
  });
}
