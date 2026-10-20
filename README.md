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
`issueDescription`, `userId`, optional `userEmail`, `createdAt`, `status`, and
optional `photoPath`. Service area is intentionally not saved. New records have
status `scheduled`; the allowed lifecycle values are `scheduled`, `cancelled`,
and `completed`. Uploaded images are stored privately in Firebase Storage and
the Firestore document records their Storage path, not a public download URL.

Firestore and Storage access is enforced by `firestore.rules` and
`storage.rules`: customers can create and read their own appointment, while an
admin with the `admin: true` custom claim can read appointments and update only
their status. The customer can access their own uploaded photo; admins can read
all appointment photos. Rules must be deployed with Firebase before using a
non-emulator project.

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
