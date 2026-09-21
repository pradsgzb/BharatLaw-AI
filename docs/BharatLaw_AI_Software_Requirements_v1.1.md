# BharatLaw AI — Software Requirements Specification

**Document:** BL-SRS-001 | **Version:** 1.1 | **Date:** 19 September 2026 | **Status:** Review draft

## 1. Document control and how to use this specification

This Software Requirements Specification (SRS) translates the BharatLaw AI engineering handoff into a shared description of the product: what users can do, how information moves, what the system must never do, and how completion will be tested. It is written for product owners, Indian legal reviewers, software engineers, testers and operations staff.

| Document field | Value |
| --- | --- |
| Product | BharatLaw AI — evidence-grounded Indian legal research |
| Document ID | BL-SRS-001 |
| Version / date | 1.1 / 19 September 2026 |
| Status | Review draft — proposed requirements baseline; not an approved production release |
| Prepared from | BharatLaw_AI_Codex_Handoff.zip, version 1.0, and its architecture, contracts, reference schema and implementation plan |
| Document owner | Product owner — to be assigned |
| Approval authorities | Product, Indian legal editorial, security/privacy, engineering and operations leads |
| Purpose | Readable product specification and traceable implementation/acceptance reference |

> **What this document does not certify**
> The application has not been built or deployed by preparing this document. Requirements, targets and diagrams are specifications. No legal accuracy, regulatory compliance, cloud deployment or production performance certification is implied.

### 1.1 Reading routes

| Reader | Recommended route |
| --- | --- |
| First-time / nontechnical reader | Sections 2–5: overview, scope, screens and step-by-step workflows. Use the glossary when a term is unfamiliar. |
| Product owner or legal reviewer | Sections 3, 5, 6, 8, 11 and 14–16: expected behavior, legal quality, controls and release decisions. |
| Developer or Codex | Sections 6–13 and Appendices A–C, together with the original machine-readable handoff contracts. |
| Tester / operations team | Sections 5, 11–16: failure paths, service targets, acceptance tests, recovery and release gates. |

### 1.2 Requirement language and precedence

**Shall** identifies a testable requirement. **Should** identifies a preferred approach that needs a recorded reason to change. **May** identifies an optional capability. **Proposed target** identifies a number that must be agreed and measured; it is not an achieved result. Every enabled requirement is mandatory unless an approved change request explicitly modifies it. A phased or disabled feature is not a completed feature.

Use this SRS as the readable proposed baseline. The original SQL, JSON Schemas and OpenAPI remain implementation inputs, not automatically approved production code. Where they conflict, record an architectural decision, update both the readable and machine-readable contracts, and test the result. This document does not silently change the supplied files.

### 1.3 Reconciliation decisions

| Decision | Treatment in this document |
| --- | --- |
| Phase numbering | Use the detailed IMPLEMENTATION_PLAN.md Phase 0–6 and tickets BL-001–BL-044. The architecture summary uses a different Phase 0–7 numbering and must be aligned before implementation. |
| Run states | Use the stored research-run enum as the persistence baseline. “Accepted” and “cancellation requested” are events/UI conditions, not undeclared database states. |
| Historical features | Basic date capture and unknown-date blocking are required before answer generation; full historical comparison and bitemporal resolution are Phase 4. |
| Private uploads / Hindi | Schemas may reserve these capabilities, but server feature gates remain off until their separate acceptance criteria are met. |

## 2. Product overview in plain language

BharatLaw AI is an online research assistant for Indian legal material. A user asks a question, searches a provision or opens a judgment. The product searches an approved library, identifies relevant passages, and explains what those passages support. Users can inspect the exact sources behind an answer rather than rely on the model’s memory.

> **Think of it as a research library with an assistant**
> The document library preserves the originals. The search engine finds useful passages. The AI drafts an explanation. The verification layer checks the evidence and permissions. Legal reviewers govern uncertain legal metadata and release decisions. No single layer replaces the others.

![Figure 01. BharatLaw AI in its working environment](diagrams/01_context.svg)
The user interacts with BharatLaw, not directly with a model or search database. Approved sources supply the research material. Reviewers govern publication and controls. Only checked results are shown as answers.

### 2.1 The problem and intended outcome

The product is intended to reduce time spent locating provisions, comparing versions, following citations and assembling research notes. Its principal value is not fluent writing alone: it is a repeatable route from a question to inspectable evidence, with dates, scope and gaps made visible. [B01, §§0–2]

| User need | Product response |
| --- | --- |
| “Show me the source.” | Open the exact legal unit and original document page or excerpt. |
| “Which wording applied at that time?” | Use reviewed applicability records and a visible law-as-of date; show uncertainty rather than guess. |
| “Is there contrary authority?” | Search for limiting or adverse material and state the corpus coverage of that check. |
| “Can my colleague see my matter?” | Apply organization and workspace permissions to search, evidence, answers and exports. |
| “What happens when AI is unavailable?” | Keep authorized catalog lookup, source viewing and lexical search available where their dependencies are healthy. |

### 2.2 First usable release

The first usable release is a source viewer, not a broad legal chatbot: an approved Constitution edition and a curated constitutional Supreme Court decision set can be imported, inspected and searched. AI explanations follow only after exact-source and retrieval checks work end to end. Until acquisition permissions exist, development uses conspicuously labeled synthetic fixtures, which production publication rejects.

### 2.3 Measures of success

Assess user usefulness alongside legal and operational quality. Measure whether researchers can locate useful sources, whether material claims are supported, whether quoted text is exact, and whether the product handles uncertainty and access changes correctly. The evaluation plan defines denominators and test coverage. A valid citation does not, by itself, prove the legal interpretation is correct.

## 3. Scope, users and permissions

### 3.1 Delivery scope

| Stage | Included capability | Boundary |
| --- | --- | --- |
| Foundation / Phases 0–1 | Identity, approved imports, exact legal units, source viewer, editorial review and immutable releases | No foundation-model training and no unsupported whole-site crawl. |
| Research / Phases 2–3 | Exact and hybrid search, reranking, evidence-linked answers, assumptions, coverage and abstention | Approved public corpus only; no claim of comprehensive current Indian law. |
| Advanced research / Phase 4 | Historical versions, reviewed citation treatment and contrary-authority workflows | Only reviewed scope; unresolved legal conflicts remain explicit. |
| Conditional expansion / Phase 5 | Bounded orchestration, private workspaces, uploads, exports and retention-aware deletion | Private features remain off until legal/security/provider gates pass. |
| Limited launch / Phase 6 | AWS staging, tested operations, security/legal pilot review and scope-controlled beta | Launch needs explicit approval; no automatic authorization to spend or deploy. |
| Later, separately approved | Hindi/Hinglish, additional courts/states/tribunals, licensed content, specialized rerankers | New corpus/language/provider requires evaluation and a release decision. |

### 3.2 Explicit exclusions

The baseline excludes guaranteed legal advice; predictions of court outcomes; automated court filing; autonomous correspondence, payments or external actions; a limitation/deadline calculator; unrestricted browser or shell tools for the model; unlicensed commercial commentary; a new foundation model; public sharing of private matters; and a claim that every Indian legal source is covered or current. Fine-tuning is not a prerequisite for the initial product. [B01, §0.2]

### 3.3 User roles

| Role | Typical responsibility | Important restriction |
| --- | --- | --- |
| Researcher | Ask questions, search, inspect sources and work in assigned matters | Cannot publish corpus releases or approve source rights. |
| Viewer | Read permitted material and existing shared research | Cannot assume write or export authority. |
| Workspace manager | Manage assigned matter membership and permitted exports | Cannot add someone outside active organization membership. |
| Tenant owner / administrator | Manage organization membership, entitlements and settings | Does not automatically receive access to every confidential workspace. |
| Legal editor | Review legal metadata, dates, citations and treatment assertions | Cannot mark the model’s own review as lawyer approval. |
| Source administrator | Register acquisition routes, terms evidence and source policies | Rights approval requires its designated reviewer and audit evidence. |
| Security/privacy administrator | Approve processing policy, investigate controls and coordinate retention | Content access is separately granted; the role is not a universal matter-reader. |
| Auditor / operations staff | Read permitted audit metadata or operate services | No routine access to question bodies, private documents or credentials. |
| Service identity | Run a narrowly scoped acquisition, parsing, indexing or research task | Each service receives only the permissions required by its job. |

### 3.4 Two permission boundaries

A **tenant** is an organization. A **workspace** is a research matter or team area inside that organization. A user must pass both boundaries. Selecting a tenant ID or knowing a document ID is not permission. The same checks apply in the browser API, background jobs, search results, source links, model requests, cached answers and downloads.

### 3.5 Assumptions requiring confirmation

Initial users are authenticated researchers, lawyers and law students; English is enabled first; local development precedes cloud deployment; AWS Mumbai is a deployment candidate rather than a residency guarantee. Source permissions, legal-review availability, processor terms, budget, retention periods and precise release coverage remain decisions for the project owners. No team size, budget or legal permission is assumed to have been supplied by the user.

## 4. Product screens and user experience

The interface should reveal the evidence and limits without requiring the user to understand embeddings, databases or agent frameworks. A first-time user should be able to submit a question and open its supporting passage without a tutorial.

| Screen | What the user sees | Required behavior |
| --- | --- | --- |
| Home / research | Question field; workspace; law date; authority cutoff; mode; visible corpus coverage | Start with simple defaults, disclose those defaults, and expose advanced controls without hiding material assumptions. |
| Search results | Title; document type; court or source; date; provision/citation; excerpt; source class | Separate exact matches from related results; preserve filters and the pinned release. |
| Research progress | Planning, finding sources and verification milestones; cancel action | Never show raw draft legal answers before publication checks. |
| Answer workspace | Direct answer; material claims; applicable law; supporting/contrary material; assumptions; limitations | Each legal proposition links to its evidence. Review status and coverage remain visible. |
| Source viewer | Exact excerpt; original page; official paragraph label if present; metadata and permitted source link | Highlight exact text, support keyboard navigation, and distinguish PDF page from printed page numbering. |
| Version comparison | Selected law date, versions, changes, applicability evidence and research mode | Label unknown dates and later interpretations. Do not imply renumbered provisions are automatically equivalent. |
| Matter workspace | Authorized members, uploads, research history and export controls | Display confidentiality scope; no public sharing of private content. |
| Editorial console | Import queue, extraction preview, uncertainty flags, source-policy decisions and release checklist | Require reasoned, attributable review; block self-approval where a second reviewer is required. |
| Operations / coverage | Source cutoffs, lag, failed jobs, cost usage, incident states and permitted audit metadata | Distinguish a successful synchronization attempt from proven legal completeness. |

### 4.1 Standard answer layout

Use a consistent order: **question and scope → direct answer → applicable provisions and versions → supporting authorities → analysis → contrary or limiting material → assumptions and missing facts → coverage and review status → citations**. The section order is a display convention, not an instruction to fabricate material for an empty section.

An evidence panel should show the source title, court/source type, decision or publication metadata, exact pinpoint, source excerpt, version/release reference and availability status. A legal claim, user-supplied fact and explanatory inference must look distinguishable. Do not display a percentage confidence badge that implies measured legal certainty.

### 4.2 Empty, uncertain and degraded states

| Situation | Example user-facing message |
| --- | --- |
| No verified authority | “No verified authority was located in the covered sources for this question. Refine the scope or review the listed coverage gaps.” |
| Unknown operative date | “The relevant commencement or transitional evidence is not yet verified. This answer cannot identify the operative wording conclusively.” |
| Conflicting material | “The retrieved authorities contain a potentially material conflict. Review the listed passages and their scope before relying on a conclusion.” |
| AI provider unavailable | “AI explanation is temporarily unavailable. You can still search and open available sources.” |
| Permission changed | “Access to this matter or source has changed. The affected material is no longer available.” |
| Source restricted after publication | “A cited source is now restricted. This answer has been limited; its original citation has not been silently replaced.” |

## 5. Detailed end-to-end workflows

Each workflow states who starts it, what must already be true, the processing steps, the visible outcome and the failure paths. The diagrams are conceptual process maps; the functional requirements and machine-readable contracts define the detailed implementation. All legal examples below are synthetic and do not state Indian law.

### WF-01 | Sign in and select a research workspace

**Primary actor:** Researcher. **Before starting:** An approved identity service and active membership exist. **Trigger:** The user opens BharatLaw.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | The user signs in through the approved identity provider. | Validate identity, token purpose, issuer, audience and expiry; privileged users complete MFA. |
| 2 | The server resolves active organization memberships. | One unambiguous organization is selected; otherwise ask the user to select one. |
| 3 | The user opens an authorized workspace. | Resolve current membership, role, processing policy and permission revision. |
| 4 | The home page loads permitted scope and recent work. | Do not expose other organizations or confidential workspaces. |

**Successful outcome:** An authenticated session is tied to an authorized workspace; subsequent requests derive scope on the server.

**Alternative and failure paths:** Expired tokens require sign-in; absent organization selection returns a safe conflict; denied access reveals no hidden resource details. A lost membership invalidates new requests and long-lived streams.

### WF-02 | Ask a question and receive a checked answer

