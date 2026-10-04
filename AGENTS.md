# Knect — AI Development Instructions

## 1. Project

You are working on **Knect**, a modern HRIS / workforce-management platform for Indonesian companies.

Knect is inspired by mature HRIS products such as **Mekari Talenta**, but it is an independent product.

Mekari Talenta is the primary UX/design reference.

Do **not** create a pixel-perfect clone.

Use Talenta as inspiration for:

- information hierarchy
- employee mobile flows
- HR admin flows
- attendance UX
- leave / overtime request flows
- approval UX
- payroll / payslip presentation
- HR dashboard organization

Knect must keep its own visual identity.

---

# 2. Repositories

Knect intentionally uses separate repositories.

```text
knect-api
knect-mobile
knect-admin
```

Do not convert this project into a monorepo.

---

# 3. Technology Decisions

These decisions are already accepted.

Do not replace them unless the user explicitly requests an architecture change.

## Backend

```text
NestJS
TypeScript
PostgreSQL
Prisma
REST API
JWT Access Token
Refresh Token Rotation
npm
```

## Mobile

```text
Flutter
Dart
Dio
flutter_secure_storage
go_router
BLoC / Cubit
geolocator
camera / image picker
```

## Admin

```text
Next.js
TypeScript
Tailwind CSS
shadcn/ui
npm
```

## Explicitly NOT used

```text
Supabase
React Native
GraphQL
monorepo
```

Do not introduce them silently.

---

# 4. Required Reading Before Coding

Before implementing or modifying a feature, read the relevant project documentation.

Source-of-truth priority:

```text
05_DECISIONS.md
        ↓
00_AI_PROJECT_CONTEXT.md
        ↓
03_ERD.md
        ↓
01_PRD.md
        ↓
02_ARCHITECTURE.md
        ↓
04_ROADMAP.md
        ↓
06_API_CONVENTIONS.md
        ↓
07_RESEARCH_GAPS_AND_NOTES.md
        ↓
08_MOBILE_UX_FLOWS.md
```

If two documents conflict, follow the document with the higher priority.

Do not silently resolve architecture conflicts yourself.

---

# 5. Current Development Strategy

Development must follow the roadmap.

Do not jump directly to advanced features.

Order:

```text
Phase 0
Project Foundation

↓

Phase 1A
Authentication + Organization

↓

Phase 1B
Employees

↓

Phase 1C
Shift & Scheduling

↓

Phase 1D
Attendance

↓

Phase 1E
Leave + Approval

↓

Phase 1F
Overtime + Attendance Correction

↓

Phase 1G
Notifications + Audit + Reports

↓

MVP COMPLETE

↓

Phase 2
Payroll

↓

Phase 3
Performance

↓

Phase 4
Recruitment + Advanced HR
```

Features listed in the long-term backlog must not automatically be implemented during MVP.

Design architecture so future features are possible, but do not over-engineer them prematurely.

---

# 6. Backend Architecture Rules

Use NestJS modules based on business domains.

Recommended structure:

```text
src/
├── common/
├── database/
└── modules/
    ├── auth/
    ├── organizations/
    ├── users/
    ├── employees/
    ├── departments/
    ├── positions/
    ├── offices/
    ├── shifts/
    ├── schedules/
    ├── attendance/
    ├── leave/
    ├── overtime/
    ├── approvals/
    ├── payroll/
    ├── performance/
    ├── recruitment/
    ├── notifications/
    ├── audit/
    └── files/
```

Use the pragmatic layering:

```text
Controller
    ↓
Service
    ↓
PrismaService
    ↓
PostgreSQL
```

Do not create repository classes only for architectural ceremony.

Introduce a repository layer only if there is a concrete need.

---

# 7. Database Rules

PostgreSQL is the source of truth.

Prisma schema must remain aligned with:

```text
docs/03_ERD.md
```

Important principles:

- organization-scoped records must preserve tenant ownership
- historical HR records must not be casually deleted
- payroll records are snapshots
- audit records are append-only
- high-frequency queries need indexes
- schema changes require migrations
- do not change entity semantics silently

Before creating a new table, verify that an existing entity does not already represent the concept.

---

# 8. Multi-Tenant Rule

The application is designed to support multiple organizations.

Tenant boundary:

```text
organization_id
```

Never fetch a sensitive record only by ID without validating organization ownership.

Incorrect:

```ts
prisma.employee.findUnique({
  where: { id }
});
```

when tenant authorization is required.

Always ensure the authenticated user's organization has access to the resource.

---

# 9. Authentication Rules

Authentication uses:

```text
Access JWT
+
Refresh Token
```

Rules:

