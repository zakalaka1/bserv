# Security rules tests

Emulator-backed tests for [`firestore.rules`](../firestore.rules) and
[`storage.rules`](../storage.rules), built on
[`@firebase/rules-unit-testing`](https://firebase.google.com/docs/rules/unit-tests).

Everything runs against the `demo-bserv` project ID, which the Emulator Suite
treats as local-only, so the suite can never reach `bserv-512916`.

## Running

```bash
npm install            # once
npm run test:emulator  # starts the emulators, runs mocha, shuts them down
```

`npm test` runs mocha on its own, for when the emulators are already up:

```bash
firebase emulators:start --only firestore,storage
npm test
```

## How it is wired

- `support/emulator.js` builds the test environments. Emulator host and port
  come from the `*_EMULATOR_HOST` variables that `firebase emulators:exec`
  exports, with the ports in `firebase.json` as the fallback, so the two files
  cannot drift apart.
- `firestore.rules.spec.js` and `storage.rules.spec.js` build clients with
  `authenticatedContext(uid, claims)`, `unauthenticatedContext()` and
  `withSecurityRulesDisabled()`.
- Adding a second `.spec.js` file also means adding it to `spec` in
  `.mocharc.json`.

## Conventions

- Payloads mirror what `lib/data/` writes; when a repository changes its fields,
  change the matching builder here.
- Every "allow" test has a "refuse" twin, so a rule that is widened by accident
  fails instead of passing quietly.
- `firestore-debug.log` and `storage-debug.log` collect the emulator's
  per-request rule traces when a test is hard to explain.

## The admin claim

Both rule files gate every admin path on `request.auth.token.admin == true`.
These tests set that claim explicitly through `authenticatedContext`, so they
check the rules themselves. They cannot check that a real admin ever receives
the claim, because nothing in the project provisions it yet.
