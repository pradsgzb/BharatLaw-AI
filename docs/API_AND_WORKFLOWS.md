# API contracts and workflow semantics

Version 1.0 · 19 September 2026 · Implementation requirements, not running endpoints.

Hash terminology: `source_sha256` on a citation means the containing canonical unit-text hash (UTF-8); `quote_sha256` hashes the exact excerpt, and the original artifact has its own byte hash. Never interchange them.

The machine-readable reference is `contracts/openapi.yaml` (OpenAPI 3.1). The separate JSON schemas are the canonical artifact contracts. Generate server models and TypeScript types, compare their output in CI, and fail on drift. Do not replace typed responses with arbitrary model-generated JSON. Additional endpoint families must use the same identity, idempotency, validation and error rules.

## 1. Request context and authorization

Authenticate through an approved OIDC issuer. Validate signature, issuer, audience, expiry and token purpose. A browser backend-for-frontend may exchange the session for an internal token. With cookies, use HttpOnly, Secure, suitable SameSite and CSRF protections; do not place bearer tokens in browser localStorage. Require MFA for privileged users.

The optional `X-Tenant-ID` header selects an organization; it does not confer membership. Resolve it against the authenticated identity. With multiple memberships and no unambiguous active organization, return `409 TENANT_SELECTION_REQUIRED`. Derive user ID, tenant ID, roles, effective workspace permission, current workspace ACL revision and processing policy on the server. No model or arbitrary client JSON may override them.

Open a database transaction, set `app.tenant_id` with transaction-local `set_config`, and use a runtime role that neither owns tables nor has BYPASSRLS. Explicitly enforce workspace membership as well as tenant RLS. This applies equally to workers, event streams, source viewers, exports, search, audit queries and final answer release. Do not leak cross-tenant resource existence through error detail. Privileged global editorial routes require a separate permission, not merely tenant admin.

Every request has a generated request ID. Log safe identifiers, latency and error codes, not questions, uploaded text, full generated answers or tokens. Public-law research questions themselves may disclose a confidential matter.

## 2. Core endpoint families

| Family | Primary endpoints | Required behavior |
|---|---|---|
| Identity/coverage | `GET /v1/me`, `GET /v1/coverage` | Organization/workspace context and honest release coverage |
| Search | `POST /v1/search` | Typed filters, pinned release, server-scoped public/private branches |
| Source viewer | `GET /v1/documents/{id}`, document-unit listing, `/v1/source-spans/{id}` | Rights-aware catalog, exact source text, original pinpoint/page anchors |
| Versions/graph | provision versions and document citations routes | Reviewed temporal assertions, evidence-scoped relationships, explicit uncertainty |
| Research | `POST /v1/research/runs`, run read/events/clarifications/cancel | Asynchronous bounded state machine, durable checkpoints |
| Answers/exports | `GET /v1/answers/{id}`, export request/approve/download | Current authorization and source availability; no silent citation replacement |
| Workspace/uploads | workspace/membership/upload-session/private-document routes | Tenant and workspace checks; quarantine before parsing; explicit deletion workflow |
| Editorial administration | sources, policies, imports, jobs, reviews, release build/publish, takedowns | Separate administrative capability and audit trail |
| Privacy/operations | deletion, usage, audit | Policy-versioned erasure and safe operational detail |

The table uses abbreviated path IDs for readability; the OpenAPI file is authoritative for exact spellings. Release history/version routes use the run's pinned release, not whichever alias is current. Keep large documents paginated at the unit level; never load a full judgment corpus into a response or prompt.

## 3. Research run lifecycle

```text
created -> queued -> planning -> retrieving -> drafting -> verifying -> completed
                     |              |             |             |
              needs_clarification   +---- bounded retry ----------+
                     |                                          |
                     +-> queued                     partial / abstained

Any active state -> cancelling -> cancelled
Any active state -> failed (safe error code and resumable checkpoint where valid)
```

Map detailed worker states to the finite API/SQL state enums rather than introducing undeclared database values. `partial`, `abstained` and `needs_clarification` are answer/product outcomes, not necessarily independent queue-job states. Every transition is compare-and-set with a run revision/lease. A late worker cannot overwrite a cancelled or already finalized run.

At creation: validate request, authorize workspace, resolve data-processing policy, reserve cost allowance, save an idempotency record and write an outbox event in one transaction. Return `202` with run ID and status/event links. Store the request hash, policy version, corpus release and concrete index names, prompt profile, approved model profiles and verifier version. An explicit corpus release request must itself be accessible and valid; do not accept withdrawn releases for new runs.

Planning separates the event date, legal-text applicability date, authority cutoff, jurisdiction and research mode. Missing material facts can produce at most two structured clarification rounds. The user may decline: continue only with explicit assumptions or abstain. A resumed answer pins its revised plan and records the change before retrieving evidence.

Acquire sources through typed tools. Before every model request recheck rights, current authorization, budget, processing route and content size. The coordinator assigns evidence handles such as E1/E2; the model is allowed to reference only these. The browser receives no raw model draft. A failed citation/quote check allows one limited repair attempt; persistent failure produces a partial/abstained answer without the unsupported proposition.

A complete answer contains direct response, provision versions, material claims, supporting/contrary evidence, assumptions, limitations, coverage, as-of dates and verification state. A generation model cannot set `lawyer_reviewed=true`. Only a real authenticated review operation may do that.

### Server-sent events

