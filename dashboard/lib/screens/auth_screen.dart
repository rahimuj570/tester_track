import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/uid_guide_dialog.dart';

/// Authentication screen displayed when user is not signed in to the active Firebase project.
class AuthScreen extends StatefulWidget {
  final DashboardState state;

  const AuthScreen({super.key, required this.state});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleEmailAuth() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    if (_isRegistering) {
      widget.state.registerWithEmail(email, password);
    } else {
      widget.state.signInWithEmail(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProject = widget.state.activeProject;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxOption(maxWidth: 460).toBoxConstraints(),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Logo & Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TesterTrack',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Developer Dashboard',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Active Project Indicator
                    if (activeProject != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined,
                                size: 18, color: AppTheme.accentColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeProject.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Project ID: ${activeProject.projectId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openProjectSelector(context),
                              child: const Text('Switch',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'No Firebase project configured.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Firebase Project'),
                              onPressed: () => _openAddProjectDialog(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (widget.state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppTheme.dangerColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          widget.state.errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFFFCA5A5), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (activeProject != null) ...[
                      // Google Sign-In Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.g_mobiledata,
                            size: 28, color: Colors.white),
                        label: const Text('Sign in with Google'),
                        onPressed: widget.state.isLoading
                            ? null
                            : () => widget.state.signInWithGoogle(),
                      ),

                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR EMAIL',
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Email & Password Fields
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Developer Email',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _handleEmailAuth(),
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed:
                            widget.state.isLoading ? null : _handleEmailAuth,
                        child: widget.state.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isRegistering
                                ? 'Register Account'
                                : 'Sign In with Email'),
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() => _isRegistering = !_isRegistering);
                          },
                          child: Text(
                            _isRegistering
                                ? 'Already have an account? Sign In'
                                : 'First time? Create developer account',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),

                      const Divider(height: 32),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.help_outline, size: 16),
                          label: const Text(
                              'How to Authorize Developer in Security Rules',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => const UidGuideDialog(),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openProjectSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Switch Saved Firebase Project',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...widget.state.projects.map((p) {
                final isCurrent = p.id == widget.state.activeProject?.id;
                return ListTile(
                  title: Text(p.name,
                      style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(p.projectId),
                  trailing: isCurrent
                      ? const Icon(Icons.check, color: AppTheme.successColor)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.state.selectProject(p);
                  },
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Another Project'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openAddProjectDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddProjectDialog(BuildContext context) async {
    final result = await showDialog<FirebaseProjectConfig>(
      context: context,
      builder: (_) => const ProjectFormDialog(),
    );
    if (result != null) {
      await widget.state.saveProject(result);
    }
  }
}

class BoxOption {
  final double maxWidth;
  const BoxOption({required this.maxWidth});
  BoxConstraints toBoxConstraints() => BoxConstraints(maxWidth: maxWidth);
}
