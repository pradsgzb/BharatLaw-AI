# Phased Codex implementation plan

Version 1.0 · 19 September 2026. Indicative schedule: **12–18 weeks for a limited pilot**, assuming two backend/AI engineers, one frontend engineer, part-time Indian legal editorial support and security/DevOps review. This is a planning estimate, not a delivery guarantee. Source permissions, editorial effort, procurement and actual test outcomes determine the schedule. Broad all-India coverage is not included in that estimate.

## Phase 0 — Decisions, legal acquisition and repository foundation

**Output:** approved or explicitly blocked decision register; reproducible local development; no paid calls or production deployment.

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-001 | Scope, audience, languages, court/date coverage and out-of-scope record | Signed/approved product decision file; no “all Indian law” claim |
| BL-002 | Source/rights register with independent operation permissions | Manual import path works; unapproved fetch/index/model/display operations denied |
| BL-003 | Provider/data-processing register | Exact profile/region/retention/pricing identified or explicitly blocked; private mode off |
| BL-004 | Monorepo, dependency locks, Python/Node tooling, local containers | Clean clone starts API/web and dependencies with documented commands |
| BL-005 | CI lint/type/unit/contract/security jobs and secret scanning | Green actual execution; no disabled checks called “passed” |
| BL-006 | Architecture decisions and threat model | Decisions cover source truth, temporal scope, indexes, tenant boundary and model gateway |

**Gate:** Phase 1 may proceed with synthetic fixtures while legal acquisition is blocked. A real legal corpus or provider route may not be marked approved merely to unblock development.

## Phase 1 — Canonical corpus and exact source viewer

**Output:** first complete local vertical slice; no LLM required.

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-007 | Alembic migrations from reviewed reference DDL | Up/down-or-forward-repair migration strategy tested on supported PostgreSQL; constraint tests |
| BL-008 | Runtime DB roles, tenant RLS and workspace policy | Two-tenant/two-workspace isolation tests execute with real application role |
| BL-009 | Manual import manifest and immutable artifact storage | Hash/media/source-policy checks, duplicate import and changed-byte versioning tests |
| BL-010 | PDF/text parser with exact legal-unit/source-span mapping | Hand-checked pages; Unicode offsets and missing paragraph numbers handled honestly |
| BL-011 | Quarantine, extraction review and editorial approval UI | Bad scans/ambiguous parsing stay unpublished; reviewer audit captured |
| BL-012 | Catalog, article/section lookup and evidence viewer | Browser can open exact original page/excerpt; content rights respected |
| BL-013 | Corpus release manifest and publication/rollback | Chunks + unit versions + temporal/graph snapshots pinned; synthetic production rejection |

**Gate:** source text cannot be silently changed; links are traceable to source bytes; no source outside the approved release is displayed as released authority. The first real corpus is an approved Constitution edition plus a legally reviewed small case set, not an unreviewed full-site crawl.

## Phase 2 — Retrieval before generation

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-014 | Exact identifier/citation resolver | Ambiguous/malformed/unknown cases not silently invented |
| BL-015 | OpenSearch concrete public indexes and rebuild job | Exact mapping applied to selected actual engine; strict-field rejection and hashes verified |
| BL-016 | Typed lexical/vector query gateway | Identical safe filters; Lucene inner k-NN filter integration tests |
| BL-017 | Application RRF + approved reranker adapter | Duplicate handling, deterministic ties and measured retrieval comparison |
| BL-018 | Definition/proviso/exception and neighbor expansion | Required context included within budget; citations use original text, not summaries |
| BL-019 | First legal-editor gold retrieval set | >=100 questions with acceptable evidence and date/jurisdiction scopes, held-out split |

**Gate:** proposed recall@20 >=0.90 on the reviewed pilot set; report denominator, confidence interval and per-category errors. No private/synthetic/restricted leakage. Do not trade away authority scope to improve aggregate recall. A missed essential qualifier/controlling source blocks affected-domain release.

## Phase 3 — Evidence-grounded answers

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-020 | Replaceable generation/embedding/reranking gateway | Approved profiles, fake provider test adapter and explicit offline behavior |
| BL-021 | Run state, idempotency, checkpoints, outbox and budgets | Duplicate delivery, crash recovery, timeout-cost reconciliation and cancellation tests |
| BL-022 | Evidence-handle assignment and structured claim generation | Unknown handle/cross-run/cross-release references rejected |
| BL-023 | Canonical quote/citation verifier and release gate | Exact quote/hash/pinpoint tests; unsupported legal proposition never published unqualified |
| BL-024 | Semantic-support evaluation and human review state | Automated check is not labelled lawyer review; supported versus merely existing citation distinguished |
| BL-025 | Safe SSE and research UI | Only verified answer content published; disconnections/ACL revocation/replay tested |
| BL-026 | Honest coverage, assumptions, conflicts and abstention | Insufficient evidence yields transparent limited answer, not fabricated precedent |

