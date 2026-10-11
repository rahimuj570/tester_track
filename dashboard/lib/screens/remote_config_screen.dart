import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/remote_config_form_model.dart';
import '../state/dashboard_state.dart';
import '../theme/app_theme.dart';

/// Screen for managing remote configuration (`config/global`).
class RemoteConfigScreen extends StatefulWidget {
  final DashboardState state;

  const RemoteConfigScreen({super.key, required this.state});

  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen> {
  late bool _enabled;
  DateTime? _expiresAt;
  late TextEditingController _minVersionController;
  int? _syncIntervalSeconds;
  bool _isSaving = false;
  String? _saveMessage;
  bool _isSuccess = true;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    final cfg = widget.state.remoteConfig ?? RemoteConfigFormModel.empty;
    _enabled = cfg.enabled;
    _expiresAt = cfg.expiresAt;
    _minVersionController =
        TextEditingController(text: cfg.minAppVersion ?? '');
    _syncIntervalSeconds = cfg.syncIntervalSeconds ?? 300;
  }

  @override
  void didUpdateWidget(covariant RemoteConfigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.remoteConfig != widget.state.remoteConfig) {
      _initValues();
    }
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiresAt ?? now),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _expiresAt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          ).toUtc();
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    // Confirmation dialog if disabling tracking
    if (!_enabled && (widget.state.remoteConfig?.enabled ?? true)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Confirm Disabling Tracking'),
            content: const Text(
              'Disabling tracking will cause all active tester sessions in installed client apps to finalize immediately and stop recording activity. Are you sure you want to proceed?',
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
                child: const Text('Yes, Disable Tracking'),
              ),
            ],
          );
        },
      );
      if (confirm != true) return;
    }

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    final formModel = RemoteConfigFormModel(
      enabled: _enabled,
      expiresAt: _expiresAt,
      minAppVersion: _minVersionController.text.trim().isNotEmpty
          ? _minVersionController.text.trim()
          : null,
      syncIntervalSeconds: _syncIntervalSeconds,
    );

    final success = await widget.state.updateRemoteConfig(formModel);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSuccess = success;
        _saveMessage = success
            ? 'Remote configuration updated successfully in config/global.'
            : (widget.state.errorMessage ??
                'Failed to update remote configuration.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm UTC');
    final updatedAt = widget.state.remoteConfig?.updatedAt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
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
                      'Remote Configuration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Firestore Document: config/global',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                if (updatedAt != null)
                  Text(
                    'Last Updated: ${dateFormat.format(updatedAt.toLocal())}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            if (_saveMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : AppTheme.dangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess
                        ? AppTheme.successColor.withValues(alpha: 0.3)
                        : AppTheme.dangerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess
                          ? AppTheme.successColor
                          : AppTheme.dangerColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _saveMessage!,
                        style: TextStyle(
                          color: _isSuccess
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCA5A5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Master Kill-Switch Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Global Tracking Kill-Switch',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Field: enabled (boolean)',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _enabled,
                          activeThumbColor: AppTheme.successColor,
                          onChanged: (val) {
                            setState(() => _enabled = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _enabled
                          ? 'Tracking is currently ENABLED. Client apps will start sessions and record foreground activity.'
                          : 'Tracking is currently DISABLED. Client apps will finalize open sessions and cease network sync on their next config check.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _enabled
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Expiration Date Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automatic Expiration Date',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Field: expiresAt (ISO 8601 Timestamp / null)',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'After this date and time, client applications automatically disable tracking without requiring an app release.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded,
                              size: 16),
                          label: Text(_expiresAt != null
                              ? 'Set: ${dateFormat.format(_expiresAt!)}'
                              : 'Set Expiration Date'),
                          onPressed: _pickExpirationDate,
                        ),
                        if (_expiresAt != null) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Clear Expiration'),
                            onPressed: () => setState(() => _expiresAt = null),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Minimum App Version Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minimum Required App Version',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Field: minAppVersion (string / null)',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Older application builds with a semantic version lower than this threshold will ignore tracking.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _minVersionController,
                            decoration: const InputDecoration(
                              labelText: 'Min Version (e.g. 1.5.0)',
                              hintText: '1.0.0',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => _minVersionController.clear(),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Firestore Sync Interval Override Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firestore Session Sync Interval',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Field: syncIntervalSeconds (integer: 60..3600)',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        Text(
                          '${_syncIntervalSeconds ?? 300} seconds (${((_syncIntervalSeconds ?? 300) / 60).toStringAsFixed(1)} min)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How often continuous foreground sessions write in-progress duration to Firestore (default: 300s / 5 min to save write cost).',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: (_syncIntervalSeconds ?? 300).toDouble(),
                      min: 60,
                      max: 3600,
                      divisions: 59,
                      activeColor: AppTheme.primaryColor,
                      label: '${_syncIntervalSeconds ?? 300}s',
                      onChanged: (val) {
                        setState(() => _syncIntervalSeconds = val.toInt());
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Action
            Row(
              children: [
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving
                      ? 'Saving to Firestore...'
                      : 'Publish Remote Configuration'),
                  onPressed: _isSaving ? null : _saveConfig,
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => setState(_initValues),
                  child: const Text('Reset Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
