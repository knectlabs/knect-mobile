# Knect — Master AI Project Context

> This file is the first document an AI coding agent must read before making implementation decisions.

## 1. Product Identity

**Product name:** Knect

**Product type:** Modern HRIS / workforce management platform for Indonesian companies.

Knect is inspired by mature HR products such as Mekari Talenta, but it is an independent implementation.

The platform focuses on:

- employee management
- organization structure
- mobile attendance
- GPS/geofencing
- selfie attendance evidence
- shift scheduling
- leave and permission management
- overtime
- approval workflows
- payroll
- payslips
- performance management
- recruitment
- analytics
- notifications
- auditability

The product must be designed as a real SaaS-style HRIS, not as a simple attendance CRUD demo.

---

# 2. Repository Strategy

Knect uses **three independent repositories**.

## Backend

Repository:

`knect-api`

Stack:

- NestJS
- TypeScript
- PostgreSQL
- Prisma
- REST API
- JWT access token
- refresh token rotation
- npm

Potential later infrastructure:

- Redis
- BullMQ
- S3-compatible object storage
- Firebase Cloud Messaging

## Mobile

Repository:

`knect-mobile`

Stack:

- Flutter
- Dart
- Dio
- flutter_secure_storage
- go_router
- BLoC/Cubit
- geolocator
- camera/image picker

Primary users:

- employee
- manager

## Admin Web

Repository:

`knect-admin`

Stack:

- Next.js
- TypeScript
- Tailwind CSS
- shadcn/ui
- npm

Primary users:

- HR
- admin
- company owner
- manager for selected workflows

---

# 3. Important Technical Decisions

These are currently non-negotiable unless explicitly changed in `05_DECISIONS.md`.

1. Do not use Supabase.
2. Use PostgreSQL as the primary relational database.
3. Use Prisma as ORM.
4. Use NestJS for backend.
5. Use Flutter for mobile.
6. Use Next.js for admin web.
7. Use JWT access token + refresh token authentication.
8. Repositories remain separate.
9. npm is used for Node.js package management.
10. Attendance geofence validation must be performed server-side.
11. Client GPS results are untrusted input.
12. Sensitive HR changes must be auditable.
13. Payroll implementation must not be coupled directly to attendance tables.
14. Approval workflows should be reusable across modules.
15. The system should support multi-company architecture from the data model level.
16. Phase 1 must not attempt to ship every advanced HR module.

---

# 4. Product Roles

## SUPER_ADMIN

Platform-level role.

Future use:
- manage tenants
- platform operations

Not required for early MVP UI.

## COMPANY_ADMIN

Full company configuration access.

Can manage:
- company
- employees
- departments
- positions
- offices
- shifts
- HR settings
- payroll settings

## HR

Operational HR role.

Can manage:
- employees
- attendance
- leave
- overtime
- payroll
- reports
- recruitment
- performance

Permissions may be narrower than COMPANY_ADMIN.

## MANAGER

Team management role.

Can:
- see direct/assigned reports
- approve leave
- approve overtime
- approve attendance corrections
- see team attendance
- participate in performance reviews

## EMPLOYEE

Mobile-first role.

Can:
- clock in/out
- see attendance
- request leave
- request overtime
- request attendance correction
- view payslip
- view personal information
- view goals/reviews
- receive announcements and notifications

---

# 5. Core Product Domains

The system is divided into these bounded domains:

1. Authentication & Sessions
2. Organization
3. Employee
4. Office & Geofence
5. Shift & Scheduling
6. Attendance
7. Leave
8. Overtime
9. Approval Engine
10. Payroll
11. Performance
12. Recruitment
13. Notifications
14. Audit
15. Files / Evidence
16. Reporting / Analytics

Avoid creating cross-domain shortcuts that tightly couple unrelated modules.

---

# 6. Phase Strategy

## Phase 1 — Core HRIS MVP

Build:

- authentication
- refresh-token rotation
- organization/company
- employee management
- departments
- positions
- offices
- geofence settings
- shifts
- employee schedules
- mobile clock in
- mobile clock out
- selfie attendance evidence
- attendance history
- leave types
- leave balance
- leave requests
- reusable approvals
- overtime requests
- basic notifications
- audit logs
- basic reports

This phase must be usable end-to-end.

## Phase 2 — Payroll

