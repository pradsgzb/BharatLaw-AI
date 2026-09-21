# BharatLaw AI — Implementation Architecture

**Version:** 1.0 • **Design date:** 2026-09-19  
**Status:** Implementation specification, not a deployed product or a legal-compliance certification.  
**Audience:** Engineering lead, Codex, Indian legal editors, security reviewer, product owner.

## 0. Executive decision

Build a **source-grounded Indian legal research application**, not a foundation model trained to memorize Indian law. The core is a versioned legal corpus, hybrid retrieval, evidence-linked answers, and an editorially reviewed legal relationship graph. Use a replaceable hosted generation model, a separately selected embedding model, and a separately selected reranker.

Start with a modular Python application and independently runnable ingestion/research workers. Do not begin with Kubernetes, autonomous multi-agent services, a graph database, or GPU training. The application must still support document lookup and keyword search when generation is unavailable.

**First end-to-end deliverable:** an approved Constitution edition and a curated set of constitutional Supreme Court decisions can be imported, searched, opened at their exact source passages, and used to answer a question with verified source identifiers. The answer must expose coverage gaps and distinguish sourced facts from analysis.

**Core product invariant:** a model may propose a legal assertion; only the application can resolve source identifiers, authorize access, determine whether evidence passes release checks, and publish an answer. A valid URL is not proof that a proposition is legally correct.

### 0.1 Assumptions and limits

These are planning decisions, not facts about the user's budget or team.

| Dimension | Initial decision |
|---|---|
| Audience | Authenticated lawyers, researchers, and law students; public educational access later |
| Initial language | English; preserve officially published Hindi alongside it when available |
| Initial scope | Constitution and a legal-editor-selected constitutional case set |
| V1 expansion | Selected Central Acts and subordinate instruments, then a defined Supreme Court date range |
| Later | High Courts by jurisdiction, state law, tribunals, Hindi retrieval, private matter workspaces |
| Deployment | Local development; AWS Mumbai (`ap-south-1`) primary deployment candidate |
| Data policy | Public-authority corpus and private tenant content are separate security domains |
| Model policy | Approved providers only; no training on customer material by default |
| Pilot scale | Engineering fixture: up to 100,000 public chunks, not an assertion of corpus completeness |
| Scale test | 1 million chunks before broad-corpus launch; measure real document and index sizes |
| Revenue | Subscription/usage entitlement hooks; payment provider integration deferred |

Private matter uploads remain disabled until their security, processor-contract, and retention gates pass. An India-only processing profile must fail closed when no approved in-country generation, embedding, or reranking route exists. Hosting the database in India alone does not establish India-only processing.

### 0.2 Explicit non-goals

No guaranteed legal advice, automatic court filing, outcome probabilities, limitation/deadline calculator, autonomous external communication, unrestricted internet browsing, or blanket “all Indian law is current” claim. No commercial headnotes/commentary ingestion without rights approval. No assumption that an official website offers a supported bulk API.

## 1. Verified source observations and open acquisition decisions

The legacy India Code address currently announces a migration to `indiacode.gov.in` [S01]. Do not hard-code the old host into business logic. The official eSCR search interface exposes a CAPTCHA [S02]; implement an approved import adapter and permission review rather than a CAPTCHA bypass. The Legislative Department PDF inspected for this design labels itself as a Constitution edition as on 1 May 2026 [S03]. Its edition date is metadata, not evidence that every provision is operative, or that no later instrument exists.

**Acquisition priority:** official Constitution editions; official legislative instruments and Gazette notifications; official judgments/orders. A consolidated statute, amendment instrument, commencement notification, corrigendum, and judicial decision affecting operation are distinct objects.

Create a source registry with separately approved permissions for: acquisition; storage; parsing; embedding/indexing; transmission to a model provider; excerpt display; full-document redistribution; and use in evaluation or training. “Publicly accessible” and “approved for all these uses” are different statuses. Capture terms URL, review date, terms hash when available, rights evidence, reviewer, attribution template, access method, rate limits, and an expiry/re-review date. Production acquisition is blocked while approval is pending.

**Do not infer permission from `robots.txt`.** Respect site terms, rate limits and technical controls. Do not discover undocumented endpoints and assume they are licensed bulk feeds. A human-obtained official PDF with a reviewed import manifest is an acceptable first acquisition route. Require legal review of copyright, database/editorial content rights, redactions, publication restrictions, and redistribution conditions.

Never use an earlier chat answer, invented legal example, or model-generated case summary as a primary authority. This package deliberately does not carry forward any unverified named case from prior discussion.

## 2. System structure

```text
Browser (Next.js / TypeScript)
        |
Regional HTTPS ingress + authentication + request limits
        |
FastAPI modular application
  |-- identity / tenants / workspaces / entitlements
  |-- legal catalog / document viewer / version comparison
  |-- retrieval gateway / query planning / authority policy
  |-- bounded research coordinator / publication gate
  |-- ingestion administration / legal-editor review
  |-- exports / deletion / audit / usage
        |
        +--> PostgreSQL: canonical records, permissions, jobs, graph, runs
        +--> OpenSearch: rebuildable public and private search projections
        +--> S3: source bytes, parse artifacts, exports, manifests
        +--> SQS: durable work notifications + separate DLQs
        +--> Approved model gateway: generate / embed / rerank

EventBridge -> approved acquisition worker -> quarantine -> parser workers
            -> editorial validation -> index worker -> release publisher
```

The API, research worker, parser worker and acquisition worker may share a repository and Python packages, but use different IAM roles, network permissions, resource limits and deployment services. Never give the LLM a database password, raw S3 access, AWS credentials, SQL execution, or arbitrary HTTP requests.

### 2.1 Repository that Codex must implement