**Primary actor:** Researcher. **Before starting:** The corpus, processing route and budget are available. **Trigger:** The user chooses Research.

![Figure 02. From a question to a verified research result](diagrams/02_research.svg)
The process has valid non-answer outcomes. A clarification or an evidence-limited result is safer than a definitive response constructed from missing facts.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Submit the question, workspace, dates and mode. | Validate input and feature gates; create a queued run and budget reservation transactionally. |
| 2 | Plan the research and resolve material gaps. | Pin a corpus release and approved profiles; ask clarification rather than silently infer decisive facts. |
| 3 | Find provisions, cases and relevant contrary material. | Combine exact, lexical and semantic search within authorized scope; recover definitions and exceptions. |
| 4 | Prepare the evidence pack and draft structured claims. | Assign server-generated evidence handles and transmit only allowed source passages. |
| 5 | Verify claims and publish eligible output. | Check exact quotes, source identity, access and support; provide one bounded repair where appropriate. |

**Successful outcome:** A supported answer, partial answer, clarification request or abstention is saved with its evidence and coverage. Only eligible final content reaches the user.

**Alternative and failure paths:** Provider failure preserves search access where possible; no evidence triggers abstention; unsupported claims are omitted or qualified. Cancellation stops new work but cannot recall a request already transmitted.

### WF-03 | Search for a provision or judgment without AI generation

**Primary actor:** Researcher or viewer. **Before starting:** A permitted release and search service are available. **Trigger:** The user enters a title, citation, section or keywords.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Resolve exact identifiers first. | Retain statutory identifier punctuation and identify ambiguous case matches. |
| 2 | Apply approved filters and execute search. | The server controls release, source, language, court, date and workspace constraints. |
| 3 | Show results with provenance and excerpts. | Identify source class and opinion/argument role; no restricted or synthetic production results. |
| 4 | Open the selected source. | Reauthorize and load canonical text and its original anchor, not an unchecked search copy. |

**Successful outcome:** The user can inspect evidence even when generation is disabled.

**Alternative and failure paths:** Unknown identifiers remain unknown; ambiguous matches offer choices. A search outage is explicit and does not produce fabricated results or silently broaden private scope.

### WF-04 | Open a citation and inspect its support

**Primary actor:** Researcher or viewer. **Before starting:** A visible answer contains an authorized citation. **Trigger:** The user clicks a citation.

![Figure 03. Three layers of answer verification](diagrams/05_verification.svg)
Source integrity, semantic support and human legal review are different checks. A real case and an exact quote can still be used to support the wrong proposition.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Resolve the evidence handle to the stored run evidence. | Confirm answer, run, release and current authorization. |
| 2 | Fetch the exact canonical excerpt and source metadata. | Verify offsets and quote/unit hashes; distinguish page labels and official paragraph labels. |
| 3 | Open the source viewer with the passage highlighted. | Show the source class, version, opinion attribution and permitted original-source link. |
| 4 | Allow the user to report a mismatch. | Create a traceable feedback item tied to the exact answer and source revision. |

**Successful outcome:** The user can compare the legal claim with the precise passage and its surrounding context.

**Alternative and failure paths:** A missing or restricted source receives an availability notice; a hash mismatch blocks the quote and creates an operational/editorial issue. Do not replace the old citation silently.

### WF-05 | Research the law applicable at a historical date

**Primary actor:** Researcher. **Before starting:** Reviewed applicability records exist for the relevant scope, or uncertainty is disclosed. **Trigger:** The user selects a law date and research mode.

![Figure 04. Historical law: two dates, two different questions](diagrams/04_historical.svg)
“What wording applied then?” and “Which later decisions may be considered?” are separate questions. Both must be visible to the researcher.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Capture the event date, law-as-of date and authority cutoff separately. | The UI explains why these dates may differ. |
| 2 | Resolve the provision, territory and material conditions. | Use approved release snapshots rather than publication date alone. |
| 3 | Select wording and allowed interpretive authorities. | Contemporaneous mode respects its authority cutoff; retrospective mode labels later interpretations. |
| 4 | Show a version comparison and cited explanation. | Include commencement, saving or transitional evidence where relevant. |

**Successful outcome:** The answer identifies the selected wording and the scope of the historical analysis.

**Alternative and failure paths:** Unknown commencement, unresolved conditions or inconsistent assertions prevent an unqualified operative-law conclusion. A successor provision is not assumed equivalent.

### WF-06 | Import, review and publish legal material

**Primary actor:** Source administrator and legal editor. **Before starting:** The specific acquisition and downstream uses are approved. **Trigger:** An approved manual import or scheduled adapter supplies a source.

![Figure 05. Approved document ingestion and release](diagrams/03_ingestion.svg)
An acquired document is not automatically published. Permission, file safety, extraction quality, legal review and search validation are separate gates.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Check the source register and preserve original bytes. | Store provenance, retrieval metadata, byte hash, source policy and immutable object version. |
| 2 | Scan, extract and segment the document. | Prefer native text; use necessary OCR only in a sandbox; retain exact legal-unit anchors. |
| 3 | Review quality, legal metadata and uncertain assertions. | Quarantine unsafe files and unresolved essential defects; record reviewer decisions. |
| 4 | Build and test a candidate release. | Generate approved embeddings and indexes; pin legal units, dates, rights and graph snapshots. |
| 5 | Obtain independent publication approval and activate the release. | New research runs pin the new release; history stays immutable. |

**Successful outcome:** Only checked, rights-approved material becomes available as public legal evidence.

**Alternative and failure paths:** Duplicate delivery is idempotent; changed bytes produce a new version; insufficient rights stop the affected operation. Partial indexing or failed checks cannot be reported as publication.

### WF-07 | Use a private document in a matter

**Primary actor:** Authorized workspace member. **Before starting:** Private-mode legal, security, provider and retention gates have passed. **Trigger:** The user requests a PDF upload.

![Figure 06. Private matter upload: disabled until approval gates pass](diagrams/06_private_upload.svg)
Private files remain separate from the public authority corpus throughout ingestion, storage, search, generation and export.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Request a constrained upload session. | Validate workspace, file type, size, checksum and quota; generate the destination on the server. |
| 2 | Upload and confirm completion. | Compare actual bytes, owner, object version and checksum; no arbitrary bucket/key substitution. |
| 3 | Quarantine, scan and parse in isolation. | Reject unsafe, encrypted or unsupported inputs; preserve original and derived versions. |
| 4 | Index private passages and activate the document. | Store tenant, workspace and current permission revision; reauthorize before use. |
| 5 | Run research that optionally includes the document. | Label document facts as private/user-supplied evidence, not binding legal authority. |

**Successful outcome:** The document is usable only by currently authorized members of its workspace.

**Alternative and failure paths:** A closed feature gate, failed scan, checksum mismatch or access revocation blocks activation. No cross-tenant deduplication signal may reveal another customer’s file.

### WF-08 | Request and download a research memorandum

**Primary actor:** Researcher with export permission. **Before starting:** A permitted answer exists and workspace export policy allows the request. **Trigger:** The user chooses Export.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Create an export job for a specific answer revision. | Save requested format, source scope and idempotency key. |
| 2 | Collect approval if required for private content. | Only an authorized reviewer may approve; the requester cannot bypass policy. |
| 3 | Render a fixed, sanitized document template. | Include citations, dates, corpus release, limitations, source availability and actual review status. |
| 4 | Reauthorize at download time. | Provide a short-lived authorized route; sensitive downloads may be proxied. |

**Successful outcome:** A readable research note is downloaded; it is not represented as an automatically filed court document.

**Alternative and failure paths:** Permission revocation, a restricted source or missing approval blocks the affected output. Model-authored HTML or template instructions are never executed.

### WF-09 | Correct a source or report a misleading answer

**Primary actor:** Researcher, legal editor and release reviewer. **Before starting:** The report identifies a source or answer revision. **Trigger:** The user submits feedback or an editor receives a correction.

![Figure 07. Correction, publication and rollback without rewriting history](diagrams/15_release.svg)
Publication changes which release new runs use. It does not alter the evidence identity behind an earlier run.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Record the issue and affected evidence. | Preserve answer/run IDs, source versions, severity and a safe audit trail. |
| 2 | Triage immediate restrictions and legal review. | Critical source or confidentiality defects can block serving before reindexing finishes. |
| 3 | Create reviewed corrections without editing old evidence in place. | New artifacts, unit versions or assertions retain lineage and reasons. |
| 4 | Publish a checked new release and invalidate dependent caches. | Old answers retain historical identity but obey current restrictions and show limitations. |

**Successful outcome:** The correction is traceable, future research uses the approved revision, and old answers are not silently rewritten.

**Alternative and failure paths:** A disputed correction remains under review; rollback cannot revive a restricted source or supersede an active access prohibition.

### WF-10 | Revoke access or delete private matter data

**Primary actor:** Workspace manager or authorized privacy operator. **Before starting:** The request is authenticated and within the requester’s authority. **Trigger:** A member is removed or deletion is requested.

![Figure 08. Access withdrawal, legal holds and verified erasure](diagrams/07_deletion.svg)
Access withdrawal is immediate. Physical erasure follows the approved retention policy and may have legitimate, disclosed restrictions.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Revoke ordinary access and increment the permission revision. | Stop new search/viewer/model/export use and invalidate relevant caches and streams. |
| 2 | Evaluate retention obligations and legal holds. | Move legitimately retained material to restricted access; no normal research use. |
| 3 | Erase permitted copies and collect component receipts. | Cover objects/versions, extracts, vectors, caches, exports and checkpoints; track provider limitations. |
| 4 | Verify completion and protect future restores. | Replay erasure/takedown controls when backups are restored; record residual obligations. |

**Successful outcome:** The user receives an accurate access/retention/erasure status rather than a premature “deleted everywhere” claim.

**Alternative and failure paths:** A legal hold produces a held state, not ordinary continued access. Failed erasure remains retryable and visible; it is not marked complete.

### WF-11 | Handle interruption, duplicate delivery and cancellation

**Primary actor:** Research coordinator and operations staff. **Before starting:** A durable job or research run exists. **Trigger:** A worker stops, a provider times out or a user cancels.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Read durable state and claim an eligible lease. | Use compare-and-set transitions; a late worker cannot overwrite a final result. |
| 2 | Retry only a permitted stage with a stable idempotency key. | Bound attempts and record uncertain external effects or charges. |
| 3 | Honor cancellation and access changes before new work. | Stop new tools and publications; reconcile in-flight requests. |
| 4 | Expose safe progress or a recoverable failure. | Keep checkpoints and report an actionable error without private logs or fabricated success. |

**Successful outcome:** The system either resumes safely or stops with an honest status and reconciled usage.

**Alternative and failure paths:** A duplicate queue event cannot create duplicate documents or published answers. Timeouts do not prove that the external service did nothing.

### WF-12 | Release a tested version and recover from a fault

**Primary actor:** Engineering, legal, security and operations approvers. **Before starting:** The phase exit evidence and deployment authorization are available. **Trigger:** A release candidate is submitted.

| Step | Actor / system action | Result or control |
| --- | --- | --- |
| 1 | Run contract, database, retrieval, security and legal evaluation gates. | Separate mocks from real service-backed tests and report blocked/untested areas. |
| 2 | Approve infrastructure and application changes. | Review migrations, source coverage, provider routes, costs, rollback and support ownership. |
| 3 | Deploy to the approved environment and run smoke tests. | Validate permissions, exact citations, health, alerts and budget controls. |
| 4 | Observe the limited pilot; rollback or restrict on a critical defect. | Restore canonical metadata and replay current deletion/takedown controls before reopening access. |

**Successful outcome:** A scope-controlled release has an accountable approval record and evidence of operating tests.

**Alternative and failure paths:** Critical legal or security failures block launch. Passing unit tests or generating Terraform does not authorize deployment or establish production readiness.

## 6. Functional requirements

The following requirements define observable behavior. The acceptance column states the evidence needed to verify each requirement. Ticket references point to the original engineering plan [B02]. Every requirement also appears in the companion machine-readable register; the traceability appendix maps modules to workflows and acceptance scenarios.

### 6.1 Identity, membership and permissions

Planned implementation: Phase 1. Baseline tickets: BL-008, BL-025, BL-036. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-001<br>Authenticate | The system shall authenticate through an approved identity provider and validate token signature, issuer, audience, expiry and purpose. | Invalid, expired and wrong-audience tokens are denied; legitimate sessions succeed. |
| BL-FR-002<br>Privileged access | The system shall require MFA for privileged roles and protect browser sessions against token exposure and request forgery. | Privileged login, session expiry, secure-cookie and CSRF tests pass. |
| BL-FR-003<br>Organization selection | The system shall resolve a requested organization against active membership; ambiguous selection shall prompt the user. | A forged tenant selector never grants access; ambiguous selection gives a safe conflict. |
| BL-FR-004<br>Workspace scope | The system shall enforce current workspace permission separately from organization membership on every resource path. | Two workspaces in one tenant cannot read each other without explicit membership. |
| BL-FR-005<br>Role separation | The system shall separate research, source, legal review, security, audit and publication capabilities. | Each role is denied operations outside its declared permission set. |
| BL-FR-006<br>Revocation | The system shall reauthorize long-running jobs, streams, model transmissions, source views and exports after permission changes. | Revocation during a run prevents further unauthorized transmission and final disclosure. |
| BL-FR-007<br>Audit identity changes | The system shall record membership, role, policy and permission-revision changes without unnecessary content bodies. | Audit events identify actor, target, time, reason and revision; secrets are absent. |

