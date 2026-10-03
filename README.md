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

## Authentication (Phase 1A)

| Concern            | Location                                              |
| ------------------ | ----------------------------------------------------- |
| API calls          | `lib/features/auth/data/auth_repository.dart`         |
| Contract models    | `lib/features/auth/domain/auth_models.dart`           |
| Session state      | `lib/features/auth/application/auth_cubit.dart`       |
| Sign-in form state | `lib/features/auth/application/login_cubit.dart`      |
| Device identity    | `lib/core/storage/device_identity.dart`               |
| Token refresh      | `_SessionRefreshInterceptor` in `api_client.dart`     |

- **Sign-in:** `POST /auth/login` with email, password, and the device. The
  device is a random installation UUID kept in secure storage, sent with
  platform `ANDROID`/`IOS`.
- **Errors:** the API error code is mapped to a message, for example wrong
  credentials, deactivated account, rate limit, or offline.
- **Refresh:** a 401 on any request triggers one `POST /auth/refresh`, then
  the request is retried.
  - 401 responses are queued, so concurrent failures share one refresh. This
    matters because refresh tokens are single-use and reuse ends the session.
  - The refresh and the retry use an interceptor-free client, so a failing
    retry cannot deadlock the queue.
- **Session expiry:** if the API rejects the refresh token, stored tokens are
  cleared and `ApiClient.sessionExpired` fires. The app then returns to sign-in
  with "Your session has ended".
- **Restore:** the app opens straight to Home when tokens are stored, even
  offline, and loads `/auth/me` in the background.
- **Sign-out:** sign out of this device (`/auth/logout`, best effort), or sign
  out of all devices (`/auth/logout-all`). Signing out of all devices fails
  visibly when offline.
- **Navigation:** the tabs are Home and Profile. Attendance, Requests, and
  Payroll join as their phases ship.
- **Not yet:** forgot or reset password (needs email delivery on the API).
  The login screen points users to HR.

Revoking sessions on the server (logout-all) takes effect at the next token
refresh, up to the access-token lifetime (15 minutes by default).
Deactivating an account takes effect on the next request.

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
