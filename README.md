<p align="center">
  <img src="assets/images/logo_wordmark.png" alt="TesterTrack — Know who is actually testing." width="520">
</p>

<p align="center">
  <a href="https://pub.dev/packages/tester_track"><img src="https://img.shields.io/badge/pub-v0.0.4-blue.svg" alt="pub package"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/platform-flutter%20%7C%20android%20%7C%20ios-blue" alt="Flutter Platform"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/firebase-firestore%20%26%20auth-orange.svg" alt="Firebase Powered"></a>
</p>

A lightweight, developer-owned Flutter package for monitoring tester engagement during **Google Play Closed Testing (14-day / 20-tester requirement)** without expensive third-party SaaS tools or backend servers.

All analytics data and remote configuration live strictly inside your own secondary Firebase project.

---

## 📑 Table of Contents

- [Why TesterTrack?](#-why-testertrack)
- [Key Features](#-key-features)
- [How It Works](#-how-it-works)
  - [Secondary Firebase App Isolation](#1-secondary-firebase-app-zero-config-collision)
  - [Session Lifecycle & 30-Minute Inactivity Window](#2-session-lifecycle--inactivity-window-30-minute-standard)
  - [Firebase Free Tier Optimization](#3-firebase-free-tier-optimization-spark-plan)
- [Quick Start Guide](#-quick-start-guide)
  - [1. Add Dependency](#1-add-dependency)
  - [2. Firebase Project Setup](#2-firebase-project-setup)
  - [3. Firestore Security Rules (Optional for Quick Testing)](#3-firestore-security-rules-optional-for-quick-testing)
  - [4. Initialize TesterTrack in Your Flutter App](#4-initialize-testertrack-in-your-flutter-app)
- [Identifying Testers by Email (Post-Login)](#-identifying-testers-by-email-post-login)
- [Companion Web Dashboard](#-companion-web-dashboard)
- [Remote Configuration & Kill Switch](#-remote-configuration--kill-switch)
- [API Reference](#-api-reference)
- [Troubleshooting & Common Errors](#-troubleshooting--common-errors)
- [FAQ & Architecture Insights](#-faq--architecture-insights)
- [Privacy & Google Play Compliance](#-privacy--google-play-compliance)
- [License](#-license)

---

## 💡 Why TesterTrack?

To publish new apps on Google Play, Google requires personal developer accounts to run a **closed test with at least 20 testers opted in for 14 continuous days**. 

Traditional analytics tools (like Google Analytics or Mixpanel) are often noisy, complicated to filter for specific QA testers, or take 24–48 hours to process session batches. 

**TesterTrack** solves this with:
- ⏱️ **Real-time daily usage metrics**: See instantly who is active today, their session durations, and overall engagement history.
- 🔒 **100% Developer-Owned**: No subscriptions, no external servers. Data goes directly from the tester's device to your Firebase Firestore database.
- ⚡ **Zero-interference integration**: Runs as a named secondary Firebase App. It never conflicts with your app's existing Firebase setup or `google-services.json`.

---

## ✨ Key Features

- **Accurate Foreground Tracking**: Only observed foreground time is tracked. Background sleep or wall-clock idle time is excluded.
- **Crash & Sudden Exit Recovery**: Automatically recovers interrupted sessions on the next app launch using locally persisted checkpoints.
- **Identify Testers by Email or Installation ID**: Tag testers by their email post-login or use cryptographically generated anonymous installation IDs.
- **Remote Kill-Switch**: Remotely disable tracking once the 14-day testing period ends by updating a Firestore document. No new app release needed!
- **Battery & Network Efficient**: Throttled heartbeats and periodic sync buffers (default: 5 minutes) protect device battery and stay well within Firebase free tier limits.
- **Beautiful Real-Time Web Dashboard**: Built-in Flutter Web dashboard with responsive UI, search, filtering, and export capabilities.

---

## 🏗️ How It Works

### 1. Secondary Firebase App (Zero Config Collision)

You **do not** need to download or merge a `google-services.json` or `GoogleService-Info.plist` file into your mobile app!

TesterTrack instantiates an isolated in-memory Firebase App:
```dart
Firebase.initializeApp(
  name: 'tester_track', // Isolated named app
  options: yourTesterTrackFirebaseOptions,
);
```

```mermaid
graph LR
    subgraph Client App
      A[Host App Logic] --> B[Default Firebase App: google-services.json]
      C[TesterTrack Engine] --> D[Named Firebase App: tester_track]
    end
    subgraph Google Cloud
      B --> E[Primary App Backend]
      D --> F[Your TesterTrack Firebase Project]
    end
```

This guarantees:
1. **Zero collisions**: Your primary Firebase auth, push notifications, and database remain untouched.
2. **Easy plug-and-play**: Simply pass your credentials in Dart code.

---

### 2. Session Lifecycle & Inactivity Window (30-Minute Standard)

Following industry analytics standards (like Google Analytics 4 / GA4), TesterTrack seamlessly handles real-world mobile app usage:

```mermaid
stateDiagram-v2
    [*] --> ActiveForeground: App Opened
    ActiveForeground --> PausedBackground: Minimized / Switched Apps
    
    state PausedBackground {
        [*] --> InactivityTimer: Start 30m Window
        InactivityTimer --> ResumedWithin30m: Reopened <= 30m
        InactivityTimer --> ExpiredAfter30m: Inactive > 30m
    }
    
    ResumedWithin30m --> ActiveForeground: Continues Same Session (0s background time added)
    ExpiredAfter30m --> FinalizedSession: Finalized in Firestore (isFinalized = true)
    FinalizedSession --> ActiveForeground: Next Open Starts New Session
```

- **Instant Flush on App Minimize / Background**:
  - The exact moment a tester minimizes or backgrounds the app (even after just 1 minute of use), all accumulated foreground duration is **instantly synced to Firestore**.
  - Your companion dashboard immediately reflects the tester's latest usage, active date, and last-seen timestamp without waiting for background timers or next app launches.
  - Even if the Android OS kills the background process seconds later, the tester's usage data is already safely stored in Firestore.
- **App Minimized or Switched (<= 30 minutes)**:
  - If a tester temporarily minimizes the app, switches to another app, checks a notification, or copies an OTP code and returns within 30 minutes:
    - The **exact same session continues** with the original session ID.
    - **Background idle time is strictly excluded**: Wall-clock background time is never added to the duration. Only active foreground seconds count.
    - Upon next pause, only the new foreground delta is synced, preventing duplicate counts.
- **App Inactive (> 30 minutes)**:
  - If the tester does not return within 30 minutes, the session is cleanly finalized in Firestore (`isFinalized: true`) with its true observed foreground duration.
  - Reopening the app after 30 minutes starts a brand-new session.
- **App Killed / Swiped Away (Cold Starts)**:
  - If the user swipes away the app from recent tasks or the OS terminates the process:
    - TesterTrack flushes the active duration and saves a local recovery checkpoint in `SharedPreferences`.
    - **Reopened <= 30m**: Seamlessly recovers and resumes the existing session.
    - **Reopened > 30m**: Finalizes the previous session and starts a new session.

---

### 3. Firebase Free Tier Optimization (Spark Plan)

TesterTrack is engineered to operate comfortably within Firebase's Spark Free Tier (20,000 writes/day):

- **Instant Flush on Pause**: When the app is minimized, 1 write flushes the session duration and updates tester aggregates.
- **In-memory local heartbeats**: Monitors foreground elapsed time every 15 seconds locally without making any network requests.
- **5-minute periodic sync**: During continuous, uninterrupted foreground use, progress flushes to Firestore once every 5 minutes.
- **Ultra-low quota footprint**: A typical session with multiple pauses uses **only ~2–4 Firestore writes total** (1 at start, 1 per pause, 1 at finalization). For 20 testers using the app multiple times daily, this consumes ~150–200 writes/day—less than **1%** of your daily free tier quota!

---

## 🚀 Quick Start Guide

### 1. Add Dependency

Add `tester_track` to your `pubspec.yaml`:

```yaml
dependencies:
  tester_track: ^0.0.4
```

Or run:
```bash
flutter pub add tester_track
```

---

### 2. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new Firebase project (e.g., `my-app-tester-track`).
2. **Enable Anonymous Authentication**:
   - Go to **Build** > **Authentication** > **Sign-in method**.
   - Enable **Anonymous** provider.
3. **Enable Cloud Firestore**:
   - Go to **Build** > **Firestore Database** > **Create database**.
   - Choose a region near your testers and start in test mode.
4. **Get Firebase Options**:
   - In Project Settings > General > Web Apps, register a web app (or use FlutterFire CLI) to copy your `FirebaseOptions` credentials:
     - `apiKey`
     - `appId`
     - `messagingSenderId`
     - `projectId`
     - `storageBucket`

> 📱 **Android Permission Requirement**: Ensure your app has internet access enabled in `android/app/src/main/AndroidManifest.xml` (outside the `<application>` tag):
> ```xml
> <uses-permission android:name="android.permission.INTERNET"/>
> <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
> ```

---

### 3. Firestore Security Rules (Optional for Quick Testing)

> ⚡ **Quick Start (Zero Config)**:  
> If you selected **"Start in test mode"** when creating Firestore, you can **skip this step completely!** The package will work immediately out of the box.

When you are ready for real closed testing (to prevent Firebase's 30-day Test Mode auto-lockout and protect tester data privacy), simply copy and paste the ready-to-use [`firestore.rules`](firestore.rules) file into your Firebase Firestore Rules tab.

*(No custom rule coding required — the rules file is pre-configured and ready to paste).*

---

### 4. Initialize TesterTrack in Your Flutter App

#### Option A: Post-Login Identification with Tester Email (Recommended)
If your app has a login flow and you want testers to appear on your dashboard with their actual email address:

```dart
import 'package:flutter/material.dart';
import 'package:tester_track/tester_track.dart';

const testerTrackOptions = FirebaseOptions(
  apiKey: 'AIzaSy...',
  appId: '1:123456789:web:...',
  messagingSenderId: '123456789',
  projectId: 'my-tester-track-project',
  storageBucket: 'my-tester-track-project.appspot.com',
);

// Call this right after the tester successfully logs in:
Future<void> onUserLoggedIn(String userEmail) async {
  await TesterTrack.initialize(
    firebaseOptions: testerTrackOptions,
    testerId: userEmail, // e.g. 'tester.alex@gmail.com'
  );
}

// In your splash screen or main() if the user is already authenticated:
void restoreSession(String? savedUserEmail) async {
  if (savedUserEmail != null) {
    await TesterTrack.initialize(
      firebaseOptions: testerTrackOptions,
      testerId: savedUserEmail,
    );
  }
}

// When tester logs out:
void onUserLoggedOut() {
  TesterTrack.instance.stopTracking();
}
```

#### Option B: Pre-Login / App-Start Initialization in `main.dart`
If you want to track pre-login startup, onboarding, or unauthenticated apps:

```dart
import 'package:flutter/material.dart';
import 'package:tester_track/tester_track.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TesterTrack.initialize(
    firebaseOptions: const FirebaseOptions(
      apiKey: 'AIzaSy...',
      appId: '1:123456789:web:...',
      messagingSenderId: '123456789',
      projectId: 'my-tester-track-project',
      storageBucket: 'my-tester-track-project.appspot.com',
    ),
    // Omit testerId to auto-generate a secure anonymous installation ID (e.g. tt_1926b01a_...)
  );

  runApp(const MyApp());
}
```

---

## 👤 Identifying Testers at Runtime (`setTesterId`)

If you initialize `TesterTrack` in `main.dart` anonymously and want to link the tester's email after they complete the login screen:

```dart
// After user signs in:
await TesterTrack.instance.setTesterId('john.doe@company.com');
```

**What happens automatically:**
1. Finalizes the pre-login anonymous session cleanly.
2. Synchronizes the new tester profile under `/testers/john.doe@company.com`.
3. Seamlessly begins tracking all future sessions under the new identity.

When the user logs out:
```dart
await TesterTrack.instance.resetTesterId(); 
// or: TesterTrack.instance.stopTracking();
```

---

## 🖥️ Companion Web Dashboard

<p align="center">
  <img src="assets/images/dashboard_preview.png" alt="TesterTrack Web Dashboard Preview" width="100%">
</p>

> 🌐 **Live Web Dashboard**: [https://tester-track.pages.dev/](https://tester-track.pages.dev/)

TesterTrack includes an open-source, responsive Flutter Web Dashboard located in the [`dashboard/`](dashboard/) folder.

### Running the Dashboard Locally

```bash
cd dashboard
flutter run -d chrome
```

### Dashboard Features:
- 📊 **Overview KPI Cards**: Total testers, active testers, sessions count, total testing hours.
- 🟢 **Active Today Tracker**: See at a glance which testers opened the app today and their exact time spent.
- 📋 **Tester Detail View**: Breakdown of all individual sessions, duration, device OS, and app version.
- ⚙️ **Remote Config Management**: Flip the global kill switch or adjust sync intervals right from the browser.

---

## 🎛️ Remote Configuration & Kill Switch

TesterTrack features built-in remote configuration managed via Firestore:

**Document Path**: `config/global`

```json
{
  "enabled": true,
  "expiresAt": null,
  "minAppVersion": null,
  "syncIntervalSeconds": 300
}
```

### Remotely Disabling Tracking
When your Google Play 14-day closed testing is complete:
1. Open the Web Dashboard (or your Firebase Console).
2. Set `"enabled": false`.
3. All tester devices will automatically finalize their current session and stop tracking immediately on their next config refresh. **No new app update needed!**

---

## 📚 API Reference

### `TesterTrack`

| Method / Property | Return Type | Description |
|---|---|---|
| `initialize({...})` | `Future<bool>` | Initializes the engine, named Firebase app, and session manager. Safe to call multiple times. |
| `instance` | `TesterTrack` | Singleton instance of `TesterTrack`. |
| `isInitialized` | `bool` | Whether the tracking engine is successfully initialized. |
| `isTracking` | `bool` | Whether a foreground session is currently active. |
| `testerId` | `String?` | The current active tester ID. |
| `setTesterId(String id)` | `Future<bool>` | Updates the active tester identity (e.g. after login), transitions session, and updates Firestore. |
| `resetTesterId()` | `Future<bool>` | Resets tester ID back to an anonymous installation identifier. |
| `startTracking()` | `void` | Manually resumes tracking if permitted. |
| `stopTracking()` | `void` | Manually finalizes active session and stops tracking. |

### `TesterTrackOptions`

```dart
const TesterTrackOptions({
  Duration sessionTimeout = const Duration(minutes: 30),
  Duration localHeartbeatInterval = const Duration(seconds: 15),
  Duration firestoreSyncInterval = const Duration(minutes: 5),
  Duration inactivityDebounce = const Duration(seconds: 15),
  bool debugLogging = false,
});
```

| Option | Default | Description |
|---|---|---|
| `sessionTimeout` | `30 minutes` | Inactivity window. Resuming the app within 30 minutes seamlessly continues the existing session (background time is excluded). Exceeding 30 minutes starts a new session. |
| `localHeartbeatInterval` | `15 seconds` | Local heartbeat timer for memory tracking (zero Firestore network overhead). |
| `firestoreSyncInterval` | `5 minutes` | Periodic Firestore duration delta flush during continuous foreground use. |
| `inactivityDebounce` | `15 seconds` | Legacy alias for `sessionTimeout`. |
| `debugLogging` | `false` | Enables internal diagnostic console logging. |

---

## 🔧 Troubleshooting & Common Errors

### 1. `W/ManagedChannelImpl: Failed to resolve name` or `[cloud_firestore/unavailable]`

#### Symptoms
```text
W/ManagedChannelImpl(10049): [{0}] Failed to resolve name. status={1}
[cloud_firestore/unavailable] The service is currently unavailable.
```

#### Causes & Fixes

1. **Missing Android Internet Permissions (Most Common on new Flutter apps)**:
   Ensure `android.permission.INTERNET` is in `android/app/src/main/AndroidManifest.xml` (outside the `<application>` tag):
   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android">
       <uses-permission android:name="android.permission.INTERNET"/>
       <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
       <application ...>
   ```

2. **Android Emulator DNS Glitch**:
   Android emulators frequently lose DNS connectivity to Google servers if the host PC switches Wi-Fi networks, wakes from sleep, or connects to a VPN.
   - **Quick Fix:** In the emulator, pull down the notification shade, turn **Airplane mode ON for 3 seconds**, then turn it **OFF**.
   - **Cold Boot:** In Android Studio, open **Device Manager** ➔ Click the **three dots** (⋮) next to your virtual device ➔ Click **Cold Boot Now**.
   - Verify by opening Chrome inside the emulator and visiting any website.

3. **Cloud Firestore Not Created in Firebase Console**:
   Make sure you have navigated to your Firebase project ➔ **Build** ➔ **Firestore Database** and clicked **Create database**.

4. **Anonymous Authentication Not Enabled**:
   If using anonymous sign-in, navigate to Firebase Console ➔ **Build** ➔ **Authentication** ➔ **Sign-in method** ➔ ensure **Anonymous** is **Enabled**.

5. **Using a Web App ID on Android**:
   In your `FirebaseOptions`, if testing on an Android device or emulator, register an **Android App** in your Firebase project (using your app's package name, e.g. `com.example.yourapp`) and use the generated Android `appId` (starts with `1:...:android:...`).

---

### 2. `WARNING: Your app uses plugins that apply Kotlin Gradle Plugin (KGP): device_info_plus, package_info_plus`

#### Symptoms
```text
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): device_info_plus, package_info_plus
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

#### What It Means & Why It Appears
- **It is an informational deprecation notice, NOT a build failure**: Your app will build, launch, and run normally in both debug and release modes.
- In Flutter 3.24+ and 3.27+, the Flutter Gradle Plugin (FGP) checks for Android plugins that apply the legacy Kotlin Gradle Plugin (`kotlin-android`) directly in their build scripts.
- Google and Flutter are transitioning towards **Built-in Kotlin** support (introduced in AGP 8.8+ / 9.0+). The warning is a forward-looking heads-up that future major versions of Flutter will eventually require Built-in Kotlin.

#### Recommended Action
- **No immediate action required**: You do not need to change anything in your app; tracking and device metadata resolution function normally.
- In your application's `android/gradle.properties`, standard compatibility mode is maintained with:
  ```properties
  android.builtInKotlin=false
  ```
- When Flutter makes Built-in Kotlin mandatory in future releases, `tester_track` will update its dependency constraints to match the new ecosystem standards.

---

### 3. `API key not valid` or Deleted Firebase Project

#### Symptoms
```text
[firebase_auth/unknown] An internal error has occurred. [ API key not valid. Please pass a valid API key. ]
[cloud_firestore/permission-denied] Permission denied on resource project <your-project-id>
[TesterTrack] Circuit breaker tripped: Fatal Firebase error
```

#### What It Means
- This occurs when the Firebase project configured in `secondaryFirebaseOptions` was deleted in Firebase Console, or invalid/revoked credentials were provided.
- **Fail-Safe Circuit Breaker**: TesterTrack automatically detects fatal backend errors and activates its internal circuit breaker. It halts tracking immediately, cancels all background timers, and returns `false` from `TesterTrack.initialize()`.
- **Your host application will NEVER crash or freeze**: Your app continues launching normally and `runApp()` executes immediately.

#### How to Resolve
1. Create or select an active Firebase project in [Firebase Console](https://console.firebase.google.com).
2. Ensure **Anonymous Authentication** and **Cloud Firestore** are enabled.
3. Update your `secondaryFirebaseOptions` with the new project's credentials. TesterTrack will automatically detect the new `projectId`, purge previous stale caches, and begin tracking cleanly.

---

## ❓ FAQ & Architecture Insights

#### Q: Why don't I need `google-services.json`?
**A:** `google-services.json` is only used by the Google Services Gradle plugin to configure the default `[DEFAULT]` Firebase App. Because TesterTrack initializes an explicitly named secondary app in Dart (`Firebase.initializeApp(name: 'tester_track', options: ...)`), it operates purely from in-memory options without needing native config files.

#### Q: What if a tester loses internet connection?
**A:** TesterTrack uses local device storage (`SharedPreferences`) to buffer active session duration. Once connectivity resumes or on the next sync interval, the accumulated foreground time is synchronized to Firestore.

#### Q: What if the app crashes or the user swipes it away?
**A:** Interrupted sessions are saved at regular local checkpoints. Upon next app launch, TesterTrack automatically recovers the interrupted session and marks it cleanly with the true observed duration.

---

## 🛡️ Privacy & Google Play Compliance

- **No Sensitive Data**: TesterTrack does not access location, contacts, advertising IDs, or camera.
- **Device Information**: Only collects platform OS version, device model, and app package version for QA device compatibility diagnostics.
- **Anonymous Authentication**: Tester devices connect via Firebase Anonymous Auth, requiring no passwords or external OAuth scopes.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
