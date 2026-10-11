import 'package:flutter/material.dart';
import 'app.dart';
import 'services/firebase_manager.dart';
import 'services/project_storage_service.dart';
import 'state/dashboard_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await ProjectStorageService.create();
  final firebaseManager = FirebaseManager();

  final dashboardState = DashboardState(
    storageService: storageService,
    firebaseManager: firebaseManager,
  );

  await dashboardState.init();

  runApp(TesterTrackDashboardApp(state: dashboardState));
}
