import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/api_environment.dart';

void main() {
  group('Security & Network Configuration Tests (DEF-13 / TLS Enforce)', () {
    test('1. Production ApiEnvironment uses strictly HTTPS and blizaus.online', () {
      final prod = ApiEnvironment.production;
      expect(prod.baseUrl, 'https://blizaus.online/api');
      expect(prod.baseUrl.startsWith('https://'), isTrue,
          reason: 'Production API URL must strictly use HTTPS protocol');
    });

    test('2. ApiService defaultBaseUrl defaults to https://blizaus.online/api', () {
      expect(ApiService.defaultBaseUrl, 'https://blizaus.online/api');
      expect(ApiService.defaultBaseUrl.startsWith('https://'), isTrue);
    });

    test('3. Deprecated technical address e340043kek.temp.swtest.ru is eliminated', () {
      expect(ApiService.defaultBaseUrl.contains('e340043kek'), isFalse);
      for (final env in ApiEnvironment.all) {
        expect(env.baseUrl.contains('e340043kek'), isFalse,
            reason: 'Environment ${env.name} still references deprecated swtest domain');
      }
    });

    test('4. Release AndroidManifest explicitly disables cleartext and wires networkSecurityConfig', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'Release AndroidManifest.xml must exist');
      final content = manifestFile.readAsStringSync();

      expect(content.contains('android:usesCleartextTraffic="true"'), isFalse,
          reason: 'Release manifest must NEVER permit cleartext traffic globally');
      expect(content.contains('android:networkSecurityConfig="@xml/network_security_config"'), isTrue,
          reason: 'Release manifest must reference networkSecurityConfig');
    });

    test('5. network_security_config.xml permits cleartext ONLY for local development', () {
      final configFile = File('android/app/src/main/res/xml/network_security_config.xml');
      expect(configFile.existsSync(), isTrue, reason: 'network_security_config.xml must exist');
      final content = configFile.readAsStringSync();

      expect(content.contains('<base-config cleartextTrafficPermitted="false">'), isTrue,
          reason: 'Base configuration must strictly forbid cleartext traffic');
      expect(content.contains('10.0.2.2'), isTrue,
          reason: 'Must permit cleartext for Android emulator loopback');
      expect(content.contains('192.168.1.105'), isTrue,
          reason: 'Must permit cleartext for developer local Wi-Fi IP');
      expect(content.contains('blizaus.online'), isFalse,
          reason: 'Must NEVER allow cleartext traffic for production domain');
    });

    test('6. Codebase audit confirms no certificate bypass mechanisms exist', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(text.contains('badCertificateCallback ='), isFalse,
            reason: 'Illegal certificate validation bypass found in ${file.path}');
        expect(text.contains('HttpOverrides.global ='), isFalse,
            reason: 'Illegal global HTTP override found in ${file.path}');
        expect(text.contains('allowBadCertificates = true'), isFalse,
            reason: 'Illegal bad cert allow found in ${file.path}');
      }
    });

    test('7. ApiEnvironment parser correctly categorizes HTTPS production URL', () {
      final env = ApiEnvironment.fromBaseUrl('https://blizaus.online/api');
      expect(env.type, EnvironmentType.production);
      expect(env.baseUrl, 'https://blizaus.online/api');
    });
  });
}