```text
bharatlaw-ai/
  AGENTS.md
  apps/web/                       Next.js product UI
  apps/api/                       FastAPI routes and dependency wiring
  workers/acquisition/            reviewed source adapters only
  workers/ingestion/              scan, parse, segment, quality gates
  workers/indexer/                idempotent index projection
  workers/research/               bounded research state machine
  packages/domain/                typed contracts and legal identifiers
  packages/storage/               repositories and object-store adapters
  packages/retrieval/             query builder, fusion, reranker, policy
  packages/evidence/              spans, quotes, claim linking, verifier
  packages/providers/             LLM, embedding and reranking gateways
  packages/security/              authorization, sanitization, policy
  packages/evaluation/            fixtures and scored regression suites
  db/migrations/                  Alembic migrations
  infra/terraform/                modules and per-environment roots
  config/                         versioned policies, not credentials
  tests/{unit,integration,e2e,security,evaluation,load}/
  docs/{adrs,runbooks,api,legal-review}/
```

Use a supported Python release, FastAPI, Pydantic v2-compatible contracts, SQLAlchemy and Alembic; React/Next.js and TypeScript for the browser. At implementation, resolve supported security-patched versions, pin them in lockfiles, pin container digests, and commit a compatibility report. Do not use `latest` image tags or an undocumented mixture of OpenSearch plugin versions. The supplied mappings intentionally use a modest feature surface, not the newest optional neural-search feature.

## 3. Canonical database architecture

PostgreSQL is the source of truth. S3 holds immutable bytes and larger artifacts. OpenSearch is a projection that can be deleted and rebuilt. Start the citation graph as indexed relational edges. Add a graph engine only after measured traversal requirements justify a second database.

`db/reference_schema.sql` defines the reference tables and constraints. It is an implementation input, not a migration already executed against PostgreSQL. Codex must translate it into tested migrations, implement the cross-record publication validators documented here, and run integration tests using the actual chosen PostgreSQL version.

### 3.1 Public legal corpus

| Tables | Responsibility |
|---|---|
| `sources`, `source_policies` | Acquisition registry and use-specific permissions |
| `artifacts` | Exact bytes, SHA-256, object version, source locator, fetch metadata |
| `documents`, `document_identifiers` | Stable legal work/decision identity and citation aliases |
| `document_versions`, `extractions` | Published edition or corrected text; reproducible parsing |
| `courts`, `judicial_details`, `case_identifiers`, `opinions` | Court, bench, case numbers, separate opinions |
| `legal_units`, `unit_versions`, `source_spans` | Articles, sections, clauses, paragraphs, exact source anchors |
| `legal_events`, `event_targets`, `applicability_assertions` | Amendment/commencement/repeal events and reviewed temporal assertions |
| `chunks`, `embedding_profiles`, `chunk_embeddings` | Rebuildable retrieval pieces and model provenance |
| `citation_mentions`, `propositions`, `legal_nodes`, `legal_edges` | Citation resolution and evidence-backed relationships |
| `corpus_releases`, `release_members` | Immutable published corpus snapshots |
| `ingestion_jobs`, `job_attempts`, `outbox_events` | Reliable ingestion and publication work |
| `editorial_reviews`, `takedowns` | Human review and immediate serving restrictions |

**Identity rules:** a case name alone is not unique; a case number is not a judgment ID; one judicial matter can produce several orders and opinions. Preserve neutral citations and report citations as aliases with provenance. Resolve ambiguities rather than manufacturing a canonical citation. Provisions have stable IDs independent of their wording; renumbering creates a reviewed relationship rather than silently replacing the identifier.

### 3.2 Tenant application data

| Tables | Responsibility |
|---|---|
| `tenants`, `users`, `memberships` | Organization boundary and authenticated identity |
| `workspaces`, `workspace_members` | Matter-level access; includes a default personal research workspace |
| `private_documents`, `private_versions`, `private_spans`, `private_chunks` | Tenant-owned content, completely separate from public authority tables |
| `research_runs`, `run_events`, `run_evidence` | Frozen query plan, reproducible inputs, authorized evidence |
| `answers`, `answer_claims`, `claim_evidence`, `verification_checks` | Claim-level answer revisions and verification outcomes |
| `model_invocations`, `usage_ledger` | Provider audit metadata, tokens, costs and budget reservations |
| `feedback`, `export_jobs`, `deletion_requests`, `legal_holds` | Product workflow, correction and retention |
| `audit_events`, `idempotency_keys` | Security audit and idempotent writes |

All tenant-owned relationships use composite foreign keys including `tenant_id`; workspace-scoped relations also include `workspace_id`. The SQL includes tenant-level row security as defense in depth. Matter-level authorization must additionally be enforced by a centralized permission service in every API, worker, export, viewer and retrieval path. Do not mistake tenant-level RLS for full workspace ACL enforcement.

The runtime database role is not a table owner, superuser, or `BYPASSRLS` role. PostgreSQL documents that those roles can bypass ordinary RLS behavior [S07]. Use `FORCE ROW LEVEL SECURITY` on tenant tables, a separate migration role, parameterized SQL, and transaction-local tenant context derived from validated identity. Never accept a caller-supplied tenant context merely because it is syntactically a UUID.

### 3.3 Dates and legal applicability

Keep these distinct:

- enactment/assent/publication dates;
- provision-specific commencement and end of operation;
- decision date, correction date and publication date;
- event date relevant to the user's facts;
- date cutoff for authorities considered;
- when the platform learned or corrected an assertion.

Use **half-open date intervals** `[valid_from, valid_to)` and database transaction intervals `[recorded_from, recorded_to)`. The end date is excluded. Unknown commencement is `null` plus an explicit status, never an invented beginning of time.

An `applicability_assertion` identifies a provision text, territory, scoped conditions, valid interval, recorded interval, review status and documentary evidence. The exclusion constraint prevents overlapping approved assertions for the same unit and scope across both time dimensions; it does not solve substantive legal conflicts. For nontrivial conditions, the answer retrieves the source and asks for missing facts or review instead of executing model-written eligibility rules.