### 6.2 Source governance and coverage

Planned implementation: Phase 0–1. Baseline tickets: BL-001, BL-002, BL-009, BL-013, BL-026. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-008<br>Use-specific rights | The system shall store independent decisions for acquisition, storage, parsing, indexing, provider transmission, display, redistribution and training/evaluation. | A source permitted for storage but not model transmission is not sent to a provider. |
| BL-FR-009<br>Fail-closed approval | The system shall deny each affected operation while its source permission is pending, rejected, expired or withdrawn. | All non-approved states block the applicable operation and record a safe reason. |
| BL-FR-010<br>Source evidence | The source register shall retain rights evidence, access method, attribution, reviewer, review date and re-review or expiry conditions. | Approval cannot be submitted without the required attributable review fields. |
| BL-FR-011<br>Approved acquisition | The system shall use reviewed manual imports or approved source adapters with explicit allowlists and rate limits. | Unapproved hosts, protected controls and undocumented acquisition routes cannot be used by the model. |
| BL-FR-012<br>Coverage disclosure | The system shall disclose source/court/date coverage, publication cutoff, synchronization status, pending items and material gaps. | A failed synchronization is not presented as an up-to-date corpus. |
| BL-FR-013<br>Immediate restriction | The system shall enforce takedowns at serving and transmission boundaries before asynchronous index removal completes. | A newly restricted source cannot be opened, transmitted or used in a new answer. |
| BL-FR-014<br>No synthetic release | Production publication shall reject synthetic fixtures, unapproved extractions and unapproved sources. | A candidate containing one synthetic unit fails its publication gate. |

### 6.3 Ingestion and editorial publication

Planned implementation: Phase 1. Baseline tickets: BL-009–BL-013. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-015<br>Original bytes | The system shall preserve the original artifact, byte hash, object version, source locator and acquisition metadata before parsing. | An extracted passage can be traced to an immutable original and its hash. |
| BL-FR-016<br>Version changes | The system shall create new artifact/text versions when source bytes or reviewed extraction change, rather than overwrite released evidence. | Same-URL changed bytes produce a new version; earlier runs remain identifiable. |
| BL-FR-017<br>Idempotent import | The system shall safely handle repeated imports and queue deliveries with stable job/stage/input keys. | Repeated delivery produces one intended version/effect and auditable attempts. |
| BL-FR-018<br>File safety | The system shall validate format, content signature, file limits and scan results before isolated parsing. | Unsafe, unsupported, oversized and corrupt files remain quarantined. |
| BL-FR-019<br>Selective OCR | The system shall use native extraction first and record OCR only where required for unusable or image-only pages. | A native-text fixture avoids OCR; a scanned fixture records OCR provenance and review needs. |
| BL-FR-020<br>Legal structure | The parser shall preserve provisions, clauses, exceptions, schedules, opinions and original judgment paragraph labels where present. | Reviewed fixtures retain essential exceptions and do not invent paragraph numbers. |
| BL-FR-021<br>Exact anchors | The system shall retain canonical text, Unicode code-point offsets, page references and optional bounding boxes for source passages. | Quoted spans match canonical text and original visual anchors, including Unicode cases. |
| BL-FR-022<br>Quality review | The system shall flag unreadable text, uncertain metadata, essential OCR ambiguities and unresolved legal assertions for review. | Unresolved essential defects cannot advance to authoritative publication. |
| BL-FR-023<br>Atomic publication | The system shall validate candidate indexes, manifests and independent approval before activating a corpus release. | Partial indexing or missing approval leaves the candidate unpublished. |
| BL-FR-024<br>Reproducible releases | A release shall pin legal units, source-policy, temporal, citation and treatment snapshots with versioned canonical hashes. | A historical run resolves the same approved evidence despite later corrections. |

### 6.4 Catalog and source viewing

Planned implementation: Phase 1–2. Baseline tickets: BL-010, BL-012, BL-014, BL-018. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-025<br>Exact lookup | The catalog shall resolve approved titles, canonical IDs and citation aliases without treating a case name as unique. | Ambiguous or unknown identifiers return choices or no verified match. |
| BL-FR-026<br>Structured browsing | The viewer shall provide paginated legal-unit navigation and surrounding context without returning an entire corpus. | Long judgments and statutes remain navigable within response size limits. |
| BL-FR-027<br>Canonical quotation | The system shall reconstruct quoted text from canonical source spans, never an unchecked search summary or model output. | A modified index excerpt cannot alter the displayed canonical quotation. |
| BL-FR-028<br>Honest pinpoints | The viewer shall distinguish original paragraph numbers, PDF page positions and printed page labels. | Unnumbered judgments use page/excerpt references, not fabricated paragraph labels. |
| BL-FR-029<br>Source availability | The viewer shall recheck rights and access on every source request and disclose restrictions without substituting authority. | Restricted and missing originals generate a safe availability state. |
| BL-FR-030<br>Context preservation | Evidence display shall retain related definitions, provisos, explanations and relevant table headers where material. | A qualifying exception remains visible with its operative provision. |

### 6.5 Search and ranking

Planned implementation: Phase 2. Baseline tickets: BL-014–BL-019, BL-020. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-031<br>Typed search | Search shall accept typed filters and bounded query text, not raw OpenSearch DSL, SQL or client-selected indexes. | Injection and arbitrary-index inputs are rejected. |
| BL-FR-032<br>Parallel retrieval | The gateway shall execute lexical and semantic branches using the same mandatory authorized scope. | Integration tests compare mandatory filters in both executed branches. |
| BL-FR-033<br>Private inner filters | Private retrieval shall include tenant, workspace, active state and permission revision within candidate selection. | Unauthorized passages never enter model evidence or returned results. |
| BL-FR-034<br>Release pinning | Public retrieval shall use the concrete indexes declared in the run’s accessible release. | An alias switch during a run cannot mix release versions. |
| BL-FR-035<br>Rank fusion | The system shall fuse candidate ranks deterministically, deduplicate and apply bounded reranking. | Repeated identical candidates produce the same ordering and no duplicates. |
| BL-FR-036<br>Profile compatibility | The system shall reject embedding/model/dimension mismatches and require a new evaluated index for profile changes. | Wrong-dimension or wrong-profile requests fail before search/index publication. |
| BL-FR-037<br>Context expansion | The retriever shall recover necessary parent context and exceptions within a bounded evidence budget. | An over-budget essential context case is narrowed or qualified, not silently truncated. |
| BL-FR-038<br>Authority distinction | The product shall distinguish retrieval relevance from legal authority and preserve court, opinion, scope and treatment metadata. | Recency or similarity alone cannot generate a conclusive precedence label. |
| BL-FR-039<br>Degraded search | The system shall expose permitted exact/lexical lookup when generation is unavailable, with explicit service limitations. | A disabled generation provider does not remove healthy catalog functionality. |

### 6.6 Research and answer generation

Planned implementation: Phase 3. Baseline tickets: BL-020–BL-026, BL-031, BL-033. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-040<br>Research input | The system shall capture question, workspace, language, depth, jurisdiction, legal date, authority cutoff, mode and private inclusion explicitly. | Required fields validate against the approved request contract and feature policy. |
| BL-FR-041<br>Bounded clarification | The planner shall ask for material missing facts, with at most two clarification rounds before assumptions, narrowing or abstention. | No material state/date/procedural assumption is silently introduced. |
| BL-FR-042<br>Durable run | The system shall save plan, release, profiles, policy, evidence and stage progress in a durable research run. | A worker restart recovers a valid checkpoint without fabricating completion. |
| BL-FR-043<br>Budget reservation | Research creation shall reserve entitlement/cost allowance and record an outbox event in the same transaction. | Concurrent requests cannot exceed a configured allowance through a race. |
| BL-FR-044<br>Evidence handles | The coordinator shall assign permitted evidence handles; the model may reference only those handles in material claims. | Unknown, cross-run and cross-release handles are rejected. |
| BL-FR-045<br>Contrary research | Research shall seek relevant limiting or contrary material when the question requires synthesis, within declared coverage. | Known adverse-authority test cases are retrieved or explicitly flagged as a coverage gap. |
| BL-FR-046<br>Structured answer | Published answers shall distinguish legal authority, user-provided facts, inference, assumptions, limits and review status. | Contract validation and UI tests confirm all applicable sections and source classes. |
| BL-FR-047<br>Safe progress | The system shall stream typed milestones and authorized evidence metadata, not unverified legal prose or hidden model reasoning. | Stream payload tests reject raw draft tokens and unauthorized source bodies. |
| BL-FR-048<br>Cancellation | The system shall stop new work after cancellation, protect terminal states and reconcile in-flight costs honestly. | Late workers cannot publish after cancellation; uncertain provider charges remain recorded. |
| BL-FR-049<br>Valid abstention | Insufficient, conflicted or unverifiable evidence shall yield clarification, qualification, partial output or abstention rather than invented authority. | Critical fake-citation and missing-source fixtures receive the appropriate non-definitive outcome. |

### 6.7 Verification and trustworthy output

Planned implementation: Phase 3. Baseline tickets: BL-022–BL-026, BL-036, BL-037. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-050<br>Integrity gates | Every published citation shall resolve to current authorized evidence within the run and its pinned release. | Every served citation passes run/release/source/permission checks. |
| BL-FR-051<br>Exact quote checks | Quoted content shall match the canonical excerpt, Unicode offsets and quote hash exactly. | One-character quotation changes and wrong offsets block publication. |
| BL-FR-052<br>Semantic support | The system shall assess whether material claims are supported, including qualifications and passage roles, separately from citation existence. | Reviewer fixtures detect a real citation used for an unsupported proposition. |
| BL-FR-053<br>Bounded repair | A failed answer-verification cycle shall allow no more than one controlled repair before omission, review or abstention. | A persistently failing generator cannot enter an unbounded repair loop. |
| BL-FR-054<br>Human review label | Only an authenticated qualifying human review operation shall set a lawyer-reviewed status. | Model-supplied review flags are ignored or rejected. |
| BL-FR-055<br>No misleading status | The product shall avoid definitive citator or accuracy badges unsupported by corpus coverage and actual review. | A no-adverse-case result includes coverage limitations, not a universal clean-status claim. |
| BL-FR-056<br>Sanitized rendering | Answers and citations shall be rendered through safe templates and sanitized content with server-resolved links. | Script URLs, executable HTML and remote-image exfiltration are blocked. |
| BL-FR-057<br>Changed availability | When evidence becomes restricted, stored answers shall be limited under policy while retaining an appropriately restricted audit identity. | Old answers show a source-availability notice and do not silently cite a replacement. |

### 6.8 Historical law and provision versions

Planned implementation: Phase 4. Baseline tickets: BL-027, BL-028, BL-032. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-058<br>Separate dates | The system shall distinguish legal applicability, event, authority cutoff, publication and platform knowledge dates. | Tests show that publication date alone does not establish commencement. |
| BL-FR-059<br>Bitemporal records | Applicability records shall preserve both legal-time intervals and knowledge-time history with half-open boundaries. | Boundary and retrospective-correction tests execute against actual PostgreSQL. |
| BL-FR-060<br>Scope conditions | Version resolution shall consider reviewed territorial, commencement, saving and transitional conditions. | Missing material conditions produce a qualified or review-required result. |
| BL-FR-061<br>Unknown dates | Unknown commencement or unresolved scope shall remain explicit and shall block an unqualified operative-law statement. | Null dates cannot be treated as an invented beginning of time. |
| BL-FR-062<br>Historical modes | Contemporaneous and retrospective-analysis modes shall apply their distinct authority-cutoff behavior. | Later interpretations are excluded or expressly labeled as required by the chosen mode. |
| BL-FR-063<br>Version comparison | The interface shall show selected wording, amendments and evidence-backed relationships without implying automatic section equivalence. | A renumbering fixture retains identity/relationship history and review scope. |
| BL-FR-064<br>Snapshot stability | Later corrections shall create new knowledge assertions and release snapshots without rewriting previous research inputs. | The same old run retains its original interpretation inputs while current restrictions remain enforced. |

### 6.9 Citation relationships and opinions

Planned implementation: Phase 4. Baseline tickets: BL-029–BL-031. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-065<br>Citation resolution | Citation mentions shall retain original text, candidate resolution, ambiguity and review state. | Ambiguous mentions do not become verified cases through model confidence alone. |
| BL-FR-066<br>Opinion attribution | The system shall distinguish majority, concurrence, dissent, arguments and quoted prior authority where known. | A dissent or counsel submission cannot be presented as a majority holding. |
| BL-FR-067<br>Treatment evidence | Follows, distinguishes, overrules and similar treatment shall have supporting source spans, scoped propositions and review evidence. | A mere citation cannot generate an approved overruling relationship. |
| BL-FR-068<br>Bounded graph | Citation-neighbor expansion shall be bounded, release-pinned and reauthorized before use. | Graph traversal respects node/edge limits and excludes restricted evidence. |
| BL-FR-069<br>Conflict reporting | The interface shall display potential conflicts and reviewed relationship scope rather than choose controlling authority from a weighted score alone. | A conflicting-authority fixture exposes the conflict and relevant passages. |

