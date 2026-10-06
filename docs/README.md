# Documentation index

Updated 2026-10-06. Start with the repository [README](../README.md) for setup and [current status](STATUS.md) for implemented scope and remaining limits. Planning documents describe product direction; they are not evidence that every planned feature ships.

## Core references

1. [Decisions](05_DECISIONS.md): accepted technical and product decisions, including later overrides.
2. [Project context](00_AI_PROJECT_CONTEXT.md): product and repository boundaries.
3. [Data model](03_ERD.md): planned model; check the active Prisma schema in the API for deployed fields.
4. [PRD](01_PRD.md): product requirements.
5. [Architecture](02_ARCHITECTURE.md): responsibilities and integration.
6. [Roadmap](04_ROADMAP.md): delivery sequence and backlog.
7. [API conventions](06_API_CONVENTIONS.md): contracts and errors.
8. [Research notes](07_RESEARCH_GAPS_AND_NOTES.md): unresolved questions.
9. [Mobile UX flows](08_MOBILE_UX_FLOWS.md): flow reference.

When documents conflict, use the source-of-truth priority in [AGENTS.md](../AGENTS.md), with accepted decisions first. Preserve historical decisions and record their overrides explicitly.

Knect remains three separate repositories: API owns rules/data/storage, Admin provides HR workflows, and Mobile provides employee self-service.

## Repository guides

- [Implementation status and acceptance limits](STATUS.md)
- [Current employee and attendance flows](FLOW.md)
- [Current palette, icons, and navigation](MOBILE_VISUAL_SYSTEM.md)