**Retrospective correction example, purely synthetic:** the platform initially records that wording B began on a certain date; later an official notification proves an earlier commencement. Preserve the earlier recorded assertion, close its transaction interval, and add the corrected assertion. Do not rewrite prior research runs. A release taken before the correction remains reproducible, subject to takedown/access restrictions.

Support two historical modes:

| Mode | Treatment |
|---|---|
| `contemporaneous` | Law date and authority cutoff reflect what was available at that historical time |
| `retrospective_analysis` | Research may use later interpretations of earlier events; later decisions are clearly identified |

A simple `decision_date <= event_date` filter is incorrect for retrospective legal analysis. Repealed law may still matter through savings/transitional provisions. A successor section is not automatically equivalent. Conditional commencement, territorial variation, prospectivity, savings, stays and judicial treatment remain separate evidence-backed records.

## 4. Document and evidence contracts

`contracts/legal_document.schema.json` is the exchange contract for a parsed public document. `contracts/research_request.schema.json` and `contracts/answer.schema.json` describe research input and final output. Reference examples are synthetic fixtures, not real law.

### 4.1 Three distinct representations

1. **Source artifact:** original PDF/HTML bytes, source URL, fetched time, SHA-256, content type and object version.
2. **Legal representation:** structural units and exact extracted text, original paragraph labels, opinion attribution, dates and evidence spans.
3. **Search representation:** retrieval chunk with heading path, keywords, embedding and denormalized filters.

An embedding chunk is not the authoritative quotation. Store the authoritative text separately; reconstruct quotes from approved source spans.

### 4.2 Units and anchors

Statutes: instrument -> part/chapter -> section/article -> subsection/clause -> proviso/explanation -> schedule/table. Judgments: decision -> opinion -> original numbered paragraph; retain separately labelled arguments, quoted prior decisions, headnotes and footnotes when detectable. A sentence in counsel's submissions is not automatically the court's holding.

An anchor includes `unit_version_id`, original paragraph label if present, 1-based PDF page index, printed page label if available, bounding boxes, and `[char_start, char_end)` in `exact_text` measured in Unicode code points. Browser code must translate code-point offsets to its string representation; JavaScript UTF-16 indices are not interchangeable. Bounding boxes are normalized `[x0,y0,x1,y1]` with an explicit top-left origin.

If the judgment has no official paragraph numbering, use page and excerpt anchors. Do not invent paragraph numbers and display them as judicial paragraph numbers. OCR corrections have their own revisions and review trail. Preserve source bytes and an alignment map for dehyphenation, normalization, ligatures and page layout.

### 4.3 Chunking policy

Start at 350–700 tokens, maximum 1,000 for ordinary chunks, adjusted after evaluation. These are tuning defaults, not legal-unit constraints. Preserve small complete sections and original paragraphs; split a long unit into several chunks with exact offsets. Include a parent context pointer. A proviso or exception must travel with its operative provision when constructing evidence context. A schedule table requires headers and associated notes, not detached cells.

Store `search_text` as heading plus local text; store `source_text` separately. Do not put an LLM-written summary into the authoritative field. Optional summaries and hypothetical query expansions are explicitly derivative, excluded from quotations and independently versioned.

## 5. Ingestion and publication pipeline

```text
DISCOVERED -> RIGHTS_APPROVED -> FETCHED -> SCANNED -> PARSED
   -> STRUCTURED -> VALIDATED -> REVIEWED -> EMBEDDED -> INDEXED
   -> RELEASE_PUBLISHED

Any stage -> RETRYABLE_FAILED / QUARANTINED / RIGHTS_BLOCKED
Published -> RESTRICTED / WITHDRAWN, with immediate serving denial
```

### 5.1 Acquisition

Adapters expose `discover(cursor)`, `fetch(reference)`, `normalize_metadata()` and `checkpoint()`. Source-specific implementation is configuration, not business logic. Use conditional GET, conservative per-host rate limits, bounded retries, checksums and content-type/magic-byte validation. Follow redirects only after rechecking the allowlist and resolved public IP range. Do not fetch loopback, link-local, RFC1918, IPv6 local, instance metadata or credentials endpoints.

Save the original before parsing. Detect bytes changing at an unchanged URL; create a new artifact version. Deduplicate byte-identical public documents while preserving multiple source locators. Never deduplicate private uploads across tenants in a way that reveals their presence.

### 5.2 Parsing and quality

Try native extraction first. OCR is a fallback for scanned or unusable pages, with a dedicated sandbox and language support chosen for the source. Do not OCR every document automatically. Use permissively licensed extraction libraries or obtain the required commercial license; include parser, OCR and model dependencies in the software bill of materials.

Check page count, text coverage, unexpected empty pages, reading order, duplicate headers, missing section labels, paragraph discontinuities, dates, negation words, provisos, footnotes, schedules and table continuity. Automatically quarantine corrupt or low-quality documents. Human review is mandatory for authoritative metadata uncertainty, important OCR ambiguities, unknown commencement and alleged adverse precedent treatment.

The parser runs without network access, arbitrary subprocess features or executable document content. Apply file, page, decompression, CPU, memory and time limits. In V1 accept PDF and UTF-8 text/HTML from approved sources; private uploads start with PDF only. Add DOCX only after its parser and external-relationship handling are hardened.

### 5.3 Reliability and idempotency

Use SQS Standard queues with idempotent consumers, not an “exactly once” assumption: SQS explicitly documents possible duplicate deliveries [S06]. PostgreSQL stores durable stage state. Commit canonical changes and an outbox event in one transaction; an outbox dispatcher publishes to SQS. A crash after publication may duplicate the message; the consumer uses a stable job/stage/input-hash key and database state to avoid duplicate effects.

Workers use leases, heartbeat/visibility extension, bounded attempts, exponential backoff with jitter and per-stage DLQs. Delete an SQS message only after durable completion. Provider timeouts may have incurred cost: record uncertain attempts rather than quietly double-invoking. Job retries are operational events, not duplicate legal documents.

