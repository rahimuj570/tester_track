# Changelog

All notable changes to `tester_track` will be documented in this file.

## 0.0.1

* Initial release of `tester_track`.
* Secondary Firebase App isolation via named `FirebaseApp` instance (`tester_track`).
* Automatic session tracking with app lifecycle observation (foreground vs. background accumulation).
* Crash recovery using locally persisted foreground session duration.
* Anonymous authentication on secondary Firebase project with zero impact on host app auth state.
* Optional runtime tester identification (`setTesterId`) and session transition.
* Remote configuration via Firestore (`config/global`) with live kill switch and sync interval control.
* Companion Flutter Web Dashboard for monitoring closed testing metrics and remote config management.
