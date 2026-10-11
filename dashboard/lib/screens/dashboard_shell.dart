import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/uid_guide_dialog.dart';
import 'auth_screen.dart';
import 'overview_screen.dart';
import 'projects_screen.dart';
import 'remote_config_screen.dart';
import 'testers_screen.dart';

/// Main application shell with responsive navigation, header, and active project switching.
class DashboardShell extends StatefulWidget {
  final DashboardState state;

  const DashboardShell({super.key, required this.state});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onNavRailDestinationSelected(int index) {
    // Navigating via sidebar or bottom bar resets selected tester drilldown to show all testers
    widget.state.clearSelectedTester();
    _onNavigate(index);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    // 1. If loading initial state
    if (state.isLoading &&
        state.projects.isEmpty &&
        state.activeProject == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading TesterTrack Dashboard...',
                  style: TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    // 2. If no project or not authenticated
    if (state.activeProject == null || !state.isAuthenticated) {
      return AuthScreen(state: state);
    }

    // 3. Main Dashboard View
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        Widget currentBody;
        switch (_selectedIndex) {
          case 0:
            currentBody = OverviewScreen(state: state, onNavigate: _onNavigate);
            break;
          case 1:
            currentBody = TestersScreen(state: state);
            break;
          case 2:
            currentBody = RemoteConfigScreen(state: state);
            break;
          case 3:
          default:
            currentBody = ProjectsScreen(state: state);
            break;
        }

        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: Row(
            children: [
              if (isDesktop)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onNavRailDestinationSelected,
                  backgroundColor: AppTheme.surfaceDark,
                  extended: constraints.maxWidth >= 1100,
                  minWidth: 72,
                  minExtendedWidth: 200,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded,
                          color: AppTheme.primaryColor),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: state.totalInProgressSessionsCount > 0
                          ? Badge(
                              label: Text(
                                  '${state.totalInProgressSessionsCount}'),
                              backgroundColor: AppTheme.warningColor,
                              textColor: Colors.black,
                              child:
                                  const Icon(Icons.people_outline_rounded),
                            )
                          : const Icon(Icons.people_outline_rounded),
                      selectedIcon: state.totalInProgressSessionsCount > 0
                          ? Badge(
                              label: Text(
                                  '${state.totalInProgressSessionsCount}'),
                              backgroundColor: AppTheme.warningColor,
                              textColor: Colors.black,
                              child: const Icon(Icons.people_rounded,
                                  color: AppTheme.primaryColor),
                            )
                          : const Icon(Icons.people_rounded,
                              color: AppTheme.primaryColor),
                      label: Text(state.totalInProgressSessionsCount > 0
                          ? 'Testers (${state.totalInProgressSessionsCount} active)'
                          : 'Testers & Sessions'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune_rounded,
                          color: AppTheme.primaryColor),
                      label: Text('Remote Config'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder_rounded,
                          color: AppTheme.primaryColor),
                      label: Text('Projects'),
                    ),
                  ],
                ),
              if (isDesktop) const VerticalDivider(width: 1),
              Expanded(child: currentBody),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onNavRailDestinationSelected,
                  backgroundColor: AppTheme.surfaceDark,
                  selectedItemColor: AppTheme.primaryColor,
                  unselectedItemColor: AppTheme.textMuted,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Overview',
                    ),
                    BottomNavigationBarItem(
                      icon: state.totalInProgressSessionsCount > 0
                          ? Badge(
                              label: Text(
                                  '${state.totalInProgressSessionsCount}'),
                              backgroundColor: AppTheme.warningColor,
                              textColor: Colors.black,
                              child:
                                  const Icon(Icons.people_outline_rounded),
                            )
                          : const Icon(Icons.people_outline_rounded),
                      label: 'Testers',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.tune_outlined),
                      label: 'Config',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.folder_outlined),
                      label: 'Projects',
                    ),
                  ],
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, DashboardState state) {
    final activeProject = state.activeProject;
    final user = state.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 750;
    final isVeryCompact = screenWidth < 500;

    return AppBar(
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          if (!isVeryCompact) ...[
            const SizedBox(width: 8),
            const Text(
              'TesterTrack',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
          if (activeProject != null) ...[
            SizedBox(width: isCompact ? 8 : 16),
            // Active Project Selector
            Flexible(
              child: PopupMenuButton<Object?>(
                tooltip: 'Switch Active Firebase Project',
                onSelected: (val) {
                  if (val is FirebaseProjectConfig) {
                    state.selectProject(val);
                  } else if (val == '__add__)') {
                    _openAddProject(context);
                  }
                },
                itemBuilder: (ctx) {
                  return [
                    ...state.projects.map((p) {
                      final isCur = p.id == activeProject.id;
                      return PopupMenuItem<Object?>(
                        value: p,
                        child: Row(
                          children: [
                            Icon(
                              isCur
                                  ? Icons.check_circle
                                  : Icons.folder_outlined,
                              size: 18,
                              color: isCur
                                  ? AppTheme.successColor
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isCur
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const PopupMenuDivider(),
                    const PopupMenuItem<Object?>(
                      value: '__add__',
                      child: Row(
                        children: [
                          Icon(Icons.add,
                              size: 18, color: AppTheme.primaryColor),
                          SizedBox(width: 10),
                          Text('Add Firebase Project...'),
                        ],
                      ),
                    ),
                  ];
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_outlined,
                          size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isCompact ? 100 : 160),
                        child: Text(
                          activeProject.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!isCompact && state.totalInProgressSessionsCount > 0) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _onNavRailDestinationSelected(1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${state.totalInProgressSessionsCount} In-Progress',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (isCompact && state.totalInProgressSessionsCount > 0)
          IconButton(
            icon: Badge(
              label: Text('${state.totalInProgressSessionsCount}'),
              backgroundColor: AppTheme.warningColor,
              textColor: Colors.black,
              child: const Icon(Icons.bolt_rounded,
                  color: AppTheme.warningColor),
            ),
            tooltip:
                '${state.totalInProgressSessionsCount} in-progress sessions',
            onPressed: () => _onNavRailDestinationSelected(1),
          ),
        // Allowlist Guide Helper Button
        IconButton(
          icon: const Icon(Icons.shield_outlined, size: 20),
          tooltip: 'Firestore Security Rules & Owner UID Guide',
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => UidGuideDialog(
                currentUid: user?.uid,
                currentEmail: user?.email,
              ),
            );
          },
        ),

        // Refresh Data
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh Data',
          onPressed: () => state.refreshDashboardData(),
        ),

        const SizedBox(width: 8),

        // User Account Menu
        if (user != null)
          PopupMenuButton<String>(
            tooltip: 'Developer Account Menu',
            onSelected: (val) {
              if (val == 'sign_out') {
                state.signOut();
              } else if (val == 'uid_guide') {
                showDialog<void>(
                  context: context,
                  builder: (_) => UidGuideDialog(
                    currentUid: user.uid,
                    currentEmail: user.email,
                  ),
                );
              }
            },
            itemBuilder: (ctx) {
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email ?? 'Developer Account',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UID: ${user.uid}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'uid_guide',
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 18),
                      SizedBox(width: 10),
                      Text('Allowlist Setup Guide'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sign_out',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: AppTheme.dangerColor),
                      SizedBox(width: 10),
                      Text('Sign Out',
                          style: TextStyle(color: AppTheme.dangerColor)),
                    ],
                  ),
                ),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      (user.email?.isNotEmpty == true
                          ? user.email![0].toUpperCase()
                          : 'D'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.email ?? user.uid.substring(0, 6),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 16),
      ],
    );
  }

  Future<void> _openAddProject(BuildContext context) async {
    final result = await showDialog<FirebaseProjectConfig>(
      context: context,
      builder: (_) => const ProjectFormDialog(),
    );
    if (result != null) {
      await widget.state.saveProject(result);
    }
  }
}
