import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/project_config.dart';

/// Manages initialization, isolation, and instance access for named Firebase apps.
class FirebaseManager {
  final Map<String, FirebaseApp> _initializedApps = {};

  /// Ensures a named [FirebaseApp] is initialized for the provided [config].
  Future<FirebaseApp> getOrCreateApp(FirebaseProjectConfig config) async {
    final appName = config.appName;

    // Check memory cache
    if (_initializedApps.containsKey(appName)) {
      return _initializedApps[appName]!;
    }

    // Check global Firebase app registry
    try {
      final existingApp = Firebase.app(appName);
      _initializedApps[appName] = existingApp;
      return existingApp;
    } catch (_) {
      // Not yet in registry
    }

    // Initialize named app
    final newApp = await Firebase.initializeApp(
      name: appName,
      options: config.toFirebaseOptions(),
    );
    _initializedApps[appName] = newApp;
    return newApp;
  }

  /// Gets isolated [FirebaseAuth] for the given [config].
  Future<FirebaseAuth> getAuth(FirebaseProjectConfig config) async {
    final app = await getOrCreateApp(config);
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Gets isolated [FirebaseFirestore] for the given [config].
  Future<FirebaseFirestore> getFirestore(FirebaseProjectConfig config) async {
    final app = await getOrCreateApp(config);
    return FirebaseFirestore.instanceFor(app: app);
  }
}