Build:

- payroll periods
- salary components
- employee salary configuration
- attendance aggregation
- overtime aggregation
- deductions
- payroll run
- payroll result
- payslip
- payroll approval
- export/reporting

Indonesia-specific tax/BPJS automation can be introduced incrementally.

## Phase 3 — Performance

Build:

- goals / KPI / OKR
- review cycles
- self review
- manager review
- peer review
- 360 review
- review templates
- development plan

## Phase 4 — Recruitment & Advanced HR

Build:

- job openings
- candidates
- applications
- recruitment stages
- interview records
- offers
- onboarding
- advanced analytics
- integration framework

---

# 7. Attendance Philosophy

Attendance is one of the most important domains.

Clock-in is not simply:

`INSERT attendance`

A clock-in flow is:

1. authenticate user
2. resolve employee
3. verify employee is active
4. resolve current date in company timezone
5. resolve assigned shift
6. resolve work location / office
7. verify attendance window
8. verify GPS accuracy
9. calculate server-side distance
10. compare with office geofence radius
11. verify selfie evidence
12. detect duplicate clock-in
13. evaluate anomaly rules
14. calculate lateness
15. persist attendance
16. persist evidence
17. persist anomaly results
18. write audit trail
19. return normalized status

Potential anomaly signals:

- mock/fake location hint
- poor GPS accuracy
- impossible travel
- clock-in outside geofence
- unexpected device
- unusual IP change
- duplicate attempt

Do not market basic heuristics as machine learning.

---

# 8. Security Principles

Mandatory:

- password hashing with Argon2 or bcrypt
- JWT access tokens are short-lived
- refresh tokens are stored hashed
- refresh token rotation
- revoke individual session/device
- RBAC and resource-scope authorization
- rate limiting
- request validation
- audit sensitive changes
- secure object storage URLs
- no raw password logging
- no refresh token logging
- no salary values in general logs
- ownership checks on employee resources

---

# 9. Database Principles

Use:

- UUID/CUID-style primary identifiers consistently
- `organization_id` on tenant-owned records
- explicit created/updated timestamps
- soft deletion only where business history requires it
- unique constraints for business invariants
- indexes for high-frequency queries

Important:

Attendance and payroll history are financial/operational records and should not be casually hard-deleted.

---

# 10. AI Coding Rules

Before implementing a feature:

1. identify its domain
2. read relevant entity definitions in `03_ERD.md`
3. check `05_DECISIONS.md`
4. check whether feature belongs to current phase
5. avoid creating new tables if an existing entity already models the concept
6. avoid changing field meaning silently
7. add migrations for schema changes
8. add tests for business rules
9. update Markdown source of truth when architecture changes

Do not:
- introduce Supabase
- move back to monorepo
- replace Flutter with React Native
- replace NestJS without explicit decision
- duplicate approval logic per module
- trust client-calculated geofence results
- calculate payroll directly inside attendance controllers

---

# 11. Definition of Done

A feature is not done only because the endpoint works.

For backend features:

- schema/migration complete
- validation complete
- authorization complete
- business rules covered
- errors normalized
- test coverage for critical flows
- Swagger/OpenAPI updated
- audit behavior evaluated

For mobile:

- loading state
- success state
- error state
- offline/network failure behavior
- permission failure behavior
- API contract respected

For admin:

- authorization
- filters/search
- loading/error/empty states
- responsive enough for laptop use
- API errors surfaced clearly

# 12. Design Reference

Primary product design reference:

**Mekari Talenta**

Knect should use Mekari Talenta as a reference for:

- information hierarchy
- HR dashboard structure
- mobile employee self-service flow
- attendance interaction patterns
- request/approval navigation
- payroll and payslip presentation
- HR/admin data-management patterns
- overall enterprise HRIS usability

Knect must **not** be a pixel-perfect copy.

Design direction:

- preserve familiar HRIS interaction patterns
- change visual identity, spacing, component styling, typography, iconography, and layout details
- keep Knect visually distinct
- prioritize clarity and usability over visual imitation
- mobile UX may also borrow interaction ideas from `qyupaww/flutter-hris` and Horilla HR Mobile
- architecture and business rules come from Knect's own source-of-truth documents, not from any external UI

When an AI generates UI, it should treat Mekari Talenta as a **design reference**, not as a cloning target.