**Gate:** deterministic source and quote checks pass for every served citation. Proposed substantive-claim support >=95% on held-out lawyer-reviewed evaluation, with zero unresolved critical defects; not a product-wide accuracy claim. No silent model or regional fallback.

## Phase 4 — Temporal law and evidence-backed citation graph

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-027 | Bitemporal applicability, territory and conditions | Half-open boundaries, unknown commencement, saved knowledge snapshot and later correction tests |
| BL-028 | Amendment/commencement/repeal/saving workflow | Instrument and provision-level evidence present; no document-date shortcut |
| BL-029 | Opinion/argument/holding separation | Dissent, quoted authority and counsel argument cannot be presented as majority holding |
| BL-030 | Citation resolution and scoped treatment graph | Cites/follows/distinguishes/overrules represented separately; adverse treatment editorially reviewed |
| BL-031 | Supporting/contrary authority search | Reports coverage limits and unresolved conflicts; not a definitive citator badge |
| BL-032 | Version comparison and historical/retrospective UI | Legal date, authority cutoff and knowledge date visible and reproducible |

**Gate:** no known critical wrong-version/false-overruling/majority-versus-dissent defect in release tests. Bitemporal SQL constraints run against real PostgreSQL, not only Python examples. Expand toward >=500 questions for a broader release; increase corpus only within tested legal domains.

## Phase 5 — Bounded research orchestration and private workspaces

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-033 | Typed coordinator with statute/case/contrary subroutines | Eight-tool/two-parallel-worker/one-repair budget enforced server-side |
| BL-034 | Tool schemas, prompt-injection tests and output policy | Retrieved instructions cannot grant tools or cross boundaries |
| BL-035 | Upload sessions, isolated parsing and private indexes | Signed upload, checksum, MIME, malicious PDF and cross-workspace retrieval tests |
| BL-036 | Membership revocation, cache isolation and legal-source separation | Mid-run revocation prevents final publication; private text is not authoritative law |
| BL-037 | Retention/hold/deletion, safe exports and matter confidentiality | Approved obligation register; component erasure receipts; export authorization tests |

**Gate:** private features remain off until legal/security/provider approvals and actual end-to-end isolation tests pass. The public-source product can launch as a limited pilot without private matter uploads. No autonomous court filings or external communication.

## Phase 6 — Staging, operational validation and limited launch

| Ticket | Deliverable | Acceptance evidence |
|---|---|---|
| BL-038 | Terraform modules and CI/CD | Format/validate/scan plus reviewed staging plan/apply; pinned images and versions |
| BL-039 | Scale and performance tests | Measured 100k/1m chunk tests, latency/concurrency/accuracy/cost report |
| BL-040 | Failure, restore and index rollback drills | Queue duplicates, DB restore, deletion replay and restricted-source rollback tested |
| BL-041 | Independent security and legal pilot review | Findings closed or deployment formally blocked; no “documented critical exception” launch |
| BL-042 | Monitoring, support and incident/deletion runbooks | Alerts reach owner; provider outage and source freshness states visible |
| BL-043 | Limited beta with scope/coverage disclosure | Release/model/policy versions, known limitations and approved user population recorded |
| BL-044 | Benchmark-driven next-phase decision | Expand only after observed utility, support quality and legal-review costs justify it |

**Gate:** production deployment, live paid APIs and source acquisition require their specific authorizations. Codex may implement infrastructure definitions without deploying them. Passing unit tests is not the launch gate.

## Later work — only after measured need

Hindi/Hinglish retrieval with bilingual legal review; additional High Courts/state laws; licensed publisher integrations; specialized legal reranker; on-premise or India-only local model serving; proposition-level graph database if relational traversal is a measured bottleneck; model fine-tuning for extraction or presentation. Do not begin training a foundation model or add Kubernetes simply to make the architecture appear sophisticated.

## Engineering definitions of done

For each ticket: implemented behavior; schema/type/API changes; positive, negative and boundary tests; actual command evidence; security and privacy implications; failure and retry behavior; operator documentation; source/model/version impact; measured cost where external calls occurred. Distinguish `implemented`, `tested`, `blocked`, `untested`, `deferred`. Mocks can prove orchestration but cannot prove model quality, real-law accuracy or AWS compatibility.

Avoid huge all-at-once code generation. One reviewable vertical slice per pull request, with migration/contract compatibility checks and a concise completion report. Do not hide missing provider credentials, legal review or source permissions behind fake success responses.
