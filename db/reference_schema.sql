-- BharatLaw AI v1.0 — PostgreSQL reference DDL, not an applied migration.
-- Execute in an isolated test database using a migration role, NEVER bl_app.
-- Requires pgcrypto and btree_gist, installed by an authorized administrator.
-- Runtime grants, workspace authorization, publication validators and immutable
-- record update policies must be implemented and integration-tested by Codex.
-- Do not treat successful DDL execution as a security or legal review.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA IF NOT EXISTS bl;
CREATE DOMAIN bl.sha256 AS text CHECK (VALUE ~ '^[a-f0-9]{64}$');

CREATE TABLE bl.sources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_key text NOT NULL UNIQUE,
 name text NOT NULL, base_url text NOT NULL, allowed_hosts jsonb NOT NULL,
 acquisition_mode text NOT NULL CHECK(acquisition_mode IN ('manual_manifest','approved_http','licensed_feed')),
 enabled boolean NOT NULL DEFAULT false, max_requests_per_minute integer NOT NULL DEFAULT 6 CHECK(max_requests_per_minute>0),
 last_attempt_at timestamptz, last_success_at timestamptz, covered_through date,
 coverage_notes text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.source_policies (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_id uuid NOT NULL REFERENCES bl.sources,
 version integer NOT NULL CHECK(version>0), status text NOT NULL CHECK(status IN ('pending','approved','rejected','expired')),
 can_fetch boolean NOT NULL DEFAULT false, can_store boolean NOT NULL DEFAULT false,
 can_index boolean NOT NULL DEFAULT false, can_send_to_model boolean NOT NULL DEFAULT false,
 can_display_excerpt boolean NOT NULL DEFAULT false, can_redistribute boolean NOT NULL DEFAULT false,
 can_train boolean NOT NULL DEFAULT false, can_evaluate boolean NOT NULL DEFAULT false,
 permitted_provider_profiles jsonb NOT NULL DEFAULT '[]', terms_url text NOT NULL,
 terms_sha256 bl.sha256, rights_evidence jsonb NOT NULL DEFAULT '[]', attribution_template text,
 reviewer_reference text, reviewed_at timestamptz, review_due_at timestamptz,
 UNIQUE(source_id,version), CHECK(status <> 'approved' OR (reviewer_reference IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE TABLE bl.artifacts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_id uuid NOT NULL REFERENCES bl.sources,
 source_policy_id uuid NOT NULL REFERENCES bl.source_policies, source_url text NOT NULL,
 bucket text NOT NULL, object_key text NOT NULL, object_version text NOT NULL,
 sha256 bl.sha256 NOT NULL, media_type text NOT NULL, byte_size bigint NOT NULL CHECK(byte_size>=0),
 fetched_at timestamptz NOT NULL, etag text, last_modified text,
 scan_status text NOT NULL DEFAULT 'pending' CHECK(scan_status IN ('pending','clean','blocked')),
 permission_state text NOT NULL DEFAULT 'pending' CHECK(permission_state IN ('pending','allowed','restricted')),
 UNIQUE(bucket,object_key,object_version)
);
CREATE INDEX artifacts_hash_idx ON bl.artifacts(sha256);
CREATE TABLE bl.documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), canonical_key text NOT NULL UNIQUE,
 document_type text NOT NULL CHECK(document_type IN ('constitution','act','rule','regulation','notification','ordinance','judgment','order','amendment','circular')),
 title text NOT NULL, jurisdiction_key text NOT NULL, is_restricted boolean NOT NULL DEFAULT false,
 is_synthetic boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.document_identifiers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 scheme text NOT NULL, raw_value text NOT NULL, normalized_value text NOT NULL,
 evidence_artifact_id uuid REFERENCES bl.artifacts,
 resolution_status text NOT NULL DEFAULT 'unreviewed' CHECK(resolution_status IN ('unreviewed','verified','ambiguous','rejected')),
 UNIQUE(document_id,scheme,normalized_value)
);
CREATE INDEX identifiers_lookup_idx ON bl.document_identifiers(scheme,normalized_value);
CREATE TABLE bl.document_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 artifact_id uuid NOT NULL REFERENCES bl.artifacts, edition_label text,
 representation_kind text NOT NULL CHECK(representation_kind IN ('official_published','editorial_consolidation','official_translation','machine_translation','synthetic_fixture')),
 language text NOT NULL, publication_date date, edition_as_of date, decision_date date,
 source_text_sha256 bl.sha256, supersedes_id uuid REFERENCES bl.document_versions,
 recorded_at timestamptz NOT NULL DEFAULT now(), UNIQUE(id,document_id), UNIQUE(document_id,artifact_id,language)
);
CREATE TABLE bl.extractions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL,
 document_version_id uuid NOT NULL, parser_profile text NOT NULL, config_sha256 bl.sha256 NOT NULL,
 normalized_artifact_id uuid REFERENCES bl.artifacts, page_count integer CHECK(page_count>0),
 used_ocr boolean NOT NULL DEFAULT false, quality_metrics jsonb NOT NULL DEFAULT '{}',
 status text NOT NULL CHECK(status IN ('pending','quarantined','validated','approved','rejected','fixture_only')),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(document_version_id,document_id) REFERENCES bl.document_versions(id,document_id),
 UNIQUE(document_version_id,parser_profile,config_sha256), UNIQUE(id,document_id)
);
CREATE TABLE bl.courts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), court_key text NOT NULL UNIQUE,
 name text NOT NULL, court_class text NOT NULL CHECK(court_class IN ('supreme_court','high_court','tribunal','subordinate_court')),
 territories jsonb NOT NULL DEFAULT '[]'
);
CREATE TABLE bl.judicial_details (
 document_id uuid PRIMARY KEY REFERENCES bl.documents, court_id uuid NOT NULL REFERENCES bl.courts,
 bench_size integer CHECK(bench_size>0), judges jsonb NOT NULL DEFAULT '[]',
 proceeding_type text, disposition text, is_speaking_order boolean,
 metadata_review_state text NOT NULL DEFAULT 'unreviewed'
);
CREATE TABLE bl.case_identifiers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 court_id uuid NOT NULL REFERENCES bl.courts, case_type text NOT NULL, case_number text NOT NULL,
 case_year integer CHECK(case_year BETWEEN 1700 AND 2200), relationship text NOT NULL DEFAULT 'main',
 UNIQUE(document_id,court_id,case_type,case_number,case_year)
);
CREATE TABLE bl.opinions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 opinion_key text NOT NULL, opinion_type text NOT NULL CHECK(opinion_type IN ('majority','concurrence','dissent','plurality','per_curiam','unknown')),
 authors jsonb NOT NULL DEFAULT '[]', attribution_review_state text NOT NULL DEFAULT 'unreviewed',
 UNIQUE(document_id,opinion_key), UNIQUE(id,document_id)
);
CREATE TABLE bl.legal_units (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 parent_id uuid, unit_key text NOT NULL, unit_type text NOT NULL,
 display_label text NOT NULL, structural_path jsonb NOT NULL, sort_order integer NOT NULL,
 UNIQUE(document_id,unit_key), UNIQUE(id,document_id),
 FOREIGN KEY(parent_id,document_id) REFERENCES bl.legal_units(id,document_id), CHECK(parent_id IS DISTINCT FROM id)
);
CREATE TABLE bl.unit_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL,
 unit_id uuid NOT NULL, extraction_id uuid NOT NULL, opinion_id uuid,
 language text NOT NULL, exact_text text NOT NULL, text_sha256 bl.sha256 NOT NULL,
 role_label text NOT NULL DEFAULT 'unclassified' CHECK(role_label IN ('operative_text','court_reasoning','party_argument','quoted_authority','headnote','footnote','unclassified')),
 original_paragraph_label text, page_anchors jsonb NOT NULL DEFAULT '[]',
 FOREIGN KEY(unit_id,document_id) REFERENCES bl.legal_units(id,document_id),
 FOREIGN KEY(extraction_id,document_id) REFERENCES bl.extractions(id,document_id),
 FOREIGN KEY(opinion_id,document_id) REFERENCES bl.opinions(id,document_id),
 UNIQUE(unit_id,extraction_id,language), UNIQUE(id,unit_id), UNIQUE(id,document_id)
);
CREATE TABLE bl.source_spans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), unit_version_id uuid NOT NULL REFERENCES bl.unit_versions,
 char_start integer NOT NULL CHECK(char_start>=0), char_end integer NOT NULL,
 quote_sha256 bl.sha256 NOT NULL, anchors jsonb NOT NULL DEFAULT '[]',
 CHECK(char_end>char_start), UNIQUE(unit_version_id,char_start,char_end)
);
CREATE TABLE bl.legal_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), event_document_id uuid NOT NULL REFERENCES bl.documents,
 event_kind text NOT NULL CHECK(event_kind IN ('amendment','commencement','repeal','omission','renumbering','corrigendum','stay','judicial_effect','saving','expiry')),
 evidence_span_id uuid NOT NULL REFERENCES bl.source_spans,
 publication_date date, stated_effective_date date, conditions jsonb NOT NULL DEFAULT '{}',
 review_state text NOT NULL DEFAULT 'unreviewed', reviewer_reference text,
 recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.event_targets (
 event_id uuid NOT NULL REFERENCES bl.legal_events, unit_id uuid NOT NULL REFERENCES bl.legal_units,
 effect_description text NOT NULL, PRIMARY KEY(event_id,unit_id)
);
CREATE TABLE bl.applicability_assertions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), unit_id uuid NOT NULL REFERENCES bl.legal_units,
 unit_version_id uuid NOT NULL, scope_key text NOT NULL, territory_key text NOT NULL,
 legal_status text NOT NULL CHECK(legal_status IN ('in_force','not_commenced','repealed','omitted','expired','unknown')),
 valid_from date, valid_to date, recorded_from timestamptz NOT NULL DEFAULT now(), recorded_to timestamptz,
 conditions jsonb NOT NULL DEFAULT '{}', event_id uuid REFERENCES bl.legal_events,
 evidence_span_id uuid NOT NULL REFERENCES bl.source_spans,
 review_state text NOT NULL CHECK(review_state IN ('candidate','approved','rejected')),
 reviewer_reference text, reviewed_at timestamptz,
 FOREIGN KEY(unit_version_id,unit_id) REFERENCES bl.unit_versions(id,unit_id),
 CHECK(valid_to IS NULL OR valid_from IS NULL OR valid_to>valid_from),
 CHECK(recorded_to IS NULL OR recorded_to>recorded_from),
 CHECK(review_state <> 'approved' OR (reviewer_reference IS NOT NULL AND reviewed_at IS NOT NULL)),
 CHECK(review_state <> 'approved' OR legal_status='unknown' OR valid_from IS NOT NULL),
 EXCLUDE USING gist (
  unit_id WITH =, scope_key WITH =,
  daterange(valid_from,valid_to,'[)') WITH &&,
  tstzrange(recorded_from,recorded_to,'[)') WITH &&
 ) WHERE (review_state='approved' AND valid_from IS NOT NULL)
);
CREATE INDEX applicability_lookup_idx ON bl.applicability_assertions(unit_id,scope_key,valid_from);
CREATE TABLE bl.chunks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), unit_version_id uuid NOT NULL REFERENCES bl.unit_versions,
 chunker_profile text NOT NULL, char_start integer NOT NULL CHECK(char_start>=0), char_end integer NOT NULL,
 source_text text NOT NULL, search_text text NOT NULL, text_sha256 bl.sha256 NOT NULL,
 token_count integer NOT NULL CHECK(token_count>0), tokenizer_profile text NOT NULL,
 required_context_unit_ids jsonb NOT NULL DEFAULT '[]', CHECK(char_end>char_start),
 UNIQUE(unit_version_id,chunker_profile,char_start,char_end)
);
CREATE TABLE bl.embedding_profiles (
 profile_key text PRIMARY KEY, provider text NOT NULL, model_id text NOT NULL, model_revision text NOT NULL,
 dimensions integer NOT NULL CHECK(dimensions>0), distance text NOT NULL CHECK(distance IN ('cosine','l2','inner_product')),
 preprocessing_sha256 bl.sha256 NOT NULL, approved_data_classes jsonb NOT NULL,
 is_enabled boolean NOT NULL DEFAULT false
);
CREATE TABLE bl.chunk_embeddings (
 chunk_id uuid NOT NULL REFERENCES bl.chunks, profile_key text NOT NULL REFERENCES bl.embedding_profiles,
 input_sha256 bl.sha256 NOT NULL, output_sha256 bl.sha256 NOT NULL,
 artifact_locator jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(chunk_id,profile_key)
);
CREATE TABLE bl.citation_mentions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), evidence_span_id uuid NOT NULL REFERENCES bl.source_spans,
 raw_citation text NOT NULL, normalized_citation text, resolved_document_id uuid REFERENCES bl.documents,
 candidate_documents jsonb NOT NULL DEFAULT '[]',
 resolution_state text NOT NULL CHECK(resolution_state IN ('unresolved','ambiguous','machine_resolved','reviewed','rejected')),
 resolver_profile text NOT NULL, reviewer_reference text,
 CHECK(resolution_state NOT IN ('machine_resolved','reviewed') OR resolved_document_id IS NOT NULL)
);
CREATE TABLE bl.propositions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES bl.documents,
 opinion_id uuid, statement text NOT NULL, evidence_span_id uuid NOT NULL REFERENCES bl.source_spans,
 proposition_kind text NOT NULL CHECK(proposition_kind IN ('holding_candidate','holding_reviewed','argument','obiter_candidate','procedural','unknown')),
 review_state text NOT NULL DEFAULT 'candidate', reviewer_reference text,
 FOREIGN KEY(opinion_id,document_id) REFERENCES bl.opinions(id,document_id)
);
CREATE TABLE bl.legal_nodes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid UNIQUE REFERENCES bl.documents,
 unit_id uuid UNIQUE REFERENCES bl.legal_units, proposition_id uuid UNIQUE REFERENCES bl.propositions,
 CHECK(num_nonnulls(document_id,unit_id,proposition_id)=1)
);
CREATE TABLE bl.legal_edges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), from_node_id uuid NOT NULL REFERENCES bl.legal_nodes,
 to_node_id uuid NOT NULL REFERENCES bl.legal_nodes,
 relation text NOT NULL CHECK(relation IN ('cites','interprets','applies','follows','distinguishes','overrules','partially_overrules','affirms','reverses','refers_to_larger_bench','amends','commences','repeals','renumbers','corresponds_to','stays_operation')),
 evidence_span_id uuid NOT NULL REFERENCES bl.source_spans, scope_description text NOT NULL,
 opinion_id uuid REFERENCES bl.opinions, decision_date date, extraction_profile text NOT NULL,
 review_state text NOT NULL CHECK(review_state IN ('candidate','machine_resolved','approved','rejected')),
 reviewer_reference text, reviewed_at timestamptz, recorded_at timestamptz NOT NULL DEFAULT now(),
 CHECK(from_node_id<>to_node_id),
 CHECK(review_state<>'approved' OR (reviewer_reference IS NOT NULL AND reviewed_at IS NOT NULL)),
 CHECK(relation='cites' OR review_state<>'machine_resolved')
);
CREATE INDEX edges_forward_idx ON bl.legal_edges(from_node_id,relation,review_state);
CREATE INDEX edges_reverse_idx ON bl.legal_edges(to_node_id,relation,decision_date);
CREATE TABLE bl.corpus_releases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), release_key text NOT NULL UNIQUE,
 status text NOT NULL CHECK(status IN ('building','validated','published','retired','withdrawn')),
 document_index text NOT NULL, chunk_index text NOT NULL, embedding_profile text NOT NULL REFERENCES bl.embedding_profiles,
 manifest_locator jsonb NOT NULL, manifest_sha256 bl.sha256 NOT NULL,
 policy_sha256 bl.sha256 NOT NULL, source_coverage jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz
);
CREATE TABLE bl.release_members (
 release_id uuid NOT NULL REFERENCES bl.corpus_releases, chunk_id uuid NOT NULL REFERENCES bl.chunks,
 PRIMARY KEY(release_id,chunk_id)
);
-- These memberships freeze evidence and reviewed annotations, not merely the
-- chunks that happened to be retrieved. The immutable S3 release manifest also
-- stores the serialized annotation snapshots; a record ID alone is insufficient.
CREATE TABLE bl.release_unit_versions (
 release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 unit_version_id uuid NOT NULL REFERENCES bl.unit_versions,
 text_sha256 bl.sha256 NOT NULL, PRIMARY KEY(release_id,unit_version_id)
);
CREATE TABLE bl.release_applicability_assertions (
 release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 assertion_id uuid NOT NULL REFERENCES bl.applicability_assertions,
 snapshot_sha256 bl.sha256 NOT NULL, snapshot_json jsonb NOT NULL,
 PRIMARY KEY(release_id,assertion_id)
);
CREATE TABLE bl.release_legal_edges (
 release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 edge_id uuid NOT NULL REFERENCES bl.legal_edges,
 snapshot_sha256 bl.sha256 NOT NULL, snapshot_json jsonb NOT NULL,
 PRIMARY KEY(release_id,edge_id)
);
CREATE TABLE bl.release_citation_resolutions (
 release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 citation_mention_id uuid NOT NULL REFERENCES bl.citation_mentions,
 snapshot_sha256 bl.sha256 NOT NULL, snapshot_json jsonb NOT NULL,
 PRIMARY KEY(release_id,citation_mention_id)
);
CREATE TABLE bl.publication_channels (
 channel_key text PRIMARY KEY, release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.ingestion_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_id uuid REFERENCES bl.sources,
 artifact_id uuid REFERENCES bl.artifacts, idempotency_key text NOT NULL UNIQUE,
 stage text NOT NULL, state text NOT NULL CHECK(state IN ('queued','running','awaiting_review','succeeded','retryable_failed','failed','cancelled','quarantined','rights_blocked')),
 input_sha256 bl.sha256 NOT NULL, pipeline_profile text NOT NULL,
 lease_owner text, lease_until timestamptz, attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 error_code text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ingestion_ready_idx ON bl.ingestion_jobs(state,created_at);
CREATE TABLE bl.job_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), job_id uuid NOT NULL REFERENCES bl.ingestion_jobs,
 attempt_number integer NOT NULL CHECK(attempt_number>0), started_at timestamptz NOT NULL,
 finished_at timestamptz, outcome text, metrics jsonb NOT NULL DEFAULT '{}', error_code text,
 UNIQUE(job_id,attempt_number)
);
CREATE TABLE bl.outbox_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), aggregate_type text NOT NULL,
 aggregate_id uuid NOT NULL, event_type text NOT NULL, payload jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), dispatched_at timestamptz,
 attempt_count integer NOT NULL DEFAULT 0
);
CREATE INDEX outbox_pending_idx ON bl.outbox_events(created_at) WHERE dispatched_at IS NULL;
CREATE TABLE bl.editorial_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), target_type text NOT NULL, target_id uuid NOT NULL,
 target_version_sha256 bl.sha256 NOT NULL, reviewer_reference text NOT NULL,
 decision text NOT NULL CHECK(decision IN ('approve','reject','request_changes')),
 rationale text NOT NULL, evidence_span_ids jsonb NOT NULL DEFAULT '[]',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.takedowns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid REFERENCES bl.documents,
 artifact_id uuid REFERENCES bl.artifacts, reason_code text NOT NULL, restricted_at timestamptz NOT NULL DEFAULT now(),
 reviewer_reference text NOT NULL, resolved_at timestamptz,
 CHECK(num_nonnulls(document_id,artifact_id)>=1)
);

