import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';
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
  String _sortBy = 'lastSeen'; // 'lastSeen', 'sessions', 'usage', 'activeDays'

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
        case 'sessions':
          return b.sessionCount.compareTo(a.sessionCount);
        case 'usage':
          return b.totalUsageSeconds.compareTo(a.totalUsageSeconds);
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
                    value: _sortBy,
                    dropdownColor: AppTheme.surfaceDark,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'lastSeen', child: Text('Sort by: Last Seen')),
                      DropdownMenuItem(
                          value: 'usage', child: Text('Sort by: Total Usage')),
                      DropdownMenuItem(
                          value: 'sessions', child: Text('Sort by: Sessions')),
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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFF0F172A)),
                        columns: const [
                          DataColumn(label: Text('Tester ID')),
                          DataColumn(label: Text('Platform')),
                          DataColumn(label: Text('Device Model')),
                          DataColumn(label: Text('App Version')),
                          DataColumn(label: Text('Sessions')),
                          DataColumn(label: Text('Total Usage')),
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
                              DataCell(Text(t.appVersion)),
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
                              DataCell(
                                Text(
                                  t.inProgressSessionCount > 0
                                      ? t.formattedTotalUsageTime
                                      : t.formattedUsageTime,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}