### 5.4 Publication and corrections

Build a candidate release into new concrete OpenSearch indexes. Verify counts, checksums, sample anchors, embeddings, permissions and legal-review gates. Store the document set, chunk membership, model profile, parser profile, mapping hash, policy version and index names in an immutable release manifest. Refresh and test the index before publication. Advance the active release pointer transactionally and align discovery aliases; each research run uses concrete index names from its pinned release, not a mutable alias halfway through execution.

Reprocessing with a new parser does not erase old evidence. Legal corrections create new source/unit versions and invalidate dependent answer caches. A takedown must block viewer and retrieval access in the authorization layer immediately, even before asynchronous index deletion. Preserved history is not permission to keep serving restricted material.

### 5.5 Coverage and freshness

Record discovery attempt time, successful synchronization time, publication cutoff, last reviewed instrument, ingest lag, pending documents, blocked source count and unresolved gaps. A successful empty fetch is not proof that no new law exists. Display these per source/court/date-range, not as a single misleading “updated today” badge.

Proposed initial scheduling: approved judgment discovery every 6 hours, legislative/Gazette checks daily, weekly reconciliation and link checks. Actual cadence is subject to source permission and capacity. Stale or incomplete sources force a visible warning; for a current-law request with materially missing authority, return a partial answer or abstain.

## 6. OpenSearch architecture

### 6.1 Index families

| Family | Purpose |
|---|---|
| `bl-public-documents-<release>` | Case/instrument lookup, identifiers and metadata |
| `bl-public-chunks-<embedding-profile>-<release>` | Lexical and vector retrieval over published public evidence |
| `bl-private-chunks-<embedding-profile>-<generation>` | Private text, tenant/workspace filters and ACL revision |

Private and public indexes are never one wildcard read. No browser or model can submit OpenSearch DSL. The retrieval gateway compiles an allowlisted typed query. Deployment IAM and OpenSearch permissions separate indexing, public retrieval and private retrieval roles.

`opensearch/public_chunks.index.json`, `private_chunks.index.json` and `documents.index.json` contain concrete reference mappings. They use explicit fields and `dynamic: strict`. The embedding dimension is **1024 as a design fixture**, not a provider recommendation. Implement a startup check against the selected embedding profile; changing model or dimension requires a new index and evaluation, even when dimensions happen to match.

### 6.2 Field and analyzer decisions

Use exact keyword fields for source IDs, canonical identifiers, citations, instrument IDs, article/section keys, court, opinion type and language. Keep section identifiers such as `19(1)(a)` intact in a keyword field. Text uses a conservative standard/lowercase analyzer and a separate exact/raw representation; do not apply destructive stemming or stopword removal to quoted text or identifiers.

For Hindi, evaluate a separate language-aware analyzer and multilingual embedding profile before enabling it. Do not transliterate or replace authoritative Hindi with a machine translation. Store language and official/derived translation status independently.

Use Lucene HNSW vectors with cosine similarity for the initial mapping. OpenSearch documents that efficient filters inside a k-NN query are supported by Lucene and Faiss engines [S04]. This matters for privacy: a post-filter applied after broad candidate retrieval is not the intended ACL design.

### 6.3 Retrieval execution

Run lexical and vector queries in parallel through `_msearch`, applying the **same mandatory tenant/workspace, publication, language, scope and date constraints inside both branches**. Resolve exact legal identifiers first. Fuse ranks in application code using reciprocal-rank fusion, avoiding a dependency on a particular managed-service neural-search pipeline. Native hybrid search remains an optional evaluated implementation; OpenSearch documents normalization/rank-fusion pipeline variants [S05].

Initial defaults: exact lookup up to 10 documents; BM25 top 80 chunks; vector top 80; RRF constant 60; deduplicate by stable chunk ID; cap repeated chunks from the same document for diversity; rerank up to 80 fused candidates; select about 12–20 evidence passages within a 12,000-token evidence budget. Retrieve definitions, exceptions and relevant parent context without silently clipping them. If the required context exceeds the budget, narrow the query or return a qualified result.

RRF is `sum(1 / (60 + rank))` with 1-based ranks. It is not a legal-authority score. Candidate counts, fusion weights and budgets are configurable and must be evaluated on lawyer-annotated questions.

### 6.4 Index lifecycle and capacity

Start pilot public indexes with 1 primary shard and 1 replica on an appropriately replicated managed domain; local fixtures may use 0 replicas. Do not create an index per document or an unbounded index per small tenant. Measure shard storage, vector memory, recall and latency; increase shard count by rebuilding a new release, not by guessing at production size.

Index vectors with recorded profile IDs and preserve reconstructable embedding artifacts or a reproducible regeneration manifest. Keep vector fields out of ordinary search responses. Bulk indexing checks every item for errors; an HTTP 200 batch response is not proof every item succeeded. Do not count an index write as visible until the relevant refresh/publication step succeeds.

For private ACL changes, increment a workspace permission revision and block stale results at the retrieval gateway until the index converges. Reauthorize every selected passage before sending it to a model and every citation before serving an answer. Revocation cannot retract data already legitimately transmitted; minimize what is transmitted and define cancellation/race behavior explicitly.

## 7. Legal retrieval and RAG

```text
Authenticate -> authorize workspace -> validate request -> reserve budget
 -> resolve legal identifiers / ask for material missing facts
 -> pin corpus release + model/policy versions + authority cutoff
 -> lexical + vector retrieval -> rank fusion -> rerank
 -> add relevant definitions / exceptions / citation-neighbor evidence
 -> assess authority metadata and possible conflicts
 -> build immutable evidence set -> generate structured claims
 -> citation/quote checks -> claim-support checks -> publication gate
 -> publish answer OR partial result OR abstention
```

### 7.1 Query plan

