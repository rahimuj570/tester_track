import 'package:flutter/widgets.dart';
import '../core/error_handler.dart';
import '../session/session_manager.dart';

/// Observes host application lifecycle transitions and delegates to [SessionManager].
class AppLifecycleObserver with WidgetsBindingObserver {
  final SessionManager sessionManager;
  final TrackerErrorHandler errorHandler;
  final VoidCallback? onResumed;
  bool _isAttached = false;

  AppLifecycleObserver({
    required this.sessionManager,
    required this.errorHandler,
    this.onResumed,
  });

  /// Whether the observer is currently attached to [WidgetsBinding].
  bool get isAttached => _isAttached;

  /// Attaches the lifecycle observer safely.
  void attach() {
    errorHandler.runGuardedSync(() {
      if (_isAttached) return;
      WidgetsBinding.instance.addObserver(this);
      _isAttached = true;
      errorHandler.log('AppLifecycleObserver attached.');
    }, operationName: 'AppLifecycleObserver.attach');
  }

  /// Detaches the lifecycle observer safely.
  void detach() {
    errorHandler.runGuardedSync(() {
      if (!_isAttached) return;
      WidgetsBinding.instance.removeObserver(this);
      _isAttached = false;
      errorHandler.log('AppLifecycleObserver detached.');
    }, operationName: 'AppLifecycleObserver.detach');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    errorHandler.runGuardedSync(() {
      errorHandler.log('App lifecycle changed: $state');
      switch (state) {
        case AppLifecycleState.resumed:
          sessionManager.onAppResume();
          onResumed?.call();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          sessionManager.onAppPauseOrInactive();
          break;
      }
    }, operationName: 'AppLifecycleObserver.didChangeAppLifecycleState');
  }
}
