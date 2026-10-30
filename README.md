# bserv

Book Service Flutter app.

## Firebase Environments

The app has two backends, selected at build time by the `USE_FIREBASE_EMULATOR`
flag (`lib/app/app_environment.dart`):

| Mode                    | Build flag                                      | Backend                       |
| ----------------------- | ----------------------------------------------- | ----------------------------- |
| Development (default)   | *(none)*                                        | Local Emulator Suite (`demo-bserv`) |
| Production              | `--dart-define=USE_FIREBASE_EMULATOR=false`     | Firebase project `bserv-512916` |

The flag is a build-time constant, not a runtime switch. A release built without
it points at a local Emulator Suite that is not running on a user's device, so
every read fails. Pass it whenever the artifact leaves this machine:

```sh
flutter build appbundle --release --dart-define=USE_FIREBASE_EMULATOR=false
flutter build apk --release --dart-define=USE_FIREBASE_EMULATOR=false
```

The production configuration is committed as `lib/firebase_options.dart`,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.
Regenerate it after adding a platform or switching projects with:

```sh
flutterfire configure --project bserv-512916 --platforms android,ios,web
```

The Android application id and the iOS bundle id are both `com.gtagas.bserv`.
They must match the apps registered in the Firebase project, so change the
project and these ids together.

`google-services.json` also carries the OAuth clients that enabling a sign-in
provider creates, so re-download it after enabling one and commit the
replacement; the file predating the Google provider had an empty `oauth_client`
array.

### The one resource that must not be shrunk

Release builds shrink resources, and Firebase looks `default_web_client_id` up
by name at runtime instead of through a compiled `R` reference, so the shrinker
deletes it as unreachable. `android/app/src/main/res/raw/keep.xml` pins it.
`build/app/outputs/mapping/release/resources.txt` records what the shrinker
removed; a release build missing that string fails Google sign-in with a
developer-error API exception while debug builds and the Firebase console both
look correct.

## Authentication Development

Development uses the separate `demo-bserv` Emulator project. Start the
emulators from this directory:

```sh
firebase emulators:start --only auth,firestore,storage --project demo-bserv
```

Auth listens on `127.0.0.1:9299`, Firestore on `127.0.0.1:8180`, and Storage
on `127.0.0.1:9298`. When started together, the Emulator UI is at
`http://127.0.0.1:4300`. The ports can be overridden with
`FIREBASE_AUTH_EMULATOR_PORT`, `FIREBASE_FIRESTORE_EMULATOR_PORT` and
`FIREBASE_STORAGE_EMULATOR_PORT`; `FIREBASE_EMULATOR_HOST` overrides the host
(for example when a physical device reaches the emulators over the local
network). This project remains independent from the `demo-gpcore` emulators
used by the neighboring Get Parts project.

Run the Flutter app with `flutter run`. Web and desktop clients connect through
`127.0.0.1`; the Android emulator connects through `10.0.2.2`. Provider
sign-in in this setup is for local development only. To run against the real
project, build with `--dart-define=USE_FIREBASE_EMULATOR=false` and enable the
providers in Firebase Authentication; provider secrets are never committed.

The customer sign-in sheet offers Google and Facebook; the admin screen uses
Email/Password. The deployed project therefore needs Google and Facebook enabled
under Authentication, sign-in method, before a customer can sign in at all: every
rule requires `request.auth != null`, so an unauthenticated client cannot even
read the service list. Email/Password alone is not enough for customers.

Deploy the security rules and the composite indexes before using the real
project. The index declared in `firestore.indexes.json` is what makes the
"latest appointment" query (equal on `userId`, order by `createdAt`) legal;
without it that query fails in production even though the emulator accepts it:

```sh
firebase deploy --only firestore,storage --project bserv-512916
```

`firebase firestore:indexes --project bserv-512916` prints what is actually
deployed.

## Release Signing

Release builds are signed with the upload keystore at
`android/app/upload-keystore.jks` (alias `upload`, RSA-2048, valid for 10,000
days). The credentials are read from `android/key.properties`:

