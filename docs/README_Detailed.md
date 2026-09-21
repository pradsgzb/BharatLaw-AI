## BharatLaw AI: architecture and Codex implementation handoff

I have prepared the architecture as a **downloadable engineering package**, including database definitions, machine-readable contracts, reference algorithms, tests, security controls, and a phased Codex implementation prompt.

**[Download the complete BharatLaw AI Codex handoff](sandbox:/mnt/data/BharatLaw_AI_Codex_Handoff.zip)**

[Read the architecture specification](sandbox:/mnt/data/BharatLaw_AI_Architecture.md) · [Read the Codex implementation prompt](sandbox:/mnt/data/BharatLaw_AI_Codex_Start_Here.md) · [Read the validation report](sandbox:/mnt/data/BharatLaw_AI_Validation_Report.md)

The package contains **34 files**, including a **60-table PostgreSQL reference schema**, an **OpenAPI contract with 45 operations**, three OpenSearch mappings, strict document/answer schemas, and **107 passing reference and contract tests**.

**Important distinction:** this is an implementation specification with tested reference components—not a completed application. PostgreSQL execution, OpenSearch integration, AWS deployment, live-model evaluation, and lawyer-reviewed legal accuracy testing remain implementation gates.

# 1. Architectural decision

Build BharatLaw as a **source-grounded legal research platform**, not a model trained to memorize Indian law.

The proposed architecture is:

```text
                     Next.js / TypeScript
                     Research UI + Source Viewer
                                |
                       Authentication + API
                                |
                    FastAPI Modular Application
                                |
       ┌────────────────────────┼──────────────────────────┐
       |                        |                          |
 Legal Catalog           Research Coordinator        Administration
 Versions / Sources      Retrieval / Verification    Reviews / Coverage
       |                        |                          |
       └────────────────────────┼──────────────────────────┘
                                |
        ┌───────────────────────┼──────────────────────────┐
        |                       |                          |
    PostgreSQL              OpenSearch                    S3
 Canonical records       Search projections          Original documents
 Temporal assertions     BM25 + vectors              Extracts / manifests
 Citation graph          Public/private indexes     Restricted exports
 Permissions / runs
        |
 Transactional Outbox → SQS → Ingestion / Research / Indexing Workers
                                |
                      Approved Model Gateway
                  Generation / Embeddings / Reranking
```

**PostgreSQL is the source of truth. OpenSearch is a rebuildable search projection. The LLM is a replaceable component.**

Start with a modular application and separately runnable workers. Do not begin with Kubernetes, multiple autonomous agent services, a separate graph database, or GPU training.

### Initial product scope

The first release should cover an approved Constitution edition and a curated constitutional Supreme Court case collection. Expand to selected Central Acts and subordinate instruments, then a defined Supreme Court date range.

English is the initial interface language. Hindi retrieval, broader courts, state legislation, and private matter workspaces follow separate quality and security gates.

This deliberately avoids an unsupported claim that the first release covers “all Indian law.”

# 2. Database schema

The reference DDL separates the corpus, legal interpretation, search projections, and application activity.

| Domain               | Principal tables                                                        | Purpose                                                                     |
| -------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Source provenance    | `sources`, `source_policies`, `artifacts`                               | Origin, original bytes, permissions, acquisition history                    |
| Legal documents      | `documents`, `document_identifiers`, `document_versions`, `extractions` | Stable document identity and versioned representations                      |
| Legal structure      | `legal_units`, `unit_versions`, `source_spans`                          | Articles, sections, clauses, paragraphs, exact quotations                   |
| Judicial metadata    | `courts`, `judicial_details`, `case_identifiers`, `opinions`            | Court, proceedings, bench information, separate opinions                    |
| Legal chronology     | `legal_events`, `event_targets`, `applicability_assertions`             | Amendments, commencement, repeal, territorial and conditional applicability |
| Citation graph       | `citation_mentions`, `propositions`, `legal_nodes`, `legal_edges`       | Resolved citations and evidence-backed legal relationships                  |
| Corpus publication   | `corpus_releases`, `release_members`, other `release_*` tables          | Immutable, reproducible corpus snapshots                                    |
| Application/security | Tenant, workspace, research, answer, audit, usage and deletion tables   | Access control, workflow state, traceability and operations                 |