-- Identity and tenant data. Global users contain authentication identities only.
CREATE TABLE bl.tenants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL,
 status text NOT NULL DEFAULT 'active', processing_policy jsonb NOT NULL DEFAULT '{}',
 retention_policy_version text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bl.users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth_issuer text NOT NULL, auth_subject text NOT NULL,
 status text NOT NULL DEFAULT 'active', created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(auth_issuer,auth_subject)
);
CREATE TABLE bl.memberships (
 tenant_id uuid NOT NULL REFERENCES bl.tenants, user_id uuid NOT NULL REFERENCES bl.users,
 role text NOT NULL CHECK(role IN ('owner','admin','researcher','viewer','auditor')),
 active boolean NOT NULL DEFAULT true, PRIMARY KEY(tenant_id,user_id)
);
CREATE TABLE bl.workspaces (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES bl.tenants,
 name text NOT NULL, acl_revision bigint NOT NULL DEFAULT 1 CHECK(acl_revision>0),
 status text NOT NULL DEFAULT 'active', created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(id,tenant_id)
);
CREATE TABLE bl.workspace_members (
 workspace_id uuid NOT NULL, tenant_id uuid NOT NULL, user_id uuid NOT NULL,
 role text NOT NULL CHECK(role IN ('manager','researcher','viewer')),
 active boolean NOT NULL DEFAULT true, PRIMARY KEY(workspace_id,user_id),
 FOREIGN KEY(workspace_id,tenant_id) REFERENCES bl.workspaces(id,tenant_id),
 FOREIGN KEY(tenant_id,user_id) REFERENCES bl.memberships(tenant_id,user_id)
);
CREATE TABLE bl.private_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 title text NOT NULL, created_by uuid NOT NULL REFERENCES bl.users,
 state text NOT NULL CHECK(state IN ('uploading','quarantined','processing','ready','restricted','deleting','deleted')),
 created_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz,
 FOREIGN KEY(workspace_id,tenant_id) REFERENCES bl.workspaces(id,tenant_id), UNIQUE(id,tenant_id,workspace_id)
);
CREATE TABLE bl.private_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 private_document_id uuid NOT NULL, object_locator jsonb NOT NULL, sha256 bl.sha256 NOT NULL,
 media_type text NOT NULL, parser_profile text, scan_status text NOT NULL DEFAULT 'pending',
 exact_text text, extraction_metrics jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(private_document_id,tenant_id,workspace_id) REFERENCES bl.private_documents(id,tenant_id,workspace_id),
 UNIQUE(id,tenant_id,workspace_id)
);
CREATE TABLE bl.private_spans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 private_version_id uuid NOT NULL, char_start integer NOT NULL CHECK(char_start>=0), char_end integer NOT NULL,
 quote_sha256 bl.sha256 NOT NULL, anchors jsonb NOT NULL DEFAULT '[]', CHECK(char_end>char_start),
 FOREIGN KEY(private_version_id,tenant_id,workspace_id) REFERENCES bl.private_versions(id,tenant_id,workspace_id),
 UNIQUE(id,tenant_id,workspace_id), UNIQUE(private_version_id,char_start,char_end)
);
CREATE TABLE bl.private_chunks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 private_version_id uuid NOT NULL, chunker_profile text NOT NULL, char_start integer NOT NULL, char_end integer NOT NULL,
 source_text text NOT NULL, search_text text NOT NULL, embedding_profile text REFERENCES bl.embedding_profiles,
 acl_revision bigint NOT NULL CHECK(acl_revision>0), state text NOT NULL DEFAULT 'pending',
 CHECK(char_start>=0 AND char_end>char_start),
 FOREIGN KEY(private_version_id,tenant_id,workspace_id) REFERENCES bl.private_versions(id,tenant_id,workspace_id),
 UNIQUE(id,tenant_id,workspace_id), UNIQUE(private_version_id,chunker_profile,char_start,char_end)
);
CREATE TABLE bl.research_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 created_by uuid NOT NULL REFERENCES bl.users, corpus_release_id uuid NOT NULL REFERENCES bl.corpus_releases,
 state text NOT NULL CHECK(state IN ('queued','planning','needs_clarification','retrieving','drafting','verifying','awaiting_review','completed','partial','abstained','failed','cancelled')),
 request_json jsonb NOT NULL, plan_json jsonb, model_profile text NOT NULL, policy_sha256 bl.sha256 NOT NULL,
 workspace_acl_revision bigint NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), finished_at timestamptz,
 deadline_at timestamptz NOT NULL, cancel_requested_at timestamptz, error_code text,
 FOREIGN KEY(workspace_id,tenant_id) REFERENCES bl.workspaces(id,tenant_id), UNIQUE(id,tenant_id,workspace_id)
);
CREATE TABLE bl.run_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, event_type text NOT NULL, safe_payload jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(run_id,tenant_id,workspace_id) REFERENCES bl.research_runs(id,tenant_id,workspace_id)
);
CREATE INDEX run_events_cursor_idx ON bl.run_events(run_id,id);
CREATE TABLE bl.run_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, handle text NOT NULL, public_span_id uuid REFERENCES bl.source_spans,
 private_span_id uuid, source_sha256 bl.sha256 NOT NULL, selected_reason text NOT NULL,
 authorization_checked_at timestamptz NOT NULL, CHECK(num_nonnulls(public_span_id,private_span_id)=1),
 FOREIGN KEY(run_id,tenant_id,workspace_id) REFERENCES bl.research_runs(id,tenant_id,workspace_id),
 FOREIGN KEY(private_span_id,tenant_id,workspace_id) REFERENCES bl.private_spans(id,tenant_id,workspace_id),
 UNIQUE(run_id,handle), UNIQUE(id,tenant_id,workspace_id,run_id)
);
CREATE TABLE bl.answers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, revision integer NOT NULL CHECK(revision>0),
 state text NOT NULL CHECK(state IN ('draft','verified','published','withdrawn')),
 answer_json jsonb NOT NULL, deterministic_checks_passed boolean NOT NULL DEFAULT false,
 semantic_review_state text NOT NULL DEFAULT 'pending', lawyer_reviewed boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz,
 FOREIGN KEY(run_id,tenant_id,workspace_id) REFERENCES bl.research_runs(id,tenant_id,workspace_id),
 UNIQUE(run_id,revision), UNIQUE(id,tenant_id,workspace_id,run_id), UNIQUE(id,tenant_id,workspace_id),
 CHECK(state<>'published' OR (deterministic_checks_passed AND published_at IS NOT NULL))
);
CREATE TABLE bl.answer_claims (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, answer_id uuid NOT NULL, claim_key text NOT NULL, claim_text text NOT NULL,
 claim_kind text NOT NULL CHECK(claim_kind IN ('legal_proposition','analysis','user_provided_fact','limitation')),
 support_state text NOT NULL CHECK(support_state IN ('pending','supported','unsupported','conflict','needs_review')),
 FOREIGN KEY(answer_id,tenant_id,workspace_id,run_id) REFERENCES bl.answers(id,tenant_id,workspace_id,run_id),
 UNIQUE(answer_id,claim_key), UNIQUE(id,tenant_id,workspace_id,run_id)
);
CREATE TABLE bl.claim_evidence (
 tenant_id uuid NOT NULL, workspace_id uuid NOT NULL, run_id uuid NOT NULL,
 claim_id uuid NOT NULL, evidence_id uuid NOT NULL, relation text NOT NULL CHECK(relation IN ('supports','contradicts','context')),
 PRIMARY KEY(claim_id,evidence_id,relation),
 FOREIGN KEY(claim_id,tenant_id,workspace_id,run_id) REFERENCES bl.answer_claims(id,tenant_id,workspace_id,run_id),
 FOREIGN KEY(evidence_id,tenant_id,workspace_id,run_id) REFERENCES bl.run_evidence(id,tenant_id,workspace_id,run_id)
);
CREATE TABLE bl.verification_checks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, answer_id uuid NOT NULL, check_type text NOT NULL,
 result text NOT NULL CHECK(result IN ('pass','fail','needs_review')), verifier_profile text NOT NULL,
 safe_details jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(answer_id,tenant_id,workspace_id,run_id) REFERENCES bl.answers(id,tenant_id,workspace_id,run_id)
);
CREATE TABLE bl.model_invocations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 run_id uuid NOT NULL, provider text NOT NULL, model_id text NOT NULL, processing_region text,
 input_sha256 bl.sha256 NOT NULL, output_sha256 bl.sha256, provider_request_id text,
 input_tokens bigint CHECK(input_tokens>=0), output_tokens bigint CHECK(output_tokens>=0),
 status text NOT NULL CHECK(status IN ('started','succeeded','failed','uncertain','cancelled')),
 estimated_cost numeric(18,8) CHECK(estimated_cost>=0), currency char(3) NOT NULL,
 started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
 FOREIGN KEY(run_id,tenant_id,workspace_id) REFERENCES bl.research_runs(id,tenant_id,workspace_id)
);
CREATE TABLE bl.usage_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES bl.tenants,
 run_id uuid, entry_kind text NOT NULL CHECK(entry_kind IN ('reservation','charge','release','adjustment')),
 amount numeric(18,8) NOT NULL CHECK(amount>=0), currency char(3) NOT NULL,
 idempotency_key text NOT NULL, rate_card_version text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,idempotency_key)
);
CREATE TABLE bl.feedback (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 answer_id uuid NOT NULL, submitted_by uuid NOT NULL REFERENCES bl.users,
 category text NOT NULL, comment text, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(answer_id,tenant_id,workspace_id) REFERENCES bl.answers(id,tenant_id,workspace_id)
);
CREATE TABLE bl.export_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, workspace_id uuid NOT NULL,
 answer_id uuid NOT NULL, requested_by uuid NOT NULL REFERENCES bl.users, approved_by uuid REFERENCES bl.users,
 state text NOT NULL CHECK(state IN ('queued','awaiting_approval','running','completed','failed','expired','cancelled')),
 format text NOT NULL CHECK(format IN ('markdown','pdf','docx')), object_locator jsonb,
 expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(answer_id,tenant_id,workspace_id) REFERENCES bl.answers(id,tenant_id,workspace_id)
);
CREATE TABLE bl.deletion_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES bl.tenants,
 workspace_id uuid, requested_by uuid NOT NULL REFERENCES bl.users, target_type text NOT NULL, target_id uuid NOT NULL,
 state text NOT NULL CHECK(state IN ('requested','access_revoked','retention_review','held','purging','completed','failed')),
 policy_version text NOT NULL, component_results jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
 FOREIGN KEY(workspace_id,tenant_id) REFERENCES bl.workspaces(id,tenant_id)
);
CREATE TABLE bl.legal_holds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES bl.tenants,
 workspace_id uuid, target_type text NOT NULL, target_id uuid NOT NULL,
 approved_by uuid NOT NULL REFERENCES bl.users, basis_reference text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), released_at timestamptz,
 FOREIGN KEY(workspace_id,tenant_id) REFERENCES bl.workspaces(id,tenant_id)
);
CREATE TABLE bl.audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES bl.tenants,
 actor_id uuid REFERENCES bl.users, action text NOT NULL, resource_type text NOT NULL, resource_id uuid,
 safe_metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(),
 event_sha256 bl.sha256 NOT NULL
);
CREATE TABLE bl.idempotency_keys (
 tenant_id uuid NOT NULL REFERENCES bl.tenants, actor_id uuid NOT NULL REFERENCES bl.users,
 operation text NOT NULL, key text NOT NULL, request_sha256 bl.sha256 NOT NULL,
 resource_id uuid, response_code integer, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
 PRIMARY KEY(tenant_id,actor_id,operation,key)
);
CREATE INDEX research_tenant_recent_idx ON bl.research_runs(tenant_id,workspace_id,created_at DESC);
CREATE INDEX private_chunks_scope_idx ON bl.private_chunks(tenant_id,workspace_id,state);
CREATE INDEX audits_tenant_time_idx ON bl.audit_events(tenant_id,created_at);
CREATE INDEX usage_tenant_time_idx ON bl.usage_ledger(tenant_id,created_at);