### 6.10 Private matters and uploaded documents

Planned implementation: Phase 5. Baseline tickets: BL-035–BL-037, BL-040. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-070<br>Private gate | The system shall keep private uploads disabled until approved processing, retention and isolation gates pass. | Missing approval denies upload and private model use on the server, not just in the UI. |
| BL-FR-071<br>Upload session | Uploads shall use server-issued, constrained destinations with ownership, checksum, media and quota checks. | Object substitution, expiry and overwrite races fail safely. |
| BL-FR-072<br>Isolated parsing | Private files shall pass quarantine and sandbox parsing without network or executable document content. | Malicious PDF and resource-exhaustion fixtures remain contained. |
| BL-FR-073<br>Separate private index | Private passages shall remain outside public authority indexes and include current tenant/workspace/permission metadata. | No public query can return private passage content or identity. |
| BL-FR-074<br>Source class | Private submissions shall be marked as user-provided factual material, not authoritative law. | Answer generation preserves the distinction in mixed public/private evidence. |
| BL-FR-075<br>No training by default | Customer content shall not be used for model training by default; any future use requires separate explicit approval and rights. | Provider/configuration tests show training-related routes remain disabled. |
| BL-FR-076<br>Retention-aware deletion | Deletion shall revoke ordinary access first, evaluate holds and permitted retention, then track erasure across applicable components. | A held record is restricted; an incompletely erased record is not marked completed. |
| BL-FR-077<br>Restore restrictions | Recovery shall replay current deletion, takedown and permission restrictions before restored data are exposed. | A restored backup cannot resurrect searchable deleted/restricted matter content. |

### 6.11 Exports, feedback and accountable changes

Planned implementation: Phase 3–5. Baseline tickets: BL-025, BL-026, BL-037, BL-042. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-078<br>Fixed exports | Exports shall use fixed safe templates and include dates, source links, release, limitations and actual review status. | Exported citations match the selected answer revision and safe rendering tests pass. |
| BL-FR-079<br>Export authorization | The system shall check policy/approval at request, execution and download time. | Revoking membership before download prevents disclosure. |
| BL-FR-080<br>Feedback capture | Users shall report answer/source issues against exact revisions with category and optional explanation. | The editorial queue receives a traceable issue without rewriting the original answer. |
| BL-FR-081<br>Correction lineage | Corrections shall retain reviewer identity, rationale, affected versions and new release linkage. | A reviewer can reconstruct what changed, why, and which release contains the correction. |
| BL-FR-082<br>No external action | Research or export shall not send correspondence, make payment or file court documents. | The available tool/endpoint surface exposes no such autonomous action. |
| BL-FR-083<br>Change notice | The product shall surface material availability or correction limitations affecting viewed answers under policy. | Restricted-source and corrected-metadata fixtures display an appropriate notice. |

### 6.12 Operations, jobs and provider controls

Planned implementation: Phase 0–6. Baseline tickets: BL-003–BL-006, BL-020, BL-021, BL-038–BL-044. Each requirement is mandatory for the phase in which the capability is enabled; optional features remain disabled until their separate gates pass.

| ID / capability | Required behavior (shall) | Acceptance evidence |
| --- | --- | --- |
| BL-FR-084<br>Provider register | Every generation, embedding, reranking or external OCR route shall identify approved profile, data classes, processing geography and retention terms. | An unapproved profile or data class fails before transmission. |
| BL-FR-085<br>No silent fallback | The system shall fail closed when no approved route exists rather than silently change model, region or content policy. | A provider outage cannot route India-only/private content to an unapproved destination. |
| BL-FR-086<br>Durable queues | Workers shall use durable state, leases, heartbeats, bounded retries and dead-letter handling for every background stage. | Crash and duplicate-delivery tests prove recoverability without duplicate effects. |
| BL-FR-087<br>Usage ledger | The system shall reconcile reserved, actual and uncertain provider cost against run and tenant allowances. | Timeout and retry tests retain uncertain cost rather than assume zero usage. |
| BL-FR-088<br>Safe observability | Logs and traces shall record operational metadata without routine question bodies, private evidence, credentials or full model outputs. | Automated log inspection finds no protected fixture content or secrets. |
| BL-FR-089<br>Operational status | Operations views shall expose queue age, source lag, failures, review backlog, budget limits and service degradation. | Induced faults generate actionable alerts and visible states. |
| BL-FR-090<br>Controlled delivery | Deployment shall use reviewed infrastructure, pinned dependencies, tested migrations and explicit environment authorization. | A clean release can be reproduced; missing production approval blocks deployment. |
| BL-FR-091<br>Honest completion | Implementation reports shall distinguish implemented, tested, blocked, untested and deferred work with actual commands and outputs. | Mock tests, undeployed infrastructure and synthetic fixtures are not reported as production evidence. |

## 7. Data model and document requirements

The data model separates original source material, legal meaning, search copies and user activity. This separation prevents a search-engine update or a new model answer from silently altering the authority being cited. PostgreSQL owns canonical records; object storage owns original bytes; OpenSearch contains rebuildable search projections. [B01, §§3–4; B04]

![Figure 09. Canonical legal data: identities, versions and evidence](diagrams/08_corpus_erd.svg)
This is a conceptual relationship diagram, not a complete physical schema. Stable document and legal-unit identities can have multiple versions. Source spans refer to exact unit versions, and releases pin approved snapshots.

### 7.1 Principal data objects

| Object | Essential information | Integrity rule |
| --- | --- | --- |
| Source / policy | Name, access route, rights evidence, allowed uses, reviewer, validity and attribution | Permission for one use never implies permission for every use. |
| Original artifact | Source locator, media type, byte size, SHA-256, fetched time and object version | Original bytes are immutable and distinct from corrected extraction text. |
| Legal document | Stable ID, type, title, language, jurisdiction and citation aliases | A case name, case number and individual decision are not interchangeable IDs. |
| Document version | Edition/correction identity, artifact lineage, parser/extraction reference and review state | New content creates a new version; released evidence is not overwritten. |
| Legal unit / version | Article/section/paragraph hierarchy; stable unit ID; versioned exact text and text hash | Identifiers survive wording changes; separate versions hold different wording. |
| Source span | Unit version, code-point offsets, quote hash, page/paragraph labels and optional bounding box | Offsets and hashes resolve to the exact canonical excerpt. |
| Applicability assertion | Provision version, legal interval, knowledge interval, territory, conditions and evidence | Unknown commencement remains unknown; approved assertions are attributable. |
| Citation / treatment | Original mention, resolved identity, proposition, relation, evidence span and reviewer | Cites is not equivalent to follows, distinguishes or overrules. |
| Corpus release | Concrete indexes, unit members, policy/temporal/graph snapshots, profile and manifest hashes | A run uses a fixed release; current takedowns still override serving. |
| Research / answer | Actor scope, request/plan, evidence handles, profiles, claims, checks, costs and revisions | An answer cannot cite evidence outside its run or override authorization. |

### 7.2 Three representations of one document

| Representation | Example contents | Permitted use |
| --- | --- | --- |
| Original | Official PDF or approved HTML bytes and provenance | Source verification, lawful display and reconstruction. |
| Canonical legal text | Exact section/paragraph text and structural anchors | Quotations, citation verification and reviewed legal interpretation. |
| Search projection | Heading path, retrieval chunk, metadata and embedding | Finding candidate passages; not authoritative quotation. |

A long provision may be split into multiple retrieval chunks, but its legal identity remains intact. The evidence builder must recover material definitions, exceptions, provisos and table notes. A derivative summary or hypothetical search expansion must be labeled and versioned separately, excluded from authoritative quotation.

### 7.3 Source-anchor contract

| Field / concept | Required meaning |
| --- | --- |
| unit_version_id | The exact version of the legal unit being cited. |
| char_start / char_end | Unicode code-point offsets in a half-open interval [start, end); browser code must convert correctly. |
| source_sha256 on a citation | Hash of the containing canonical unit text in UTF-8, as defined by the baseline contract. |
| quote_sha256 | Hash of the exact quoted excerpt; it is not the original file hash. |
| artifact hash | Hash of the original source bytes; separate from unit and excerpt hashes. |
| Page and paragraph anchors | One-based PDF page index, original printed page label if present, and original paragraph label only if it exists. |
| Bounding box | Optional normalized coordinates with an explicitly defined origin and page rotation handling. |
| Serialization profile | Named, versioned canonical JSON serialization for structured-object hashing. |

### 7.4 Synthetic historical example

> **Training example — not Indian law**
> A fictional Act A, section 4 has wording A valid from 1 January 2020 to, but not including, 1 January 2024. Wording B begins on 1 January 2024. A query for 31 December 2023 selects A; a query for 1 January 2024 selects B only if reviewed commencement and scope evidence support that date.

If the platform learns a correction later, it closes the previous knowledge interval and records a new assertion. Earlier research runs retain the snapshot used at the time. The system must distinguish a historical legal fact from when BharatLaw learned that fact. Later interpretations may appear in retrospective mode, but they must be explicitly identified.

![Figure 10. Application data: permissions, runs, claims and sources](diagrams/09_application_erd.svg)
User data has two access boundaries: organization and workspace. Claims link to a run’s authorized evidence, which in turn resolves to exact public or private source spans. The complete physical table inventory appears in Appendix A.

### 7.5 Cross-record invariants

Use composite tenant-aware relationships for tenant-owned data, and workspace-aware relationships where applicable. Database row security is defense in depth; a permission service still checks workspace scope. Publication validators must reject synthetic material, missing rights, unresolved essential checks, invalid snapshot membership and incompatible embedding profiles. These invariants require actual database and service integration tests, not only JSON validation.

Private and public evidence use separate structures. Private cross-tenant deduplication must not reveal that another organization possesses the same file. Indexes and caches must carry scope and version keys; restore procedures must replay current restrictions. The baseline reference SQL has 60 tables, listed in Appendix A, but implementation remains phased.

## 8. Search, RAG and citation-graph design

RAG means retrieval-augmented generation: the system finds evidence first and asks the model to explain that evidence second. The model does not decide whether it is allowed to access a source, whether a statute is operative, or whether an answer has passed release checks.

![Figure 11. Hybrid search with canonical evidence verification](diagrams/10_retrieval.svg)
Lexical search finds exact words and legal identifiers. Semantic search finds related meaning. The merged candidates are reranked and checked against canonical source records before they can become evidence.

### 8.1 Search indexes

| Index family | Purpose | Required constraints |
| --- | --- | --- |
| bl-public-documents-<release> | Titles, IDs, aliases, court/source and date metadata | Published release; approved source; no restricted or synthetic production record. |
| bl-public-chunks-<profile>-<release> | Lexical and vector search over approved legal passages | Strict fields; exact legal identifiers; compatible model profile; canonical source pointer. |
| bl-private-chunks-<profile>-<generation> | Private workspace search | Tenant/workspace/permission revision/active state inside both retrieval branches; no wildcard public/private query. |

The baseline mapping specifies strict fields and a 1024-dimensional reference vector. That dimension is a fixture, not an approved production model choice. A real model/profile change requires a new compatible index and measured evaluation. The baseline Lucene/HNSW/cosine configuration must be applied and tested against the chosen supported OpenSearch version before relying on its behavior. [B01, §6; B06]

### 8.2 Initial tuning defaults, not performance claims

| Setting | Initial value | Why it exists |
| --- | --- | --- |
| Lexical / vector candidates | 80 per branch | Gather a bounded candidate pool before reranking. |
| Rank-fusion constant | 60; one-based ranks | Combine rank positions without pretending scores represent legal authority. |
| Rerank cap | 80 candidates | Control model latency and cost. |
| Evidence passages / token budget | Approximately 12–20 passages; 12,000 tokens | Keep source context bounded while retaining material qualifications. |
| Search variants / graph neighbors | 3 variants; 20 neighbors | Limit expansion, latency and adversarial token consumption. |
| Ordinary chunk target | 350–700 tokens; ordinary maximum 1,000 | A starting retrieval setting, not a limit on legal-unit size. |

Evaluate changes against lawyer-annotated questions. A higher aggregate recall score must not be obtained by leaking private passages, ignoring relevant dates or omitting legal qualifications. When essential context cannot fit, narrow the question or state the limitation.

### 8.3 Evidence-pack contract

Each evidence item needs a server-issued handle, public/private source class, canonical span reference, current access decision, release/version provenance, exact text and applicable legal metadata. Keep user facts separate from authority. Before every provider call, recheck current permission, permitted processing route, rights, budget and input size. A citation resolver, not the model, turns handles into displayed citations.

### 8.4 Legal authority and contrary material

Use retrieval relevance to find candidates, not to settle precedent. Preserve court, bench information, opinion role, relevant issue, procedural context, legal date, jurisdiction and reviewed treatment. Recency, citation counts or similarity scores are not enough to decide a legal conflict. Where the corpus cannot establish a conclusion, display the conflict and the evidence rather than assert an unsupported hierarchy result.