- short-lived access token
- long-lived refresh token
- refresh token stored hashed
- refresh-token rotation
- per-device/session revocation
- logout one session
- logout all sessions

Never store raw refresh tokens in the database.

Never log:

- passwords
- refresh tokens
- authentication secrets

---

# 10. Authorization

Authentication and authorization are different.

Always validate:

```text
Who is this user?
        ↓
What organization do they belong to?
        ↓
What role / permission do they have?
        ↓
Are they allowed to access this resource?
```

Core roles:

```text
SUPER_ADMIN
COMPANY_ADMIN
HR
MANAGER
EMPLOYEE
```

Dynamic permissions are part of the future roadmap.

Do not prematurely build a complicated permissions engine unless required by the active phase.

---

# 11. Attendance Rules

Attendance is a critical business domain.

Never implement clock-in as only:

```text
insert attendance
```

Clock-in must conceptually perform:

```text
Authenticate
↓
Resolve Employee
↓
Check Employee Active
↓
Resolve Organization Timezone
↓
Resolve Today's Shift
↓
Resolve Office
↓
Validate Attendance Window
↓
Validate GPS Accuracy
↓
Calculate Distance Server-Side
↓
Validate Geofence
↓
Validate Selfie Evidence
↓
Check Duplicate Attendance
↓
Run Anomaly Checks
↓
Calculate Lateness
↓
Save Attendance
↓
Save Evidence
↓
Save Anomaly Results
↓
Write Audit Information
```

---

# 12. Geofence Security

The mobile client is not trusted to determine attendance validity.

Mobile sends:

```json
{
  "latitude": 0,
  "longitude": 0,
  "accuracy": 0
}
```

Backend calculates distance from office coordinates.

The authoritative geofence decision is made on the backend.

Client-side distance calculation may exist only for UX.

Never trust:

```text
isInsideGeofence: true
```

sent by the client.

---

# 13. Attendance Fraud / Risk

Supported anomaly concepts include:

```text
OUTSIDE_GEOFENCE
LOW_GPS_ACCURACY
MOCK_LOCATION
IMPOSSIBLE_TRAVEL
DUPLICATE_ATTEMPT
UNKNOWN_DEVICE
```

An anomaly is a risk signal.

It does not automatically prove fraud.

Do not label rule-based heuristics as AI/ML.

---

# 14. Leave Rules

Leave includes:

```text
leave_types
leave_balances
leave_requests
```

Leave approval must use the generic approval engine.

Business values such as:

```text
minimum request H-3
```

must eventually be organization-configurable.

Do not globally hardcode assumptions taken from SmartGeo HRIS.

---

# 15. Approval Engine

Do not create separate approval architectures for every module.

Use a reusable approval engine.

Supported target examples:

```text
LEAVE_REQUEST
OVERTIME_REQUEST
ATTENDANCE_CORRECTION
SHIFT_CHANGE
WORK_TYPE_CHANGE
```

Concept:

```text
ApprovalRequest
        ↓
ApprovalStep 1
        ↓
ApprovalStep 2
        ↓
...
```

---

# 16. Attendance Correction

Employees must not directly modify historical attendance.

Flow:

```text
Employee submits correction
        ↓
Approval workflow
        ↓
Authorized service applies correction
        ↓
Audit log preserved
```

Never silently overwrite attendance history.

---

# 17. Payroll Rule

Payroll belongs to Phase 2.

Do not place payroll calculation inside attendance controllers/services.

Attendance produces operational records.

Payroll consumes aggregated approved data.

Payroll results must be snapshots.

Example:

```text
Basic Salary
+ Allowances
+ Overtime
- Deductions
- Tax
- BPJS
- Loan Installment
= Net Salary
```

Use salary/payroll components rather than hardcoding every company rule into database columns.

Historical payroll must remain unchanged if current salary configuration changes.

---

# 18. Indonesia-Specific Business Rules

Research references include SmartGeo HRIS.

Potential rules include:

```text
minimum leave notice
maximum weekday overtime
no-work-no-pay
BPJS
PPh21
late deductions
employee loan installment limits
```

These are reference rules.

Whenever possible, model them as organization configuration.

For example:

```text
leave_min_notice_days = 3
weekday_overtime_max_minutes = 120
loan_installment_max_percent = 30
```

Do not assume all companies use the same values.

---

# 19. Flutter Architecture

Mobile should use feature-based organization.

Recommended:

```text
lib/
├── core/
├── shared/
└── features/
    ├── auth/
    ├── home/
    ├── attendance/
    ├── shifts/
    ├── leave/
    ├── overtime/
    ├── approvals/
    ├── payroll/
    ├── notifications/
    └── profile/
```

