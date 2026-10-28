# Stockin

Stockin is an Android-first Flutter POS and inventory MVP backed by Firebase
Authentication, Cloud Firestore, and Firebase Storage. Each registered
business is a separate tenant. The app uses Provider, `mobile_scanner`,
`image_picker`, `intl`, and `uuid`.

## Firebase project

The Android app is configured for Firebase project `stockin-1de1f` in
`lib/firebase_options.dart`. Firebase is initialized before the Flutter app
starts. The existing Firebase project uses the Firestore Standard edition.

Before signing in for the first time, enable **Email/Password** in Firebase
Console under Authentication > Sign-in method. Firestore, Authentication, and Firebase Storage must be enabled for the
project. Then run:

```powershell
flutter pub get
flutter run
```

## Membership and admin approval

Owners choose a tier and submit a transfer reference/note, an image of the
payment proof, or both. Images are stored in Firebase Storage and shown to
admins reviewing a request. A payment document and the pending tier/seat
limits are saved together. The available plans are
Rp50,000 for 1 month (2 cashier + 2 stock accounts), Rp250,000 for 6 months
(6 + 6 accounts), and Rp400,000 for 1 year (20 + 20 accounts). Admins can
review requests in the Stockin admin dashboard, activate the selected plan for
its calendar duration, reject requests, and mark memberships inactive or
expired.
Admins can permanently delete a business and its products, transactions, stock
logs, and membership payments. User profiles are retained and marked as banned,
and the corresponding Firebase Authentication accounts are not deleted. A
banned account cannot sign in again and receives an account-banned notice.

### Bootstrap the first admin

Admin signup is intentionally not available in the app. Since Cloud Functions
were not enabled, provision the first admin account manually in the trusted
Firebase Console:

1. In Authentication > Users, create an Email/Password account for
   `admin@gmail.com` and set its password privately.
2. Copy the new account's UID.
3. In Firestore, create `users/{UID}` with these fields:
   - `businessId`: `__admin__` (string)
   - `name`: `Stockin Admin` (string)
   - `role`: `admin` (string)
   - `isActive`: `true` (boolean)
   - `createdAt`: current timestamp
4. Sign in to Stockin using that email and password. The app opens the admin
   dashboard on Android or Web.

The Firestore rules only grant admin privileges to an active profile with role
`admin`; normal app accounts cannot create or change that role. Treat access to
the Firebase Console as privileged and never share the admin password.

The seat counters are updated atomically with employee profile creation and
activation changes. Employee Auth accounts are created on a secondary Firebase
Auth instance so adding an employee does not sign the owner out.

## Firestore data and rules

`firestore.rules` is configured for the app's tenant-scoped data. User profile
documents intentionally omit email addresses; employee email addresses are
handled by Firebase Authentication and are not exposed through Firestore.
Rules deny unknown collections, restrict admin operations to membership
approval/status changes and locked business deletion, and prevent ordinary
clients from granting themselves admin access. Banned profiles cannot access
tenant data.

Membership proof images are restricted by `storage.rules` to the owning
business and active admins. Enable the project's Storage bucket before using
image uploads, and deploy the Firestore and Storage rules with
`firebase deploy --only firestore:rules,storage`. Each transaction retains the
cashier UID for access control and stores the cashier's name for display.

Review and test the prototype rules against your operational needs before
deploying them to a live database. In particular, complete sale line-item
validation and barcode uniqueness are application-checked; high-assurance
validation of those invariants should move to a trusted backend before
production. No payment gateway is included.

## Android

The registered Android Firebase app uses application ID `com.example.stockin`.
If you change the Android application ID, run `flutterfire configure
--project=stockin-1de1f --platforms=android` again.