![Figure 12. Evidence-backed legal relationships (synthetic example)](diagrams/12_citation_graph.svg)
The example uses fictional decision labels. A citation is a basic link. A treatment relationship such as “distinguishes” requires source evidence, proposition scope and review; it is not inferred merely because one decision mentions another.

### 8.5 Cache and reproducibility policy

Cache keys must bind tenant/workspace where relevant, permission revision, question/plan, corpus release, processing policy, model/prompt/verifier profiles and source restrictions. Reauthorize before serving cached private evidence or answers. A cache hit must not resurrect withdrawn content. Historical reproducibility preserves identity and audit records; it does not override current access restrictions.

## 9. Bounded agents and workflow state

An agent is a controlled program that may ask a model to choose among allowed research actions. BharatLaw begins with one research coordinator and logical stages, not a fleet of unconstrained autonomous bots. Framework selection is an implementation choice; the required controls remain the same. [B01, §9; B03]

| Logical stage | Input | Output / restriction |
| --- | --- | --- |
| Planner | Question, workspace policy, dates and coverage | Typed plan or clarification; cannot grant tools or decide permissions. |
| Legislation researcher | Approved provision searches and date scope | Candidate provisions, versions and commencement evidence. |
| Case-law researcher | Approved case searches and issue scope | Relevant decisions, passages and opinion metadata. |
| Contrary researcher | Proposed issue/proposition and known evidence | Potential limiting or adverse material plus search coverage. |
| Synthesizer | Server-approved evidence pack | Structured candidate claims using issued evidence handles only. |
| Verifier | Candidate answer, canonical evidence and policies | Integrity/support outcomes; automated checks are not human review. |
| Publisher | Eligible answer and current access/rights state | Final answer, qualified partial result, review request or abstention. |

### 9.1 Allowed tools and explicit prohibitions

Allowed tools are typed, read-only capabilities such as search_statutes, search_cases, get_source_span, get_version_history and get_treatment_evidence. The model receives no shell, raw SQL, arbitrary network fetch, credentials, unrestricted object-storage access, email, payment or court-filing capability. Retrieved document instructions are treated as data, not as operating instructions.

| Control | Initial maximum / rule |
| --- | --- |
| Tool calls | 8 per run |
| Parallel research branches | 2 |
| Answer repair | 1 attempt |
| Clarification rounds | 2 |
| Quick / deep deadlines | 60 / 120 seconds as initial policy limits, separately measured against SLOs |
| Spend | Per-run and tenant allowance; the baseline USD 2 fixture is not a price quote or approved production budget. |
| Fallback | Only separately approved model and processing routes; otherwise fail closed. |

![Figure 13. Research lifecycle and user-visible outcomes](diagrams/11_run_states.svg)
The stored research-run states are the implementation baseline. Progress labels and events must map to these states. “Partial” and “abstained” are valid research outcomes, not necessarily infrastructure failures.

### 9.2 State consistency and cancellation

State changes use durable compare-and-set transitions and worker leases. A late worker must not overwrite a completed, cancelled or failed terminal result. The API may acknowledge a cancellation request before an external call returns, but it must not claim that already-transmitted content was recalled. Track the request separately from terminal state and reconcile uncertain charges.

The baseline narrative mentions “created” and “cancelling,” while the reference SQL does not store those values. Resolve this in an ADR and synchronized schema/API migration; do not insert undeclared enum values. Answer lifecycle (draft/verified/published/withdrawn), answer response outcome (answered/partial/abstained/needs_clarification) and worker job state are different state machines and must not be conflated.

## 10. APIs and external interfaces

The baseline OpenAPI contains 45 operations, reproduced in Appendix B. Endpoints described here are requirements, not live services. Implement request/response models from the approved contracts and test drift between backend, frontend and JSON schemas. [B03, B05]

### 10.1 Request and response conventions

| Area | Required convention |
| --- | --- |
| Authentication | Validated identity; a tenant selector is a request to choose an organization, not proof of membership. |
| Mutation idempotency | Tenant + actor + operation + key scope. Same key/body returns the same intended resource; same key/different body returns conflict. |
| Research creation | Create queued state, budget reservation, idempotency record and outbox event transactionally; return 202 with run links. |
| Pagination | Opaque, bounded cursors tied to scope, filters and release; reject cross-scope replay. |
| Errors | Safe problem code, request ID and actionable message; no SQL, secrets, storage paths or hidden resource existence. |
| Events | Ordered event IDs, authorized replay and periodic access checks; no raw drafts or hidden model reasoning. |
| Contract changes | Version schema and migrations together; reject unexpected fields; document compatibility and rollout. |
| Health endpoints | Expose only necessary readiness/liveness information without credentials or sensitive topology. |

### 10.2 Research input, explained

| Field | User meaning / validation |
| --- | --- |
| workspace_id | The matter or research area the user is authorized to use. |
| question | The actual question; baseline length is 3–12,000 characters. |
| language | English initially; Hindi exists in the schema but remains feature-gated. |
| research_mode | Contemporaneous research or retrospective analysis using clearly identified later interpretations. |
| depth | Quick or deep, each with an enforced execution/cost policy. |
| jurisdiction_key | The relevant territorial/court scope; clarify material ambiguity. |
| event_date | Date of the facts, where relevant; may be unknown. |
| law_as_of | Date for determining the applicable provision text. |
| authority_cutoff | Cutoff for authorities considered; distinct from the event date. |
| include_private_documents | Explicit inclusion choice; effective only with access and a passed private launch gate. |
| corpus_release_id | Optional requested release; the server resolves and validates accessible membership. |

### 10.3 Error and recovery behavior

| Code / condition | User-visible behavior |
| --- | --- |
| TENANT_SELECTION_REQUIRED | Ask the user to select an organization they belong to. |
| WORKSPACE_ACCESS_DENIED | Deny access without confirming hidden matter details. |
| CORPUS_NOT_READY / SOURCE_UNAVAILABLE | Show coverage or availability limits; offer healthy catalog paths where permitted. |
| SOURCE_RIGHTS_BLOCKED | Do not retrieve, transmit or display the material for that operation. |
| TEMPORAL_SCOPE_UNRESOLVED | Ask for material dates/conditions or issue a qualified result. |
| PROVIDER_ROUTE_UNAPPROVED | Block transmission; never silently weaken geography or privacy policy. |
| BUDGET_EXCEEDED | Do not start additional chargeable work; preserve current results and explain the limit. |
| EMBEDDING_PROFILE_MISMATCH | Stop incompatible retrieval/indexing and alert operations. |
| CITATION_VERIFICATION_FAILED | Apply one permitted repair, then omit, qualify or abstain. |
| UPLOAD_QUARANTINED / LEGAL_HOLD | Show quarantine or retention status without treating the operation as complete. |
| IDEMPOTENCY_CONFLICT | Reject different request content reusing the same key. |

### 10.4 External integration contracts

Identity, object storage, approved acquisition sources, model providers, OpenSearch, PostgreSQL and work queues are explicit integration boundaries. Adapter contracts must define authentication, timeout, retry, cancellation, payload limits, safe logging, regional/data policy and test evidence. Source adapters do not assume a supported bulk API. Live credentials, paid calls, acquisition and production deployment each require their own approval; generating code does not grant it.

## 11. Security, privacy and legal operational controls

Security decisions belong to deterministic application code and approved policy, not to the model. Treat source files, OCR output, websites, uploads, questions and model responses as untrusted input. Private legal questions can disclose confidential facts even when all retrieved authorities are public. [B07]

### 11.1 Principal trust boundaries

![Figure 14. Application components and replaceable services](diagrams/13_components.svg)
Only the application and its scoped workers interact with data services. The browser and model cannot choose raw database or search operations. Original storage, canonical records and search projections have separate responsibilities and permissions.

| Threat / failure | Required prevention and detection |
| --- | --- |
| Cross-organization or cross-matter exposure | Non-owner application database role, tenant row security, explicit workspace checks, scoped search and adversarial two-tenant tests. |
| Stale access during a long run | Permission revisions, current checks before model transmission/publication/download, cache invalidation and stream termination. |
| Malicious or oversized documents | Quarantine, signature/checksum validation, isolated no-network parsing and bounded CPU/memory/page/decompression limits. |
| Indirect prompt injection | Untrusted-content separation, typed read-only tools, server budgets, no model-controlled permissions and adversarial fixtures. |
| Network fetch abuse / SSRF | Allowlisted acquisition routes, redirect revalidation, private/link-local/metadata address denial and restricted worker egress. |
| Fabricated citations or quotations | Issued evidence handles, canonical-span/hash checks, claim-support evaluation and bounded abstention behavior. |
| Stored XSS or exfiltration through output | Safe rendering, no executable model HTML, block unsafe URLs and remote image fetches. |
| Leaked credentials or private logs | Managed secrets, task identities, payload-safe logs, secret scanning and controlled audit access. |
| Restricted material restored from backup | Independent restriction/deletion ledger replay before reopening restored services. |
| Uncontrolled token or financial consumption | Input limits, quotas, run/tenant cost reservations, retry bounds, provider throttles and cost alerts. |

### 11.2 Privacy and confidentiality policy

Maintain a counsel-approved obligation register before processing real private matters. For each obligation record the legal entity/role, data class, purpose, applicable rule, effective date, retention minimum/maximum, legal-hold precedence, reporting trigger/deadline, source evidence and reviewer. This SRS does not state that any particular statutory deadline or rule is universally applicable. Current Indian data protection, IT/CERT-In obligations, confidentiality, publication restrictions and source licensing require qualified review before launch.

Private retention values remain unset until approved. Separate immediate access withdrawal from lawful retention and physical erasure. Cover original files and versions, extracts, vectors, indexes, caches, exports, checkpoints and provider-held data subject to verified contracts. Do not promise provider deletion features or residency that have not been confirmed. Immutable audit archives and erasable customer files need different policies.

### 11.3 Provider and processing-location control

Approve generation, embeddings, reranking, external OCR, tracing and support access independently. The provider register must identify exact profile/version, permitted data classes, geography, retention/training terms, subprocessors, budget rates and outage behavior. An India-only policy must validate the actual processing route; an Indian database location alone is insufficient. No silent cross-region or unapproved model fallback is allowed.

### 11.4 Release and review separation

Source approvals, legal assertions, processing-policy changes and production publication need their designated reviewers. Sensitive publication/policy actions require an independent second reviewer under the approval matrix. A legal editor does not automatically receive access to all private workspaces. The product must not represent itself as a licensed advocate or imply that a lawyer-client relationship is automatically created. The research warning supplements the controls; it does not excuse unsupported output.

## 12. Deployment, operations and recovery

The architecture begins as a modular application with separately runnable workers. This reduces unnecessary distributed-system complexity while preserving separate security roles and resource limits. Local development is reproducible; staging and production are independently approved. No Kubernetes cluster, graph database or GPU training infrastructure is required for the first release. [B01, §11; B07]

![Figure 15. Proposed AWS deployment and security zones](diagrams/14_aws.svg)
This is the proposed deployment, not an existing installation. Account separation, private networking, scoped service roles, approved model routes and measured recovery are requirements. Exact instance sizes and cost are selected after testing.

### 12.1 Infrastructure responsibilities

| Component | Proposed responsibility | Required operational control |
| --- | --- | --- |
| Route 53 / ACM / ALB / WAF | DNS, TLS, authenticated ingress and request protection | No public database/search endpoints; rate limits and safe headers. |
| ECS Fargate | Web/API and separate acquisition, parser, indexer, research and export workers | Different task roles, egress and resource limits; pinned images. |
| RDS PostgreSQL | Canonical catalog, permissions, temporal history, graph, runs and audit metadata | Private networking, tested migrations, backups/PITR and runtime privilege tests. |
| Managed OpenSearch | Public catalog/chunk and isolated private retrieval projections | Strict mappings, approved version, access segregation, rebuild/rollback tests. |
| S3 with KMS | Original artifacts, quarantine, private files, release manifests and exports | Distinct policy domains; checksum/object-version validation; retention-aware deletion. |
| SQS / dead-letter queues | Durable workload notifications | Idempotent consumers, leases, retry limits, visibility/heartbeat and DLQ runbooks. |
| EventBridge | Approved periodic source discovery/reconciliation | Respect source permissions and show missed/stale synchronizations. |
| Secrets / observability / CI | Managed credentials, safe monitoring, artifact build and approved delivery | No static secrets; separate environments; reviewed infrastructure plans and release evidence. |

### 12.2 Environments and deployment flow

Use separate development, staging and production accounts or equivalently reviewed isolation, with distinct keys, secrets and datasets. The proposed primary AWS region is ap-south-1. A multi-AZ arrangement does not, by itself, define a cross-region disaster-recovery strategy. Confirm the availability and approved data route of every selected service before deployment.

A release pipeline builds from locked dependencies, runs lint/type/contract/unit/security checks, tests actual database/search integrations, produces pinned images and reviews migrations and Terraform. Staging deployment and smoke tests precede production approval. Rollback must preserve schema compatibility and must not reactivate prohibited sources. No real private legal material belongs in source control or routine test fixtures.

### 12.3 Monitoring and support

