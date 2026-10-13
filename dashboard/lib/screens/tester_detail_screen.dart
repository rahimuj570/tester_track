import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tester = widget.tester;
    final onBack = widget.onBack;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final sessions = state.selectedTesterSessions;

    final activeSessions =
        sessions.where((s) => s.isCurrentlyActive()).toList();
    final activeCount = activeSessions.length;
    final totalRecordedCount =
        sessions.isNotEmpty ? sessions.length : tester.sessionCount;
    final inProgressSessions = sessions.where((s) => !s.isFinalized).toList();
    final inProgressSeconds =
        inProgressSessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
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
                        if (activeCount > 0)
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
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Info', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () => _showEditTesterDialog(context, state, tester),
              ),
              const SizedBox(width: 8),
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
                    value: activeCount > 0
                        ? '$totalRecordedCount ($activeCount Active)'
                        : '$totalRecordedCount',
                    subtitle: 'Total usage: ${_formatUsageSeconds(totalSeconds)}',
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
                          if (activeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle,
                                      size: 7, color: AppTheme.successColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$activeCount Active Now',
                                    style: const TextStyle(
                                      color: AppTheme.successColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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
                              DataColumn(label: Text('Live State')),
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
                                        color: s.isCurrentlyActive()
                                            ? AppTheme.successColor
                                                .withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        s.isCurrentlyActive()
                                            ? 'ACTIVE NOW'
                                            : 'COMPLETED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: s.isCurrentlyActive()
                                              ? AppTheme.successColor
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(dateFormat
                                      .format(s.startedAt.toLocal()))),
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
                                    s.isCurrentlyActive()
                                        ? Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.successColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: AppTheme
                                                      .successColor
                                                      .withValues(
                                                          alpha: 0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle,
                                                    size: 7,
                                                    color: AppTheme
                                                        .successColor),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Active Now',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: AppTheme
                                                        .successColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_outline,
                                                  size: 14,
                                                  color: AppTheme.textMuted),
                                              SizedBox(width: 4),
                                              Text(
                                                'Completed',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textMuted),
                                              ),
                                            ],
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

  void _showEditTesterDialog(
    BuildContext context,
    DashboardState state,
    TesterViewModel tester,
  ) {
    final platformCtrl = TextEditingController(
        text: tester.platform == 'unknown' ? '' : tester.platform);
    final modelCtrl = TextEditingController(
        text: tester.deviceModel == 'unknown' ? '' : tester.deviceModel);
    final osCtrl = TextEditingController(
        text: tester.osVersion == 'unknown' ? '' : tester.osVersion);
    final appCtrl = TextEditingController(
        text: tester.appVersion == 'unknown' ? '' : tester.appVersion);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Text('Edit Info (${tester.testerId})'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: platformCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Platform (e.g. android, ios, web)',
                    hintText: 'android',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device Model (e.g. Pixel 7, Galaxy S23)',
                    hintText: 'Google Pixel 7',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: osCtrl,
                  decoration: const InputDecoration(
                    labelText: 'OS Version (e.g. Android 14)',
                    hintText: 'Android 14',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appCtrl,
                  decoration: const InputDecoration(
                    labelText: 'App Version (e.g. 1.0.0 (1))',
                    hintText: '1.0.0 (1)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await state.updateTesterMetadata(
                testerId: tester.testerId,
                platform: platformCtrl.text.trim(),
                deviceModel: modelCtrl.text.trim(),
                osVersion: osCtrl.text.trim(),
                appVersion: appCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Updated ${tester.testerId} metadata successfully!'
                        : 'Failed to update tester metadata.'),
                    backgroundColor:
                        success ? AppTheme.successColor : AppTheme.dangerColor,
                  ),
                );
              }
            },
            child: const Text('Save'),
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
