import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/project_config.dart';
import '../theme/app_theme.dart';

/// Modal dialog for adding or editing a saved Firebase Web Project Configuration.
class ProjectFormDialog extends StatefulWidget {
  final FirebaseProjectConfig? initialProject;

  const ProjectFormDialog({super.key, this.initialProject});

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _apiKeyController;
  late TextEditingController _appIdController;
  late TextEditingController _messagingSenderIdController;
  late TextEditingController _projectIdController;
  late TextEditingController _storageBucketController;
  late TextEditingController _authDomainController;
  late TextEditingController _measurementIdController;
  late TextEditingController _pasteSnippetController;

  bool _showRawPaste = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProject;
    _nameController = TextEditingController(text: p?.name ?? '');
    _apiKeyController = TextEditingController(text: p?.apiKey ?? '');
    _appIdController = TextEditingController(text: p?.appId ?? '');
    _messagingSenderIdController =
        TextEditingController(text: p?.messagingSenderId ?? '');
    _projectIdController = TextEditingController(text: p?.projectId ?? '');
    _storageBucketController =
        TextEditingController(text: p?.storageBucket ?? '');
    _authDomainController = TextEditingController(text: p?.authDomain ?? '');
    _measurementIdController =
        TextEditingController(text: p?.measurementId ?? '');
    _pasteSnippetController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _appIdController.dispose();
    _messagingSenderIdController.dispose();
    _projectIdController.dispose();
    _storageBucketController.dispose();
    _authDomainController.dispose();
    _measurementIdController.dispose();
    _pasteSnippetController.dispose();
    super.dispose();
  }

  void _parseFirebaseSnippet(String snippet) {
    setState(() => _parseError = null);
    try {
      String extractKey(String key) {
        final regex = RegExp('$key\\s*[:=]\\s*["\']([^"\']+)["\']');
        final match = regex.firstMatch(snippet);
        return match?.group(1)?.trim() ?? '';
      }

      final apiKey = extractKey('apiKey');
      final appId = extractKey('appId');
      final messagingSenderId = extractKey('messagingSenderId');
      final projectId = extractKey('projectId');
      final storageBucket = extractKey('storageBucket');
      final authDomain = extractKey('authDomain');
      final measurementId = extractKey('measurementId');

      if (apiKey.isEmpty && projectId.isEmpty) {
        // Try JSON decode
        try {
          final json = jsonDecode(snippet) as Map<String, dynamic>;
          _apiKeyController.text = json['apiKey']?.toString() ?? '';
          _appIdController.text = json['appId']?.toString() ?? '';
          _messagingSenderIdController.text =
              json['messagingSenderId']?.toString() ?? '';
          _projectIdController.text = json['projectId']?.toString() ?? '';
          _storageBucketController.text =
              json['storageBucket']?.toString() ?? '';
          _authDomainController.text = json['authDomain']?.toString() ?? '';
          _measurementIdController.text =
              json['measurementId']?.toString() ?? '';
          if (_nameController.text.isEmpty &&
              _projectIdController.text.isNotEmpty) {
            _nameController.text = _projectIdController.text;
          }
          setState(() => _showRawPaste = false);
          return;
        } catch (_) {}

        setState(() {
          _parseError =
              'Could not find standard Firebase web config keys (apiKey, projectId, etc.).';
        });
        return;
      }

      _apiKeyController.text = apiKey;
      _appIdController.text = appId;
      _messagingSenderIdController.text = messagingSenderId;
      _projectIdController.text = projectId;
      _storageBucketController.text = storageBucket;
      _authDomainController.text = authDomain;
      _measurementIdController.text = measurementId;

      if (_nameController.text.isEmpty && projectId.isNotEmpty) {
        _nameController.text = projectId;
      }

      setState(() => _showRawPaste = false);
    } catch (e) {
      setState(() => _parseError = 'Parse error: $e');
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final config = FirebaseProjectConfig(
      id: widget.initialProject?.id ??
          'proj_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      appId: _appIdController.text.trim(),
      messagingSenderId: _messagingSenderIdController.text.trim(),
      projectId: _projectIdController.text.trim(),
      storageBucket: _storageBucketController.text.trim(),
      authDomain: _authDomainController.text.trim().isNotEmpty
          ? _authDomainController.text.trim()
          : null,
      measurementId: _measurementIdController.text.trim().isNotEmpty
          ? _measurementIdController.text.trim()
          : null,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProject != null;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEditing ? 'Edit Firebase Project' : 'Add Firebase Project'),
          TextButton.icon(
            icon: Icon(_showRawPaste ? Icons.edit_note : Icons.content_paste),
            label:
                Text(_showRawPaste ? 'Manual Form' : 'Paste Firebase Config'),
            onPressed: () {
              setState(() => _showRawPaste = !_showRawPaste);
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: _showRawPaste
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste your Firebase Web App configuration snippet from Firebase Console (Settings > Project Settings > Your apps > Web app):',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pasteSnippetController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText:
                            'const firebaseConfig = {\n  apiKey: "...",\n  projectId: "...",\n  ...\n};',
                      ),
                    ),
                    if (_parseError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _parseError!,
                        style: const TextStyle(
                            color: AppTheme.dangerColor, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Parse and Auto-Fill Form'),
                      onPressed: () =>
                          _parseFirebaseSnippet(_pasteSnippetController.text),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Friendly Project Name *',
                          hintText: 'e.g. My Flutter App (Production)',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Please enter a project name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _projectIdController,
                              decoration: const InputDecoration(
                                labelText: 'Firebase Project ID *',
                                hintText: 'e.g. my-app-prod-12345',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _appIdController,
                              decoration: const InputDecoration(
                                labelText: 'App ID (appId) *',
                                hintText: '1:1234567890:web:abcdef',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key (apiKey) *',
                          hintText: 'AIzaSy...',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _messagingSenderIdController,
                              decoration: const InputDecoration(
                                labelText: 'Messaging Sender ID *',
                                hintText: '1234567890',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _storageBucketController,
                              decoration: const InputDecoration(
                                labelText: 'Storage Bucket *',
                                hintText: 'my-app.appspot.com',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _authDomainController,
                              decoration: const InputDecoration(
                                labelText: 'Auth Domain (Optional)',
                                hintText: 'my-app.firebaseapp.com',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _measurementIdController,
                              decoration: const InputDecoration(
                                labelText: 'Measurement ID (Optional)',
                                hintText: 'G-XXXXXXXXXX',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Connect Project'),
        ),
      ],
    );
  }
}