The 60-table design describes the target platform. Codex should implement the necessary subset for each phase—not all business workflows simultaneously.

### Stable identity versus changing text

A provision’s identity must survive amendments:

```text
Legal document
    └── Stable section/article identity
          ├── Text version A
          ├── Text version B
          └── Text version C
```

A judgment’s case number, individual decision, separate opinion, and paragraph are also distinct concepts. They should not be collapsed into one unstructured document record.

### Two kinds of time

The schema uses **bitemporal records**:

| Time dimension           | Meaning                                                     |
| ------------------------ | ----------------------------------------------------------- |
| Legal applicability time | When an approved assertion says a provision/version applied |
| Platform knowledge time  | When BharatLaw recorded that assertion                      |

This supports both:

> “What law applied on the relevant date?”

and:

> “What evidence and version information did BharatLaw use when it produced this answer?”

Unknown commencement dates remain unknown. A publication date does not automatically become an effective date.

### Immutable corpus releases

Every research run pins a release containing the selected document/unit versions, index names, source-policy decisions, and snapshots of temporal assertions and citation relationships.

A later corpus update must not silently change the evidence behind an earlier answer. Current restrictions and takedowns still override access to historical material.

# 3. Document schema and source anchoring

The document contract preserves three separate layers:

```text
Original PDF / HTML
        ↓
Canonical legal units and exact text
        ↓
Search chunks and embedding inputs
```

**Search text is not quotation text.**

A chunk may contain added headings or retrieval context. Quotations must come from the canonical source span, not an LLM summary or a modified search representation.

Each legal unit records its structural position, language, role, source lineage, and text hash. Each cited span records:

```text
unit_version_id
char_start
char_end
quote_sha256
pdf_page_number
printed_page_label
bounding_box
original_paragraph_label, when present
```

Offsets use Unicode code points with half-open intervals: `[start, end)`. Browser highlighting must account for JavaScript’s different string indexing behavior.

When an original judgment lacks numbered paragraphs, the system must cite the page and excerpt rather than manufacture paragraph numbers.

For judicial material, the schema distinguishes majority, concurrence, dissent, and unknown opinion attribution, together with court reasoning, party arguments, quoted authorities, and headnotes. These labels prevent a retrieved passage from being treated automatically as the court’s holding.

# 4. Ingestion pipeline

The proposed pipeline is:

```text
Approved source / manual import
        ↓
Source-rights and acquisition check
        ↓
Original artifact → checksum → quarantine
        ↓
File validation / malware screening
        ↓
Text extraction; OCR only where needed
        ↓
Legal structure and metadata extraction
        ↓
Citation / chronology candidates
        ↓
Editorial validation and approval
        ↓
Legal-unit-aware chunking
        ↓
Approved embeddings
        ↓
Candidate OpenSearch indexes
        ↓
Integrity, retrieval and permission tests
        ↓
Published corpus release
```

### Source access must be configurable

Two verified source observations affect implementation: the legacy India Code site now announces migration to `indiacode.gov.in`, and the eSCR search interface includes CAPTCHA. Therefore, the source adapters must support reviewed manual imports or approved feeds rather than assume stable, unrestricted bulk APIs. ([India Code][1])

The source register separately controls permission to acquire, store, index, transmit to model providers, display excerpts, redistribute documents, and use material for training or evaluation.

Pending permission means the relevant operation remains blocked.

### Reliable background processing

Use PostgreSQL job state, transactionally recorded outbox events, SQS notifications, worker leases, bounded retries, and dead-letter queues.

SQS Standard can deliver a message more than once, so workers must be idempotent. A duplicate message must not create duplicate document versions, repeated external actions, or uncontrolled model charges. ([AWS Documentation][2])

