# admin-tools

One-off administrative tasks for the `bserv-512916` Firebase project. Today it
holds a single script, `set-admin-claim.js`.

## What the admin claim is

Both `firestore.rules` and `storage.rules` gate every admin path on

```
request.auth.token.admin == true
```

and `lib/services/firebase_auth_gateway.dart` reads the same claim off the ID
token before it lets the admin screens open. Nothing sets that claim at sign-up,
so an account is a normal customer account until this script grants it. The
Firebase console has no screen for custom claims, which is why the Admin SDK is
involved.

## Prerequisites

1. **A service account key.** Firebase console, project settings, service
   accounts, "Generate new private key". Save the JSON *outside* this
   repository, for example `~/.config/bserv/bserv-admin-service-account.json`.
   The key grants project-wide access, so treat it like a password. `.gitignore`
   already refuses the usual `service-account*.json` names.
2. **The admin user.** Created in Authentication with the email/password
   provider. The script finds it by `--uid` or `--email`.
3. **Dependencies.** `npm install` in this directory, once.

## Usage

```sh
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/bserv/bserv-admin-service-account.json

# Look first: this is a dry run and writes nothing.
node set-admin-claim.js --email admin@example.com

# Grant the claim.
node set-admin-claim.js --email admin@example.com --apply

# Take it away again.
node set-admin-claim.js --uid <uid> --revoke --apply
```

The key can also be passed per run with `--credential path/to/key.json`.

A dry run prints the target user, the claims before, and the claims after:

```
  project : bserv-512916
  user    : Q3f...9k <admin@example.com>
  before  : (none)
  after   : {"admin":true}

  dry run : nothing was written. Re-run with --apply to make this change.
```

## Testing it against the emulator

With no arguments about credentials, the script talks to the local Auth
emulator when `FIREBASE_AUTH_EMULATOR_HOST` is set. `firebase emulators:exec`
exports that variable, so this works from a clean checkout:

```sh
firebase emulators:exec --only auth --project demo-bserv \
  "cd admin-tools && node set-admin-claim.js --email admin@example.com --apply"
```

Create the user in the emulator first (the Emulator UI at
`http://127.0.0.1:4300` has an Authentication tab), or with the Admin SDK from a
throwaway script. This is the same backend `flutter run` uses by default, so
granting the claim here is what unlocks the admin screens locally.

## Notes

- `setCustomUserClaims` replaces the whole claims object. Granting merges into
  the existing claims so nothing else is lost; `--revoke` clears everything,
  which is why it is spelled that way.
- Custom claims are limited to 1000 bytes, far more than `{"admin":true}`.
- A change only reaches a running client when its ID token is refreshed. The app
  refreshes on sign-in (`getIdTokenResult(refreshToken: true)`), so signing in
  again is enough.
