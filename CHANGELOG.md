# Changelog

All notable changes to `tester_track` will be documented in this file.

## 0.0.4

* **Automatic Circuit Breaker for Fatal Firebase Errors**: Instantly trip circuit breaker and gracefully disable tracking on fatal backend errors (e.g., deleted Firebase project, invalid API keys, revoked project access, or disabled anonymous authentication), eliminating noisy crash-like stack traces.
* **Early Initialization Guard**: Abort initialization safely if anonymous authentication fails or backend is unreachable, preventing startup hangs, Application Not Responding (ANR) dialogs, and continuous background retry loops.
* **Hot Restart & Runtime Configuration Resilience**: Automatically detect credential changes during development and hot restart; seamlessly recover from native Android `[core/duplicate-app]` errors by deleting stale native app instances and cleanly applying the latest `FirebaseOptions`.
* **Automatic Stale Cache Invalidation**: When switching or updating Firebase projects (`projectId`), immediately purge stale local cache (`tt_cached_remote_config`) and unfinalized session state from the previous project.
* **Fail-Fast Launch Timeouts**: Add strict timeouts (4–5 seconds) to anonymous authentication and remote config fetching to guarantee that backend network latency never stalls application launch or delays `runApp()`.

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
