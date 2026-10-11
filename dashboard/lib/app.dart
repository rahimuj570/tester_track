import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/dashboard_shell.dart';
import 'state/dashboard_state.dart';
import 'theme/app_theme.dart';

class TesterTrackDashboardApp extends StatelessWidget {
  final DashboardState state;

  const TesterTrackDashboardApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'TesterTrack Dashboard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.unknown,
            },
          ),
          home: DashboardShell(state: state),
        );
      },
    );
  }
}
