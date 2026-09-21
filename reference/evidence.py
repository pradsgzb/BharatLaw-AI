"""Deterministic source/quote integrity checks; NOT a legal correctness verifier.

Objects must be constructed from authenticated repository results, never trusted
because an LLM or a client supplied them. Canonical repository lookup and current
source-rights/takedown checks remain mandatory production integration work.
"""
from __future__ import annotations
from dataclasses import dataclass
from hashlib import sha256
from typing import Callable, Mapping
import re

class EvidenceError(ValueError):
    """An answer must not be published using this evidence."""

def text_hash(value: str) -> str:
    return sha256(value.encode("utf-8")).hexdigest()

@dataclass(frozen=True)
class Evidence:
    handle: str
    run_id: str
    release_id: str | None
    tenant_id: str | None
    workspace_id: str | None
    source_class: str
    source_span_id: str
    unit_text: str
    unit_text_sha256: str
    char_start: int
    char_end: int
    excerpt_sha256: str
    artifact_sha256: str
    active: bool = True

@dataclass(frozen=True)
class VerificationContext:
    run_id: str
    release_id: str
    tenant_id: str
    workspace_id: str

def verify_citation(handle: str, quoted_text: str, evidence: Mapping[str, Evidence],
                    context: VerificationContext,
                    is_authorized: Callable[[Evidence], bool]) -> Evidence:
    if re.fullmatch(r"E[1-9][0-9]*", handle) is None or handle not in evidence:
        raise EvidenceError("Unknown evidence handle")
    item = evidence[handle]
    if item.handle != handle or item.run_id != context.run_id:
        raise EvidenceError("Evidence belongs to a different run")
    if not item.active or not is_authorized(item):
        raise EvidenceError("Evidence is unavailable or no longer authorized")
    if item.source_class == "public_authority":
        if item.release_id != context.release_id or item.tenant_id is not None or item.workspace_id is not None:
            raise EvidenceError("Public evidence is not from the pinned release")
    elif item.source_class == "private_upload":
        if (item.tenant_id, item.workspace_id) != (context.tenant_id, context.workspace_id):
            raise EvidenceError("Private evidence scope mismatch")
        if item.release_id is not None:
            raise EvidenceError("Private uploads are not public corpus members")
    else:
        raise EvidenceError("Unapproved source class")
    for digest in (item.unit_text_sha256, item.excerpt_sha256, item.artifact_sha256):
        if re.fullmatch(r"[a-f0-9]{64}", digest) is None:
            raise EvidenceError("Invalid content digest")
    if text_hash(item.unit_text) != item.unit_text_sha256:
        raise EvidenceError("Canonical text hash mismatch")
    if not (0 <= item.char_start < item.char_end <= len(item.unit_text)):
        raise EvidenceError("Invalid source offsets")
    exact = item.unit_text[item.char_start:item.char_end]
    if text_hash(exact) != item.excerpt_sha256 or quoted_text != exact:
        raise EvidenceError("Quotation does not exactly match its source span")
    return item

def require_legal_authority(kind: str, support: list[Evidence]) -> None:
    """Private submissions alone cannot establish a legal proposition.

    This is only a source-class gate. A real public document can still fail to
    support a claim, be a dissent, or be superseded; check those separately.
    """
    if kind == "legal_proposition" and not any(e.source_class == "public_authority" for e in support):
        raise EvidenceError("A legal proposition requires verified public authority")
