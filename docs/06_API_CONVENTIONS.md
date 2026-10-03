# Kerjancok — API Conventions

Base path:

```text
/api/v1
```

# 1. Response Format

Successful object:

```json
{
  "data": {}
}
```

Successful list:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 200,
    "totalPages": 10
  }
}
```

Error:

```json
{
  "error": {
    "code": "ATTENDANCE_OUTSIDE_GEOFENCE",
    "message": "You are outside the allowed attendance area.",
    "details": {}
  }
}
```

Do not expose stack traces in production.

Phase 0 implementation: `ApiExceptionFilter` is registered globally through
`APP_FILTER` in `AppModule`. HTTP errors retain their status and always include
`error.code`, `error.message`, and an object `error.details`. Successful
responses are unaffected.

Framework client errors use the HTTP status name as the code (for example
`BAD_REQUEST`, `UNAUTHORIZED`, `NOT_FOUND`, `CONFLICT`) and the standard HTTP
reason phrase as the message. Unrecognized status names use `HTTP_ERROR`.
Framework string messages and arbitrary exception response properties are
discarded: parser errors can include fragments of sensitive request data.
An unmatched route returns HTTP 404 with
`{"error":{"code":"NOT_FOUND","message":"Not Found","details":{}}}`.

For an intentional public domain error, throw `ApiException`:

```ts
throw new ApiException(409, 'RESOURCE_CONFLICT', 'A conflicting record exists.', {
  field: 'name',
});
```

This helper accepts only 400-499, an uppercase underscore-separated error code,
and a nonempty public message. Details default to `{}`. Callers must supply only
client-safe details, never secrets, raw input, SQL, or private HR data. Domain
codes and status choices are defined when their roadmap feature is implemented;
the example does not add a business endpoint.

Framework message arrays are normalized to `message: "Request validation failed"`
and `details: { messages: [...] }`, retaining the original HTTP status code and
its corresponding error code. Validation messages must not interpolate secret
values. This normalization still applies to framework exceptions raised outside
the global DTO pipe.

## Request validation

`AppModule` registers one global `ValidationPipe` through `APP_PIPE`, so the
same policy applies to the normal server, test applications, and future
bootstrap paths:

- request body, query, and path DTOs use `class-validator` decorators;
- validated inputs are transformed into DTO instances;
- implicit type conversion is disabled; declare conversion with
  `class-transformer` such as `@Type(() => Number)`;
- properties without a validation decorator are rejected rather than silently
  accepted or stripped;
- nested objects require both `@ValidateNested()` and an explicit `@Type()`;
- unknown root values are rejected; and
- validation errors never include the rejected values or DTO target object.

A DTO validation failure returns HTTP 400:

```json
{
  "error": {
    "code": "REQUEST_VALIDATION_FAILED",
    "message": "Request validation failed",
    "details": {
      "fields": [
        {
          "field": "profile.name",
          "rules": ["isString", "minLength"]
        }
      ]
    }
  }
}
```

Field paths use dot notation for nested values. `rules` contains sorted
`class-validator` constraint identifiers; an undeclared property uses
`whitelistValidation`. Fields are sorted to keep responses and tests stable.
Clients may associate errors with fields, but should not treat validation rule
identifiers as translated UI copy.

Every accepted DTO property must have a validation decorator. Use `@IsOptional()`
for optional input and `@Allow()` only when a field intentionally has no other
constraint. Validation decorators must not include supplied values in custom
messages. Primitive JSON bodies rejected by the HTTP parser never reach a DTO;
they retain the generic `BAD_REQUEST` response. Malformed JSON behaves the same.
Routes without a DTO metatype cannot receive DTO validation, so each domain
endpoint must declare DTO classes when it is implemented.

## OpenAPI

Swagger UI is served at `/docs` and the generated OpenAPI JSON contract at
`/docs/openapi.json`. The specification declares `/api/v1` as its server base,
the `access-token` JWT bearer scheme, and reusable schemas for normalized API
and request-validation errors. Planned routes are not emitted before their
controllers exist. See `12_OPENAPI.md` for endpoint documentation requirements.

All server errors (500-599) use `message: "Internal server error"` and empty
details, including explicit NestJS server exceptions. Unknown thrown values and
untranslated Prisma failures return HTTP 500 / `INTERNAL_SERVER_ERROR`.
The filter logs only the server status, without exception text, stack, request
URL, or request body. Application and Nest system logs use the redacting JSON
logger documented in `13_LOGGING.md`. Domain-specific database error translation
remains later work. Startup/configuration failures occur before HTTP listening
and are outside this response contract.

## Health readiness

`GET /api/v1/health` is public and verifies that the API can query PostgreSQL.
It returns `200` with:

```json
{
  "data": {
    "status": "ok",
    "checks": {
      "database": "up"
    }
  }
}
```

If PostgreSQL cannot be queried, it returns `503 SERVICE_UNAVAILABLE` through
the standard error envelope without database details. The response uses
`Cache-Control: no-store`.

---

# 2. Authentication

```text
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/logout-all
GET  /auth/me
```

All controller routes require a valid access JWT by default. Only routes marked
with `@Public()` bypass authentication. Public metadata must be limited to
routes that intentionally accept anonymous requests, such as login, token
refresh, and a future health endpoint.

The verified request principal contains only:

```json
{
  "id": "user_id",
  "organizationId": "organization_id",
  "role": "EMPLOYEE"
}
```

`@Roles(...)` performs basic role checks after JWT authentication. A missing or
invalid token returns `401 UNAUTHORIZED`; a valid identity without an allowed
role returns `403 FORBIDDEN`. Role checks do not replace organization ownership
checks. Domain services must still scope tenant-owned records by the principal's
`organizationId`.

---

# 3. Employees

```text
GET    /employees
POST   /employees
GET    /employees/:id
PATCH  /employees/:id
```

Use query params:

```text
?page=
&limit=
&search=
&departmentId=
&positionId=
&status=
```

---

# 4. Organization

```text
GET/PATCH /organization

