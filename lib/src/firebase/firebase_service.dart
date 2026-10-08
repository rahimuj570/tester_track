import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants.dart';
import '../core/error_handler.dart';

/// Manages isolated named Firebase App, Auth, and Firestore instances for TesterTrack.
class TrackerFirebaseService {
  final TrackerErrorHandler errorHandler;
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  TrackerFirebaseService({required this.errorHandler});

  /// The isolated secondary [FirebaseApp].
  FirebaseApp get app {
    if (_app == null) {
      throw StateError('TrackerFirebaseService has not been initialized.');
    }
    return _app!;
  }

  /// The isolated secondary [FirebaseAuth] instance.
  FirebaseAuth get auth {
    if (_auth == null) {
      throw StateError('TrackerFirebaseService has not been initialized.');
    }
    return _auth!;
  }

  /// The isolated secondary [FirebaseFirestore] instance.
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw StateError('TrackerFirebaseService has not been initialized.');
    }
    return _firestore!;
  }

  /// Whether Firebase has been initialized.
  bool get isInitialized => _app != null && _auth != null && _firestore != null;

  /// Initializes the secondary named Firebase App without modifying the host app's default app.
  Future<bool> initialize({
    required FirebaseOptions firebaseOptions,
    String appName = TrackerConstants.namedFirebaseAppName,
  }) async {
    return await errorHandler.runGuarded<bool>(() async {
          errorHandler.log('Initializing named FirebaseApp: $appName');

          // Check if named app already exists (e.g. from hot reload or previous initialization)
          FirebaseApp? existingApp;
          try {
            existingApp = Firebase.app(appName);
          } catch (_) {
            // App not found in registry yet, which is expected on fresh launch
          }

          if (existingApp != null) {
            errorHandler.log('Reusing existing named FirebaseApp: $appName');
            _app = existingApp;
          } else {
            _app = await Firebase.initializeApp(
              name: appName,
              options: firebaseOptions,
            );
          }

          _auth = FirebaseAuth.instanceFor(app: _app!);
          _firestore = FirebaseFirestore.instanceFor(app: _app!);

          errorHandler.log(
              'Secondary Firebase App "$appName" initialized successfully.');
          return true;
        }, operationName: 'FirebaseApp.initialize', fallbackValue: false) ??
        false;
  }

  /// Signs in anonymously on the secondary Firebase project.
  Future<UserCredential?> signInAnonymously() async {
    return await errorHandler.runGuarded<UserCredential?>(() async {
      if (_auth == null) {
        throw StateError('FirebaseAuth instance is not initialized.');
      }

      final currentUser = _auth!.currentUser;
      if (currentUser != null) {
        errorHandler.log(
            'Reusing existing anonymous auth session (${currentUser.uid})');
        return null;
      }

      errorHandler
          .log('Signing in anonymously to secondary Firebase project...');
      final userCredential = await _auth!.signInAnonymously();
      errorHandler
          .log('Anonymous sign-in complete. UID: ${userCredential.user?.uid}');
      return userCredential;
    }, operationName: 'FirebaseAuth.signInAnonymously', fallbackValue: null);
  }

  /// Returns the current anonymous user's UID if signed in.
  String? get currentAuthUid => _auth?.currentUser?.uid;
}
