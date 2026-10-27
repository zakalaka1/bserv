# bserv

Book Service Flutter app.

## Authentication Development

Authentication, Firestore, and Storage use the separate `demo-bserv` Firebase
Emulator project. Start the emulators from this directory:

```sh
firebase emulators:start --only auth,firestore,storage --project demo-bserv
```

Auth listens on `127.0.0.1:9299`, Firestore on `127.0.0.1:8180`, and Storage
on `127.0.0.1:9298`. When started together, the Emulator UI is at
`http://127.0.0.1:4300`. This project remains independent from the
`demo-gpcore` emulators used by the neighboring Get Parts project.

Run the Flutter app with `flutter run`. Web and desktop clients connect through
`127.0.0.1`; the Android emulator connects through `10.0.2.2`. Provider
sign-in in this setup is for local development only. Before using real Firebase
projects, configure their platform options and enable Google/Facebook providers
in Firebase Authentication without committing provider secrets.

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
create accounts. To test locally:

1. In the Emulator UI, open Authentication and add an Email/Password user.
2. Grant that user's UID the custom claim `{ "admin": true }` using the Firebase
	Admin SDK while connected to the emulator. For Node.js, set
	`FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9299`, initialize the Admin SDK with
	project ID `demo-bserv`, look up the user by email, and call
	`setCustomUserClaims(user.uid, { admin: true })`.
3. Sign in through Admin Login. The app refreshes the ID token and only exposes
	admin actions when the token contains the trusted `admin: true` claim.

For production, enable **Email/Password** in Firebase Authentication and create
the administrator account through a trusted administrative process. Grant the
same custom claim only from a privileged server or one-off Admin SDK script.
Never ship the Admin SDK or service-account credentials in the Flutter app.
Firebase Security Rules must independently enforce admin permissions; hiding
admin controls in the UI is not authorization.
