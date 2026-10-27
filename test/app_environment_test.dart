import 'package:bserv/app/app_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the emulator is the default backend', () {
    expect(AppEnvironment.useFirebaseEmulator, isTrue);
  });

  test('emulator ports match firebase.json', () {
    expect(AppEnvironment.authEmulatorPort, 9299);
    expect(AppEnvironment.firestoreEmulatorPort, 8180);
    expect(AppEnvironment.storageEmulatorPort, 9298);
  });

  test('the emulator project is the demo project', () {
    expect(AppEnvironment.emulatorProjectId, 'demo-bserv');
    expect(AppEnvironment.emulatorOptions.projectId, 'demo-bserv');
    expect(
      AppEnvironment.emulatorOptions.storageBucket,
      'demo-bserv.appspot.com',
    );
  });

  test('non-web clients reach the emulators through loopback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(AppEnvironment.emulatorHost, '127.0.0.1');
  });

  test('the Android emulator reaches the host through 10.0.2.2', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(AppEnvironment.emulatorHost, '10.0.2.2');
  });
}
