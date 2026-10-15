import 'dart:math';
import 'package:flutter/material.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/uid_guide_dialog.dart';

/// Overview Screen with summary KPI cards and Google Play Closed Testing readiness metrics.
class OverviewScreen extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<int> onNavigate;

  const OverviewScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final testers = state.testers;
    final remoteConfig = state.remoteConfig;

    // Platform distribution
    final androidCount = testers
        .where((t) => t.platform.toLowerCase().contains('android'))
        .length;
    final iosCount =
        testers.where((t) => t.platform.toLowerCase().contains('ios')).length;
    final otherCount = testers.length - androidCount - iosCount;

    // Google Play Closed Testing progress: 20 active testers in last 14 days
    final active14 = state.activeTesters14DaysCount;
    final progress20Testers = (active14 / 20.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unauthorized warning banner
          if (!state.isAuthorized && state.isAuthenticated) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.dangerColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppTheme.dangerColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Owner Authorization Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Firebase account (${state.currentUser?.email ?? state.currentUser?.uid}) is authenticated, but not on the authorized developer allowlist in firestore.rules.',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Setup Guide'),
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
          ],

          // Remote Config Status Banner
          if (remoteConfig != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: remoteConfig.enabled
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: remoteConfig.enabled
                      ? AppTheme.successColor.withValues(alpha: 0.3)
                      : AppTheme.dangerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    remoteConfig.enabled
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: remoteConfig.enabled
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      remoteConfig.enabled
                          ? 'Remote Tracking is currently ENABLED. Client apps record sessions normally.'
                          : 'Remote Tracking is currently DISABLED by remote configuration. Installed apps have ceased tracking.',
                      style: TextStyle(
                        fontSize: 13,
                        color: remoteConfig.enabled
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        onNavigate(2), // Switch to Remote Config tab
                    child: const Text('Manage Config'),
                  ),
                ],
              ),
            ),
          ],

          // Summary KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100
                  ? 4
                  : constraints.maxWidth > 650
                      ? 2
                      : 1;

              const targetCardHeight = 120.0;
              final totalSpacing = (crossAxisCount - 1) * 16.0;
              final cardWidth =
                  (constraints.maxWidth - totalSpacing) / crossAxisCount;
              final childAspectRatio =
                  (cardWidth / targetCardHeight).clamp(1.1, 4.0);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: childAspectRatio,
                children: [
                  StatCard(
                    title: 'Total Testers',
                    value: '${state.totalTestersCount}',
                    subtitle: 'Unique app installations',
                    icon: Icons.people_outline_rounded,
                    iconColor: AppTheme.primaryColor,
                  ),
                  StatCard(
                    title: 'Active (Last 14 Days)',
                    value: '${state.activeTesters14DaysCount}',
                    subtitle: 'Google Play closed testing metric',
                    icon: Icons.event_available_rounded,
                    iconColor: AppTheme.accentColor,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: active14 >= 20
                            ? AppTheme.successColor.withValues(alpha: 0.15)
                            : AppTheme.warningColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        active14 >= 20 ? 'Goal Met (≥20)' : '$active14/20',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: active14 >= 20
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ),
                  StatCard(
                    title: 'Total Sessions',
                    value:
                        '${max(state.totalSessionsCount, state.totalRecordedSessionsCount)}',
                    subtitle: state.totalActiveSessionsCount > 0
                        ? '${state.totalSessionsCount} Finalized · ${state.totalActiveSessionsCount} Active'
                        : state.totalStaleSessionsCount > 0
                            ? '${state.totalSessionsCount} Finalized (${state.totalStaleSessionsCount} unfinalized)'
                            : 'Recorded foreground sessions',
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                  StatCard(
                    title: 'Total Foreground Time',
                    value: state.totalObservedUsageSeconds >
                            state.totalUsageSeconds
                        ? state.formattedTotalObservedUsage
                        : state.formattedTotalUsage,
                    subtitle: state.totalActiveSessionsCount > 0
                        ? '${state.formattedTotalUsage} Finalized · ${state.formattedActiveUsage} Active'
                        : 'Observed active time only',
                    icon: Icons.hourglass_top_rounded,
                    iconColor: AppTheme.successColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Secondary Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Google Play Track Progress Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_outlined,
                                    color: AppTheme.accentColor, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Google Play 20-Tester Progress',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Google Play closed testing requires at least 20 active testers engaged continuously over a 14-day testing period.',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: progress20Testers,
                              backgroundColor: const Color(0xFF0F172A),
                              color: active14 >= 20
                                  ? AppTheme.successColor
                                  : AppTheme.accentColor,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$active14 / 20 Active Testers',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  active14 >= 20
                                      ? 'Requirement Met!'
                                      : '${20 - active14} more needed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active14 >= 20
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (isWide)
                    const SizedBox(width: 16)
                  else
                    const SizedBox(height: 16),

                  // Platform Breakdown Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.devices_rounded,
                                    color: AppTheme.primaryColor, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Platform Breakdown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _PlatformRow(
                              name: 'Android',
                              count: androidCount,
                              total: testers.length,
                              icon: Icons.android_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(height: 8),
                            _PlatformRow(
                              name: 'iOS',
                              count: iosCount,
                              total: testers.length,
                              icon: Icons.phone_iphone_rounded,
                              color: const Color(0xFF38BDF8),
                            ),
                            if (otherCount > 0) ...[
                              const SizedBox(height: 8),
                              _PlatformRow(
                                name: 'Other (Web/Desktop)',
                                count: otherCount,
                                total: testers.length,
                                icon: Icons.laptop_chromebook_rounded,
                                color: const Color(0xFFA855F7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Recent Testers Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Testers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('View All Testers'),
                        onPressed: () {
                          state.clearSelectedTester();
                          onNavigate(1);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (testers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 40, color: AppTheme.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'No testers recorded yet for this project.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...testers.take(5).map((t) {
                      final totalSessions =
                          max(t.sessionCount, t.totalRecordedSessions);
                      final totalUsage = t.totalObservedUsageSeconds > 0
                          ? t.formattedTotalUsageTime
                          : t.formattedUsageTime;
                      final activeDays = max(
                        t.activeDaysCount,
                        (totalSessions > 0 ||
                                t.isUsedToday ||
                                t.recentActiveDates.isNotEmpty)
                            ? 1
                            : 0,
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: Icon(
                            _getPlatformIcon(t.platform),
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          t.testerId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '${t.platform} • ${t.deviceModel} • App ${t.appVersion}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (t.isCurrentlyActive) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                Text(
                                  '$totalSessions ${totalSessions == 1 ? 'session' : 'sessions'} ($totalUsage)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$activeDays ${activeDays == 1 ? 'active day' : 'active days'}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          state.selectTester(t.testerId);
                          onNavigate(1);
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  final String name;
  final int count;
  final int total;
  final IconData icon;
  final Color color;

  const _PlatformRow({
    required this.name,
    required this.count,
    required this.total,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total) : 0.0;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          '$count (${(pct * 100).toStringAsFixed(0)}%)',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

IconData _getPlatformIcon(String platform) {
  final p = platform.toLowerCase();
  if (p.contains('ios') || p.contains('iphone') || p.contains('ipad')) {
    return Icons.phone_iphone_rounded;
  } else if (p.contains('web')) {
    return Icons.language_rounded;
  } else if (p.contains('win') || p.contains('mac') || p.contains('linux')) {
    return Icons.laptop_chromebook_rounded;
  }
  return Icons.android_rounded;
}
