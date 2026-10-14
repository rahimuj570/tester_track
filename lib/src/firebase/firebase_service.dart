import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
// ignore: implementation_imports
import 'package:cloud_firestore_platform_interface/src/method_channel/method_channel_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

          // Check if named app already exists in Dart registry (e.g. hot reload)
          FirebaseApp? existingApp;
          try {
            existingApp = Firebase.app(appName);
          } catch (_) {
            // App not found in Dart registry yet, which is expected on fresh launch or hot restart
          }

          if (existingApp != null) {
            // If developer updated Firebase options, delete and re-create with new options
            if (existingApp.options.projectId != firebaseOptions.projectId ||
                existingApp.options.apiKey != firebaseOptions.apiKey ||
                existingApp.options.appId != firebaseOptions.appId) {
              errorHandler.log(
                'Firebase options changed for "$appName". Re-creating app instance (${existingApp.options.projectId} -> ${firebaseOptions.projectId}).',
              );
              try {
                await existingApp.delete();
              } catch (_) {}
              existingApp = null;
            }
          }

          if (existingApp != null) {
            errorHandler.log('Reusing existing named FirebaseApp: $appName');
            _app = existingApp;
          } else {
            try {
              _app = await Firebase.initializeApp(
                name: appName,
                options: firebaseOptions,
              );
            } catch (e) {
              if (e.toString().contains('duplicate-app')) {
                errorHandler.log(
                  'Detected existing native FirebaseApp "$appName". Deleting and re-initializing with latest configuration...',
                );
                try {
                  final staleApp = Firebase.app(appName);
                  await staleApp.delete();
                } catch (_) {
                  try {
                    const channel =
                        MethodChannel('plugins.flutter.io/firebase_core');
                    await channel.invokeMethod<void>(
                      'FirebaseApp#delete',
                      <String, dynamic>{'appName': appName},
                    );
                  } catch (delError) {
                    errorHandler
                        .log('Note: native app delete invoked with: $delError');
                  }
                }

                // Re-initialize now that the native duplicate has been removed
                _app = await Firebase.initializeApp(
                  name: appName,
                  options: firebaseOptions,
                );
              } else {
                rethrow;
              }
            }
          }

          // Strict verification: ensure active app matches latest options passed by developer
          if (_app!.options.projectId != firebaseOptions.projectId ||
              _app!.options.apiKey != firebaseOptions.apiKey) {
            errorHandler.log(
              'Stale options detected on "$appName" (${_app!.options.projectId} != ${firebaseOptions.projectId}). Forcing recreate with latest config...',
            );
            try {
              await _app!.delete();
            } catch (_) {}
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
        try {
          await currentUser.getIdToken().timeout(
                const Duration(seconds: 4),
                onTimeout: () => null,
              );
        } catch (e) {
          if (TrackerErrorHandler.isFatalFirebaseError(e)) {
            errorHandler.tripCircuitBreaker('Cached auth token validation failed: $e');
            try {
              await _auth!.signOut();
            } catch (_) {}
            return null;
          }
        }
        return null;
      }

      errorHandler
          .log('Signing in anonymously to secondary Firebase project...');
      try {
        final userCredential = await _auth!.signInAnonymously().timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException(
                'Anonymous authentication timed out after 5 seconds.',
              ),
            );
        errorHandler
            .log('Anonymous sign-in complete. UID: ${userCredential.user?.uid}');
        try {
          await userCredential.user?.getIdToken().timeout(
                const Duration(seconds: 4),
                onTimeout: () => null,
              );
        } catch (_) {}
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
