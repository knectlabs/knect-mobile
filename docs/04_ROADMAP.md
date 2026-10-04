# Knect — Development Roadmap

This roadmap is ordered by dependency, not by visual importance.

# Phase 0 — Foundation

## Goals

Create stable project foundations before business features.

### Backend

- [x] NestJS bootstrap
- [x] environment validation
- [x] Prisma (client generation and NestJS provider integration)
- [x] PostgreSQL (isolated local setup and live connection verification)
- [x] Docker Compose for local database
- [x] error response format
- [x] request validation
- [x] Swagger/OpenAPI
- [x] logger
- [x] config service
- [x] base auth guards
- [x] testing setup

Backend progress (2026-10-03): environment validation rejects invalid startup
configuration without exposing supplied credentials. Prisma client generation
and lifecycle-managed `PrismaService` are implemented. Schema
parsing/formatting is corrected without changing model semantics. The scaffold
review is in `09_PRISMA_FOUNDATION.md`; domain alignment must precede
migrations. PostgreSQL 17 is provisioned in an isolated local cluster with a
restricted application role. Live connection, read-only transactions, UTF8/UTC,
and NestJS initialization/cleanup are verified; see
`10_POSTGRESQL_FOUNDATION.md`. Docker Compose provides an isolated PostgreSQL 17
database with persistent storage, generated local secrets, a restricted
application role, and live verification after container recreation; see
`11_DOCKER_COMPOSE.md`. A global exception filter enforces the documented error
envelope and hides internal server details. Global DTO validation rejects
unknown properties, requires explicit type conversion, supports nested DTOs,
and returns safe field/rule details; see `06_API_CONVENTIONS.md`. Swagger UI and
JSON expose the implemented contract, JWT bearer definition, and shared error
schemas; see `12_OPENAPI.md`. The application emits bounded, redacting JSON logs;
see `13_LOGGING.md`. Validated environment values are exposed through one typed,
immutable configuration service; see `14_CONFIGURATION.md`. The API is protected
by default with access-token authentication and basic role guards; see
`15_AUTH_GUARDS.md`. Jest now has deterministic test configuration, separated
live-database tests, CI coverage commands, and enforced coverage floors; see
`16_TESTING.md`. The public readiness endpoint now verifies API and PostgreSQL
availability; see `17_HEALTH_ENDPOINT.md`. The backend Phase 0 foundation list
and its API/database exit criteria are complete.

### Mobile

- [x] Flutter project
- [x] routing
- [x] theme
- [x] Dio client
- [x] secure storage
- [x] environment configuration
- [x] auth state

Mobile progress (2026-10-03): the Flutter application has reproducible Android
and iOS platform projects, lint configuration, dependency locking, and widget
tests. `go_router` guards routes by session state (signed-out users reach only
`/login`). A shared Material 3 theme uses the Knect brand green. A Dio
`ApiClient` attaches the stored access token and maps failures to `ApiFailure`
using the documented error envelope. Tokens live only in
`flutter_secure_storage`. `AppConfig` reads `APP_ENV` / `API_BASE_URL` from
`--dart-define` and requires HTTPS outside development. `AuthCubit` restores
the session before the first frame. Android release builds declare `INTERNET`;
only debug builds allow cleartext HTTP to a local API. Login, refresh, and
logout API calls are Phase 1A; see the mobile `README.md`.

### Admin

- [x] Next.js project
- [x] layout shell
- [x] auth handling
- [x] API client
- [x] route protection
- [x] UI primitives

Admin progress (2026-10-03): Next.js 16 (App Router, TypeScript, Tailwind CSS
v4, shadcn/ui) with Knect design tokens for light and dark themes. The
layout shell follows the PRD admin navigation, and sections become links when
their phase ships. Sessions are held server-side in httpOnly cookies, and the
browser never sees tokens. `src/proxy.ts` performs an optimistic redirect, and
protected layouts re-check the session on the server. A typed server-side API
client maps the error envelope to `ApiError`. Configuration is validated at
startup. Loading, error, empty, and not-found primitives exist. The dashboard
shows live API/database status from `GET /health`. See the admin
`docs/ADMIN_FOUNDATION.md`.

