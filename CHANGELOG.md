# Changelog

All notable changes to `tester_track` will be documented in this file.

## 0.0.3

* Implement industry-standard 30-minute session inactivity window (`sessionTimeout`). Returning to the app within 30 minutes seamlessly resumes the active session.
* Strictly exclude background/minimize wall-clock idle time from session duration — only foreground usage is accumulated.
* Optimize Firestore network operations for Firebase Spark Free Tier: eliminate redundant network writes on momentary app minimize/switching, buffering state locally in `SharedPreferences`.
* Enhance crash & cold-start recovery to safely resume unfinalized sessions on app restart within the timeout window.
* Resolve transient `[cloud_firestore/unavailable]` errors during app backgrounding.

## 0.0.2

* Harden initial tester profile synchronization and session creation against non-existent document pre-check read errors.
* Ensure immediate Auth token retrieval on anonymous sign-in and session reuse to prevent first-launch race conditions.
* Update Firestore security rules to safely allow non-existent document pre-check reads (`resource == null`).
* Add unit tests verifying fresh launch tester creation.

## 0.0.1

* Initial release of `tester_track`.
* Secondary Firebase App isolation via named `FirebaseApp` instance (`tester_track`).
* Automatic session tracking with app lifecycle observation (foreground vs. background accumulation).
* Crash recovery using locally persisted foreground session duration.
* Anonymous authentication on secondary Firebase project with zero impact on host app auth state.
* Optional runtime tester identification (`setTesterId`) and session transition.
* Remote configuration via Firestore (`config/global`) with live kill switch and sync interval control.
* Companion Flutter Web Dashboard for monitoring closed testing metrics and remote config management.
