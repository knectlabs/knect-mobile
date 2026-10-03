# Kerjancok — System Architecture

## 1. High-Level Architecture

```mermaid
flowchart LR
    M[Flutter Mobile App] -->|HTTPS REST| API[NestJS API]
    W[Next.js Admin] -->|HTTPS REST| API

    API --> DB[(PostgreSQL)]
    API --> OBJ[(S3-compatible Object Storage)]

    API -. Phase 2 .-> REDIS[(Redis)]
    REDIS -. Jobs .-> WORKER[BullMQ Workers]

    WORKER -. Push .-> FCM[Firebase Cloud Messaging]
```

---

# 2. Repository Boundaries

## kerjancok-api

Owns:
- business rules
- authentication
- authorization
- persistence
- payroll computation
- approval engine
- server-side geofence
- auditing
- API contract

## kerjancok-mobile

Owns:
- employee UX
- manager mobile UX
- GPS permission
- camera permission
- selfie capture
- local secure token storage
- API consumption

Must not own:
- final geofence decision
- payroll calculation
- leave balance truth

## kerjancok-admin

Owns:
- HR/admin workflows
- organization management
- employee management
- attendance monitoring
- approval management
- payroll UI
- reports

Must not duplicate backend business rules.

---

# 3. Suggested Backend Modules

```text
src/
├── app.module.ts
├── common/
│   ├── decorators/
│   ├── guards/
│   ├── interceptors/
│   ├── filters/
│   ├── pipes/
│   ├── errors/
│   └── utils/
│
├── database/
│   ├── prisma.module.ts
│   └── prisma.service.ts
│
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

---

# 4. Backend Layering

Recommended pragmatic structure:

```text
Controller
    ↓
Service
    ↓
PrismaService
    ↓
PostgreSQL
```

Do not add repository classes purely for ceremony.

Introduce a repository abstraction only when:

- multiple persistence implementations exist
- query logic becomes significantly complex
- unit-test isolation clearly benefits
- domain logic requires persistence boundaries

---

# 5. Authentication Architecture

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant D as PostgreSQL

    C->>A: POST /auth/login
    A->>D: Verify user
    A->>D: Store hashed refresh token session
    A-->>C: accessToken + refreshToken

    C->>A: API request + accessToken
    A-->>C: Protected response

    C->>A: POST /auth/refresh
    A->>D: Validate refresh session
    A->>D: Revoke old token + create rotated token
    A-->>C: new accessToken + refreshToken
```

Access token:
- short-lived

Refresh token:
- longer-lived
- hashed in database
- bound to session/device where possible

---

# 6. Attendance Architecture

```mermaid
sequenceDiagram
    participant M as Mobile
    participant A as API
    participant D as PostgreSQL
    participant S as Object Storage

    M->>M: Get GPS
    M->>M: Capture selfie
    M->>S: Upload selfie or request signed upload
    M->>A: POST /attendance/clock-in
    A->>D: Load employee + shift + office
    A->>A: Calculate geofence distance
    A->>A: Evaluate time rules
    A->>A: Evaluate anomaly rules
    A->>D: Create attendance
    A->>D: Create evidence/anomaly records
    A-->>M: attendance result
```

---

# 7. Object Storage

Use for:

- attendance selfies
- employee documents
- sick notes
- candidate resumes
- future payslip PDFs

Store metadata in PostgreSQL.

Do not store raw images in PostgreSQL.

---

# 8. Redis / Queue

Do not require Redis in earliest MVP unless needed.

Add later for:

- notification jobs
- payroll background processing
- report generation
- email delivery
- scheduled reminders
- analytics aggregation

---

# 9. Multi-Tenancy

Tenant boundary:

`organization_id`

Tenant-owned data should consistently include organization ownership directly or indirectly.

Authorization must always verify tenant ownership.

Never trust a resource ID without organization scoping.

---

# 10. Date and Time

Time handling is critical.

Store timestamps in UTC.

Organization has timezone.

Business date calculations use organization timezone.

Examples:

- attendance date
- shift date
- payroll cutoff
- leave start/end day

Do not calculate business dates only from server machine timezone.
