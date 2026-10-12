# Changelog

All notable changes to `tester_track` will be documented in this file.

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