The ingestion specification also covers partial failures, changed source bytes, parser revisions, source-format changes, index rebuilds, and rollback.

# 5. OpenSearch design

The package supplies three mappings:

| Index family             | Content                                                                |
| ------------------------ | ---------------------------------------------------------------------- |
| Public document catalog  | Titles, canonical identifiers, court/date metadata                     |
| Public legal chunks      | Approved legal text, headings, citations, vectors and scope metadata   |
| Private workspace chunks | Tenant/workspace-scoped uploaded material, enabled only after approval |

Use concrete, versioned index names. Research runs should not depend on an alias that can change halfway through retrieval.

### Retrieval configuration

The initial design uses:

```text
Exact identifier lookup
        +
BM25 lexical retrieval
        +
Vector retrieval
        ↓
Application-side reciprocal rank fusion
        ↓
Reranking
        ↓
Context expansion and canonical verification
```

Proposed starting parameters are 80 lexical candidates, 80 vector candidates, RRF constant 60, reranking of up to 80 merged candidates, and approximately 12–20 evidence passages within a controlled context budget. These are tuning defaults, not measured optimal settings.

The reference vector mapping uses Lucene HNSW with cosine similarity. OpenSearch documents support for filters inside k-NN queries with the Lucene and Faiss engines. The architecture uses those inner filters rather than relying solely on filtering results after retrieval. ([OpenSearch Documentation][3])

For private search, both retrieval branches must enforce:

```text
tenant_id
workspace_id
current ACL revision
active document state
approved embedding profile
```

The supplied dimension of `1024` is a reference parameter—not a chosen production model. The actual embedding provider, revision, dimensions, preprocessing, and processing region must be approved and tested before indexing.

# 6. RAG and answer verification

The research pipeline is:

```text
Authenticate and authorize
        ↓
Resolve question, jurisdiction and relevant dates
        ↓
Pin corpus release and model/policy versions
        ↓
Retrieve provisions, cases and contrary material
        ↓
Resolve applicable versions and inspect authority metadata
        ↓
Assemble evidence handles: E1, E2, E3 …
        ↓
Generate structured claims referencing those handles
        ↓
Deterministic integrity checks
        ↓
Semantic-support assessment
        ↓
Publish / qualify / request clarification / abstain
```

### Separate source integrity from legal correctness

The design has three verification layers.

**Deterministic integrity** checks whether evidence belongs to the run, is currently authorized, matches the pinned version, and contains the exact quoted text.

**Semantic support** assesses whether the passage supports the proposition, preserves qualifications, concerns the correct provision, and has the right opinion or argument attribution. This assessment is fallible.

**Legal review** handles disputed interpretation, uncertain chronology, newly asserted precedent treatment, release sampling, and outputs intended for consequential legal use.

A real case citation can still support an incorrect answer. Valid links are therefore necessary but insufficient.

### No unverified answer streaming

The interface may stream progress and authorized source selections. It should not stream raw draft answers before verification.

Allow one bounded repair attempt. Persistent failures produce a qualified partial answer or abstention rather than repeated generation until something appears acceptable.

### Required answer presentation

Every substantive response should expose the direct answer, applicable provisions and versions, supporting authorities, contrary or limiting material, assumptions, relevant dates, corpus coverage, and review status.

Avoid artificial “95% confident” labels. Prefer statements such as:

> “No adverse treatment was located in the covered corpus through the stated cutoff. This is not a comprehensive citator check.”

# 7. Citation graph and precedent treatment

Start with a relational graph in PostgreSQL.

The relationship vocabulary includes:

```text
cites / interprets / applies / follows / distinguishes
overrules / partially_overrules / affirms / reverses
refers_to_larger_bench / amends / commences / repeals
renumbers / corresponds_to / stays_operation
```

Every substantive relationship carries an evidence span, scope description, opinion attribution where relevant, decision date, extraction method, review state, and reviewer record.

**A citation establishes only that something was cited—not that it was followed.**

An alleged overruling or limiting treatment must be supported by reviewed text and scoped to the affected proposition where necessary.