Monitor retrieval latency and recall, claim-support failures, quotation mismatches, permission denials, queue age, source freshness, indexing failures, review backlog, uncertain provider costs, budget limits, deletion backlog and export failures. Alerts need an owner, severity and runbook. A healthy HTTP response is not proof that legal source coverage is current or that every bulk-index item succeeded.

### 12.4 Backup, restore and service degradation

Preserve authorized original artifacts and immutable release manifests. Back up canonical metadata and test a real restore into an isolated environment. Search is rebuildable, but a broad reindex may take longer than the service recovery target. Define degraded source-viewing/lexical behavior and measure semantic-search restoration separately. Replay current access, deletion and takedown controls before restored data can be served.

### 12.5 Cost model and limits

Budget separately for fixed application/database/search/network capacity, storage and backups, document extraction/embedding, query embedding/reranking/generation, and observability/egress. Use current approved unit prices and measured workload—not a universal monthly-price claim. Per-run reservations, tenant limits, concurrency bounds and token budgets must operate before chargeable calls. Record costs that remain uncertain after a timeout.

## 13. Nonfunctional requirements and service targets

These are proposed acceptance requirements and measurable service targets. They must be approved, tested and reported with workload and environment. “Zero known critical failures” means the declared release suite, not a guarantee of zero failure on every unseen legal question. [B01, §§11–13]

| ID / quality | Requirement / proposed target | Measurement or acceptance evidence |
| --- | --- | --- |
| BL-NFR-001<br>Search responsiveness | At 100,000 chunks and 10 concurrent researchers on the declared environment, target search p95 below 3 seconds. | Record p50/p95/p99, request count, warm/cold conditions and failed requests. |
| BL-NFR-002<br>Quick research | On the same declared pilot workload, target quick-research p95 below 60 seconds with approved provider profiles. | Measure the full workflow, including retrieval, provider time and verification. |
| BL-NFR-003<br>Availability | Target 99.9% monthly production availability after operational validation; define included routes and outage accounting. | Calculate a declared monthly indicator; do not advertise the target as achieved before measurement. |
| BL-NFR-004<br>Recovery point | Target metadata RPO of 15 minutes with the configured backup/PITR strategy. | A restore drill identifies the recoverable point and actual data loss interval. |
| BL-NFR-005<br>Recovery time | Target service RTO of 4 hours, with semantic index recovery measured separately and degraded mode documented. | A timed restore/rollback exercise includes access and deletion replay. |
| BL-NFR-006<br>Scale qualification | Test 100,000 chunks for pilot and 1 million before broad-corpus release. | Report index size, recall, latency, concurrency, cost and rebuild duration. |
| BL-NFR-007<br>Citation integrity | Every served citation must pass current identity, source, release and access checks. | Per-answer deterministic gate plus adversarial cross-run/release/permission fixtures. |
| BL-NFR-008<br>Quotation integrity | Every served quotation must exactly match its canonical approved span. | Unicode, ligature/extraction, offset and tampered-quote tests pass. |
| BL-NFR-009<br>Retrieval quality | Proposed Recall@20 at least 0.90 on lawyer-annotated relevant authorities. | Report dataset size, denominator, category breakdown and uncertainty, with held-out separation. |
| BL-NFR-010<br>Claim support | Proposed at least 95% of substantive claims supported on independent review, with no unresolved critical defect. | Review claim-level support and qualifications; real citations alone do not count as support. |
| BL-NFR-011<br>Contrary evidence | Proposed at least 90% recall on annotated known adverse/limiting-authority cases. | Report the known-reference denominator and corpus coverage; do not claim a complete citator. |
| BL-NFR-012<br>Scope and temporal safety | Zero known critical wrong-version, wrong-jurisdiction or opinion-attribution failures in the release suite. | Boundary, unknown commencement, dissent and saving/transitional fixtures pass. |
| BL-NFR-013<br>Tenant confidentiality | Zero unauthorized content or source identity exposure in the declared isolation test suite. | Check results, provider payloads, logs, events, caches, exports and restore behavior. |
| BL-NFR-014<br>Bounded execution | All requests, tools, retries, files and provider calls shall obey configured time, size, cost and concurrency limits. | Adversarial loops and oversized files terminate safely with correct usage status. |
| BL-NFR-015<br>Accessibility | Target WCAG 2.2 AA for enabled user journeys, subject to audit; provide keyboard navigation and accessible source text. | Automated checks plus manual keyboard, screen-reader, focus and contrast review. |
| BL-NFR-016<br>Usability | A new user shall be able to ask a question and locate its cited passage without technical terminology being required. | Observed pilot tasks capture success, time, confusion and actionable findings. |
| BL-NFR-017<br>Maintainability | Use modular boundaries, pinned dependencies, schema versioning and documented configuration; no hard-coded secrets or source hosts. | Clean-clone setup, contract drift checks, migration tests and dependency review pass. |
| BL-NFR-018<br>Security launch gate | No unresolved critical/high security finding may remain for the enabled production scope. | Independent security evidence, remediation and regression results are recorded. |
| BL-NFR-019<br>Observability and privacy | Operational diagnosis shall be possible through safe identifiers and metrics without routine private payload logging. | A fault investigation succeeds using permitted logs; protected fixture text is absent. |
| BL-NFR-020<br>Reproducibility | Research history shall preserve release, source, model/prompt, policy and verification identity, subject to current restrictions. | A stored run’s evidence and configuration can be reconstructed without silently altering it. |

## 14. Test strategy and user acceptance

Testing must establish actual behavior, not just the appearance of a complete code repository. Unit tests prove local logic; contract tests prove data shape; database/search integration tests prove service behavior; browser tests prove user journeys; legal evaluation assesses supported conclusions. No one layer substitutes for the others.

### 14.1 Test layers and ownership

| Layer | Required examples | Owner / evidence |
| --- | --- | --- |
| Unit / property tests | Offsets, hashes, rank fusion, date boundaries, budgets and state transitions | Engineering; executable test results and edge-case fixtures. |
| Contract tests | OpenAPI/JSON validation, strict field rejection, frontend/backend type compatibility | Engineering/QA; versioned contracts and drift report. |
| Database integration | Actual PostgreSQL migrations, constraints, runtime roles, row security and temporal queries | Backend/security; real application role, not an administrator test shortcut. |
| Search integration | Applied mappings, inner scope filtering, profile mismatch, candidate fusion and release switching | Retrieval team; actual supported engine and measured queries. |
| Browser end-to-end | Import → source viewer; research → citation; revocation → denied export | QA; recorded workflow outcomes with positive and negative paths. |
| Legal evaluation | Relevant authority, material claim support, contrary evidence, dates, opinions and abstention | Qualified Indian legal reviewers; versioned gold set and held-out results. |
| Security / resilience | Injection, malicious files, scope abuse, duplicate jobs, outages, backup restore and deletion replay | Security/operations; findings, remediation and drills. |
| Performance / cost | Declared corpus/concurrency, latency percentiles, recall and provider consumption | Engineering/product; reproducible workload and cost report. |

### 14.2 Acceptance scenarios

| Scenario | Test | Pass condition | Workflow |
| --- | --- | --- | --- |
| UAT-01 | Valid and invalid sign-in | An authorized researcher enters a workspace; expired/wrong-audience tokens fail. | WF-01 |
| UAT-02 | Cross-tenant selector attack | A supplied foreign tenant/workspace ID returns no protected data or existence detail. | WF-01 |
| UAT-03 | Exact source lookup | A known fixture provision opens its exact text and original page. | WF-03 |
| UAT-04 | Unverified case identity | An invented or ambiguous citation does not become a fabricated verified case. | WF-03 |
| UAT-05 | Supported research answer | The final answer links each substantive legal proposition to supporting run evidence. | WF-02 |
| UAT-06 | Material missing facts | The system asks a focused clarification, then records assumptions or abstains within its limit. | WF-02 |
| UAT-07 | No evidence available | The product returns an honest evidence-limited result, not a guessed authority. | WF-02 |
| UAT-08 | Tampered quotation | A one-character quote change fails deterministic checks and cannot be published as an exact quote. | WF-04 |
| UAT-09 | Real source, wrong proposition | A valid citation with unsupported analysis fails claim-support review. | WF-04 |
| UAT-10 | Unknown commencement | No unqualified operative-law conclusion appears when the effective date is unresolved. | WF-05 |
| UAT-11 | Half-open boundary date | The synthetic version ending at a boundary is excluded on that boundary date. | WF-05 |
| UAT-12 | Later interpretation | Contemporaneous and retrospective modes treat a later decision differently and visibly. | WF-05 |
| UAT-13 | Duplicate import | Repeated delivery yields one intended import/version effect with attempt history. | WF-06 |
| UAT-14 | Changed bytes at same URL | New bytes create a new version without altering earlier evidence. | WF-06 |
| UAT-15 | Bad scan or missing exception | The document remains under review/quarantine and does not become published authority. | WF-06 |
| UAT-16 | Synthetic production material | A production release containing a synthetic fixture is rejected. | WF-06 |
| UAT-17 | Private feature gate | Unapproved private processing prevents upload and provider transmission. | WF-07 |
| UAT-18 | Malicious upload | A malicious/oversized/unsupported PDF remains isolated and unavailable for research. | WF-07 |
| UAT-19 | Mid-run revocation | Removed workspace access blocks further private transmission, final publication and streams. | WF-10 |
| UAT-20 | Private facts versus authority | Uploaded case facts are labeled as private material, not legislation or a court holding. | WF-07 |
| UAT-21 | Export approval and access | An export requires policy approval and fresh authorization at download. | WF-08 |
| UAT-22 | Source takedown | Serving is blocked immediately and earlier answers show appropriate availability limits. | WF-09 |
| UAT-23 | Legal hold and deletion | Access is withdrawn, held material is restricted, and erasure status is accurate. | WF-10 |
| UAT-24 | Worker crash and duplicate event | A durable checkpoint resumes safely without duplicate answer publication. | WF-11 |
| UAT-25 | Provider outage / wrong region | No unapproved fallback occurs; healthy catalog functionality remains available. | WF-11 |
| UAT-26 | Cancellation race | A late worker cannot publish after cancellation; uncertain external cost is retained. | WF-11 |
| UAT-27 | Prompt injection in source | Document instructions cannot grant tools, disclose secrets or cross scope. | WF-02 / WF-07 |
| UAT-28 | Budget exhausted | No new chargeable action begins after the permitted allowance is exhausted. | WF-11 |
| UAT-29 | Restore deleted content | Restoration replays restrictions before reopening; deleted/restricted data is not searchable. | WF-12 |
| UAT-30 | Critical release defect | An unresolved critical legal/security defect blocks launch despite passing average metrics. | WF-12 |

### 14.3 Legal evaluation dataset

Begin with at least 100 lawyer-annotated constitutional questions for retrieval, then expand toward at least 500 before broader V1 scope. Keep development, validation and held-out sets separate by question/issue/source family to reduce leakage from paraphrases and near duplicates. Include lookup, synthesis, false citations, missing sources, exceptions, adverse authority, historical cutoffs, opinion attribution and deliberately unanswerable questions. Report results by category, not only an overall average.

### 14.4 Severity and release rules

**Critical:** unauthorized disclosure, invented authority, or materially misleading operative-law/version behavior. **Major:** misstated holding, missing important limiting evidence or material workflow failure. **Minor:** nonmaterial display or formatting issues. Critical defects block affected release scope even when aggregate scores are high. Documented exceptions cannot convert an unresolved critical legal/security defect into a safe launch.

### 14.5 Evidence package for each milestone

Each milestone report must include implemented files, schema/contract changes, exact test commands, observed results, environment versions, coverage, failures, security/privacy implications, source/provider approvals, cost incurred where applicable, known limitations and rollback instructions. Separate implemented, tested, blocked, untested and deferred work. The earlier handoff reports reference/contract tests; that is not evidence that the full application, legal corpus or cloud deployment has been validated. [B08]

## 15. Phased delivery and Codex handoff

The detailed baseline ticket plan controls the phase numbering in this SRS. Work proceeds in small end-to-end increments, with reviewable changes and evidence at every gate. The public-source pilot may proceed without private workspaces; private functionality cannot bypass its separate approval gates. [B02]

| Phase | User-visible deliverable | Tickets | Exit gate |
| --- | --- | --- | --- |
| 0. Decisions and foundation | Scope, approvals/blocks, provider/source registers, repository and local tooling | BL-001–006 | Reproducible local setup; no unapproved acquisition, paid calls or production deployment. |
| 1. Canonical source viewer | Import approved material, inspect exact units/pages and publish a controlled corpus release | BL-007–013 | Real database/authorization tests; exact anchors and immutable provenance; synthetic production rejection. |
| 2. Retrieval before generation | Exact, lexical and vector search with reranking and context expansion | BL-014–019 | Actual engine integration; declared legal recall and access tests. |
| 3. Evidence-grounded answers | Bounded runs, structured claims, verification, safe progress and abstention | BL-020–026 | Every served citation/quote passes integrity; independent support evaluation; no silent fallback. |
| 4. Temporal law and graph | Version comparison, opinion separation and evidence-backed treatment/contrary research | BL-027–032 | No known critical wrong-version/false-treatment/opinion defect in the suite. |
| 5. Bounded research and private matters | Controlled tools, gated private uploads, revocation, retention and safe exports | BL-033–037 | Private processing, retention, provider and isolation approvals/tests complete. |
| 6. Staging and limited launch | Infrastructure, performance/recovery drills, legal/security review and pilot operations | BL-038–044 | Explicit deployment approval, no unresolved critical/high security findings and documented support ownership. |

