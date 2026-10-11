import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'tester_detail_screen.dart';

/// Testers list screen with search, sorting, filtering, and detail drilldown.
class TestersScreen extends StatefulWidget {
  final DashboardState state;

  const TestersScreen({super.key, required this.state});

  @override
  State<TestersScreen> createState() => _TestersScreenState();
}

class _TestersScreenState extends State<TestersScreen> {
  String _searchQuery = '';
  String _platformFilter = 'All';
  String _activityFilter = 'All'; // 'All', 'today', 'inactive_today'
  String _sortBy = 'lastSeen'; // 'lastSeen', 'todayUsage', 'usage', 'sessions', 'activeDays'
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    // If a tester is selected, display the detailed session drilldown view
    if (state.selectedTester != null) {
      return TesterDetailScreen(
        state: state,
        tester: state.selectedTester!,
        onBack: () => state.clearSelectedTester(),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Filter testers
    var filtered = state.testers.where((t) {
      if (_platformFilter != 'All' &&
          !t.platform.toLowerCase().contains(_platformFilter.toLowerCase())) {
        return false;
      }
      if (_activityFilter == 'today' && !t.isUsedToday) {
        return false;
      }
      if (_activityFilter == 'inactive_today' && t.isUsedToday) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesId = t.testerId.toLowerCase().contains(q);
        final matchesPlatform = t.platform.toLowerCase().contains(q);
        final matchesModel = t.deviceModel.toLowerCase().contains(q);
        final matchesVersion = t.appVersion.toLowerCase().contains(q);
        return matchesId || matchesPlatform || matchesModel || matchesVersion;
      }
      return true;
    }).toList();

    // Sort testers
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'todayUsage':
          return b.todayUsageSeconds.compareTo(a.todayUsageSeconds);
        case 'sessions':
          return b.totalRecordedSessions.compareTo(a.totalRecordedSessions);
        case 'usage':
          return b.totalObservedUsageSeconds
              .compareTo(a.totalObservedUsageSeconds);
        case 'activeDays':
          return b.activeDaysCount.compareTo(a.activeDaysCount);
        case 'lastSeen':
        default:
          return b.lastSeen.compareTo(a.lastSeen);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Controls
          Row(
            children: [
              Expanded(
                child: Text(
                  'Testers (${filtered.length} of ${state.testers.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Testers',
                onPressed: () => state.refreshDashboardData(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily Engagement KPI Cards
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
                    subtitle: 'Registered test devices',
                    icon: Icons.people_outline_rounded,
                    iconColor: AppTheme.primaryColor,
                  ),
                  StatCard(
                    title: 'Active Today',
                    value: '${state.activeTestersTodayCount}',
                    subtitle: state.totalTestersCount > 0
                        ? '${((state.activeTestersTodayCount / state.totalTestersCount) * 100).toStringAsFixed(0)}% of total testers'
                        : 'No testers registered',
                    icon: Icons.today_rounded,
                    iconColor: AppTheme.successColor,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.activeTestersTodayCount > 0
                            ? AppTheme.successColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        state.activeTestersTodayCount > 0
                            ? 'LIVE TODAY'
                            : 'NONE TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: state.activeTestersTodayCount > 0
                              ? AppTheme.successColor
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  StatCard(
                    title: "Today's Total Usage",
                    value: state.formattedTotalTodayUsage,
                    subtitle:
                        '${state.totalTodaySessionsCount} session(s) observed today',
                    icon: Icons.timer_rounded,
                    iconColor: const Color(0xFF38BDF8),
                  ),
                  StatCard(
                    title: 'Active In-Progress',
                    value: '${state.totalInProgressSessionsCount}',
                    subtitle: state.totalInProgressUsageSeconds > 0
                        ? '${state.formattedInProgressUsage} in-flight active time'
                        : 'Currently foreground active',
                    icon: Icons.bolt_rounded,
                    iconColor: AppTheme.warningColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Search & Filter Toolbar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search tester ID, model, version...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _platformFilter,
                    dropdownColor: AppTheme.surfaceDark,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'All', child: Text('All Platforms')),
                      DropdownMenuItem(
                          value: 'android', child: Text('Android Only')),
                      DropdownMenuItem(value: 'ios', child: Text('iOS Only')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _platformFilter = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _activityFilter,
                    dropdownColor: AppTheme.surfaceDark,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'All', child: Text('All Activity')),
                      DropdownMenuItem(
                          value: 'today', child: Text('🟢 Active Today')),
                      DropdownMenuItem(
                          value: 'inactive_today',
                          child: Text('⚪ Inactive Today')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _activityFilter = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: AppTheme.surfaceDark,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'lastSeen', child: Text('Sort by: Last Seen')),
                      DropdownMenuItem(
                          value: 'todayUsage',
                          child: Text("Sort by: Today's Usage")),
                      DropdownMenuItem(
                          value: 'usage', child: Text('Sort by: Total Usage')),
                      DropdownMenuItem(
                          value: 'sessions',
                          child: Text('Sort by: Total Sessions')),
                      DropdownMenuItem(
                          value: 'activeDays',
                          child: Text('Sort by: Active Days')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Testers Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              state.testers.isEmpty
                                  ? 'No tester documents found in testers collection.'
                                  : 'No testers matching search filters.',
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Scrollbar(
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
                          DataColumn(label: Text('Tester ID')),
                          DataColumn(label: Text('Platform')),
                          DataColumn(label: Text('Device Model')),
                          DataColumn(label: Text('Today Status')),
                          DataColumn(label: Text("Today's Usage")),
                          DataColumn(label: Text('App Version')),
                          DataColumn(label: Text('Total Usage')),
                          DataColumn(label: Text('Sessions')),
                          DataColumn(label: Text('Active Days')),
                          DataColumn(label: Text('Last Seen')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((t) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      t.platform.toLowerCase().contains('ios')
                                          ? Icons.phone_iphone
                                          : Icons.android,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    SelectableText(
                                      t.testerId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(t.platform)),
                              DataCell(Text(t.deviceModel)),
                              DataCell(
                                t.inProgressSessionCount > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppTheme.warningColor
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle,
                                                size: 7,
                                                color: AppTheme.warningColor),
                                            SizedBox(width: 6),
                                            Text(
                                              'Active Now',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.warningColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : t.isUsedToday
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.successColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                              BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: AppTheme.successColor
                                                      .withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.circle,
                                                    size: 7,
                                                    color:
                                                        AppTheme.successColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  t.todaySessionsCount > 0
                                                      ? 'Used Today (${t.todaySessionsCount})'
                                                      : 'Used Today',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppTheme.successColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.1)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle,
                                                    size: 7,
                                                    color: AppTheme.textMuted),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Not Today',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                              ),
                              DataCell(
                                t.isUsedToday
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.todayUsageSeconds > 0
                                                ? t.formattedTodayUsageTime
                                                : '< 1m',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF38BDF8),
                                            ),
                                          ),
                                          if (t.inProgressSessionCount > 0)
                                            const Text(
                                              'tracking now',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.warningColor,
                                              ),
                                            ),
                                        ],
                                      )
                                    : const Text(
                                        '—',
                                        style: TextStyle(
                                            color: AppTheme.textMuted),
                                      ),
                              ),
                              DataCell(Text(t.appVersion)),
                              DataCell(
                                Text(
                                  t.inProgressSessionCount > 0
                                      ? t.formattedTotalUsageTime
                                      : t.formattedUsageTime,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                t.inProgressSessionCount > 0
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${t.totalRecordedSessions}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.warningColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+${t.inProgressSessionCount} active',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.warningColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '${t.sessionCount}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                              DataCell(Text('${t.activeDaysCount} d')),
                              DataCell(Text(
                                  dateFormat.format(t.lastSeen.toLocal()))),
                              DataCell(
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 14),
                                  label: const Text('View Sessions',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    state.selectTester(t.testerId);
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }
}