I have also replaced the earlier proposed additive “authority score” with a more cautious design: **retrieval relevance and legal authority are separate decisions**. Court, bench, opinion, dates, jurisdiction, issue, and reviewed treatment are preserved for analysis; recency or citation frequency cannot automatically resolve a legal conflict.

Initially, bound graph expansion to a small number of incoming and outgoing relationships. Introduce a dedicated graph database only if measured traversal requirements justify it.

# 8. Agent design

Use **one bounded research workflow with seven logical stages**, not seven independently deployed autonomous agents.

| Stage                         | Responsibility                                          |
| ----------------------------- | ------------------------------------------------------- |
| Planner                       | Identify issues, dates, jurisdiction and missing facts  |
| Legislation researcher        | Locate provisions and applicable-version evidence       |
| Case-law researcher           | Retrieve decisions and relevant passages                |
| Contrary-authority researcher | Search for limiting, distinguishing or adverse material |
| Synthesizer                   | Draft claims from approved evidence handles             |
| Verifier                      | Check integrity and assess evidentiary support          |
| Publisher                     | Reauthorize and enforce publication/abstention rules    |

The model receives only typed, read-only tools such as `search_statutes`, `search_cases`, `get_source_span`, `get_version_history`, and `get_treatment_evidence`.

It receives no shell, raw SQL, unrestricted web-fetch, email, payment, deletion, or filing tool.

Proposed limits include eight retrieval/tool calls, two parallel research branches, one graph-expansion stage, one repair pass, and separate quick/deep time and cost budgets.

Document instructions remain untrusted data. This matters because indirect prompt injection can arrive through retrieved files or websites; OWASP recommends controls including least privilege, validated outputs, separation of external content, and human approval for high-risk operations. ([OWASP Gen AI Security Project][4])

# 9. AWS infrastructure

The initial deployment candidate is AWS Mumbai, with separate development, staging, and production accounts.

```text
Route 53
   ↓
Regional ALB + ACM + WAF
   ↓
Private ECS Fargate services
   ├── Web / API
   ├── Research workers
   ├── Acquisition workers
   ├── Isolated parser workers
   └── Indexing / export / privacy workers
           ↓
   RDS PostgreSQL + VPC OpenSearch + S3 + SQS
```

Use separate IAM roles for acquisition, parsing, indexing, research, publication, and privacy operations. Acquisition workers need controlled outbound access; parser workers should not have unrestricted network access.

The package specifies Terraform module boundaries for networking, identity, storage/KMS, PostgreSQL, search, queues, compute, observability, and recovery. Codex must implement and test those modules; the package does not pretend Terraform has already been deployed.

### Processing geography

Hosting PostgreSQL in India does not establish India-only processing. Generation, embedding, reranking, OCR, telemetry, and support access require their own approved data flows.

Amazon Bedrock cross-Region inference supports geographic and global routing options. An APAC profile is not equivalent to India-only processing. The proposed India-only policy must reject incompatible routes rather than silently fall back during an outage. ([AWS Documentation][5])

### Cost and recovery

The design includes per-run budget reservations, actual usage reconciliation, queue-based worker scaling, source-freshness monitoring, backup restoration, and index rollback.

Latency, availability, recovery, and cost caps are explicitly **targets to validate**, not promises. A fixed monthly cost would be premature without the corpus size, traffic, model profiles, and redundancy requirements.

# 10. APIs, security and private workspaces

The OpenAPI contract covers source lookup, search, research runs, event streams, citations, version histories, workspaces, uploads, exports, editorial administration, source policies, corpus publication, deletion, audit, and usage.

Representative endpoints include:

```http
POST /v1/search
POST /v1/research/runs
GET  /v1/research/runs/{run_id}/events
GET  /v1/source-spans/{span_id}
GET  /v1/provisions/{unit_id}/versions
GET  /v1/documents/{document_id}/citations
POST /v1/uploads
POST /v1/answers/{answer_id}/exports
POST /v1/admin/corpus-releases/{release_id}/publish
```

