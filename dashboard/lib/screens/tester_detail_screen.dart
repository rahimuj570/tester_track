import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session_view_model.dart';
import '../models/tester_view_model.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';

/// Detailed view for an individual tester and their recorded sessions history.
class TesterDetailScreen extends StatefulWidget {
  final DashboardState state;
  final TesterViewModel tester;
  final VoidCallback onBack;

  const TesterDetailScreen({
    super.key,
    required this.state,
    required this.tester,
    required this.onBack,
  });

  @override
  State<TesterDetailScreen> createState() => _TesterDetailScreenState();
}

class _TesterDetailScreenState extends State<TesterDetailScreen> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  String _formatUsageSeconds(int totalSec) {
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

  Future<void> _finalizeSingle(
      BuildContext context, SessionViewModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Session'),
        content: Text(
          'Mark session "${session.sessionId}" as FINALIZED with observed duration of ${session.formattedDuration} and add it to tester aggregates?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await widget.state.finalizeSession(session);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Session finalized successfully and added to aggregates.'
                  : 'Failed to finalize session.',
            ),
            backgroundColor:
                ok ? AppTheme.successColor : AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _finalizeAllStale(BuildContext context, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize In-Progress Sessions'),
        content: Text(
          'Are you sure you want to finalize all $count in-progress sessions for ${widget.tester.testerId} and update cumulative totals?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalize All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await widget.state.finalizeAllStaleSessions();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'All in-progress sessions finalized successfully.'
                  : 'Failed to finalize sessions.',
            ),
            backgroundColor:
                ok ? AppTheme.successColor : AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tester = widget.tester;
    final onBack = widget.onBack;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final sessions = state.selectedTesterSessions;

    final inProgressSessions = sessions.where((s) => !s.isFinalized).toList();
    final inProgressCount = inProgressSessions.length;
    final totalRecordedCount =
        sessions.isNotEmpty ? sessions.length : tester.sessionCount;
    final inProgressSeconds = inProgressSessions.fold<int>(
        0, (sum, s) => sum + s.durationSeconds);
    final totalSeconds = tester.totalUsageSeconds + inProgressSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Testers'),
                onPressed: onBack,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          tester.testerId,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tester.platform.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        if (inProgressCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.warningColor
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 7, color: AppTheme.warningColor),
                                SizedBox(width: 5),
                                Text(
                                  'ACTIVE NOW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (tester.isUsedToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle,
                                    size: 7, color: AppTheme.successColor),
                                const SizedBox(width: 5),
                                Text(
                                  'ACTIVE TODAY (${tester.formattedTodayUsageTime})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Text(
                              'NOT ACTIVE TODAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Tester Document: testers/${tester.testerId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Sessions',
                onPressed: () => state.selectTester(tester.testerId),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tester Metadata Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1050
                  ? 5
                  : constraints.maxWidth > 700
                      ? 3
                      : constraints.maxWidth > 480
                          ? 2
                          : 1;

              const targetCardHeight = 92.0;
              final totalSpacing = (crossAxisCount - 1) * 12.0;
              final cardWidth =
                  (constraints.maxWidth - totalSpacing) / crossAxisCount;
              final childAspectRatio =
                  (cardWidth / targetCardHeight).clamp(1.1, 4.0);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: childAspectRatio,
                children: [
                  _DetailCard(
                    title: 'Device & Model',
                    value: tester.deviceModel,
                    subtitle: tester.osVersion,
                    icon: Icons.devices,
                  ),
                  _DetailCard(
                    title: 'App Version',
                    value: tester.appVersion,
                    subtitle:
                        'First seen: ${dateFormat.format(tester.firstSeen.toLocal())}',
                    icon: Icons.apps_rounded,
                  ),
                  _DetailCard(
                    title: "Today's Usage",
                    value: tester.isUsedToday
                        ? (tester.todayUsageSeconds > 0
                            ? tester.formattedTodayUsageTime
                            : '< 1m')
                        : 'No Activity',
                    subtitle: tester.isUsedToday
                        ? '${tester.todaySessionsCount} session(s) today'
                        : 'Inactive today',
                    icon: Icons.today_rounded,
                  ),
                  _DetailCard(
                    title: 'Total Sessions',
                    value: inProgressCount > 0
                        ? '$totalRecordedCount ($inProgressCount Active)'
                        : '$totalRecordedCount',
                    subtitle: inProgressCount > 0
                        ? 'Total: ${_formatUsageSeconds(totalSeconds)} (${tester.formattedUsageTime} Finalized)'
                        : 'Total usage: ${tester.formattedUsageTime}',
                    icon: Icons.timer,
                  ),
                  _DetailCard(
                    title: 'Active Days',
                    value: '${tester.activeDaysCount} Days',
                    subtitle:
                        'Last seen: ${dateFormat.format(tester.lastSeen.toLocal())}',
                    icon: Icons.calendar_today,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Sessions Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          Text(
                            'Recorded Sessions (${sessions.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (inProgressCount > 0)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 14),
                              label: Text(
                                'Finalize All In-Progress ($inProgressCount)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.warningColor,
                                side: const BorderSide(
                                    color: AppTheme.warningColor),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                              ),
                              onPressed: () =>
                                  _finalizeAllStale(context, inProgressCount),
                            ),
                        ],
                      ),
                      Text(
                        'testers/${tester.testerId}/sessions',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.isLoading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ] else if (sessions.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No session documents recorded for this tester yet.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ] else ...[
                    Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thickness: 10.0,
                      radius: const Radius.circular(5),
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF0F172A)),
                        columns: const [
                          DataColumn(label: Text('Session ID')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Started At (Local)')),
                          DataColumn(label: Text('Ended At')),
                          DataColumn(label: Text('Observed Duration')),
                          DataColumn(label: Text('Active Date')),
                          DataColumn(label: Text('App Version')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: sessions.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SelectableText(
                                  s.sessionId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: s.isFinalized
                                        ? AppTheme.successColor
                                            .withValues(alpha: 0.15)
                                        : AppTheme.warningColor
                                            .withValues(alpha: 0.15),
                                  ),
                                  child: Text(
                                    s.isFinalized ? 'FINALIZED' : 'IN-PROGRESS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: s.isFinalized
                                          ? AppTheme.successColor
                                          : AppTheme.warningColor,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                  dateFormat.format(s.startedAt.toLocal()))),
                              DataCell(Text(s.endedAt != null
                                  ? dateFormat.format(s.endedAt!.toLocal())
                                  : '—')),
                              DataCell(
                                Text(
                                  s.formattedDuration,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(Text(s.activeDate)),
                              DataCell(Text(s.appVersion)),
                              DataCell(
                                s.isFinalized
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle,
                                              size: 14,
                                              color: AppTheme.successColor),
                                          SizedBox(width: 4),
                                          Text(
                                            'Closed',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted),
                                          ),
                                        ],
                                      )
                                    : ElevatedButton.icon(
                                        icon: const Icon(Icons.done_all,
                                            size: 12),
                                        label: const Text('Finalize',
                                            style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () =>
                                            _finalizeSingle(context, s),
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _DetailCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