Store language, research mode, user facts, unresolved factual assumptions, jurisdiction, relevant event date, law-as-of date, authority cutoff, exact identifiers, search variants, corpus release and source restrictions. Do not silently infer the state, court, applicable statutory regime or procedural stage when it changes the result. A clarification response is a valid result, not a failed agent run.

For vague educational questions, proceed with explicit nationwide/general assumptions. For fact-sensitive queries, ask a concise missing-facts question and avoid a false definitive conclusion.

### 7.2 Authority policy, not a weighted shortcut

Article 141 identifies the binding force of law declared by the Supreme Court [S03]. That does not mean every sentence in every decision is a binding holding. Preserve court, bench size, opinion authorship, concurrence/dissent, relevant legal question, procedural disposition and later treatment. Do not infer overruling from recency, citation count or an LLM's confidence.

Apply scope constraints and **flag potential controlling authority**, subject to legal editorial review. A later smaller-bench decision does not receive automatic precedence merely for being newer. A stay, review filing, referral, non-speaking disposition, distinguished factual situation, or partial overruling needs its own type and explanatory evidence. Conflicting authorities remain visible; do not hide adverse authority to improve answer fluency.

No boolean “good law” badge unless a deliberately defined, adequately reviewed citator service supports that exact representation. Default language: “No adverse treatment located in the covered corpus through [cutoff]; this is not a comprehensive citator check.”

### 7.3 Evidence and answer generation

Assign short run-local evidence handles (`E1`, `E2`, ...) to server-resolved spans. The model sees source titles, dates, opinion labels, structured scope metadata and source text. It can cite only those handles. It cannot generate display citation strings, source URLs or pinpoint paragraph numbers as authoritative metadata; the renderer obtains those from the database.

Require a typed draft with `direct_response`, issue sections, claims, supporting/contrary evidence handles, explicit assumptions and limitations. Derived analysis is labelled as analysis. Claims unsupported by evidence cannot be reclassified as “analysis” merely to avoid the gate.

Three verification layers:

1. **Deterministic integrity:** handle belongs to this run, source is available and authorized, version hash matches, quote is an exact permitted span, all cited locators resolve.
2. **Semantic support:** does the cited passage support the claim, concern the right provision, distinguish an argument from a holding, and preserve exceptions? Use an independent evaluation pass and lawyer-reviewed regression tests. This is fallible, not a proof.
3. **Legal review:** high-impact outputs, disputed interpretation, new treatment labels, uncertain chronology and release sampling. Require professional review before a user relies on a memo for filing or legal action.

Limit repair to one pass. On failure, remove unsupported claims and return a qualified partial answer or abstention. **Never stream unverified answer text.** SSE may show progress, authorized sources and the final checked answer, not raw generation tokens. A status message such as “checking evidence” must not imply substantive legal correctness has been established.

### 7.4 Caches and reproducibility

Cache keys include tenant, user/permission fingerprint, workspace ACL revision, query hash, mode/dates, corpus release, embedding/reranker/generator versions, prompt hash and policy version. Never share answer or query-embedding caches across tenants by default; questions themselves may be confidential. Cache hits still undergo current authorization, takedown and expiry checks.

A run records its selected evidence, candidate IDs, ranks, policy decisions, provider metadata, schema validation and final claim links. Record operational steps and concise evidence-based explanations, not private model chain-of-thought. Re-running a model may not reproduce identical prose; the evidence and published artifact must be reproducible.

## 8. Citation graph

Use `legal_nodes` for documents, provisions and reviewed propositions. An edge contains source/target IDs, relation type, evidence span, scope, opinion ID, decision date, extraction method, review state, reviewer and recorded timestamp. Keep raw citation mentions, ambiguous candidates and resolution decisions even when no target can be resolved.

Supported relations: `cites`, `interprets`, `applies`, `follows`, `distinguishes`, `overrules`, `partially_overrules`, `affirms`, `reverses`, `refers_to_larger_bench`, `amends`, `commences`, `repeals`, `renumbers`, `corresponds_to`, `stays_operation`.

A bare citation permits `cites`; it does not permit `follows`. `Overrules` must be scoped to the proposition or part affected where necessary and supported by reviewed text. An allegation by counsel is not judicial treatment. Machine-extracted adverse-treatment candidates go to an editorial queue and cannot publish a definitive badge.

Initial graph retrieval is one hop outward for cited sources and one hop inward for subsequent treatment, filtered by authority cutoff and source permission; cap each expansion at 20 candidates and deduplicate before reranking. Two-hop traversal is optional only with explicit budgets. PageRank may aid discovery but never establishes legal authority. Do not promise complete subsequent-treatment coverage when the source range is incomplete.

## 9. Agent/workflow design

Use **one bounded research workflow with seven logical stages**, not seven independently deployed autonomous agents.

| Stage | Model use | Permitted capabilities |
|---|---|---|
| Intake/planner | Optional small model | Parse query into validated plan; request clarification |
| Legislation researcher | Search + optional model | Read statutory sources and relevant version evidence |
| Case-law researcher | Search + optional model | Read judicial sources with opinion attribution |
| Contrary-authority researcher | Optional second search branch | Find limiting or adverse evidence without assuming it exists |
| Synthesizer | Strong generation model | Draft claims using supplied evidence handles only |
| Evidence verifier | Code plus independent semantic pass | Integrity checks; assess support and omissions |
| Publisher | Deterministic code | Reauthorize, enforce gates, publish/abstain/escalate |

Begin with a typed Python state machine and PostgreSQL checkpoints. LangGraph may be used for the same workflow when it improves resumability and human review; its persistence/checkpoint model is documented by its maintainers [S10]. Persist only reviewed state contracts and avoid a second competing source of job truth.

Tools: `search_statutes`, `search_cases`, `get_unit`, `get_source_span`, `get_version_history`, `get_citing_decisions`, `get_treatment_evidence`, `request_clarification`. Every tool is schema-validated, read-only, permission-scoped and metered. The model never selects its tenant or overrides its authority cutoff through tool arguments.