Mutations use idempotency keys. A tenant selector never grants access: authentication, active membership, and workspace permission are resolved server-side.

### Isolation requirements

Use forced tenant row-level security plus explicit workspace authorization. PostgreSQL documents that table owners normally bypass row security and that superusers and `BYPASSRLS` roles bypass it; the application must therefore run with appropriately restricted roles and actual isolation tests. ([PostgreSQL][6])

Private uploads remain disabled until the relevant gates pass. Once enabled, they require quarantined uploads, file/checksum validation, isolated parsing, separate search boundaries, current authorization checks, and policy-controlled retention.

A client-uploaded submission may establish a user-provided fact; it must not become authoritative law merely because it was retrieved.

### Privacy and legal operational review

The official DPDP Rules notification specifies phased commencement. The implementation must therefore use a counsel-approved obligation register rather than assume every rule took effect simultaneously or hard-code a universal retention or breach-reporting deadline. 

Deletion workflows distinguish access withdrawal, lawful retention or holds, and physical erasure. They cover source files, object versions, extracted text, vectors, caches, exports, checkpoints, and restoration controls.

The current applicability of CERT-In requirements remains an explicit legal-verification gate: the primary document retrieval was unsuccessful during preparation, and the package does not present its requirements as independently verified.

# 11. Phased implementation plan

The package provides **44 implementation tickets** with acceptance evidence.

| Phase | Deliverable                                    | Exit condition                                                        |
| ----- | ---------------------------------------------- | --------------------------------------------------------------------- |
| 0     | Scope, approvals, repository and local tooling | Decisions recorded; unapproved operations remain blocked              |
| 1     | Canonical corpus and exact-source viewer       | Import, version, authorize, inspect and trace source text end to end  |
| 2     | Exact and hybrid retrieval                     | Actual search integration and lawyer-reviewed retrieval evaluation    |
| 3     | Evidence-grounded answers                      | Citation/quote gates, bounded workflow, honest partial answers        |
| 4     | Temporal law and citation graph                | Version boundaries, opinion attribution and reviewed treatment tested |
| 5     | Bounded research and private workspaces        | Injection, isolation, provider and retention gates passed             |
| 6     | Staging and limited launch                     | Infrastructure, recovery, security and legal pilot review completed   |

An indicative limited-pilot planning range is **12–18 weeks**, assuming two backend/AI engineers, one frontend engineer, and available legal/security reviewers. Source permissions and editorial work may extend that. This is not an estimate for comprehensive all-India coverage.

Proposed evaluation gates include retrieval recall, substantive claim support, contrary-authority recall, and zero known critical failures in the release suite. The figures in the specification are targets—not achieved legal-quality results.

## Where Codex should begin

Give Codex the complete ZIP contents and the included `CODEX_START_HERE.md` prompt.

The first milestone is deliberately narrower than a chatbot:

> **Import an approved document, preserve its original bytes, extract its legal units, search it, and open the exact source passage under the correct permissions.**

Once that works end to end, add retrieval, evidence-grounded generation, temporal reasoning, and bounded agents in sequence.

**The foundation of BharatLaw should be a trustworthy legal corpus and evidence system. The model should operate within that system—not substitute for it.**

[1]: https://www.indiacode.nic.in/ "India Code - Site Migration"
[2]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues-at-least-once-delivery.html "Amazon SQS at-least-once delivery - Amazon Simple Queue Service"
[3]: https://docs.opensearch.org/latest/query-dsl/specialized/k-nn/index/ "k-NN query | OpenSearch Documentation"
[4]: https://genai.owasp.org/llmrisk/llm01-prompt-injection/ "LLM01:2025 Prompt Injection - OWASP Gen AI Security Project"
[5]: https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html "Route model inference requests across AWS Regions with cross-Region inference - Amazon Bedrock"
[6]: https://www.postgresql.org/docs/current/ddl-rowsecurity.html "PostgreSQL: Documentation: 18: 5.9. Row Security Policies"
