# Knect Mobile

Flutter employee self-service app for Knect. Employees can view their shift, record attendance, submit requests, track approvals, read announcements, and access profile, payslip, and performance information.

## Available flows

- Login, session restore/refresh, sign-out, and sign-out on all devices.
- Home with shift status, attendance actions, quick actions, announcements, and manager direct reports.
- Employee directory, team activity, and profile pictures where available.
- Location/geofence decision, required selfie/face verification, attendance result/history, and corrections.
- Leave, overtime, reimbursement, request history, and role-restricted approvals.
- Inbox notifications/approval entry, optional FCM delivery, payslips, goals/reviews, and announcement detail.
- Profile information and profile-photo upload. A separate employee face enrollment is not needed.

Recruitment administration belongs to Admin/API; this mobile app does not provide a recruitment console. Forgot/reset password is not implemented; the login screen directs users to HR.

## Stack and structure

Flutter/Dart, Dio, BLoC/Cubit, go_router, flutter_secure_storage, geolocator, camera/image_picker, flutter_map, Firebase Messaging, and flutter_svg.

| Path                                 | Purpose                                           |
| ------------------------------------ | ------------------------------------------------- |
| `lib/features/`                      | Feature screens, repositories, models, and state  |
| `lib/core/config/`                   | Compile-time environment validation               |
| `lib/core/network/`                  | Shared API client, token refresh, and errors      |
| `lib/core/storage/`                  | Secure tokens and installation device identity    |
| `lib/core/routing/`                  | Routes and authentication redirects               |
| `lib/core/theme/`, `lib/core/brand/` | Theme, tokens, and Knect palette                  |
| `lib/shared/widgets/`                | Reusable UI, profile avatars, and icon components |
| `assets/icons/`, `assets/brand/`     | Original SVG icons and brand artwork              |
| `android/`, `ios/`                   | Platform projects                                 |
| `test/`                              | Widget and unit checks                            |

## Local setup and backend URL

Use a Flutter SDK compatible with the lockfile, Android SDK/JDK for Android, or Xcode on macOS for iOS. Start Knect API first.

```bash
flutter doctor
flutter pub get
flutter run --dart-define-from-file=env/development.json
```

The backend configuration file is `env/development.json`. Values are compiled into the app, so restart/rebuild after editing; changing API `.env` does not change the mobile URL.

| Define         | Values                                                               |
| -------------- | -------------------------------------------------------------------- |
| `APP_ENV`      | `development` (default), `staging`, `production`                     |
| `API_BASE_URL` | Absolute URL ending in `/api/v1`; HTTPS required outside development |

Without an override, development uses `http://10.0.2.2:3000/api/v1`, which reaches the host from the standard Android emulator. A physical Pixel needs the computer's reachable LAN address or an HTTPS tunnel URL; phone `localhost` refers to the phone.

```bash
flutter run --dart-define=API_BASE_URL=https://your-tunnel.example/api/v1
```

For a tunnel, expose the backend's port 3000 and use its HTTPS URL plus `/api/v1`. If it changes, update the define and restart. For LAN access, confirm both devices share a network and the API port is reachable. A healthy emulator connection alone does not prove phone connectivity.

For staging/release, copy `env/staging.example.json` to ignored `env/staging.json`, set the URL, then run:

```bash
flutter build apk --release --dart-define-from-file=env/staging.json
```

Never put Cloudinary secrets, JWT signing secrets, or database credentials in Flutter defines. Images upload through authenticated API endpoints; storage-provider integration is owned by the backend. JPG/PNG/WebP image uploads are supported; general PDF/Office document uploads are not part of the current image contract.

## Attendance behavior

The flow starts with location and geofence checking. When face verification is required, Continue opens the camera and the API compares the selfie against the employee's profile-photo reference. A missing valid reference blocks attendance. When disabled, attendance can submit without a profile photo or selfie.

Outside-location behavior follows the company policy: `BLOCK`, `ALLOW_WITH_APPROVAL` (required note and pending approval), or `ALLOW` (recorded anomaly). The server validates location, face, clock windows, and duplicate attempts.

Clock In is disabled after a recorded entry; Clock Out remains available under the existing clock rules. After a recorded exit, both are disabled for that record. Pending approval is not shown as completed attendance and does not contribute to payroll.

## Visual system and navigation

The main tabs are Home, Employees, Request, Inbox, and Account. Requests uses a bottom-right floating plus button that opens the request-category sheet.

The original Knect violet palette follows system light/dark mode through `AppTheme`. Home quick actions and Account rows use original local SVG icons with contrasting theme colors and neutral containers. Employee avatars show profile pictures, falling back to initials for missing/failed images. See [visual system](docs/MOBILE_VISUAL_SYSTEM.md) and [flow guide](docs/FLOW.md).

## Verification and build notes

```bash
flutter analyze
flutter test test/mobile_visual_system_test.dart test/employee_photo_test.dart
flutter build apk --debug --dart-define-from-file=env/development.json
```

The targeted tests cover priority-screen navigation, request creation, narrow widths/enlarged text, attendance permission/camera error states, profile rendering, and clock-button availability. They do not replace physical-device GPS/camera acceptance. `flutter test` runs the full suite when explicitly needed.

Android currently retains TensorFlow Lite namespace/JVM/toolchain compatibility settings in `android/gradle.properties` and `android/build.gradle.kts`. Camera/Firebase Kotlin plugin warnings are separate from a fatal manifest-merger error. Review these settings when upgrading Flutter/Gradle/plugins.

Firebase delivery needs the platform Firebase configuration and server credentials; iOS also needs APNs configuration. Inbox persistence remains the source of truth when push is unavailable.

Start with the [documentation index](docs/README.md), [current status](docs/STATUS.md), and [decisions](docs/05_DECISIONS.md).
