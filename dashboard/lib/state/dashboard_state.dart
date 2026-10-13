import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../models/remote_config_form_model.dart';
import '../models/session_view_model.dart';
import '../models/tester_view_model.dart';
import '../services/dashboard_auth_service.dart';
import '../services/dashboard_firestore_service.dart';
import '../services/firebase_manager.dart';
import '../services/project_storage_service.dart';

/// Central state controller for the TesterTrack dashboard.
class DashboardState extends ChangeNotifier {
  final ProjectStorageService storageService;
  final FirebaseManager firebaseManager;
  late final DashboardAuthService authService;
  late final DashboardFirestoreService firestoreService;

  List<FirebaseProjectConfig> _projects = [];
  FirebaseProjectConfig? _activeProject;
  User? _currentUser;
  bool _isAuthorized = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<TesterViewModel> _testers = [];
  TesterViewModel? _selectedTester;
  List<SessionViewModel> _selectedTesterSessions = [];
  RemoteConfigFormModel? _remoteConfig;

  StreamSubscription<User?>? _authSubscription;

  DashboardState({
    required this.storageService,
    required this.firebaseManager,
  }) {
    authService = DashboardAuthService(firebaseManager);
    firestoreService = DashboardFirestoreService(firebaseManager);
  }

  // Getters
  List<FirebaseProjectConfig> get projects => _projects;
  FirebaseProjectConfig? get activeProject => _activeProject;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAuthorized => _isAuthorized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<TesterViewModel> get testers => _testers;
  TesterViewModel? get selectedTester => _selectedTester;
  List<SessionViewModel> get selectedTesterSessions => _selectedTesterSessions;
  RemoteConfigFormModel? get remoteConfig => _remoteConfig;

  // Computed summary statistics
  int get totalTestersCount => _testers.length;

  int get activeTesters14DaysCount =>
      _testers.where((t) => t.isActiveWithin(14)).length;

  int get activeTesters7DaysCount =>
      _testers.where((t) => t.isActiveWithin(7)).length;

  int get activeTestersTodayCount =>
      _testers.where((t) => t.isUsedToday).length;

  int get totalTodayUsageSeconds =>
      _testers.fold<int>(0, (sum, t) => sum + t.todayUsageSeconds);

