import 'package:firebase_auth/firebase_auth.dart';
import '../models/project_config.dart';
import 'firebase_manager.dart';

/// Handles authentication on the selected developer Firebase project.
class DashboardAuthService {
  final FirebaseManager _firebaseManager;

  DashboardAuthService(this._firebaseManager);

  /// Signs in with Google using a popup dialog on Web.
  Future<UserCredential> signInWithGoogle(FirebaseProjectConfig config) async {
    final auth = await _firebaseManager.getAuth(config);
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');
    return await auth.signInWithPopup(googleProvider);
  }

  /// Signs in with Email and Password.
  Future<UserCredential> signInWithEmailPassword({
    required FirebaseProjectConfig config,
    required String email,
    required String password,
  }) async {
    final auth = await _firebaseManager.getAuth(config);
    return await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a developer account with Email and Password.
  Future<UserCredential> registerWithEmailPassword({
    required FirebaseProjectConfig config,
    required String email,
    required String password,
  }) async {
    final auth = await _firebaseManager.getAuth(config);
    return await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out of the current project.
  Future<void> signOut(FirebaseProjectConfig config) async {
    final auth = await _firebaseManager.getAuth(config);
    await auth.signOut();
  }

  /// Gets the current signed-in user for the project.
  Future<User?> getCurrentUser(FirebaseProjectConfig config) async {
    final auth = await _firebaseManager.getAuth(config);
    return auth.currentUser;
  }

  /// Listens to auth state changes on the selected project.
  Future<Stream<User?>> authStateChanges(FirebaseProjectConfig config) async {
    final auth = await _firebaseManager.getAuth(config);
    return auth.authStateChanges();
  }
}