GET/POST /departments
GET/PATCH/DELETE /departments/:id

GET/POST /positions
GET/PATCH/DELETE /positions/:id

GET/POST /offices
GET/PATCH/DELETE /offices/:id
```

---

# 5. Shift

```text
GET/POST /shifts
GET/PATCH /shifts/:id

GET  /schedules/me/today
POST /employee-shifts
```

---

# 6. Attendance

```text
GET  /attendance/me/today
GET  /attendance/me/history
POST /attendance/clock-in
POST /attendance/clock-out

GET  /attendance
GET  /attendance/:id
```

Clock-in request:

```json
{
  "latitude": -6.2001,
  "longitude": 106.8167,
  "accuracy": 8.4,
  "evidenceFileId": "file_xxx",
  "deviceIdentifier": "device_xxx"
}
```

Clock-in response:

```json
{
  "data": {
    "attendanceId": "att_xxx",
    "status": "LATE",
    "clockInAt": "2026-10-03T01:17:00.000Z",
    "lateMinutes": 17,
    "distanceFromOfficeMeters": 28.6,
    "locationValid": true,
    "riskLevel": "LOW"
  }
}
```

---

# 7. Leave

```text
GET  /leave-types
GET  /leave-balances/me
GET  /leave-requests/me
POST /leave-requests
POST /leave-requests/:id/cancel
```

Admin:

```text
GET/POST/PATCH /leave-types
GET /leave-requests
```

---

# 8. Approvals

```text
GET  /approvals/me
GET  /approvals/:id
POST /approvals/:id/approve
POST /approvals/:id/reject
```

---

# 9. Overtime

```text
GET  /overtime/me
POST /overtime
GET  /overtime
```

---

# 10. Payroll

Phase 2:

```text
GET/POST /payroll-periods
POST /payroll-periods/:id/calculate
POST /payroll-periods/:id/finalize
GET  /payroll-periods/:id/employees
GET  /payslips/me
GET  /payslips/me/:id
```

---

# 11. Versioning

Breaking contract changes require:

- new API version, or
- coordinated migration with clients

Do not silently rename response fields consumed by mobile/admin.

---

# 12. Idempotency

Consider idempotency protection for:

- clock-in
- clock-out
- payroll finalization
- payment/disbursement integrations

At minimum, server must guard duplicate attendance operations transactionally.
