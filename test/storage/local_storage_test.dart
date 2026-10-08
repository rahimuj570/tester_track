import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrackerErrorHandler errorHandler;
  late LocalStorage localStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    errorHandler = TrackerErrorHandler(debugLogging: false);
    localStorage = LocalStorage(errorHandler: errorHandler);
    await localStorage.init();
  });

  group('LocalStorage', () {
    test('savePersistentTesterId and getPersistentTesterId work correctly',
        () async {
      expect(localStorage.getPersistentTesterId(), isNull);

      final success =
          await localStorage.savePersistentTesterId('tt_12345_abcdef');
      expect(success, isTrue);

      expect(localStorage.getPersistentTesterId(), equals('tt_12345_abcdef'));
    });

    test('setString, getString, and remove work safely', () async {
      await localStorage.setString('custom_key', 'custom_value');
      expect(localStorage.getString('custom_key'), equals('custom_value'));

      await localStorage.remove('custom_key');
      expect(localStorage.getString('custom_key'), isNull);
    });
  });
}
