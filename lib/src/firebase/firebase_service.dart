import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
// ignore: implementation_imports
import 'package:cloud_firestore_platform_interface/src/method_channel/method_channel_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

          // If the host application does not have a default Firebase app initialized,
          // FlutterFire's FirebaseFirestorePlatform.instanceFor falls back to
          // FirebaseFirestorePlatform.instance, which lazily calls Firebase.app('[DEFAULT]')
          // and throws [core/no-app]. We set the platform instance delegate to our named app
          // to avoid requiring the host app to initialize a default Firebase app.
          try {
            Firebase.app();
          } catch (_) {
            if (!kIsWeb) {
              try {
                // ignore: implementation_imports
                FirebaseFirestorePlatform.instance =
                    MethodChannelFirebaseFirestore(app: _app!);
              } catch (_) {
                // Ignore if platform interface is already locked or custom mocked.
              }
            }
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
      try {
        final userCredential = await _auth!.signInAnonymously();
        errorHandler
            .log('Anonymous sign-in complete. UID: ${userCredential.user?.uid}');
        return userCredential;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'admin-restricted-operation') {
          errorHandler.log(
            'CRITICAL: Anonymous Authentication is disabled in your Firebase project (${_app?.options.projectId}).\n'
            'To resolve this:\n'
            '  1. Open Firebase Console (https://console.firebase.google.com)\n'
            '  2. Select project "${_app?.options.projectId}"\n'
            '  3. Go to Build > Authentication > Sign-in method\n'
            '  4. Enable the "Anonymous" provider and click Save.',
          );
        }
        rethrow;
      }
    }, operationName: 'FirebaseAuth.signInAnonymously', fallbackValue: null);
  }

  /// Returns the current anonymous user's UID if signed in.
  String? get currentAuthUid => _auth?.currentUser?.uid;
}