  int get totalTodaySessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.todaySessionsCount);

  int get totalSessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.sessionCount);

  int get totalInProgressSessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.inProgressSessionCount);

  int get totalActiveSessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.activeSessionCount);

  int get totalStaleSessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.staleSessionCount);

  int get activeTestersNowCount =>
      _testers.where((t) => t.isCurrentlyActive).length;

  int get totalActiveUsageSeconds =>
      _testers.fold<int>(0, (sum, t) => sum + t.activeUsageSeconds);

  int get totalRecordedSessionsCount =>
      _testers.fold<int>(0, (sum, t) => sum + t.totalRecordedSessions);

  int get totalUsageSeconds =>
      _testers.fold<int>(0, (sum, t) => sum + t.totalUsageSeconds);

  int get totalInProgressUsageSeconds =>
      _testers.fold<int>(0, (sum, t) => sum + t.inProgressUsageSeconds);

  int get totalObservedUsageSeconds =>
      _testers.fold<int>(0, (sum, t) => sum + t.totalObservedUsageSeconds);

  String _formatSeconds(int totalSec) {
    if (totalSec < 60) return '${totalSec}s';
    final minutes = totalSec ~/ 60;
    if (minutes < 60) {
      final remSec = totalSec % 60;
      return remSec > 0 ? '${minutes}m ${remSec}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }

  String get formattedTotalUsage => _formatSeconds(totalUsageSeconds);

  String get formattedTotalObservedUsage =>
      _formatSeconds(totalObservedUsageSeconds);

  String get formattedInProgressUsage =>
      _formatSeconds(totalInProgressUsageSeconds);

  String get formattedActiveUsage => _formatSeconds(totalActiveUsageSeconds);

  String get formattedTotalTodayUsage =>
      _formatSeconds(totalTodayUsageSeconds);

  /// Initializes the dashboard state by loading saved projects.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _projects = storageService.loadProjects();
      final savedActiveId = storageService.getActiveProjectId();

      if (savedActiveId != null &&
          _projects.any((p) => p.id == savedActiveId)) {
        _activeProject = _projects.firstWhere((p) => p.id == savedActiveId);
      } else if (_projects.isNotEmpty) {
        _activeProject = _projects.first;
        await storageService.setActiveProjectId(_activeProject!.id);
      }

      if (_activeProject != null) {
        await _connectToProject(_activeProject!);
      }
    } catch (e) {
      _errorMessage = 'Failed to load projects: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches active project.
  Future<void> selectProject(FirebaseProjectConfig project) async {
    if (_activeProject?.id == project.id) return;
    _activeProject = project;
    await storageService.setActiveProjectId(project.id);
    await _connectToProject(project);
  }

  /// Adds or updates a project configuration.
  Future<void> saveProject(FirebaseProjectConfig project) async {
    final validationErrors = project.validate();
    if (validationErrors.isNotEmpty) {
      _errorMessage = validationErrors.join('\n');
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await storageService.saveOrUpdateProject(project);
      _activeProject = project;
      await storageService.setActiveProjectId(project.id);
      await _connectToProject(project);
    } catch (e) {
      _errorMessage = 'Failed to save project: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Removes a project configuration.
  Future<void> deleteProject(String projectId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _projects = await storageService.deleteProject(projectId);
      if (_activeProject?.id == projectId) {
        _activeProject = _projects.isNotEmpty ? _projects.first : null;
        if (_activeProject != null) {
          await _connectToProject(_activeProject!);
        } else {
          _currentUser = null;
          _isAuthorized = false;
          _testers = [];
          _selectedTester = null;
          _remoteConfig = null;
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to delete project: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectToProject(FirebaseProjectConfig config) async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _errorMessage = null;

    try {
      // Listen to auth changes on the selected project
      final stream = await authService.authStateChanges(config);
      _currentUser = await authService.getCurrentUser(config);

      _authSubscription = stream.listen((user) async {
        _currentUser = user;
        if (_currentUser != null) {
          await refreshDashboardData();
        } else {
          _isAuthorized = false;
          _testers = [];
          _selectedTester = null;
          _remoteConfig = null;
          notifyListeners();
        }
      });

      if (_currentUser != null) {
        await refreshDashboardData();
      }
    } catch (e) {
      _errorMessage = 'Error connecting to project "${config.name}": $e';
      notifyListeners();
    }
  }

  /// Signs in using Google.
  Future<void> signInWithGoogle() async {
    if (_activeProject == null) {
      _errorMessage = 'Please select or add a Firebase project first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await authService.signInWithGoogle(_activeProject!);
      _currentUser = credential.user;
      await refreshDashboardData();
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs in with Email and Password.
  Future<void> signInWithEmail(String email, String password) async {
    if (_activeProject == null) {
      _errorMessage = 'Please select or add a Firebase project first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await authService.signInWithEmailPassword(
        config: _activeProject!,
        email: email,
        password: password,
      );
      _currentUser = credential.user;
      await refreshDashboardData();
    } catch (e) {
      _errorMessage = 'Sign in failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a developer with Email and Password.
  Future<void> registerWithEmail(String email, String password) async {
    if (_activeProject == null) {
      _errorMessage = 'Please select or add a Firebase project first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await authService.registerWithEmailPassword(
        config: _activeProject!,
        email: email,
        password: password,
      );
      _currentUser = credential.user;
      await refreshDashboardData();
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs out of the active project.
  Future<void> signOut() async {
    if (_activeProject == null) return;
    try {
      await authService.signOut(_activeProject!);
      _currentUser = null;
      _isAuthorized = false;
      _testers = [];
      _selectedTester = null;
      _remoteConfig = null;
    } catch (e) {
      _errorMessage = 'Sign out error: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Refreshes testers, statistics, and remote configuration from Firestore.
  Future<void> refreshDashboardData() async {
    if (_activeProject == null || _currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check Owner Authorization
      final isAuth = await firestoreService.checkAuthorization(_activeProject!);
      _isAuthorized = isAuth;

      if (!_isAuthorized) {
        _errorMessage =
            'Permission Denied: Your account (${_currentUser?.email ?? _currentUser?.uid}) is not on the authorized developer allowlist in firestore.rules.';
        _testers = [];
        _remoteConfig = null;
        return;
      }

      // 2. Fetch testers
      _testers = await firestoreService.fetchTesters(_activeProject!);

      // 3. Fetch remote config
      _remoteConfig = await firestoreService.fetchRemoteConfig(_activeProject!);

      // 4. Refresh selected tester if open
      if (_selectedTester != null) {
        await selectTester(_selectedTester!.testerId);
      }
    } catch (e) {
      _errorMessage = 'Error loading dashboard data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a tester to view detail and load sessions.
  Future<void> selectTester(String testerId) async {
    if (_activeProject == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final tester =
          await firestoreService.fetchTester(_activeProject!, testerId);
      _selectedTester = tester;
      if (tester != null) {
        _selectedTesterSessions =
            await firestoreService.fetchSessions(_activeProject!, testerId);
      } else {
        _selectedTesterSessions = [];
      }
    } catch (e) {
      _errorMessage = 'Failed to load tester details: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedTester() {
    _selectedTester = null;
    _selectedTesterSessions = [];
    notifyListeners();
  }

  /// Updates remote configuration in `config/global`.
  Future<bool> updateRemoteConfig(RemoteConfigFormModel formModel) async {
    if (_activeProject == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await firestoreService.updateRemoteConfig(_activeProject!, formModel);
      _remoteConfig = formModel.copyWith(updatedAt: DateTime.now().toUtc());
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update remote configuration: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Finalizes a session from the dashboard and refreshes tester stats.
  Future<bool> finalizeSession(SessionViewModel session) async {
    if (_activeProject == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final endedAt =
          session.startedAt.add(Duration(seconds: session.durationSeconds));
      await firestoreService.finalizeSession(
        _activeProject!,
        testerId: session.testerId,
        sessionId: session.sessionId,
        endedAt: endedAt,
        durationSeconds: session.durationSeconds,
        activeDate: session.activeDate,
      );

      // Refresh tester details and testers list
      await selectTester(session.testerId);
      _testers = await firestoreService.fetchTesters(_activeProject!);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to finalize session: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Finalizes all unfinalized/stale sessions for the currently selected tester.
  Future<bool> finalizeAllStaleSessions() async {
    if (_activeProject == null || _selectedTester == null) return false;

    final staleSessions =
        _selectedTesterSessions.where((s) => !s.isFinalized).toList();
    if (staleSessions.isEmpty) return true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      for (final session in staleSessions) {
        final endedAt =
            session.startedAt.add(Duration(seconds: session.durationSeconds));
        await firestoreService.finalizeSession(
          _activeProject!,
          testerId: session.testerId,
          sessionId: session.sessionId,
          endedAt: endedAt,
          durationSeconds: session.durationSeconds,
          activeDate: session.activeDate,
        );
      }

      await selectTester(_selectedTester!.testerId);
      _testers = await firestoreService.fetchTesters(_activeProject!);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to finalize stale sessions: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Automatically finalizes all stale sessions (heartbeat > 5 mins) across testers.
  Future<int> autoFinalizeStaleSessions({Duration timeout = const Duration(minutes: 5)}) async {
    if (_activeProject == null) return 0;

    _isLoading = true;
    notifyListeners();

    try {
      final count = await firestoreService.autoFinalizeStaleSessions(
        _activeProject!,
        timeout: timeout,
      );
      if (count > 0) {
        await refreshDashboardData();
      }
      return count;
    } catch (e) {
      _errorMessage = 'Failed to auto-finalize stale sessions: $e';
      return 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates metadata for a specific tester profile and refreshes local state.
  Future<bool> updateTesterMetadata({
    required String testerId,
    String? platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
  }) async {
    if (_activeProject == null) return false;

    try {
      final success = await firestoreService.updateTesterMetadata(
        _activeProject!,
        testerId: testerId,
        platform: platform,
        deviceModel: deviceModel,
        osVersion: osVersion,
        appVersion: appVersion,
      );

      if (success) {
        if (_selectedTester?.testerId == testerId) {
          _selectedTester = _selectedTester!.copyWith(
            platform: platform,
            deviceModel: deviceModel,
            osVersion: osVersion,
            appVersion: appVersion,
          );
        }
        await refreshDashboardData();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update tester info: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
