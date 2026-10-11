import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project_config.dart';

/// Manages local browser storage for saved Firebase project configurations.
class ProjectStorageService {
  static const String _projectsKey = 'tt_dashboard_saved_projects';
  static const String _activeProjectIdKey = 'tt_dashboard_active_project_id';

  final SharedPreferences _prefs;

  ProjectStorageService(this._prefs);

  static Future<ProjectStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProjectStorageService(prefs);
  }

  /// Loads all saved project configurations.
  List<FirebaseProjectConfig> loadProjects() {
    final raw = _prefs.getString(_projectsKey);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) =>
              FirebaseProjectConfig.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the list of project configurations.
  Future<bool> saveProjects(List<FirebaseProjectConfig> projects) async {
    final data = projects.map((p) => p.toMap()).toList();
    return await _prefs.setString(_projectsKey, jsonEncode(data));
  }

  /// Adds or updates a project configuration.
  Future<List<FirebaseProjectConfig>> saveOrUpdateProject(
      FirebaseProjectConfig project) async {
    final current = loadProjects();
    final index = current.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      current[index] = project;
    } else {
      current.add(project);
    }
    await saveProjects(current);
    return current;
  }

  /// Removes a project configuration by ID.
  Future<List<FirebaseProjectConfig>> deleteProject(String projectId) async {
    final current = loadProjects();
    current.removeWhere((p) => p.id == projectId);
    await saveProjects(current);

    if (getActiveProjectId() == projectId) {
      if (current.isNotEmpty) {
        await setActiveProjectId(current.first.id);
      } else {
        await _prefs.remove(_activeProjectIdKey);
      }
    }
    return current;
  }

  /// Gets the active project ID.
  String? getActiveProjectId() {
    return _prefs.getString(_activeProjectIdKey);
  }

  /// Sets the active project ID.
  Future<bool> setActiveProjectId(String projectId) async {
    return await _prefs.setString(_activeProjectIdKey, projectId);
  }
}
