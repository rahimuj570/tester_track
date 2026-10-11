# TesterTrack — Developer Dashboard (Flutter Web)

A lightweight, developer-owned Flutter Web application for monitoring tester engagement, tracking closed-testing progress (e.g. Google Play 14-day / 20-tester requirements), and remotely managing tracking configuration directly on each developer's secondary Firebase project.

---

## Architecture — Zero Backend

```text
Developer's Browser
  ├── TesterTrack Web Dashboard (Flutter Web)
  └── Local Browser Storage (localStorage)
        │
        ▼ (Direct Encrypted Connection via Firebase SDK)
Developer's Secondary Firebase Project
  ├── Firebase Authentication (Google Sign-In / Email-Password)
  └── Cloud Firestore (Isolated testers/ & config/global collections)
```

- **No Third-Party Servers**: Runs completely in the browser. Zero VPS, serverless functions, or intermediary databases.
- **Client-Side Project Storage**: Firebase web app configs are saved locally in browser `localStorage`.
- **Enforced Project Isolation**: Multiple Firebase projects are isolated using named `FirebaseApp` instances (`FirebaseAuth.instanceFor(app: ...)`, `FirebaseFirestore.instanceFor(app: ...)`).
- **Owner Security Rules Authority**: Security is enforced at the database level by `firestore.rules` using an explicit authorized developer UID allowlist.

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (>=3.10.0)
- Google Chrome browser (for local debugging)

### 2. Run Dashboard Locally

From the `dashboard/` directory:

```bash
cd dashboard
flutter pub get
flutter run -d chrome
```

---

## Firebase Setup Guide

### Step 1: Register a Web App in Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/) and select your secondary TesterTrack Firebase project.
2. Go to **Project Settings** > **General** > **Your apps** > click **Add app** (select **Web** `</>`).
3. Enter an app nickname (e.g. `TesterTrack Web Dashboard`).
4. Copy the `firebaseConfig` object containing:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `storageBucket`
   - `authDomain` (optional)

### Step 2: Enable Authentication Providers
1. In Firebase Console, go to **Build** > **Authentication** > **Sign-in method**.
2. Enable **Google** and/or **Email/Password**.
3. Under **Authorized Domains**, ensure `localhost` (and your production hosting domain if hosted) is listed.

### Step 3: Configure Owner UID Allowlist in `firestore.rules`
Because there is no central server, project ownership is securely enforced by matching the signed-in developer's Firebase Auth UID in `firestore.rules`.

1. Launch the dashboard and sign in using Google or Email/Password.
2. Click the **Shield Icon** or **Setup Guide** in the top navigation bar to view and copy your **Auth UID** (e.g. `abc123xyz456`).
3. Open `firestore.rules` in your project and add your UID to `isAuthorizedDeveloper()`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthorizedDeveloper() {
      return request.auth != null && 
             request.auth.token.firebase.sign_in_provider != 'anonymous' &&
             request.auth.uid in [
               'YOUR_COPIED_DEVELOPER_AUTH_UID_HERE'
             ];
    }
    // ...
```

4. Deploy the rules:
```bash
firebase deploy --only firestore:rules
```

---

## Features

### 1. Overview & Google Play 20-Tester Progress
- **Total Testers**: All unique installation IDs registered in `testers/`.
- **Active in Last 14 Days**: Number of testers seen in the last 14 days with visual progress towards Google Play's 20-tester closed testing requirement.
- **Total Recorded Sessions**: Sum of foreground sessions across all testers.
- **Total Usage Duration**: Cumulative foreground time observed.
- **Platform Breakdown**: Android vs. iOS distribution.

### 2. Testers & Session History
- Search testers by Tester ID, device model, or app version.
- Sort by Last Seen, Total Usage, Sessions, or Active Days.
- Drill down into an individual tester to view their device metadata and paginated list of recorded sessions (`testers/{testerId}/sessions/{sessionId}`) with exact start/end times and finalization status.

### 3. Remote Tracking Controls (`config/global`)
- **Global Kill-Switch**: Remotely disable tracking without releasing a new app build. Installed apps will finalize active sessions and stop tracking on their next config check.
- **Expiration Date**: Set a future timestamp after which client apps automatically disable tracking.
- **Minimum Version Constraint**: Enforce a minimum app version (e.g. `1.5.0`).
- **Sync Interval**: Adjust foreground sync interval (60 to 3600 seconds) to balance real-time data vs Firestore write costs.

### 4. Multiple Project Management
- Add multiple apps/projects (e.g. Production, Staging, App 1, App 2).
- Switch active projects in 1 click.
- Rename or delete saved configurations locally.

---

## Troubleshooting & FAQ

| Error | Solution |
|---|---|
| `permission-denied (Code: 7)` | Your authenticated account's UID is not in the `isAuthorizedDeveloper()` list in `firestore.rules`. Click the Shield icon in the top navigation bar to copy your UID, add it to `firestore.rules`, and run `firebase deploy --only firestore:rules`. |
| `auth/unauthorized-domain` | Add `localhost` to **Authentication** > **Settings** > **Authorized domains** in Firebase Console. |
| `auth/popup-closed-by-user` | Re-click Sign in with Google and complete the sign-in popup without closing the window. |
| Missing session documents | Ensure client applications were initialized with the matching `FirebaseOptions` for this project and have connected to the internet. |