Emit event IDs in monotonically increasing run-event order. Allow `Last-Event-ID` replay only for that authorized run. Example event types: `run.accepted`, `plan.ready`, `source.selected`, `verification.started`, `answer.ready`, `run.failed`, `run.cancelled`. Payloads are safe typed metadata, not private chain-of-thought, arbitrary tool output or unverified text. Revalidate authorization during long-lived streams; an ACL change closes unauthorized connections. Expose gaps/expired replay explicitly instead of silently skipping events.

Cancellation is best effort: stop new tools, cancel pending jobs, mark in-flight external requests as uncertain if necessary and reconcile actual billing. Never promise an already-sent model request can be recalled. Retry only operations whose effects are understood; a provider timeout may still incur a charge.

## 4. Search semantics

Search accepts a question and typed filter fields, never raw OpenSearch DSL. Exact identifier resolution precedes broad retrieval. The server chooses allowed concrete public/private index names; no wildcard from a client or model. Apply tenant, workspace, ACL revision and active-state constraints within both private BM25 and vector queries, then reauthorize retrieved canonical spans before transmission/display.

Public retrieval pins a release and an allowed source set, excludes restricted and synthetic records, and obeys current rights. Private uploads do not become authoritative legislation. Search results expose source class and opinion/role labels. Exact case-name matches with ambiguous identity remain ambiguous.

A statutory search may need a later-published edition to locate earlier wording. Publication date is not a general replacement for legal applicability. Use approved temporal snapshots to select the correct provision version. Apply research-mode-specific judicial decision cutoffs only where meaningful; retrospective legal analysis may use later interpretations, which must be explicitly identified.

Index relevance metadata is advisory. The canonical repository rechecks exact text, version membership, source rights and current takedowns. Never quote OpenSearch `_source` without the canonical verification step.

## 5. Upload workflow (disabled until private-content launch gate)

1. The authenticated user requests an upload session for one authorized workspace with filename, MIME type, expected size and SHA-256. Enforce per-file, per-user and tenant quotas before signing.
2. The server generates an opaque key in a tenant/workspace-specific quarantine prefix. Never accept an arbitrary bucket/key from the client. A short-lived signed upload grants only that object operation. Convert validated hex SHA-256 to the Base64 checksum representation expected by the selected S3 API; test this using the AWS SDK and real staging service, not a local emulator alone.
3. At completion, resolve the session on the server, verify ownership, object version, actual byte count, media signature and checksum. Reject key substitutions, overwrite races and expired sessions. An S3 ETag is not treated as a SHA-256 checksum.
4. Scan for malware and active content; isolate PDF parsing with no network, read-only runtime and CPU/memory/time/page limits. Render previews only through a sanitized viewer. Do not execute embedded scripts or document instructions. Reject or quarantine encrypted/unsupported files rather than guessing their contents.
5. Preserve original source bytes and create versioned extracts. Use OCR only for image-only or failed text extraction, recording its use and review requirements. Stage private index rows with the current ACL revision; activate only after all checks.
6. Recheck authorization before every private retrieval or download. Short URL expiry narrows but does not eliminate bearer-link risk; for sensitive workspaces proxy downloads through the authorization service. Disable caching of private content at public edges.

Initial limits are configurable design defaults: PDF only, 50 MiB and 500 pages; no archive uploads. The actual limits must be tested for parser resilience and cost. Private retention values remain unset until the applicable policy is approved.

## 6. Idempotency, pagination and errors

Mutation endpoints require `Idempotency-Key` except explicitly documented operations with equivalent conditional semantics. Key scope is tenant + actor + operation. Save a canonical request hash: the same key/hash returns the same resource; the same key/different hash returns `409 IDEMPOTENCY_CONFLICT`. Concurrent duplicate requests must be tested. Retention/expiry of idempotency records must not make an old external effect run again silently.

Use opaque cursor pagination and stable sort keys. Never embed private search text or unprotected authorization context in cursors. Signed cursors bind tenant, workspace, filters and release; reject a cursor replayed across scopes. Set list result limits and document resource size caps. API problem responses include safe code, request ID and user-actionable message, with no internal SQL, bucket names, credentials or hidden resource existence.

Required product error codes include `TENANT_SELECTION_REQUIRED`, `WORKSPACE_ACCESS_DENIED`, `CORPUS_NOT_READY`, `SOURCE_RIGHTS_BLOCKED`, `SOURCE_UNAVAILABLE`, `TEMPORAL_SCOPE_UNRESOLVED`, `PROVIDER_ROUTE_UNAPPROVED`, `BUDGET_EXCEEDED`, `EMBEDDING_PROFILE_MISMATCH`, `CITATION_VERIFICATION_FAILED`, `UPLOAD_QUARANTINED`, `LEGAL_HOLD`, and `IDEMPOTENCY_CONFLICT`. Map semantic conditions consistently to 4xx/5xx; expected answer abstention is a successful product outcome, not automatically HTTP 500.

## 7. Source removal, deletion and exports

A takedown immediately blocks new retrieval, source viewing and model transmission and invalidates matching caches. For a published answer whose cited authority becomes restricted, hide the affected quotation/derived material as policy requires and show an availability notice; preserve an appropriately restricted audit record. Do not silently substitute a different authority into an old answer.

Private deletion initially revokes ordinary access, then evaluates retention requirements and legal holds before erasure. Track object versions, exact text, chunks, embeddings, checkpoints, provider-retained copies, cached responses, exported files and backup restoration controls. “Deleted from the active index” is not a completed erasure claim.

Exports are explicit user actions. Require approval when workspace policy demands it; recheck access both at job execution and download. Render structured answer fields using fixed templates. Escape HTML/Markdown and hyperlink targets; never execute model-authored template code. Include corpus release, date scope, source availability and legal-review state. A research memo is not an automatically filed legal document.