-- Defense-in-depth tenant RLS. API and worker authorization MUST additionally
-- validate active membership, workspace role and current ACL revision.
-- The application sets app.tenant_id using set_config(..., true) in a transaction
-- after authenticating. The application role must never be exposed to an LLM.
CREATE FUNCTION bl.current_tenant() RETURNS uuid LANGUAGE sql STABLE
SET search_path=pg_catalog AS $$
 SELECT NULLIF(current_setting('app.tenant_id',true),'')::uuid
$$;
DO $rls$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
 'memberships','workspaces','workspace_members','private_documents','private_versions',
 'private_spans','private_chunks','research_runs','run_events','run_evidence','answers',
 'answer_claims','claim_evidence','verification_checks','model_invocations','usage_ledger',
 'feedback','export_jobs','deletion_requests','legal_holds','audit_events','idempotency_keys'
 ] LOOP
  EXECUTE format('ALTER TABLE bl.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE bl.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('CREATE POLICY tenant_boundary ON bl.%I USING (tenant_id=bl.current_tenant()) WITH CHECK (tenant_id=bl.current_tenant())',t);
 END LOOP;
END $rls$;

ALTER TABLE bl.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE bl.tenants FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_self ON bl.tenants
 USING (id=bl.current_tenant()) WITH CHECK (id=bl.current_tenant());
-- Bootstrap identity/membership discovery uses a separately scoped identity
-- service operation, not a general application role with RLS bypass.

-- Service-level invariants REQUIRED in addition to these relational constraints:
-- 1. Hashes match bytes; source policy belongs to artifact source; rights are current.
-- 2. Span/chunk offsets are within text; source_text equals exact_text slice.
-- 3. Public evidence is a member of the run's release, including approved parent
--    context/version/treatment evidence explicitly added to its release manifest.
-- 4. Private evidence belongs to an active authorized workspace; final recheck.
-- 5. Answer publication validates all substantive claims, evidence and takedowns.
-- 6. Approved temporal/graph records are edited by closing/revising, never silently
--    overwriting history. Published artifact and release manifests are immutable.
-- 7. Run pointers on usage ledger and polymorphic administrative targets resolve
--    within the authenticated tenant and the approved resource type allowlist.
-- 8. Runtime privileges are least-privilege. Audit inserts allowed; update/delete
--    denied to ordinary application roles; security archives remain independent.
COMMIT;
