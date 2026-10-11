# TesterTrack

A lightweight, developer-owned Flutter package for monitoring tester engagement during closed testing (e.g., Google Play 14-day / 20-tester requirements) without third-party servers or backend infrastructure.

All tracking data and configurations live strictly inside the developer's secondary Firebase project.

---

## Features

- **Developer Owned**: Zero external backend or subscription services. You own and control your data.
- **Project Isolation**: Runs as a named secondary Firebase App (`tester_track`), guaranteeing zero interference with your host application's default Firebase app.
- **Accurate Duration**: Tracks observed foreground activity only; background wall-clock time is never counted.
- **Crash Recovery**: Automatically recovers interrupted sessions upon app restart using observed foreground time.
- **Remote Configuration**: Remotely disable tracking, set expiration dates, or enforce minimum app versions without releasing a new app build.
- **Offline Resilient & Failure Safe**: Built-in circuit breakers, local caching, and non-invasive error handling guarantee your host app will never crash.

---

## Getting Started

### 1. Add Dependency

Add `tester_track` to your `pubspec.yaml`:

```yaml
dependencies:
  tester_track: ^0.0.1
```

### 2. Initialize TesterTrack

Initialize `TesterTrack` on application startup using your dedicated secondary Firebase project's `FirebaseOptions`:

```dart
import 'package:flutter/material.dart';
import 'package:tester_track/tester_track.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TesterTrack.initialize(
    firebaseOptions: const FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
      projectId: 'your-testertrack-project',
      storageBucket: 'your-testertrack-project.appspot.com',
    ),
    // Optional: provide custom tester ID (e.g. from invite link)
    testerId: 'T001', 
    options: const TesterTrackOptions(
      debugLogging: false,
      firestoreSyncInterval: Duration(minutes: 5),
    ),
  );

  runApp(const MyApp());
}
```

---

## Remote Configuration

TesterTrack includes a built-in remote configuration engine that fetches settings from your Firebase project.

### Document Location

```text
config/global
```

### Document Schema

```json
{
  "enabled": true,
  "expiresAt": null,
  "minAppVersion": null,
  "syncIntervalSeconds": 300
}
```

| Field | Type | Description |
|---|---|---|
| `enabled` | `boolean` | Master kill-switch. When `false`, tracking immediately stops and active sessions are finalized. Default: `true`. |
| `expiresAt` | `Timestamp` / `string` / `null` | Expiration date/time after which tracking is automatically disabled. |
| `minAppVersion` | `string` / `null` | Minimum required app version (e.g. `"1.5.0"`). Older app versions will not track activity. |
| `syncIntervalSeconds` | `integer` | Optional remote override for Firestore session sync interval (allowed range: `60` to `3600` seconds). |

### Remotely Disabling Tracking

When testing is complete (e.g. Google Play closed testing requirements met):
1. Open your Firebase Console.
2. Navigate to Firestore > `config/global`.
3. Set `"enabled": false`.
4. Installed tester apps will automatically finalize their current session and cease tracking on their next config check. No app release required.

### Offline & Caching Behavior

- **Local Cache**: The last valid remote configuration is cached locally.
- **Offline Device**: When offline or if the config document cannot be fetched, TesterTrack uses the cached configuration. If no cache exists, tracking defaults to `enabled: true`.
- **Expiration**: The `expiresAt` check is always evaluated against the current device clock, even when using cached configuration. Expiration depends on device clock accuracy.

---

## Firestore Security Rules

Deploy the included `firestore.rules` to your Firebase project:

- **Testers (Anonymous Auth)**: Can read `config/global` and can only create, update, and read their own tester document (`testers/{testerId}`) and sessions (`testers/{testerId}/sessions/{sessionId}`).
- **Developers (Viewer / Dashboard)**: Can read all tester documents and write `config/global`. Deletion and tampering of historical session data is blocked.

---

## Flutter Web Dashboard

A companion Flutter Web application for monitoring testers and managing remote tracking configuration is located in the [`dashboard/`](dashboard/) directory.

- **Zero Central Backend**: Connects directly from the developer's browser to their own Firebase project.
- **Multi-Project Support**: Manage multiple tracking projects and switch between them locally.
- **Owner-Allowlist Protected**: Enforces explicit Firebase Auth UID allowlists in Firestore Security Rules.
- **Isolated Dependencies**: Dashboard dependencies live entirely in `dashboard/pubspec.yaml` and do not bloat the published package.

See [`dashboard/README.md`](dashboard/README.md) for local run instructions and Firebase configuration.

---

## License

MIT License.
