// Web implementation of the Auth emulator pre-seed.
//
// `firebase_auth_web` initialises the Auth instance while
// `Firebase.initializeApp()` is still running (it awaits `onAuthStateChanged`
// to resolve the persisted user). Once that happens the JS SDK refuses any
// later `connectAuthEmulator` call with `auth/emulator-config-failed`, and
// `firebase_auth_web` swallows that specific error - leaving Auth pointed at
// production.
//
// The plugin works around this on reload by re-applying a previously stored
// emulator origin from `sessionStorage` *before* it touches the Auth instance
// (`ensurePluginInitialized`). Writing that same entry before
// `Firebase.initializeApp()` makes the very first load behave like a reload.

import 'package:web/web.dart' as web;

/// `authEmulatorOriginStorageKey(Firebase.app().name)` from
/// `package:firebase_auth_web`; the default app is always named `[DEFAULT]`.
const _storageKey = '[DEFAULT]-firebaseEmulatorOrigin';

/// Stores [origin] (e.g. `http://127.0.0.1:9299`) where `firebase_auth_web`
/// looks for it during `Firebase.initializeApp()`.
void seedAuthEmulatorOrigin(String origin) {
  web.window.sessionStorage.setItem(_storageKey, origin);
}