### 15.1 Ticket acceptance summary

| Ticket | Deliverable | Acceptance evidence from the baseline plan |
| --- | --- | --- |
| BL-001 | Scope, audience, languages, court/date coverage and out-of-scope record | Signed/approved product decision file; no “all Indian law” claim |
| BL-002 | Source/rights register with independent operation permissions | Manual import path works; unapproved fetch/index/model/display operations denied |
| BL-003 | Provider/data-processing register | Exact profile/region/retention/pricing identified or explicitly blocked; private mode off |
| BL-004 | Monorepo, dependency locks, Python/Node tooling, local containers | Clean clone starts API/web and dependencies with documented commands |
| BL-005 | CI lint/type/unit/contract/security jobs and secret scanning | Green actual execution; no disabled checks called “passed” |
| BL-006 | Architecture decisions and threat model | Decisions cover source truth, temporal scope, indexes, tenant boundary and model gateway |
| BL-007 | Alembic migrations from reviewed reference DDL | Up/down-or-forward-repair migration strategy tested on supported PostgreSQL; constraint tests |
| BL-008 | Runtime DB roles, tenant RLS and workspace policy | Two-tenant/two-workspace isolation tests execute with real application role |
| BL-009 | Manual import manifest and immutable artifact storage | Hash/media/source-policy checks, duplicate import and changed-byte versioning tests |
| BL-010 | PDF/text parser with exact legal-unit/source-span mapping | Hand-checked pages; Unicode offsets and missing paragraph numbers handled honestly |
| BL-011 | Quarantine, extraction review and editorial approval UI | Bad scans/ambiguous parsing stay unpublished; reviewer audit captured |
| BL-012 | Catalog, article/section lookup and evidence viewer | Browser can open exact original page/excerpt; content rights respected |
| BL-013 | Corpus release manifest and publication/rollback | Chunks + unit versions + temporal/graph snapshots pinned; synthetic production rejection |
| BL-014 | Exact identifier/citation resolver | Ambiguous/malformed/unknown cases not silently invented |
| BL-015 | OpenSearch concrete public indexes and rebuild job | Exact mapping applied to selected actual engine; strict-field rejection and hashes verified |
| BL-016 | Typed lexical/vector query gateway | Identical safe filters; Lucene inner k-NN filter integration tests |
| BL-017 | Application RRF + approved reranker adapter | Duplicate handling, deterministic ties and measured retrieval comparison |
| BL-018 | Definition/proviso/exception and neighbor expansion | Required context included within budget; citations use original text, not summaries |
| BL-019 | First legal-editor gold retrieval set | >=100 questions with acceptable evidence and date/jurisdiction scopes, held-out split |
| BL-020 | Replaceable generation/embedding/reranking gateway | Approved profiles, fake provider test adapter and explicit offline behavior |
| BL-021 | Run state, idempotency, checkpoints, outbox and budgets | Duplicate delivery, crash recovery, timeout-cost reconciliation and cancellation tests |
| BL-022 | Evidence-handle assignment and structured claim generation | Unknown handle/cross-run/cross-release references rejected |
| BL-023 | Canonical quote/citation verifier and release gate | Exact quote/hash/pinpoint tests; unsupported legal proposition never published unqualified |
| BL-024 | Semantic-support evaluation and human review state | Automated check is not labelled lawyer review; supported versus merely existing citation distinguished |
| BL-025 | Safe SSE and research UI | Only verified answer content published; disconnections/ACL revocation/replay tested |
| BL-026 | Honest coverage, assumptions, conflicts and abstention | Insufficient evidence yields transparent limited answer, not fabricated precedent |
| BL-027 | Bitemporal applicability, territory and conditions | Half-open boundaries, unknown commencement, saved knowledge snapshot and later correction tests |
| BL-028 | Amendment/commencement/repeal/saving workflow | Instrument and provision-level evidence present; no document-date shortcut |
| BL-029 | Opinion/argument/holding separation | Dissent, quoted authority and counsel argument cannot be presented as majority holding |
| BL-030 | Citation resolution and scoped treatment graph | Cites/follows/distinguishes/overrules represented separately; adverse treatment editorially reviewed |
| BL-031 | Supporting/contrary authority search | Reports coverage limits and unresolved conflicts; not a definitive citator badge |
| BL-032 | Version comparison and historical/retrospective UI | Legal date, authority cutoff and knowledge date visible and reproducible |
| BL-033 | Typed coordinator with statute/case/contrary subroutines | Eight-tool/two-parallel-worker/one-repair budget enforced server-side |
| BL-034 | Tool schemas, prompt-injection tests and output policy | Retrieved instructions cannot grant tools or cross boundaries |
| BL-035 | Upload sessions, isolated parsing and private indexes | Signed upload, checksum, MIME, malicious PDF and cross-workspace retrieval tests |
| BL-036 | Membership revocation, cache isolation and legal-source separation | Mid-run revocation prevents final publication; private text is not authoritative law |
| BL-037 | Retention/hold/deletion, safe exports and matter confidentiality | Approved obligation register; component erasure receipts; export authorization tests |
| BL-038 | Terraform modules and CI/CD | Format/validate/scan plus reviewed staging plan/apply; pinned images and versions |
| BL-039 | Scale and performance tests | Measured 100k/1m chunk tests, latency/concurrency/accuracy/cost report |
| BL-040 | Failure, restore and index rollback drills | Queue duplicates, DB restore, deletion replay and restricted-source rollback tested |
| BL-041 | Independent security and legal pilot review | Findings closed or deployment formally blocked; no “documented critical exception” launch |
| BL-042 | Monitoring, support and incident/deletion runbooks | Alerts reach owner; provider outage and source freshness states visible |
| BL-043 | Limited beta with scope/coverage disclosure | Release/model/policy versions, known limitations and approved user population recorded |
| BL-044 | Benchmark-driven next-phase decision | Expand only after observed utility, support quality and legal-review costs justify it |

### 15.2 First implementation increment

The first increment is: **import a clearly labeled fixture or approved document → preserve original bytes → parse exact legal units → open the source viewer → verify the quoted passage under correct authorization**. It needs no live model. Build the real database/security path early instead of creating a polished chatbot over unverified data.

### 15.3 Codex execution instructions

Place this SRS and its companion requirements register beside the original handoff. First inspect the repository and baseline contracts, record the phase/state discrepancies, and run available tests honestly. Implement Phase 0–1 before broad generation. Use real PostgreSQL for schema and row-security tests, documented local storage and explicit synthetic fixtures. Do not use fake success responses to hide missing source rights, credentials, model evaluation or deployment.

After each phase, produce a completion report and test evidence; update requirement status in the register through a reviewed change. Do not mark a feature production-ready because it compiles. Source acquisition, legal processing, paid model calls, private-data use and production deployment remain independent authorizations. The original CODEX_START_HERE.md continues to provide the detailed implementation prompt. [B09]

### 15.4 Schedule and resourcing

The original plan offers an indicative 12–18-week limited-pilot range assuming two backend/AI engineers, one frontend engineer and available legal/security reviewers. This is a baseline planning assumption, not a commitment or verified staffing fact. Source permission, legal editorial effort, procurement, integration problems and test outcomes determine the actual schedule. Broad all-India coverage is outside that estimate.

## 16. Decisions, risks, change control and approval

### 16.1 Decision register

| Decision | Owner | Required before |
| --- | --- | --- |
| Initial legal domain, court/date range and audience | Product + legal editorial | Real corpus publication |
| Acquisition, indexing, display and provider-transmission rights | Source/legal reviewer | Each affected source operation |
| Exact generation/embedding/reranking profiles and processing routes | Engineering + security/privacy | Any live provider transmission |
| Retention, legal holds, processor terms and private launch scope | Legal/privacy + security | Private uploads or private-content research |
| Budget, quotas, paid-service and cloud deployment authority | Product/finance + operations | Any paid call or cloud mutation |
| Identity provider, roles and export approval policy | Security + product | Authenticated pilot |
| Performance workload and accepted SLOs | Engineering + product + operations | Staging acceptance |
| Phase/state/schema conflict resolution | Engineering lead + product | Implementation baseline approval |
| Incident ownership, escalation and review response process | Operations + security + legal | Limited public or private launch |
| Hindi/additional court expansion and new evaluation sets | Product + bilingual/domain legal reviewers | Each expanded release |

### 16.2 Key risks and mitigation

| Risk | Mitigation / release response |
| --- | --- |
| Incomplete or inaccessible sources | Coverage labels, manual approved imports, source-specific rights and acquisition monitoring; do not claim completeness. |
| Wrong operative law or missed exception | Reviewed temporal evidence, preserved legal context and critical regression tests; restrict affected scope. |
| Incorrect precedent treatment | Evidence-backed, proposition-scoped relationships and qualified legal review; no automatic “good law” badge. |
| Provider or region policy drift | Pinned/approved profiles, periodic register review and fail-closed routing. |
| Private matter disclosure | Layered scope enforcement, prompt-injection tests, current authorization and safe export/deletion controls. |
| Unexpected cost or latency | Measured workloads, budgets, bounded agents and separate per-document/per-query cost accounting. |
| Overly broad initial scope | Deliver the exact-source viewer and curated corpus before expanding models, agents or legal domains. |
| Specification/code divergence | Requirement IDs, contract tests, ADRs, migration review and milestone evidence. |

### 16.3 Change-control procedure

Every material change records a change ID, reason, affected requirement IDs, data/API/security impact, migration plan, evaluation impact, approvers and effective release. Changes to source rights, provider routing, legal dates, citation treatment, permissions, deletion or release gates require the relevant legal/security reviewer. Update this SRS, machine-readable contracts, tests and traceability together; preserve prior approved versions.

### 16.4 Approval record

| Approval area | Required decision | Name / date / status |
| --- | --- | --- |
| Product | Scope, priorities and user experience accepted | Pending |
| Legal editorial | Corpus, authority treatment, uncertainty and evaluation controls accepted | Pending |
| Security/privacy | Identity, processing, isolation, retention and incident controls accepted | Pending |
| Engineering | Contracts, phases, state mappings and implementation approach accepted | Pending |
| Operations / deployment | Budget authority, monitoring, recovery and launch support accepted | Pending |

> **Approval is specific**
> Signing off this requirements document does not, by itself, authorize cloud spend, external communications, protected-source acquisition, private client-data use or production deployment. Those decisions are separately recorded.

## Appendix A. Complete reference database inventory

The baseline reference_schema.sql contains the following 60 tables. This inventory explains their purpose without requiring the reader to interpret SQL. The reference DDL is not a migration already proven against the selected PostgreSQL environment. Implement only the necessary phase subset, while preserving future identities and boundaries. [B04]

| Table | Plain-language responsibility |
| --- | --- |
| sources | Approved-source identity, access route and provenance registry. |
| source_policies | Versioned, use-specific rights and review decisions. |
| artifacts | Immutable original bytes, source metadata, storage versions and checksums. |
| documents | Stable identity of a legal instrument or judicial decision. |
| document_identifiers | Canonical identifiers, citation aliases and identity evidence. |
| document_versions | Editions/corrections of a document with artifact lineage. |
| extractions | Versioned parsing/OCR outputs, quality and review status. |
| courts | Court identifiers and metadata for legal scope. |
| judicial_details | Decision metadata, bench details and proceeding context. |
| case_identifiers | Case numbers and related judicial identifiers. |
| opinions | Separate opinion identity, authorship and majority/dissent classification. |
| legal_units | Stable structural units such as articles, sections and paragraphs. |
| unit_versions | Exact versioned legal text and hierarchy references. |
| source_spans | Exact citation excerpts, offsets, hashes and original anchors. |
| legal_events | Amendment, commencement, repeal and related events. |
| event_targets | Links from legal events to the affected provisions/objects. |
| applicability_assertions | Reviewed legal/knowledge time, territory and conditional applicability. |
| chunks | Rebuildable retrieval text linked to canonical source units. |
| embedding_profiles | Model/version/dimension and preprocessing identity. |
| chunk_embeddings | Vector artifacts and provenance for a chunk/profile. |
| citation_mentions | Raw cited text, resolution candidates and verification state. |
| propositions | Scoped legal propositions used to qualify treatment relationships. |
| legal_nodes | Graph identities for decisions, provisions and legal entities. |
| legal_edges | Evidence-backed citation/treatment/amendment relationships. |
| corpus_releases | Versioned corpus manifest, publication state and index identities. |
| release_members | Chunk membership of a particular corpus release. |
| release_unit_versions | Pinned canonical unit-version membership. |
| release_applicability_assertions | Frozen temporal assertion snapshots. |
| release_legal_edges | Frozen citation/treatment relationship snapshots. |
| release_citation_resolutions | Frozen citation-resolution snapshots. |
| publication_channels | Active release selections for approved serving channels. |
| ingestion_jobs | Durable import/processing stage and state. |
| job_attempts | Worker attempt, failure, retry and execution history. |
| outbox_events | Transactional events awaiting reliable dispatch. |
| editorial_reviews | Attributable review decisions for exact object versions. |
| takedowns | Current source/content restrictions that override serving. |
| tenants | Organization-level data and entitlement boundary. |
| users | Authenticated user identity references. |
| memberships | User membership and role within an organization. |
| workspaces | Matter/research areas inside an organization. |
| workspace_members | Matter-level access and membership. |
| private_documents | Private uploaded-document identity and lifecycle. |
| private_versions | Versioned private artifacts/extracted text. |
| private_spans | Exact private source excerpts and anchors. |
| private_chunks | Tenant/workspace-scoped retrieval projection metadata. |
| research_runs | Durable plan, scope, profiles and research state. |
| run_events | Ordered progress and finalization events. |
| run_evidence | Authorized evidence handles assigned to a specific run. |
| answers | Answer revisions, checks and publication state. |
| answer_claims | Structured material claims and support status. |
| claim_evidence | Links between claims and their run evidence. |
| verification_checks | Deterministic/semantic check results and provenance. |
| model_invocations | Provider requests, profiles, outcomes and uncertain attempts. |
| usage_ledger | Budget reservation, actual usage and reconciliation entries. |
| feedback | User-reported issues tied to exact research/source revisions. |
| export_jobs | Policy-scoped export generation and approval lifecycle. |
| deletion_requests | Access withdrawal, retention review and erasure progress. |
| legal_holds | Approved restrictions on physical erasure. |
| audit_events | Permission-scoped operational/security audit metadata. |
| idempotency_keys | Request identity and replay/conflict protection. |