```properties
storePassword=<random>
keyPassword=<random>
keyAlias=upload
storeFile=upload-keystore.jks
```

`android/key.properties`, `*.jks`, and `*.keystore` are gitignored, so the key
never enters the repository; each machine that builds a release needs its own
copy. When `key.properties` is missing (fresh clone, CI, a contributor without
the key) `android/app/build.gradle.kts` falls back to the debug key so that a
release build still completes. That fallback is why an artifact can build fine
and still be unusable: check which key signed it before shipping it.

The upload certificate fingerprints are:

| Algorithm | Fingerprint |
| --------- | ----------- |
| SHA-1     | `8E:D4:5D:45:08:7E:A6:E5:87:74:D7:30:11:9A:03:EE:27:50:A7:25` |
| SHA-256   | `85:0E:C5:B6:0F:78:DC:40:7F:37:4A:3D:23:2C:50:42:A1:1C:BC:7C:12:62:B3:CF:72:2E:89:AF:23:46:83:1C` |

Both are registered on the `bserv (android)` app in `bserv-512916`, which is what
creates the Android OAuth client Google Sign-In needs. Re-register them after a
key change (`firebase apps:android:sha:create <app id> <sha> --project
bserv-512916`, or Project settings, Your apps). Those APIs compare the
fingerprint of the key that signed the *installed* app, and `flutter run` on a
device signs with the machine-local debug key, so provider sign-in from a debug
build needs the debug key's fingerprint registered too.

> **Back up `android/app/upload-keystore.jks` and `android/key.properties`** to a
> password manager or encrypted backup. If the upload key is lost you cannot
> publish updates to the existing Play Console listing without a key reset
> request. Never regenerate the keystore once the first release is uploaded.

## Continuous Integration

`.github/workflows/ci.yml` runs two jobs on every push to `main` and every pull
request:

- **verify**: `dart format --set-exit-if-changed`, `flutter analyze`, and
  `flutter test`.
- **rules**: the Firestore and Cloud Storage security-rules tests against the
  Emulator Suite.

## Security Rules Tests

`firestore.rules` and `storage.rules` have an emulator-backed suite in
`rules-tests/` (Mocha plus `@firebase/rules-unit-testing`). Run it with:

```bash
cd rules-tests
npm install          # once
npm run test:emulator
```

The suite pins the `demo-bserv` project ID, so it can never reach
`bserv-512916`. See [rules-tests/README.md](rules-tests/README.md) for the
layout and the conventions the specs follow.

### Appointment Records

Submitting Book creates an `appointments` document only after the optional
photo upload succeeds. The document uses camelCase fields: `appointmentDate`,
`timeSlot`, `customerName`, `phone`, `streetAddress`, `city`, `postalCode`,
`issueDescription`, `serviceType`, `userId`, optional `userEmail`, `createdAt`,
`status`, and optional `photoPath`. `serviceType` stores what the customer
booked (`maintain heat` for Heating system maintenance, from `ServiceCatalog`),
while the service area is intentionally not saved. `phone` is saved as
`999-999-9999` and `postalCode` as `A9A 9A9`, whichever of the accepted input
forms the customer typed. New records have status `scheduled`; the allowed
lifecycle values are `scheduled`, `cancelled`, and `completed`. Uploaded images
are stored privately in Firebase Storage and the Firestore document records
their Storage path, not a public download URL.

Firestore and Storage access is enforced by `firestore.rules` and
`storage.rules`: customers can create and read their own appointment, while an
admin with the `admin: true` custom claim can read appointments and update only
their status. The customer can access their own uploaded photo; admins can read
all appointment photos. Rules must be deployed with Firebase before using a
non-emulator project.

### Service Area Coverage

Everything about the service areas lives in `lib/app/app_config.dart`
(`ServiceAreaCoverage`) so areas can be added or removed - and coverage changed
- without touching the map or booking code, then picked up by a rebuild.

