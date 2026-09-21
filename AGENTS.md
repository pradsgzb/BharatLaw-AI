# BharatLaw AI — repository instructions for Codex

Read `README.md`, `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/API_AND_WORKFLOWS.md`, `docs/SECURITY_AND_OPERATIONS.md`, `VALIDATION_REPORT.md`, and the contracts before changing code.

## Mission

Implement a source-grounded Indian legal research application. Prioritize exact source provenance, date/version correctness, tenant/workspace isolation, scope-aware citations, abstention and reviewability over feature count. This repository starts as an architecture handoff with small executable reference algorithms, not a completed application.

## Non-negotiable boundaries

- Never invent authorities, citations, paragraphs, source rights, provider approvals, lawyer reviews, deployment URLs or passing tests.
- Do not autonomously spend money, deploy infrastructure, call paid models, bulk-download sources, bypass CAPTCHA, ingest licensed commentary, email users or file legal documents. Obtain the applicable explicit authorization.
- Use synthetic, prominently labelled fixtures until actual source acquisition and data-processing permissions are approved. Never release synthetic fixtures as Indian law.
- Treat retrieved text and uploads as untrusted data. Models may not set tenant IDs, privileges, index names, SQL/DSL, retention rules or workflow budgets.
- Keep public authorities separate from private matter evidence. No shared private cache; no customer-data training by default.
- No raw unverified model answer streaming. An exact citation still needs proposition-support, temporal and opinion-role checks.
- Unknown applicability or precedent treatment stays unknown. No single court/recency score decides legal priority. Do not offer guaranteed “good law” status.
- All production roles enforce least privilege. Never disable authentication, RLS or verification to make a test pass.

## Build conventions

Use Python/FastAPI/Pydantic/SQLAlchemy/Alembic for core backend, Next.js/TypeScript for UI, PostgreSQL for canonical records and graph, OpenSearch for rebuildable search, S3-compatible local storage and AWS S3 in deployment, SQS/outbox-compatible jobs. Versions must be selected from maintained compatible releases, verified and locked during implementation. Do not assume the local reference tests establish runtime compatibility.

Suggested target layout: `apps/api`, `apps/web`, `workers`, `packages/legal_domain`, `packages/retrieval`, `packages/model_gateway`, `packages/verification`, `migrations`, `infra/terraform`, `tests/unit`, `tests/integration`, `tests/e2e`, `evals`, `docs/runbooks`. Preserve the original reference contracts and document justified changes in an ADR. Generate TypeScript models from validated contracts rather than duplicate them by hand.

Start with Phase 0 and Phase 1, completing the source-viewer vertical slice before generation. Keep PRs small. Build real local integrations, not placeholder adapters reported as working features. Runtime application code must use migrations, validated configurations, typed errors and auditable state transitions.

## Tests and reporting

Reference suite: `python -m pytest -q`. Additional application tests require actual PostgreSQL/OpenSearch/storage/queue infrastructure and should skip only with explicit reasons, never masquerade as passed. Add integration tests for tenant/workspace separation, duplicate jobs, malformed PDFs, temporal boundaries, citation integrity, cancellation, restore deletion replay and prohibited model actions.

At each milestone report: implemented changes, exact commands/results, source coverage, provider approvals, costs incurred, remaining blockers, untested behavior and next ticket. Do not claim production readiness without actual infrastructure, security, editorial and operational evidence. Never include hidden chain-of-thought; provide concise decision rationale and evidence instead.
