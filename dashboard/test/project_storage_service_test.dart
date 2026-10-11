import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_track_dashboard/models/project_config.dart';
import 'package:tester_track_dashboard/services/project_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProjectStorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = ProjectStorageService(prefs);
  });

  group('ProjectStorageService Tests', () {
    const project1 = FirebaseProjectConfig(
      id: 'proj_1',
      name: 'Project One',
      apiKey: 'key_1',
      appId: 'app_1',
      messagingSenderId: 'msg_1',
      projectId: 'project-one',
      storageBucket: 'project-one.appspot.com',
    );

    const project2 = FirebaseProjectConfig(
      id: 'proj_2',
      name: 'Project Two',
      apiKey: 'key_2',
      appId: 'app_2',
      messagingSenderId: 'msg_2',
      projectId: 'project-two',
      storageBucket: 'project-two.appspot.com',
    );

    test('initial state has empty projects list', () {
      final projects = service.loadProjects();
      expect(projects, isEmpty);
      expect(service.getActiveProjectId(), isNull);
    });

    test('saveOrUpdateProject adds and persists new project', () async {
      await service.saveOrUpdateProject(project1);

      final loaded = service.loadProjects();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('proj_1'));
      expect(loaded.first.name, equals('Project One'));

      // Update existing project
      final updatedProject1 = project1.copyWith(name: 'Project One Renamed');
      await service.saveOrUpdateProject(updatedProject1);

      final reloaded = service.loadProjects();
      expect(reloaded.length, equals(1));
      expect(reloaded.first.name, equals('Project One Renamed'));
    });

    test('multiple projects management and active project switching', () async {
      await service.saveOrUpdateProject(project1);
      await service.saveOrUpdateProject(project2);

      final loaded = service.loadProjects();
      expect(loaded.length, equals(2));

      await service.setActiveProjectId('proj_2');
      expect(service.getActiveProjectId(), equals('proj_2'));

      // Delete active project
      final remaining = await service.deleteProject('proj_2');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('proj_1'));
      // Automatically fell back to remaining project
      expect(service.getActiveProjectId(), equals('proj_1'));
    });
  });
}
