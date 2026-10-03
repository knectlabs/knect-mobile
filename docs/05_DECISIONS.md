# Kerjancok — Architecture Decision Log

This file overrides older planning documents when decisions conflict.

---

## ADR-001 — Separate Repositories

**Status:** Accepted

Kerjancok uses separate repositories.

- `kerjancok-api`
- `kerjancok-mobile`
- `kerjancok-admin`

Reason:
- user explicitly does not want a monorepo
- independent deployment lifecycle
- cleaner repository ownership

---

## ADR-002 — Flutter Mobile

**Status:** Accepted

Mobile application uses Flutter.

Reason:
- explicit project decision
- reference HR apps studied use Flutter patterns
- strong mobile-first attendance capability

---

## ADR-003 — NestJS Backend

**Status:** Accepted

Backend uses NestJS + TypeScript.

Reason:
- HRIS contains many business domains
- built-in dependency injection
- guards/interceptors/pipes
- clear modular architecture
- good maintainability for long-lived backend

---

## ADR-004 — PostgreSQL + Prisma

**Status:** Accepted

Primary database: PostgreSQL.

ORM: Prisma.

Reason:
- HRIS data is highly relational
- transactions are important
- Prisma provides strong TypeScript DX

---

## ADR-005 — No Supabase

**Status:** Accepted

Supabase is not part of Kerjancok architecture.

Authentication and business logic are owned by Kerjancok API.

---

## ADR-006 — JWT + Refresh Token

**Status:** Accepted

Authentication uses:
- short-lived access JWT
- long-lived refresh token
- hashed refresh session storage
- rotation
- revocation

---

## ADR-007 — npm

**Status:** Accepted

Node.js repositories use npm.

---

## ADR-008 — REST API

**Status:** Accepted

Initial API style is REST.

GraphQL is not required.

---

## ADR-009 — Server-Side Geofence

**Status:** Accepted

Mobile sends:
- latitude
- longitude
- accuracy

Backend calculates distance and makes the authoritative geofence decision.

Client-side geofence checks are UX-only.

---

## ADR-010 — Generic Approval Engine

**Status:** Accepted

Leave, overtime, attendance correction, and later HR workflows reuse an approval engine.

Avoid duplicating approval tables per domain.

---

## ADR-011 — Payroll Snapshot Model

**Status:** Accepted

Payroll results are persisted snapshots.

Changing current salary configuration must not retroactively mutate historical payroll.

---

## ADR-012 — Progressive Infrastructure

**Status:** Accepted

Do not add Redis/BullMQ only for architectural aesthetics.

Start with PostgreSQL + NestJS.

Introduce queue/cache when workloads justify it.
