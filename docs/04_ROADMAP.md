# Kerjancok — Development Roadmap

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
`/login`). A shared Material 3 theme uses the Kerjancok brand green. A Dio
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
v4, shadcn/ui) with Kerjancok design tokens for light and dark themes. The
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

- users
- refresh tokens
- devices
- login
- refresh
- logout
- RBAC
- organization CRUD
- department CRUD
- position CRUD
- office CRUD

Admin:

- login
- organization settings
- departments
- positions
- offices

Mobile:

- login
- token refresh
- logout
- profile placeholder

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
