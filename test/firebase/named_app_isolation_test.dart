import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track/src/core/constants.dart';
import 'package:tester_track/src/core/error_handler.dart';
import 'package:tester_track/src/firebase/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackerFirebaseService Isolation', () {
    test('named app name is strictly isolated to "tester_track"', () {
      expect(TrackerConstants.namedFirebaseAppName, equals('tester_track'));
    });

    test('accessing app before initialization throws StateError safely', () {
      final service = TrackerFirebaseService(
        errorHandler: TrackerErrorHandler(debugLogging: false),
      );

      expect(service.isInitialized, isFalse);
      expect(() => service.app, throwsStateError);
      expect(() => service.auth, throwsStateError);
      expect(() => service.firestore, throwsStateError);
    });

    test(
        'error during initialization is handled by error handler without throwing',
        () async {
      final errorHandler = TrackerErrorHandler(debugLogging: false);
      final service = TrackerFirebaseService(errorHandler: errorHandler);

      // Attempting to initialize with invalid/unmocked options in test environment
      // should return false gracefully through errorHandler.runGuarded
      final success = await service.initialize(
        firebaseOptions: const FirebaseOptions(
          apiKey: 'fake',
          appId: 'fake',
          messagingSenderId: 'fake',
          projectId: 'fake',
        ),
      );

      // In unit test environment without native Firebase platform channel mocks,
      // it should safely catch the MissingPluginException / PlatformException and return false.
      expect(success, isFalse);
    });
  });
}
