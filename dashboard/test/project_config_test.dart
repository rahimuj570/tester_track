import 'package:flutter_test/flutter_test.dart';
import 'package:tester_track_dashboard/models/project_config.dart';

void main() {
  group('FirebaseProjectConfig Model Tests', () {
    test('validation detects missing required fields', () {
      const invalid = FirebaseProjectConfig(
        id: 'p1',
        name: '',
        apiKey: '',
        appId: '',
        messagingSenderId: '',
        projectId: '',
        storageBucket: '',
      );

      final errors = invalid.validate();
      expect(errors.length, equals(6));
      expect(errors.any((e) => e.contains('Project Name')), isTrue);
      expect(errors.any((e) => e.contains('API Key')), isTrue);
      expect(errors.any((e) => e.contains('App ID')), isTrue);
      expect(errors.any((e) => e.contains('Messaging Sender ID')), isTrue);
      expect(errors.any((e) => e.contains('Project ID')), isTrue);
      expect(errors.any((e) => e.contains('Storage Bucket')), isTrue);
    });

    test('validation succeeds when all required fields are present', () {
      const valid = FirebaseProjectConfig(
        id: 'proj_123',
        name: 'My Demo App',
        apiKey: 'AIzaSyExampleFakeKey123',
        appId: '1:123456789:web:abcdef',
        messagingSenderId: '123456789',
        projectId: 'demo-app-123',
        storageBucket: 'demo-app-123.appspot.com',
      );

      final errors = valid.validate();
      expect(errors, isEmpty);
    });

    test('deterministic appName is generated for named Firebase app isolation',
        () {
      const config = FirebaseProjectConfig(
        id: 'proj_unique_999',
        name: 'My App',
        apiKey: 'fake',
        appId: 'fake',
        messagingSenderId: 'fake',
        projectId: 'my-cool-project',
        storageBucket: 'fake',
      );

      expect(config.appName.startsWith('tt_dash_my_cool_project_'), isTrue);
    });

    test('toFirebaseOptions maps fields accurately', () {
      const config = FirebaseProjectConfig(
        id: 'proj_1',
        name: 'Test Project',
        apiKey: 'api_key_test',
        appId: 'app_id_test',
        messagingSenderId: 'sender_123',
        projectId: 'proj_test',
        storageBucket: 'bucket_test',
        authDomain: 'test.firebaseapp.com',
        measurementId: 'G-12345',
      );

      final options = config.toFirebaseOptions();
      expect(options.apiKey, equals('api_key_test'));
      expect(options.appId, equals('app_id_test'));
      expect(options.messagingSenderId, equals('sender_123'));
      expect(options.projectId, equals('proj_test'));
      expect(options.storageBucket, equals('bucket_test'));
      expect(options.authDomain, equals('test.firebaseapp.com'));
      expect(options.measurementId, equals('G-12345'));
    });

    test('JSON serialization roundtrip preserves all fields', () {
      const original = FirebaseProjectConfig(
        id: 'proj_roundtrip',
        name: 'Roundtrip Test',
        apiKey: 'key_123',
        appId: 'app_456',
        messagingSenderId: 'msg_789',
        projectId: 'proj_abc',
        storageBucket: 'bucket_xyz',
        authDomain: 'auth.domain',
        measurementId: 'meas_id',
      );

      final jsonStr = original.toJson();
      final reconstructed = FirebaseProjectConfig.fromJson(jsonStr);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.name, equals(original.name));
      expect(reconstructed.apiKey, equals(original.apiKey));
      expect(reconstructed.appId, equals(original.appId));
      expect(
          reconstructed.messagingSenderId, equals(original.messagingSenderId));
      expect(reconstructed.projectId, equals(original.projectId));
      expect(reconstructed.storageBucket, equals(original.storageBucket));
      expect(reconstructed.authDomain, equals(original.authDomain));
      expect(reconstructed.measurementId, equals(original.measurementId));
    });
  });
}
