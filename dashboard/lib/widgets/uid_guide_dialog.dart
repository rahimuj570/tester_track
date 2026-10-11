import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Modal dialog providing instructions and copy helpers for configuring developer allowlist in firestore.rules.
class UidGuideDialog extends StatelessWidget {
  final String? currentUid;
  final String? currentEmail;

  const UidGuideDialog({
    super.key,
    this.currentUid,
    this.currentEmail,
  });

  @override
  Widget build(BuildContext context) {
    final uid = currentUid ?? 'SIGN_IN_TO_VIEW_YOUR_UID';

    final rulesSnippet = '''
// In firestore.rules:
function isAuthorizedDeveloper() {
  return request.auth != null && 
         request.auth.token.firebase.sign_in_provider != 'anonymous' &&
         request.auth.uid in [
           '$uid' // Your Auth UID
         ];
}
''';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 12),
          Text('Owner Authorization Setup'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Because the TesterTrack dashboard connects directly to your Firebase project without an intermediary backend, project ownership is securely enforced via an allowlist in your Firestore Security Rules.',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Your Firebase Auth Account:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentEmail != null)
                      Text('Email: $currentEmail',
                          style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Auth UID: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Expanded(
                          child: SelectableText(
                            uid,
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy UID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Auth UID copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '2. Add your UID to firestore.rules:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      rulesSnippet,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Rules Snippet'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rulesSnippet));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Rules snippet copied!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '3. Deploy Rules to Firebase:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Run `firebase deploy --only firestore:rules` or paste into Firebase Console > Firestore Database > Rules tab, then click Publish.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
