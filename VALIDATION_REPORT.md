# Validation report

**Handoff version:** 1.0  
**Validation date:** 19 September 2026  
**Result:** 107 reference and contract tests passed in the local environment.

## What was actually executed

```text
Command: python -m pytest -q
Working directory: BharatLaw_AI_Handoff
Result: 107 passed
```

Environment used: Python 3.13.5, pytest 9.0.2, jsonschema 4.26.0, PyYAML 6.0.3.

The tests exercised deterministic rank fusion; public/private query-filter structure; rejection of invalid vectors, scopes and budgets; exact citation handles and text hashes; Unicode code-point offsets; cross-run/release/workspace and revoked-authorization rejection; private-evidence source-class checks; half-open legal/knowledge date intervals; unknown dates/conditions and conflicts; JSON Schema structure and example validation; extra-field rejection; JSON/YAML parsing; local OpenAPI reference resolution, unique operation IDs, path parameters and authentication metadata; mapping field/profile consistency; fail-closed source/provider configuration; and a textual uniqueness/presence inspection of the reference SQL.

## What these tests do not establish

| Component | Status and required follow-up |
|---|---|
| PostgreSQL DDL/migrations/RLS/exclusion constraints | **Not executed.** PostgreSQL server/client and Docker were not available. Apply reviewed migrations and test privileges, tenant/workspace isolation and bitemporal SQL on the selected actual PostgreSQL version. |
| OpenSearch mappings, BM25/vector filtering and managed AWS compatibility | **Not executed against a search engine.** Request/mapping structure was inspected only. Apply to the approved version, test inner k-NN filtering and benchmark actual retrieval. |
| OpenAPI implementation | **Structural references and selected invariants validated only.** No generated server, official full OpenAPI validator, HTTP integration or browser end-to-end application test was run. |
| AWS infrastructure | **Not provisioned or deployed.** The package contains a module design, not completed Terraform. No cloud spend or real recovery exercise was performed. |
| Provider integrations/LLMs | **Not called.** No live generation, embeddings, reranking, fine-tuning, token-billing benchmark or regional processing validation occurred. |
| Indian legal accuracy | **Not evaluated on real legal questions.** Fixtures are prominently synthetic. Citation integrity does not prove legal correctness. Lawyer-authored held-out benchmarks and real editorial review remain mandatory. |
| Source acquisition/licensing | Official source interfaces/documents were inspected for architecture research, but no production corpus was acquired or licensed. Source registers remain pending; no CAPTCHA bypass or commercial scraping occurred. |
| Security/privacy/compliance | Threat/control design is supplied; no penetration test, complete regulatory opinion or compliance certification occurred. CERT-In primary-document retrieval was unsuccessful, so current obligations remain a stated legal-verification gate. |
| Performance/cost/recovery | All SLOs, scale figures, budget caps and schedule figures are proposed planning targets, not achieved measurements or price quotations. |

## Release status

Suitable as an engineering specification and small reference-code handoff. **Not suitable to advertise as an operational, production-tested Indian-law AI application.** Begin with the source-viewer vertical slice and follow the documented phase gates.

The machine-readable contracts and reference DDL are starting points for reviewable implementation. The SQL includes service-level invariants that are not expressed solely as database constraints; Codex must implement and test those explicitly. Authorization callbacks in reference tests are synthetic, not a real identity service.

Package checksums are recorded in `MANIFEST.sha256`; the manifest excludes itself. ZIP integrity and contained-file checksums are verified during packaging.
