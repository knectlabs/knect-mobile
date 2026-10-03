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

## Environments

The app reads its environment at compile time through `--dart-define`.
Screens and repositories never contain API URLs; they use `AppConfig` through
the shared `ApiClient`.

| Variable       | Values                                  | Notes                                       |
| -------------- | --------------------------------------- | ------------------------------------------- |
| `APP_ENV`      | `development`, `staging`, `production`  | Defaults to `development`.                  |
| `API_BASE_URL` | absolute URL ending in `/api/v1`        | Required and HTTPS-only outside development |

Development defaults to `http://10.0.2.2:3000/api/v1`, the Android emulator
alias for the host machine running `kerjancok-api`. Debug Android builds allow
cleartext HTTP for this purpose; release builds do not. On the iOS simulator or
a physical device, pass a reachable URL:

```bash
flutter run --dart-define-from-file=env/development.json
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1

# Staging / production: copy the example and set the real URL (git-ignored)
cp env/staging.example.json env/staging.json
flutter build apk --release --dart-define-from-file=env/staging.json
```

An invalid or missing configuration fails at startup instead of falling back to
an unexpected API.

## Foundation (Phase 0)

| Concern            | Location                                   |
| ------------------ | ------------------------------------------ |
| Environment config | `lib/core/config/app_config.dart`          |
| HTTP client (Dio)  | `lib/core/network/api_client.dart`         |
| API error model    | `lib/core/network/api_failure.dart`        |
| Secure token store | `lib/core/storage/token_storage.dart`      |
| Session state      | `lib/features/auth/application/auth_cubit.dart` |
| Routing + guard    | `lib/core/routing/app_router.dart`         |
| Theme              | `lib/core/theme/app_theme.dart`            |

- `ApiClient` attaches the stored access token as a bearer header and converts
  failures into `ApiFailure`, which reads the API's
  `{"error": {"code", "message", "details"}}` envelope.
- Tokens are stored only in `flutter_secure_storage` (Keychain / Android
  Keystore-backed storage). A partial token pair is discarded.
- `AuthCubit` restores the session before the first frame. The `go_router`
  redirect sends unauthenticated users to `/login` and authenticated users away
  from it.
- Login, token refresh, and logout API calls are Phase 1A. Until then the login
  screen is an informational placeholder and no fake credentials exist.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

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