Initial limits: 3 search variants per issue; 2 parallel search workers; 8 retrieval/tool calls; 1 graph expansion stage; 1 repair; 60-second quick-research deadline and 120-second deep-research ceiling; per-run token and currency budget. These are configurable product limits, not measured performance. Cancellation is cooperative with durable state; stop issuing new calls, record already incurred cost and never publish an unfinished draft.

No shell, Python execution, raw SQL, web fetch, email, court filing, payment, document deletion or source-policy write tool in the research workflow. Human approval for exports containing private material, editorial release, legal treatment approval and retention-policy changes must be checked server-side.

## 10. API and UI contract

`contracts/openapi.yaml` is the reference HTTP contract for the main vertical slice and security-critical workflows. `docs/API_AND_WORKFLOWS.md` specifies endpoint behavior, errors, idempotency and UI actions. Codex must generate its runtime OpenAPI from the same typed models and test contract parity.

All protected endpoints authenticate bearer tokens or a same-site, secure HttpOnly browser session through a backend-for-frontend. Validate issuer, audience, signature algorithm, expiration and scopes. Browsers do not store long-lived tokens in localStorage. Derive tenant membership server-side; a tenant route parameter only selects among authorized tenants.

Main screens: research workspace; search results; source viewer with passage highlights; provision version comparison; evidence/limitations panel; saved research; optional private matter documents; legal-editor review queue; source coverage/ingestion console; organization access/retention controls. Show extraction/OCR status and original source access. Exports retain all citations, source edition/cutoff, coverage notice and whether a lawyer reviewed the output.

Research creation returns `202 Accepted` with run ID. `GET /research/runs/{id}` returns durable state; `/events` provides authenticated SSE with monotonic event IDs and resumable cursors. Polling remains supported. Repeat `Idempotency-Key` with the same payload returns the original resource; a different payload is a conflict. Failed or unauthorized IDs do not expose another tenant's existence.

## 11. AWS infrastructure and operations

### 11.1 Environment design

Separate AWS accounts for development, staging and production, with distinct KMS keys, secrets and datasets. Use Terraform modules and an encrypted remote state bucket with access controls and state locking appropriate to the pinned Terraform version. Deployment is approval-gated; design approval does not authorize spending, production mutation or destructive teardown.

| Component | Initial production design |
|---|---|
| Ingress | Route 53, ACM, regional ALB, AWS WAF; authenticated application served regionally |
| Static assets | Optional CloudFront only for public static assets; no private document/query caching |
| Compute | ECS Fargate services for API/web and separate research/index/parse workers |
| Relational | RDS PostgreSQL Multi-AZ, private subnets, backups and PITR |
| Search | Managed OpenSearch VPC domain; encrypted, fine-grained access; measured multi-AZ sizing |
| Objects | Separate S3 public-corpus, quarantine, private-content and audit/export buckets/prefix domains |
| Messaging | SQS per workload, individual DLQs, EventBridge schedules |
| Models | Approved Bedrock regional endpoint or reviewed external gateway route |
| Secrets | Secrets Manager + task roles; no static credentials in images or browser bundles |
| Audit | CloudTrail, CloudWatch and encrypted security archives; payload-safe application logs |
| CI/CD | GitHub Actions with OIDC to AWS, ECR images, test-gated staging and approved production |

Use three AZs where supported for the VPC. RDS Multi-AZ and search topology are separately configured, not assumed from subnet count. A launch search profile can use three data nodes and three dedicated manager/master nodes subject to the selected instance types and load test; a cheaper one-node development profile is explicitly non-HA. Minimum two API tasks across AZs; autoscale workers from queue age/backlog and provider quotas, not CPU alone.

AWS documents VPC-scoped OpenSearch domains [S08]. Use no public OpenSearch/RDS endpoints. Separate security groups and roles for public search, private search, acquisition and indexing. Add S3 gateway endpoints and appropriate private service endpoints, but compare interface-endpoint and NAT cost instead of deploying every endpoint automatically. Acquisition needs controlled outbound access; parser containers do not.

### 11.2 Model region control

Approve generation, embedding, reranking, OCR, tracing and support-access routes separately. Bedrock cross-Region inference can route across geographic or global regions [S09]; APAC is not synonymous with India. An India-only policy must validate the actual permitted destination set and deny incompatible inference profiles. A provider failover cannot silently weaken privacy or residency requirements.

Public corpus processing may use a different approved profile from private cases. Maintain a provider register: model ID/version, contract basis, allowed data classifications, processing geography, retention/training settings, subprocessors, budget rates, and outage behavior. Model IDs and current prices are supplied through verified deployment configuration, not fictional constants in this specification.

### 11.3 Backup and recovery

Proposed goals after validation: production availability 99.9%; metadata RPO 15 minutes; service restoration RTO 4 hours, with search recovery separately measured. These are targets, not current guarantees. Configure point-in-time recovery and encrypted snapshots; test restores into isolated infrastructure before launch. Preserve release manifests and S3 versions for authorized public sources. Treat OpenSearch as rebuildable, but take tested snapshots for faster recovery.

A full large-corpus reindex may exceed the RTO. Support degraded catalog/keyword mode against a restored release or warm recovery index rather than claiming instant full semantic service. If another Indian region is approved for disaster recovery, replicate only after service, contract and security review. Multi-AZ is not cross-region disaster recovery.

Maintain a deletion/takedown ledger outside ordinary replay paths. After restoring backups, replay restrictions and deletions before reopening service. Legal holds and statutory retention may defer physical deletion while immediate access removal remains necessary.

### 11.4 Performance, observability and cost

Proposed pilot acceptance workload: 100,000 chunks, 10 concurrent researchers, declared source sizes and exact model profile. Measure p50/p95/p99 retrieval, reranking, provider, verification and overall latency. Target p95 search under 3 seconds and quick-research completion under 60 seconds on the agreed fixture; failures require optimization or a revised approved SLO, not a misleading green test.

