import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Represents a saved developer Firebase project configuration stored locally.
@immutable
class FirebaseProjectConfig {
  final String id;
  final String name;
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;
  final String? authDomain;
  final String? measurementId;

  const FirebaseProjectConfig({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
    this.authDomain,
    this.measurementId,
  });

  /// Deterministic unique Firebase App name for isolated multi-project handling.
  String get appName =>
      'tt_dash_${projectId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}_${id.substring(0, id.length > 8 ? 8 : id.length)}';

  /// Validates required fields before connecting.
  /// Returns a list of validation error messages, or an empty list if valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Project Name is required.');
    }
    if (apiKey.trim().isEmpty) {
      errors.add('API Key (apiKey) is required.');
    }
    if (appId.trim().isEmpty) {
      errors.add('App ID (appId) is required.');
    }
    if (messagingSenderId.trim().isEmpty) {
      errors.add('Messaging Sender ID is required.');
    }
    if (projectId.trim().isEmpty) {
      errors.add('Project ID (projectId) is required.');
    }
    if (storageBucket.trim().isEmpty) {
      errors.add('Storage Bucket is required.');
    }
    return errors;
  }

  /// Converts to standard [FirebaseOptions].
  FirebaseOptions toFirebaseOptions() {
    return FirebaseOptions(
      apiKey: apiKey.trim(),
      appId: appId.trim(),
      messagingSenderId: messagingSenderId.trim(),
      projectId: projectId.trim(),
      storageBucket: storageBucket.trim(),
      authDomain:
          authDomain?.trim().isNotEmpty == true ? authDomain!.trim() : null,
      measurementId: measurementId?.trim().isNotEmpty == true
          ? measurementId!.trim()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'storageBucket': storageBucket,
      'authDomain': authDomain,
      'measurementId': measurementId,
    };
  }

  factory FirebaseProjectConfig.fromMap(Map<String, dynamic> map) {
    return FirebaseProjectConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Project',
      apiKey: map['apiKey'] as String? ?? '',
      appId: map['appId'] as String? ?? '',
      messagingSenderId: map['messagingSenderId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      storageBucket: map['storageBucket'] as String? ?? '',
      authDomain: map['authDomain'] as String?,
      measurementId: map['measurementId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FirebaseProjectConfig.fromJson(String source) =>
      FirebaseProjectConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);

  FirebaseProjectConfig copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? appId,
    String? messagingSenderId,
    String? projectId,
    String? storageBucket,
    String? authDomain,
    String? measurementId,
  }) {
    return FirebaseProjectConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      messagingSenderId: messagingSenderId ?? this.messagingSenderId,
      projectId: projectId ?? this.projectId,
      storageBucket: storageBucket ?? this.storageBucket,
      authDomain: authDomain ?? this.authDomain,
      measurementId: measurementId ?? this.measurementId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebaseProjectConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          projectId == other.projectId &&
          apiKey == other.apiKey;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ projectId.hashCode ^ apiKey.hashCode;
}
