# Kerjancok Mobile

Flutter employee self-service app for Kerjancok.

## Local setup

Requirements: Flutter stable with an Android SDK, or Xcode on macOS for iOS.

```bash
flutter pub get
flutter run
```

The checked-in platform projects target Android and iOS. Run `flutter doctor`
to verify the local toolchain before starting the app.

## Planned features

- Login with JWT access + refresh token
- Home / today status
- Clock in / clock out
- GPS + server-side geofence validation
- Selfie attendance evidence
- Attendance history
- Shift schedule
- Leave / sick / overtime request
- Approval inbox for managers
- Payslip
- KPI / performance
- Notifications
- Profile

## Architecture direction

Feature-first folders inspired by mature Flutter HR apps. API state and secure token storage stay isolated in core services.