Exit criteria:
- [x] all three repos run locally
- [x] API health endpoint works
- [x] PostgreSQL connection works

Phase 0 complete (2026-10-03). The API ran against Docker Compose PostgreSQL.
The admin production build ran against it and rendered live health status. The
mobile debug APK ran on an Android emulator and routed the signed-out session
to login. The next task is Phase 1A backend authentication (users, refresh
tokens, devices, login).

---

# Phase 1A — Authentication & Organization

Backend:

- [x] users
- [x] refresh tokens
- [x] devices
- [x] login
- [x] refresh
- [x] logout
- [x] RBAC
- [x] organization CRUD
- [x] department CRUD
- [x] position CRUD
- [x] office CRUD

Backend progress (2026-10-03): the first migration creates `organizations`,
`users`, `devices`, `refresh_tokens`, `departments`, `positions`, and
`offices`, with UUID keys and snake_case names.

- **Decisions:** globally unique lowercased email (ADR-013), UUID keys
  (ADR-014), CLI bootstrap of the first organization and `COMPANY_ADMIN`
  (ADR-015).
- **Auth:** login binds the session to a device. Refresh tokens are
  HMAC-hashed, single-use, and rotated in a transaction; reuse revokes the
  session. Logout ends one session or all, and `/auth/me` returns the user.
  Every request re-checks the user and organization in the database.
- **Organization structure:** organization profile plus department, position,
  and office CRUD. Each list is tenant-scoped, paginated, and searchable.
  Writes are restricted by role, department cycles are prevented, and
  referenced records cannot be deleted.
- **Tests:** live-PostgreSQL suites cover rotation, reuse, concurrency, RBAC,
  and cross-tenant isolation.

Deferred, with reasons, in `18_AUTH_AND_ORGANIZATION.md`: forgot/reset
password, user management endpoints (Phase 1B), and audit logging (Phase 1G).

Admin:

- [x] login
- [x] organization settings
- [x] departments
- [x] positions
- [x] offices

Admin progress (2026-10-03):

- **Sign-in:** a server-action login keeps tokens only in httpOnly cookies.
  Employee accounts are refused.
- **Session renewal:** the proxy renews expired access tokens and exchanges
  each refresh token once per process, so parallel requests do not trigger
  reuse detection. Revoked sessions return to login with a notice.
- **Organization:** a profile form plus department, position, and office
  pages with URL-driven search, status filter, and pagination. Create and
  edit run in dialogs that map API errors to fields. Deletes are confirmed.
  HR and managers get read-only views.
- **Verification:** a browser end-to-end run against the live API passed. See
  the admin `docs/ADMIN_FOUNDATION.md`.

Mobile:

- [x] login
- [x] token refresh
- [x] logout
- [x] profile placeholder

Mobile progress (2026-10-03):

- **Sign-in:** a real `POST /auth/login` bound to a secure-storage
  installation id, with messages per error code.
- **Token refresh:** a queued Dio interceptor refreshes once per expiry and
  retries through an interceptor-free client. If the API rejects the refresh,
  the app returns to sign-in with a session-ended notice.
- **Session restore and profile:** the stored session is restored offline;
  the profile from `/auth/me` shows email, role, and organization. The app has
  Home and Profile tabs, sign-out, and sign-out of all devices.
- **Verification:** checked on an Android emulator against the live API:
  wrong password, sign-in, profile, restore after force-stop, and forced
  session end.

Phase 1A complete (2026-10-03) across all three repositories. Next: Phase 1B
Employees, starting with the backend employee schema
(`employees` + `users.employee_id`) and CRUD.

---

# Phase 1B — Employees

Backend:

- employee CRUD
- employee status
- manager relation
- office assignment
- department assignment
- position assignment
- pagination
- search/filter

Admin:

- employees list
- employee detail
- create/edit employee

Mobile:

- employee profile
- basic employment information

---

# Phase 1C — Shift & Scheduling

Backend:

- shift CRUD
- employee shift assignment
- today schedule resolution

Admin:

- shift management
- employee assignment

Mobile:

- today's shift

---

# Phase 1D — Attendance

Backend:

- clock-in
- clock-out
- geofence calculation
- attendance status
- attendance history
- attendance evidence
- anomaly engine v1

Mobile:

