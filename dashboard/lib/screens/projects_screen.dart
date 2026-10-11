import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/uid_guide_dialog.dart';

/// Screen for managing, switching, adding, and editing developer Firebase projects.
class ProjectsScreen extends StatelessWidget {
  final DashboardState state;

  const ProjectsScreen({super.key, required this.state});

  Future<void> _openAddProject(BuildContext context) async {
    final result = await showDialog<FirebaseProjectConfig>(
      context: context,
      builder: (_) => const ProjectFormDialog(),
    );
    if (result != null) {
      await state.saveProject(result);
    }
  }

  Future<void> _openEditProject(
      BuildContext context, FirebaseProjectConfig project) async {
    final result = await showDialog<FirebaseProjectConfig>(
      context: context,
      builder: (_) => ProjectFormDialog(initialProject: project),
    );
    if (result != null) {
      await state.saveProject(result);
    }
  }

  Future<void> _confirmDeleteProject(
      BuildContext context, FirebaseProjectConfig project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Project Configuration?'),
          content: Text(
            'Are you sure you want to remove "${project.name}" from your local browser dashboard? (This will NOT delete any data in your Firebase project).',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await state.deleteProject(project.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = state.projects;
    final activeId = state.activeProject?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firebase Projects',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage and switch between your secondary Firebase project configurations',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Firebase Project'),
                  onPressed: () => _openAddProject(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (projects.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            size: 56, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'No Firebase projects configured yet.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your secondary developer Firebase project to view tester sessions.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Project Now'),
                          onPressed: () => _openAddProject(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              ...projects.map((p) {
                final isActive = p.id == activeId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceBorder,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.cloud_outlined,
                            color: isActive
                                ? AppTheme.primaryColor
                                : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ACTIVE PROJECT',
                                        style: TextStyle(
                                          color: AppTheme.successColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Project ID: ${p.projectId} • App ID: ${p.appId}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!isActive)
                          OutlinedButton(
                            onPressed: () => state.selectProject(p),
                            child: const Text('Connect'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Project',
                          onPressed: () => _openEditProject(context, p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppTheme.dangerColor),
                          tooltip: 'Delete Project',
                          onPressed: () => _confirmDeleteProject(context, p),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),

            // Help & Allowlist Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded,
                            color: AppTheme.primaryColor, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Firestore Security Rules & Owner Authorization',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Remember to add your authenticated developer UID to firestore.rules in each connected Firebase project so you have read permissions to tester profiles and write permissions to config/global.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text('View Allowlist Setup Instructions'),
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => UidGuideDialog(
                            currentUid: state.currentUser?.uid,
                            currentEmail: state.currentUser?.email,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