Metrics: retrieval recall, unsupported claims, citation integrity failures, temporal mismatches, permission denials/leaks, model retries, queue age, source lag, indexing failure rate, budget overruns, stale cache hits, legal review backlog and deletion completion.

Cost model: fixed compute/search/database/network baseline + storage/backups + per-document extraction/embedding + per-query embedding/reranking/generation + logging/egress. Calculate from measured tokens and current region-specific unit prices. Record token usage and reserved/actual spend per tenant/run; include uncertain timeout charges. Enforce concurrency, tokens, graph depth and daily spending caps. Do not promise free production hosting or provide an unsupported flat monthly bill.

## 12. Security, privacy and legal operational controls

### 12.1 Trust boundaries

External documents, source HTML, uploads, OCR output and model responses are untrusted. OWASP identifies indirect prompt injection through files/web content and recommends limiting privileges and separating untrusted content [S11]. Prompts are not the security boundary. Use deterministic authorization, typed tools, network restrictions, output sanitization and release checks.

Threat cases include cross-tenant vector retrieval, object-ID guessing, stale ACL cache, malicious PDF, search-query abuse, model-driven SSRF, poisoned legal content, fabricated quotations, source withdrawal, stored XSS in model markdown, exposed signed URLs, prompt leakage, token exhaustion and restored deleted data.

Render markdown through a strict sanitizer; block remote images, executable HTML, script URLs and automatic external fetches. Only server-resolved citations may become authority links. Short-lived presigned downloads require fresh permission checks and must not be logged with query credentials. Disable public sharing of private cases in V1.

### 12.2 Privacy and retention are policy, not a checkbox

The DPDP Rules notification inspected for this design explicitly uses phased commencement [S12]. Rules addressing logs, retention and breach reporting have specific text and timing; do not copy a universal “delete everything after 30 days” or “all incidents use a 72-hour clock” into code. Maintain a **counsel-approved obligation register** with legal entity/role, data class, purpose, applicability, effective date, retention minimum/maximum, legal hold precedence, reporting trigger/deadline, reviewer and source evidence.

Implement configurable notices, consent/lawful-processing records as applicable, data minimization, purpose controls, processor agreements, access/correction/deletion requests, and incident workflows. Counsel must assess the current DPDP Act/rules/notifications, applicable IT/CERT-In obligations, professional confidentiality, publication restrictions and source licensing before public or private-data launch. The CERT-In primary PDFs could not be fetched during this design review; their exact current applicability/timing is a **documented launch verification task**, not a certified finding here.

Immediate logical access withdrawal and later legally permitted physical erasure are separate states. Deletion must cover raw files, all object versions as permitted, extracted text, embeddings, search projections, caches, exports, checkpoints and provider-held content subject to contract. Do not promise provider deletion capabilities that have not been contractually verified. Use tightly restricted retention storage for legitimately retained records; do not leave them available to normal search.

Retain operational security logs according to the approved register but avoid unnecessary question text, evidence text, names, credentials and model responses in logs. Separate security metadata from user content. Put immutable audit archives on a different policy from erasable customer files; do not indiscriminately apply S3 Object Lock to all uploads.

### 12.3 Roles and approval separation

Roles: tenant owner, workspace manager, researcher, viewer, legal editor, source administrator, security administrator, auditor and service identities. Legal-editor role does not automatically grant access to every private workspace. Source administrators approve connectors; legal editors approve legal metadata/treatment; security administrators approve processing policy. Production content release and sensitive policy changes require a second reviewer.

The system does not claim to be an advocate, establish a lawyer-client relationship automatically, or replace qualified review. Distinguish general research from advice for a specific matter. A disclaimer is supplementary; it does not compensate for unsupported answers or insecure processing.

## 13. Evaluation and acceptance gates

Maintain separate development, validation and held-out questions with source/issue-family separation; prevent near-duplicate cases and paraphrased questions leaking into the held-out set. Start with 100 lawyer-annotated constitutional questions, expand to at least 500 before broad V1 release, and report results by jurisdiction, date mode, issue, language and extraction quality. Include direct lookup, synthesis, ambiguity, missing sources, fabricated citation input and contrary authority.

| Gate | Required result on declared test set |
|---|---|
| Citation IDs and anchors | 100% of published citations resolve to allowed evidence in that run |
| Quoted text | 100% matches approved source spans; no quote repair by guessing |
| Tenant/workspace isolation | Zero unauthorized passages or identifiers in output, prompts, logs or exports |
| Retrieval | Proposed Recall@20 >= 0.90 against lawyer-defined relevant authorities |
| Semantic support | Proposed >= 95% of substantive claims supported on independent review |
| Temporal/jurisdiction critical cases | Zero known critical failures in the release suite |
| Contrary authority | Proposed >= 90% recall on annotated known adverse-authority test cases |
| Abstention | Returns insufficient/partial/clarification for all critical insufficient-evidence fixtures |
| Recovery | Duplicate jobs safe; worker interruption safe; restore and deletion replay demonstrated |
| Security | No unresolved critical/high vulnerability for production launch |

These metrics have denominators, sample size and confidence intervals where suitable. Passing does not prove legal correctness on all unseen questions. No blanket zero-hallucination marketing claim. A 100% deterministic gate is enforced on each served answer; a semantic judge's pass is not equivalent to legal review.

Use failure severity: critical (cross-tenant leak, invented authority, wrong operative law causing a materially misleading answer); major (misstated holding, missing important adverse evidence); minor (formatting). Critical failures block release even when averages look good. Freeze a gold set; changes require reviewer rationale and versioning.

## 14. Phased implementation and exit gates