## Appendix B. Complete API operation inventory

These are the 45 operations in the supplied OpenAPI reference. Exact payloads, security schemes and responses remain in contracts/openapi.yaml. The implementation must enforce the functional requirements even when a route is listed: a reserved private or administrative endpoint is not permission to enable it. [B05]

| Method | Route | Purpose |
| --- | --- | --- |
| GET | /health/live | Process health |
| GET | /health/ready | Dependency readiness |
| GET | /v1/me | Authenticated identity and tenant memberships |
| GET | /v1/coverage | Published source coverage |
| POST | /v1/search | Authorized hybrid legal search |
| GET | /v1/documents/{document_id} | Read a public legal document |
| GET | /v1/documents/{document_id}/units | Read structural units |
| GET | /v1/source-spans/{span_id} | Read a source passage and anchor |
| GET | /v1/provisions/{unit_id}/versions | Reviewed version and applicability history |
| GET | /v1/documents/{document_id}/citations | Citation and reviewed treatment evidence |
| POST | /v1/research/runs | Create bounded research run |
| GET | /v1/research/runs/{run_id} | Get durable research state |
| GET | /v1/research/runs/{run_id}/events | Progress and verified final events |
| POST | /v1/research/runs/{run_id}/cancel | Request cooperative cancellation |
| POST | /v1/research/runs/{run_id}/clarifications | Submit requested missing facts |
| POST | /v1/answers/{answer_id}/exports | Create permission-scoped export |
| GET | /v1/exports/{export_id} | Export job state |
| POST | /v1/exports/{export_id}/approve | Approve export containing private evidence |
| POST | /v1/exports/{export_id}/download | Create short-lived authorized download link |
| POST | /v1/answers/{answer_id}/feedback | Report a research issue |
| GET | /v1/workspaces | List only authorized workspaces |
| POST | /v1/workspaces | Create workspace |
| GET | /v1/workspaces/{workspace_id} | Read authorized workspace |
| POST | /v1/workspaces/{workspace_id}/members | Grant matter access to an existing tenant member |
| DELETE | /v1/workspaces/{workspace_id}/members/{user_id} | Revoke matter access and invalidate ACL revision |
| POST | /v1/uploads | Create quarantined PDF upload |
| POST | /v1/private-documents/{document_id}/complete | Verify uploaded checksum and enqueue scanning |
| GET | /v1/private-documents/{document_id} | Private document status |
| DELETE | /v1/private-documents/{document_id} | Revoke access and start retention-aware deletion |
| GET | /v1/private-spans/{span_id} | Read an authorized private passage |
| POST | /v1/privacy/deletions | Request access withdrawal and policy-governed erasure |
| GET | /v1/privacy/deletions/{deletion_id} | Read deletion and retention status |
| GET | /v1/admin/sources | Source registry |
| POST | /v1/admin/sources | Register a disabled source |
| POST | /v1/admin/source-policy-reviews | Record source use approval |
| POST | /v1/admin/imports | Import a reviewed storage manifest |
| GET | /v1/admin/jobs/{job_id} | Read ingestion job |
| POST | /v1/admin/jobs/{job_id}/retry | Retry an eligible failed stage |
| POST | /v1/admin/editorial-reviews | Review exact versioned legal metadata |
| POST | /v1/admin/corpus-releases | Build candidate release |
| POST | /v1/admin/corpus-releases/{release_id}/publish | Publish after independent approval |
| POST | /v1/admin/takedowns | Immediately block serving of a source |
| GET | /v1/admin/audit | Permission-scoped security metadata |
| GET | /v1/usage | Tenant budget and usage |
| GET | /v1/answers/{answer_id} | Read an answer after current workspace and source-availability checks |

## Appendix C. Requirements traceability matrix

This matrix provides module-level navigation from requirement IDs to user workflows, original tickets and acceptance scenarios. The companion JSON register retains every individual requirement, acceptance criterion and phase. Requirement status is “proposed” until a reviewed implementation and test report establishes otherwise.

| Requirements | Module | Workflows | Baseline tickets | Acceptance tests |
| --- | --- | --- | --- | --- |
| BL-FR-001–007 | Identity, membership and permissions | WF-01, WF-10 | BL-008, BL-025, BL-036 | UAT-01, 02, 19 |
| BL-FR-008–014 | Source governance and coverage | WF-06, WF-09 | BL-001, BL-002, BL-009, BL-013, BL-026 | UAT-15, 16, 22 |
| BL-FR-015–024 | Ingestion and editorial publication | WF-06, WF-09 | BL-009–BL-013 | UAT-13–16 |
| BL-FR-025–030 | Catalog and source viewing | WF-03, WF-04 | BL-010, BL-012, BL-014, BL-018 | UAT-03, 04, 08 |
| BL-FR-031–039 | Search and ranking | WF-02, WF-03 | BL-014–BL-019, BL-020 | UAT-03–05, 19, 25 |
| BL-FR-040–049 | Research and answer generation | WF-02, WF-11 | BL-020–BL-026, BL-031, BL-033 | UAT-05–07, 24–28 |
| BL-FR-050–057 | Verification and trustworthy output | WF-02, WF-04, WF-09 | BL-022–BL-026, BL-036, BL-037 | UAT-08, 09, 22, 27 |
| BL-FR-058–064 | Historical law and provision versions | WF-05 | BL-027, BL-028, BL-032 | UAT-10–12 |
| BL-FR-065–069 | Citation relationships and opinions | WF-04, WF-05 | BL-029–BL-031 | UAT-09, 12, 30 |
| BL-FR-070–077 | Private matters and uploaded documents | WF-07, WF-10 | BL-035–BL-037, BL-040 | UAT-17–20, 23, 29 |
| BL-FR-078–083 | Exports, feedback and accountable changes | WF-08, WF-09 | BL-025, BL-026, BL-037, BL-042 | UAT-21, 22 |
| BL-FR-084–091 | Operations, jobs and provider controls | WF-11, WF-12 | BL-003–BL-006, BL-020, BL-021, BL-038–BL-044 | UAT-24–30 |

BL-NFR-001–020 apply across the enabled workflows, with service-backed, legal, security, accessibility and recovery evidence as described in Sections 13–14. A one-to-many relationship is intentional: a single permission or citation invariant must be tested in search, streams, model requests, exports and restore behavior.

## Appendix D. Glossary for nontechnical readers

| Term | Meaning |
| --- | --- |
| Agent | A controlled workflow that uses a model to choose among permitted actions; it is not an independent authority. |
| API | A defined interface through which software components exchange requests and responses. |
| Artifact | An original stored file or a separately versioned processing output. |
| Authority cutoff | The latest date of interpretive authorities allowed for a research run. |
| Bitemporal | Recording both when something applied and when the platform learned or recorded it. |
| BM25 / lexical search | Search that ranks documents using their words and how those words match the query. |
| Canonical source | The approved, versioned text used for quotations and verification. |
| Chunk | A bounded piece of text used for retrieval; it is not necessarily a complete legal provision. |
| Citation graph | A network of evidence-backed links among cases, provisions and legal propositions. |
| Corpus | The collection of documents that the product has actually acquired, checked and made available. |
| Corpus release | An immutable snapshot of approved documents, versions, indexes and supporting metadata. |
| Embedding / vector | A numerical representation of text used to find related meaning. |
| Evidence handle | A server-issued reference such as E1 that identifies authorized evidence for one research run. |
| Hybrid retrieval | Combining exact/word search and semantic search before reranking. |
| Idempotency | Repeating the same operation does not unintentionally create the effect twice. |
| Ingestion | The controlled process of acquiring, checking, parsing and preparing documents for use. |
| Law-as-of date | The date used to determine which wording or legal status is being researched. |
| LLM | A large language model that generates text; its output still needs evidence and validation. |
| OCR | Optical character recognition: extracting text from page images when usable native text is absent. |
| OpenSearch | The selected search-engine component; its data is a projection of canonical records. |
| Prompt injection | Untrusted content that tries to make a model ignore its permitted task or boundaries. |
| RAG | Retrieval-augmented generation: finding sources before generating an explanation. |
| Reranker | A component that reorders retrieved candidates for relevance to the question. |
| RLS / row security | Database rules restricting which organization’s rows an application session can access. |
| RPO / RTO | Recovery point objective: tolerated data-loss interval. Recovery time objective: target time to restore service. |
| SLO / p95 | Service-level objective. p95 is the time within which 95% of measured requests completed. |
| Source span | An exact excerpt anchored to a specific version, page and text offset. |
| Tenant / workspace | An organization / a restricted matter or team research area within it. |
| Takedown | An immediate restriction on serving or processing specified content. |
| Version / snapshot | A recorded revision / a frozen selection of versions used together. |
| Abstention | An explicit decision not to provide a definitive answer because evidence or scope is insufficient. |
| Legal review | An attributable decision by an authorized qualified human reviewer, not a model’s self-assessment. |

## Appendix E. Source baseline, revisions and validation limits

This document reformats and elaborates the supplied project handoff. It does not independently revalidate current Indian law, source terms, software versions, provider policies or cloud service availability. Those remain implementation and launch review gates. References below identify the project files from which the requirements were derived; external sources cited inside those files should be rechecked when implementing the affected capability.

| Ref | Baseline file | Use in this specification |
| --- | --- | --- |
| B01 | docs/ARCHITECTURE.md | Overall architecture, data, retrieval, security, operations and design assumptions. |
| B02 | docs/IMPLEMENTATION_PLAN.md | Detailed Phase 0–6 plan and 44 ticket deliverables/acceptance evidence. |
| B03 | docs/API_AND_WORKFLOWS.md | Authorization, run semantics, uploads, idempotency, source restrictions and exports. |
| B04 | db/reference_schema.sql | Reference 60-table data model; requires tested migrations and runtime privilege validation. |
| B05 | contracts/openapi.yaml and contracts/*.schema.json | 45 API operations and strict legal-document/research/answer contracts. |
| B06 | opensearch/*.index.json; config/policy.example.yaml | Reference mappings, profile placeholder and configurable workflow limits. |
| B07 | docs/SECURITY_AND_OPERATIONS.md | Threat controls, processing policies, recovery, privacy and operational gates. |
| B08 | VALIDATION_REPORT.md | Baseline reference-test results and explicit untested production areas. |
| B09 | CODEX_START_HERE.md; AGENTS.md | Implementation instructions, constraints and honest milestone reporting. |

### E.1 Document-specific changes

This version adds plain-language explanations, user journeys, process diagrams, requirement IDs, acceptance criteria, screen descriptions, user-acceptance scenarios and module traceability. It standardizes phase names to the detailed ticket plan and exposes the run-state mismatch for explicit contract reconciliation. The accessibility/usability requirements are proposed SRS elaborations requiring acceptance; they are not claims that the baseline product already meets them.

### E.2 Implementation status and evidence boundaries

The source handoff reports 107 passing reference/contract tests, while explicitly excluding executed PostgreSQL migrations, live OpenSearch, AWS deployment, live-model/legal accuracy, security certification and production performance validation. This SRS does not promote that report into proof of a running application. Preparing and reviewing this document verifies its own structure and consistency, not the product’s legal or operational behavior.

### E.3 Baseline file integrity

Source archive: BharatLaw_AI_Codex_Handoff.zip. SHA-256: 6143c82b22dc4d56d3941a4535b196c9e6595ec5f3e55bd39497c0d64d767ae9. This identifies the specific input archive used to prepare this requirements document.
