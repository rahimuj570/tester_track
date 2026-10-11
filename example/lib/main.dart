import 'package:flutter/material.dart';
import 'package:tester_track/tester_track.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TesterTrack with secondary Firebase project options.
  // Replace these with your actual secondary Firebase project options.
  const secondaryFirebaseOptions = FirebaseOptions(
    apiKey: "YOUR_FIREBASE_API_KEY_HERE",
    projectId: "your-tester-track-project",
    storageBucket: "your-tester-track-project.firebasestorage.app",
    messagingSenderId: "123456789012",
    appId: "1:123456789012:android:abcdef1234567890",
  );

  // Initialize tracking with an optional explicit tester ID.
  await TesterTrack.initialize(
    firebaseOptions: secondaryFirebaseOptions,
    testerId: 'T001',
    options: const TesterTrackOptions(
      debugLogging: true,
    ),
  );

  runApp(const TesterTrackExampleApp());
}

class TesterTrackExampleApp extends StatelessWidget {
  const TesterTrackExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = TesterTrack.instance;

    return MaterialApp(
      title: 'TesterTrack Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TesterTrack Example'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.track_changes_rounded,
                  size: 64,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                Text(
                  'TesterTrack Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _StatusRow(
                  label: 'Initialized',
                  value: tracker.isInitialized ? 'Yes' : 'No',
                  isSuccess: tracker.isInitialized,
                ),
                _StatusRow(
                  label: 'Tester ID',
                  value: tracker.testerId ?? 'None (auto-generated)',
                ),
                _StatusRow(
                  label: 'Active Tracking',
                  value: tracker.isTracking ? 'Active' : 'Standby',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool? isSuccess;

  const _StatusRow({
    required this.label,
    required this.value,
    this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(
              color: isSuccess != null
                  ? (isSuccess! ? Colors.green : Colors.red)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