See `docs/IMPLEMENTATION_PLAN.md` for ticket-level tasks and Codex deliverables. Indicative effort assumes two backend/AI engineers, one frontend engineer and scheduled legal/security reviewers. A private beta may take roughly 12–18 calendar weeks if acquisition and reviews are available; coverage expansion can take longer. This is a planning estimate, not a delivery commitment.

| Phase | Deliverable | Exit gate |
|---|---|---|
| 0 | ADRs, threat model, rights/source approvals, dependency matrix, fixtures | No invented bulk APIs; scope and data routes approved |
| 1 | Authenticated skeleton, migrations, object store, jobs and local CI | Tenant isolation and idempotent job tests pass |
| 2 | Approved corpus ingestion, source viewer, lexical lookup | Exact anchors, source traceability and quality gates pass |
| 3 | Hybrid retrieval, reranking, evaluation harness | Recall and ACL tests pass with declared baseline |
| 4 | Structured RAG, citation/quote gates, version-date logic | Unsupported/fake citation and historical tests pass |
| 5 | Reviewed treatment graph, contrary-authority workflow, resumable research | Bounded execution, review and conflict tests pass |
| 6 | AWS staging, monitoring, backup/restore, adversarial and load tests | Legal/security/cost/operational sign-off |
| 7 | Private workspaces, deletion, exports; optional Hindi after separate gate | Cross-tenant, retention and processor-policy tests pass |

Do not block basic source lookup on fine-tuning. Consider tuning the reranker or query classifier only after error analysis shows a clear gap and approved labelled data exist. Never train on private matter content by default. Track model weights/data rights separately from corpus retrieval rights.

## 15. Definition of done for Codex

A feature is done only when it has implemented behavior, contract tests, error paths, security tests, configuration documentation and evidence of actual execution. No mocked LLM response counted as real-model evaluation. No disabled auth in production. No fake “current” corpus flag. No empty adapters reported as implemented.

Codex must publish a completion report identifying implemented, tested, blocked, untested and deferred items; commands and outputs; dependency versions; actual source coverage; costs incurred; and remaining legal/provider approvals. It must never fabricate a passing test, a deployed URL, an AWS bill, a permission approval or a legal review.

This specification can guide the whole build. Production launch still requires real source acquisition, legal editorial decisions, actual infrastructure tests and explicit deployment authorization.

## 16. Cross-contract implementation clarifications

The release manifest freezes **unit versions, source-policy decisions, citation-resolution snapshots, temporal-assertion snapshots and treatment-edge snapshots**, not only chunk IDs. The corresponding `release_*` tables support lookups. Store canonical serialized snapshots and their hashes in the immutable manifest. Closing a bitemporal knowledge interval must not retroactively change a previously released assertion snapshot. All hashes over structured data must use a named, versioned canonical serialization profile; ordinary JSON object serialization order is not a hashing contract.

The index is a relevance projection. The canonical temporal resolver selects provision versions using reviewed applicability snapshots, the requested legal date, territorial/conditional scope and the research mode. A broad index date filter must never accidentally eliminate a later-published consolidation that reproduces earlier operative wording. Conversely, a publication date alone must never establish commencement. Retrieval may discover unresolved material, but unresolved material cannot support an unqualified current-law statement.

`is_synthetic` and `synthetic_fixture` exist only to exercise local tests. Production release validation rejects every synthetic document, fixture-only extraction and unapproved source. Reference mapping dimensions are placeholders, not the identification of a real embedding model. SQL migrations, privileges, temporal SQL behavior and actual OpenSearch filtering require service-backed integration tests.

OpenSearch’s stored source content is never the canonical authority for quotes. Fetch exact text from PostgreSQL, compare it against the selected immutable release and source artifact lineage, then construct citations. The reference verifier demonstrates these checks for a supplied evidence object; the production repository must independently supply the authoritative text, hashes, current rights and current authorization.

The API carries a tenant selector only as a request to select an organization. Authentication and active membership determine whether that selection is permitted. Use transaction-local RLS settings plus explicit workspace authorization, including background jobs, source viewing, exports, run events and final answer publication. A user-provided tenant or workspace ID never grants access.

See `API_AND_WORKFLOWS.md`, `SECURITY_AND_OPERATIONS.md`, `IMPLEMENTATION_PLAN.md` and the root `CODEX_START_HERE.md` for implementation detail. The reference Python modules and tests are a small executable illustration of critical invariants, not a complete backend.

## References

Sources below informed specific factual/platform observations. Architectural choices and numeric thresholds are proposed design decisions. Official-source facts and service capabilities must be rechecked during implementation.

[S01] India Code migration notice: https://www.indiacode.nic.in/ ; current destination https://indiacode.gov.in/ .

[S02] Supreme Court Reports search interface: https://scr.sci.gov.in/scrsearch/ .

[S03] Legislative Department, Constitution PDF inspected, edition as on 1 May 2026; Article 141: https://www.legislative.gov.in/static/uploads/2025/07/88cca69e868e50b217f855be2fb8bdba.pdf . A URL path date is not its current content/version date.

[S04] OpenSearch k-NN query and filtering: https://docs.opensearch.org/latest/query-dsl/specialized/k-nn/index/ .

[S05] OpenSearch hybrid search: https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/ ; AWS supported operations: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-operations.html .

[S06] SQS at-least-once delivery: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html .

[S07] PostgreSQL row security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html .

[S08] AWS OpenSearch VPC domains: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/vpc.html .

[S09] Bedrock cross-Region inference: https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html .

[S10] LangGraph persistence: https://docs.langchain.com/oss/python/langgraph/persistence .

[S11] OWASP LLM01 prompt injection: https://genai.owasp.org/llmrisk/llm01-prompt-injection/ .

[S12] MeitY DPDP Rules notification, including rule 1 commencement and rules 6–8: https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf . Recheck corrigenda, later notifications and applicability with Indian counsel.

[S13] OpenAI AGENTS.md instructions documentation: https://developers.openai.com/codex/guides/agents-md .