`serviceAreas` is the list of areas offered, keyed by the id used everywhere
else. Each entry carries the marker's `latitude`/`longitude` in decimal degrees
and the `name` shown on the map and in the booking flow. Adding or removing an
area means editing this map together with the matching outline in
`areaBoundaries`; the map, its markers, the booking screens, and the tests all
follow automatically. `test/app_config_test.dart` fails if an area is listed
without an outline (or the reverse), so the two stay in step.

`areaBoundaries` is keyed by the same id and each value is a polygon ring of
`[latitude, longitude]` pairs (latitude first, like `LatLng(latitude,
longitude)`); the ring closes automatically, so do not repeat the first corner.
Many map tools copy coordinates as `[longitude, latitude]`, so swap each pair
before pasting it into the config. An area can be selected by tapping its marker
or anywhere inside its drawn outline, and tapping the map away from every area
clears the selection again. Each marker is drawn at the middle of its outline,
so it stays on the shape when the geometry changes; a missing or too-short
boundary only drops the outline, and the marker falls back to the
`latitude`/`longitude` configured for the area.

`mapInitialZoom` sets how close the map opens; the default fills a desktop
window with the GTA rather than the whole region.

`allowedPostalPrefixes` holds the Forward Sortation Areas (the first three
characters of a postal code, upper case) that may book; the booking form
rejects any other postal code with "This postal code is outside our service
area." and saves nothing.

### Service Types

The "Type of Service" dropdown on the landing page is built from
`ServiceCatalog.serviceTypes` in `lib/app/app_config.dart`, so a type can be
added or removed without touching the map or booking code, then picked up by a
rebuild.

Each entry is keyed by a unique id and carries the `storageValue` written to the
appointment document plus the `label` shown to customers and admins. The first
entry is the default selection. A stored value that the current build does not
know is displayed exactly as it was saved, so removing a type never hides older
bookings. `test/app_config_test.dart` fails if an entry has a blank storage value
or label, or if two entries share a storage value.

### Notes and Pricing Content

The Notes & Pricing screen reads `publicContent/notesAndPricing`. Its camelCase
fields are `notes`, `pricing`, `updatedAt`, and `updatedBy`. Both text values
are limited to 2,000 characters; only a user with the `admin: true` custom
claim can update them. The content is readable publicly so customers can see
the provider's latest notes and prices without signing in. Firestore Rules
enforce the write restriction independently of the hidden admin form.

### Latest Appointment

The Latest tab shows the signed-in customer's most recently created appointment,
regardless of status, using `userId` and descending `createdAt`. The Firestore
composite index is defined in `firestore.indexes.json`. Signed-out customers are
prompted to log in; customers with no appointments can start a booking from the
empty state. Firestore Rules restrict appointment reads to the owner or admin.

While the appointment is still `scheduled`, the customer can edit three things
in place, one row at a time: the name, the issue description, and - only when
the booking has no photo yet - a photo attachment. A pencil button opens the
row as a text field with a close button (discard) and a check button (save); a
missing photo shows an add-photo button that opens the gallery and then offers
the same check/discard pair above a preview. The name and issue description are
optional, so an empty value is accepted. Each save reports success or failure in
a snackbar and keeps the editor open on failure so the change can be retried.
Cancelled and completed appointments are read-only.

`updateOwnAppointment` writes only the provided fields after uploading a photo
to `appointment-photos/{userId}/{appointmentId}/{fileName}`, and deletes that
object if the document write fails. Firestore Rules allow the owner to change
`customerName` or `issueDescription` only while the status is `scheduled`, and
allow `photoPath` to be added only when the booking has none; `storage.rules`
already restricts uploads to the customer's own folder.

### Handedness and Theme

The app bar carries a handedness toggle and a light/dark theme toggle. The
handedness toggle swaps between the `front_hand_rounded` glyph (right-handed)
and `back_hand_rounded` (left-handed), and rearranges the bar on every screen.

