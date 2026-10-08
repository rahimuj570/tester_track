import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/error_handler.dart';

/// Lightweight wrapper around [SharedPreferences] with fail-safe fallback handling.
class LocalStorage {
  final TrackerErrorHandler errorHandler;
  SharedPreferences? _prefs;

  LocalStorage({required this.errorHandler});

  /// Initializes the underlying [SharedPreferences] instance safely.
  Future<bool> init() async {
    return await errorHandler.runGuarded<bool>(() async {
          _prefs = await SharedPreferences.getInstance();
          return true;
        }, operationName: 'LocalStorage.init', fallbackValue: false) ??
        false;
  }

  /// Gets the persistent tester ID if previously generated and stored.
  String? getPersistentTesterId() {
    return errorHandler.runGuardedSync<String?>(() {
      return _prefs?.getString(TrackerConstants.prefsTesterIdKey);
    }, operationName: 'LocalStorage.getPersistentTesterId');
  }

  /// Saves the persistent anonymous tester ID.
  Future<bool> savePersistentTesterId(String testerId) async {
    return await errorHandler.runGuarded<bool>(() async {
          if (_prefs == null) await init();
          return await _prefs?.setString(
                TrackerConstants.prefsTesterIdKey,
                testerId,
              ) ??
              false;
        },
            operationName: 'LocalStorage.savePersistentTesterId',
            fallbackValue: false) ??
        false;
  }

  /// Gets raw string value for a key safely.
  String? getString(String key) {
    return errorHandler.runGuardedSync<String?>(() {
      return _prefs?.getString(key);
    }, operationName: 'LocalStorage.getString');
  }

  /// Sets raw string value for a key safely.
  Future<bool> setString(String key, String value) async {
    return await errorHandler.runGuarded<bool>(() async {
          if (_prefs == null) await init();
          return await _prefs?.setString(key, value) ?? false;
        }, operationName: 'LocalStorage.setString', fallbackValue: false) ??
        false;
  }

  /// Removes a key safely.
  Future<bool> remove(String key) async {
    return await errorHandler.runGuarded<bool>(() async {
          if (_prefs == null) await init();
          return await _prefs?.remove(key) ?? false;
        }, operationName: 'LocalStorage.remove', fallbackValue: false) ??
        false;
  }
}