Every major feature should separate:

```text
data
domain
presentation
```

where useful.

Avoid putting all API requests directly inside widgets.

---

# 20. Mobile UI Rules

Primary reference:

**Mekari Talenta**

Secondary references:

```text
qyupaww/flutter-hris
Horilla HR Mobile
```

Employee mobile navigation should initially center around:

```text
Home
Attendance
Requests
Payroll
Profile
```

Manager role can later gain:

```text
My Team
Approvals
```

Every screen should consider:

```text
Loading
Content
Empty
Error
Refreshing
Permission denied
Network failure
```

Use skeleton loading when appropriate.

---

# 21. Flutter Environment Rules

Mobile must support:

```text
development
staging
production
```

API URLs must not be hardcoded inside screens or repositories.

---

# 22. Mobile Security

Tokens must use secure storage.

Future biometric unlock:

```text
Face ID
Fingerprint
```

is only a local app unlock mechanism.

It does not replace backend authentication.

---

# 23. Admin Web Rules

Admin dashboard should prioritize operational HR tasks.

Main sections:

```text
Dashboard
Employees
Organization
Attendance
Schedule & Shifts
Leave
Overtime
Approvals
Payroll
Performance
Recruitment
Reports
Settings
```

Do not replicate business rules in Next.js.

Business rules belong in the API.

---

# 24. External Research Notes

Initial research sources:

```text
qyupaww/flutter-hris
Horilla HR Mobile
tyser1995/hris_app
SmartGeo HRIS
```

Lessons from these repositories are documented in:

```text
07_RESEARCH_GAPS_AND_NOTES.md
```

Features discovered there that are not part of the current phase must remain in the backlog.

Do not forget them.

Do not implement them prematurely.

---

# 25. Long-Term Backlog Awareness

Architecture should remain compatible with:

```text
attendance breaks
monthly hour account
timesheets
holiday calendars
employment types
contracts
employee documents
announcements
people directory
My Team dashboard
work types
shift changes
expense claims
assets
employee code generator
company branding
employee loans / kasbon
biometric unlock
dynamic permissions
split shifts
flexible shifts
BPJS
PPh21
succession planning
individual development plans
advanced onboarding
advanced analytics
```

These are known future requirements.

They are not accidental omissions.

---

# 26. API Convention

Base URL:

```text
/api/v1
```

Successful object response:

```json
{
  "data": {}
}
```

List response:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 0,
    "totalPages": 0
  }
}
```

Error:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Readable message",
    "details": {}
  }
}
```

Do not return random response shapes between modules.

---

# 27. Testing Requirement

Critical business logic requires tests.

Highest-priority areas:

```text
authentication
refresh token rotation
RBAC
tenant isolation
geofence
clock-in
clock-out
leave balance
approval
attendance correction
payroll
```

A feature is not considered complete only because the happy-path endpoint returns 200.

---

# 28. Feature Completion Checklist

Before declaring a backend feature complete:

- database schema checked
- migration created
- DTO validation added
- authorization checked
- organization ownership checked
- business logic implemented
- errors normalized
- tests added
- Swagger updated
- audit implications checked
- docs updated if architecture changed

Before declaring mobile work complete:

- loading state
- empty state
- error state
- success state
- permission handling
- API failure handling
- secure token handling
- dev/staging/prod checked

Before declaring admin work complete:

- authorization
- loading/error/empty state
- filters
- pagination
- search where needed
- API contract consistency

---

# 29. When Requirements Are Unclear

Do not invent major product behavior.

First inspect:

```text
PRD
ERD
Decisions
Research Notes
Roadmap
```

If still ambiguous:

Choose the smallest implementation that:

1. respects existing architecture,
2. does not block known future requirements,
3. does not prematurely implement another phase.

Document significant assumptions.

---

# 30. Mandatory Workflow for AI

Before coding:

```text
1. Read AGENTS.md
2. Read project docs
3. Identify current phase
4. Identify affected domain
5. Inspect existing implementation
6. Inspect existing Prisma models/API contracts
7. Plan smallest coherent change
```

During coding:

```text
8. Implement
9. Add tests
10. Run formatter
11. Run lint/analyze
12. Run tests
13. Check migrations
```

After coding:

```text
14. Summarize what changed
15. List files changed
16. Report tests executed
17. Report known limitations
18. Update project docs if decisions/schema/contracts changed
19. Recommend the next roadmap task
```

---

# 31. Most Important Rule

Do not optimize only for making the current task pass.

Optimize for keeping **Knect internally consistent over the entire product roadmap**.

When in doubt:

```text
Product consistency
>
short-term convenience
```