Right-handed mode keeps the back arrow and the three controls (overflow menu,
handedness, theme) trailing, with the arrow innermost so the cluster sits
together right next to the title: `Booking Details … ← ⋮ ✋ 🌙`. Left-handed mode
mirrors that cluster onto the leading edge: the controls reverse and the arrow
stays innermost, again beside the title: `🌙 ✋ ⋮ ← … Booking Details`.

Every screen centers its title in the open space beside the cluster. Because the
cluster sits on a single edge, the title centers between that edge and the
opposite edge of the bar rather than on the bar's geometric midpoint; wide
titles ellipsize instead of running under the cluster.

### Company Logo

The landing screen (the Book tab's service-area map) shows the company logo in
the app-bar title slot, centered like every other heading. The assets live in
`assets/images/`, declared as a folder in `pubspec.yaml`:

- `logo_light.png` - shown in the light theme
- `logo_dark.png` - shown in the dark theme

Both are transparent PNGs, 600x240 (a 2.5:1 wordmark). They render 40 logical
pixels tall, so Flutter scales the 240-pixel source down to fit the 56-pixel
toolbar. Replacing either file - keeping the name - updates the app after a
rebuild; use a two-to-three-times-height transparent PNG so the mark stays crisp
on high-density screens.

### Admin Account Provisioning

The Admin Login screen signs in an existing Email/Password account. It does not
create accounts, and nothing grants the claim automatically. Both rules files and
the app check for `admin: true`, so an account stays a normal customer account
until something sets it. The Firebase console has no screen for custom claims,
which is why `admin-tools/` exists.

```sh
cd admin-tools && npm install && cd ..

# Emulator: no credentials needed, `emulators:exec` exports the host.
firebase emulators:exec --only auth --project demo-bserv \
  "cd admin-tools && node set-admin-claim.js --email admin@example.com --apply"

# Deployed project: service account key kept outside the repository.
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/bserv/bserv-admin-service-account.json
node set-admin-claim.js --email admin@example.com          # dry run, writes nothing
node set-admin-claim.js --email admin@example.com --apply
node set-admin-claim.js --uid <uid> --revoke --apply
```

Locally, add the Email/Password user in the Emulator UI (Authentication tab),
grant the claim, then sign in through Admin Login. The app refreshes the ID token
and only exposes admin actions when the token contains the trusted `admin: true`
claim.

For production, enable **Email/Password** in Firebase Authentication and create
the administrator account, then run the script with a service account key. Never
ship the Admin SDK or service-account credentials in the Flutter app. Firebase
Security Rules must independently enforce admin permissions; hiding admin
controls in the UI is not authorization.

`admin-tools/README.md` documents every flag, including `--revoke` and the
pinned-project guard.

## Known Build Warnings

Android release builds print:

```text
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): firebase_auth, firebase_core, firebase_storage
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

and, when Gradle configures the projects directly:

```text
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
WARNING: The option setting 'android.newDsl=false' is deprecated.
```

Both are forward-looking notices, not build errors. They come from the two flags
`android/gradle.properties` inherits from the Flutter 3.47 template:

```properties
android.newDsl=false
android.builtInKotlin=false
```

`android.builtInKotlin=false` makes Flutter apply `org.jetbrains.kotlin.android`
to every Android subproject, which is why the FlutterFire plugins
(`firebase_auth`, `firebase_core`, `firebase_storage`) are reported as applying
KGP. AGP 9 deprecates both flags and plans to remove them in AGP 10.

**Do not remove them yet.** Verified against Flutter 3.47.5 + AGP 9.1.0, deleting
both flags fails the build, because `dev.flutter.flutter-gradle-plugin`
still casts the Android extension to the legacy `AbstractAppExtension`:

```text
Failed to apply plugin 'dev.flutter.flutter-gradle-plugin'.
  > class com.android.build.gradle.internal.dsl.ApplicationExtensionImpl
    cannot be cast to class com.android.build.gradle.AbstractAppExtension
```

The flags and the warnings go away together, when a Flutter release ships a
Gradle plugin that supports AGP's new DSL and Built-in Kotlin. See
<https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin>.

