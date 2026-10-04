# Knect — AI Project Context

This folder is the long-term source of truth for the Knect HRIS project.

## Purpose

These documents are designed to be read by:
- AI coding assistants
- Backend developers
- Flutter developers
- Web/admin developers
- Future maintainers

The goal is to preserve product, architecture, data-model, and delivery context consistently over a long development cycle.

## Reading Order

Every AI or developer should read these files in this order:

1. `00_AI_PROJECT_CONTEXT.md`
2. `01_PRD.md`
3. `02_ARCHITECTURE.md`
4. `03_ERD.md`
5. `04_ROADMAP.md`
6. `05_DECISIONS.md`
7. `06_API_CONVENTIONS.md`
8. `07_RESEARCH_GAPS_AND_NOTES.md`
9. `08_MOBILE_UX_FLOWS.md`

## Source of Truth Priority

If documents conflict, use this priority:

1. `05_DECISIONS.md`
2. `00_AI_PROJECT_CONTEXT.md`
3. `03_ERD.md`
4. `01_PRD.md`
5. `02_ARCHITECTURE.md`
6. `04_ROADMAP.md`
7. Code comments

Never silently change product architecture or database semantics. Update the relevant Markdown document first.

## Repositories

Knect is intentionally **not a monorepo**.

Repositories:

- `knect-api` — NestJS API
- `knect-mobile` — Flutter mobile application
- `knect-admin` — Next.js HR/admin dashboard

All repositories should keep a copy or link to the latest AI context documents.