- permission flow
- GPS
- selfie
- clock-in
- clock-out
- attendance result
- attendance history

Admin:

- daily attendance
- attendance detail
- anomaly visibility

---

# Phase 1E — Leave & Approval

Backend:

- leave type
- leave balance
- leave request
- approval request
- approval steps
- approval action
- balance transaction

Mobile:

- leave balance
- submit leave
- leave history
- manager approval inbox

Admin:

- leave configuration
- leave monitoring
- approval monitoring

---

# Phase 1F — Overtime & Attendance Correction

Backend:

- overtime request
- attendance correction
- reusable approvals
- audited attendance correction application

Mobile:

- overtime request
- correction request
- manager approval

Admin:

- requests dashboard
- correction review

---

# Phase 1G — Notifications, Audit & Reports

Backend:

- notification persistence
- audit logging
- attendance reports
- leave reports
- overtime reports

Admin:

- audit log view
- reports
- dashboard metrics

Mobile:

- notification center

MVP complete after Phase 1G.

## Mobile status (2026-10-03)

Phases 1B–1G are implemented in the mobile app (backend 1A–1G is complete;
admin screens for 1B–1G are still to do):

Navigation (Talenta-inspired, Knect visuals; chosen by the product owner on
2026-10-04, superseding the Attendance tab in AGENTS.md §20): Home ·
Employees · Request · Inbox · Account. Home has a greeting, today's shift card
with Clock In | Clock Out, an app grid (Time Off, Live Attendance, Overtime,
Correction, Attendance Log, My Requests, Approvals), and My direct reports
with today's team activity. Employees is the people directory
(`GET /directory`): on leave today, A–Z list, call/email/WhatsApp. Inbox holds
notifications and, for managers/HR, Need My Approval. Account has My Info and
sign-out. Announcements, banners, payslip, reimbursement, shift-schedule
history, and PIN/biometric are not shown until their backends exist.

- **1B** Profile: employment (ID, position, department, office, manager, join
  date), contact, and account.
- **1C** Home: today's shift with clock-in/out times; the clock button follows
  the API windows (not open yet / closed → correction).
- **1D** Live Attendance tab (live clock, schedule, Clock in / Clock out,
  today's log, full log) and a two-step clock flow: (1) map with the user and
  the office geofence (OpenStreetMap via `flutter_map`), with an out-of-range
  sheet — clock-in must recheck; clock-out may continue with a mandatory note
  and is flagged; (2) in-app front camera with a face guide, notes, submit.
  Selfies upload to `/files/images`.
- **1E** Leave balances, leave request, request history with cancel, and the
  approval inbox (approve/reject with comment) for managers and HR.
- **1F** Overtime and attendance-correction requests (correction times are
  sent as UTC instants of organization-local wall-clock times).
- **1G** Notification center with unread badge, mark read, mark all read.

Verified: `flutter analyze`, the existing tests, every 1D–1G call replayed
against the API with the app's payloads, and on the Android emulator against
the live API: Home, Live Attendance, and an out-of-range clock-out through
map, note, camera selfie, result, and log. Widget tests for these screens are
deferred until the end of Phase 1, as agreed. OpenStreetMap's public tiles
are for development; production needs a tile provider that permits the load.

---

# Phase 2 — Payroll

Order:

1. salary component configuration
2. employee compensation configuration
3. payroll period
4. attendance aggregation
5. overtime aggregation
6. deductions
7. payroll preview
8. payroll finalization
9. payslip
10. employee mobile payslip
11. payroll reports

Only after payroll core is stable:

- BPJS
- PPh21
- bank integration
- payroll disbursement

---

# Phase 3 — Performance

Order:

1. performance cycles
2. goals
3. KPI/OKR
4. review templates
5. self review
6. manager review
7. peer review
8. 360 review
9. analytics
10. development plans

---

# Phase 4 — Recruitment & Onboarding

Order:

1. job openings
2. candidate
3. application
4. recruitment stage
5. interview
6. offer
7. hired candidate conversion
8. onboarding checklist
9. document collection

---

# Cross-Cutting Work

Continuously improve:

- tests
- API docs
- database indexes
- authorization
- observability
- backups
- CI/CD
- performance
- security review
- migrations
- release process
