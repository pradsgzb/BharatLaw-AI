"""Bitemporal selection demonstration, not an engine for legal interpretation."""
from __future__ import annotations
from dataclasses import dataclass
from datetime import date, datetime
from typing import Iterable

@dataclass(frozen=True)
class Applicability:
    assertion_id: str
    unit_version_id: str
    scope_key: str
    territory_key: str
    status: str
    valid_from: date | None
    valid_to: date | None
    recorded_from: datetime
    recorded_to: datetime | None
    approved: bool
    # True ONLY after the server resolves all relevant conditions from reviewed
    # rules/evidence and supplied facts; not a model confidence score.
    conditions_satisfied: bool

@dataclass(frozen=True)
class Resolution:
    status: str
    assertion_ids: tuple[str, ...]
    unit_version_id: str | None

def resolve(assertions: Iterable[Applicability], *, law_date: date,
            known_at: datetime, scope_key: str, territory_key: str) -> Resolution:
    if known_at.tzinfo is None or known_at.utcoffset() is None:
        raise ValueError("Known-at time must be timezone-aware")
    possible: list[Applicability] = []
    unresolved: list[str] = []
    for a in assertions:
        if a.recorded_from.tzinfo is None or (a.recorded_to is not None and a.recorded_to.tzinfo is None):
            raise ValueError("Recorded intervals must be timezone-aware")
        if a.valid_from is not None and a.valid_to is not None and a.valid_to <= a.valid_from:
            raise ValueError("Invalid legal interval")
        if a.recorded_to is not None and a.recorded_to <= a.recorded_from:
            raise ValueError("Invalid recorded interval")
        if (a.scope_key, a.territory_key) != (scope_key, territory_key):
            continue
        if a.recorded_from > known_at or (a.recorded_to is not None and known_at >= a.recorded_to):
            continue
        if not a.approved:
            continue
        # Known date bounds can exclude an assertion even if another bound is
        # missing. Do not label a known non-overlap as a possible conflict.
        if a.valid_from is not None and law_date < a.valid_from:
            continue
        if a.valid_to is not None and law_date >= a.valid_to:
            continue
        if not a.conditions_satisfied or a.valid_from is None or a.status == "unknown":
            unresolved.append(a.assertion_id)
            continue
        if a.status not in {"in_force", "not_commenced", "repealed", "omitted", "expired"}:
            raise ValueError("Unsupported legal status")
        possible.append(a)
    ids = tuple(sorted(a.assertion_id for a in possible))
    if len(possible) > 1:
        return Resolution("conflict", tuple(sorted((*ids, *unresolved))), None)
    if unresolved:
        return Resolution("needs_review", tuple(sorted((*ids, *unresolved))), None)
    if not possible:
        return Resolution("unknown", (), None)
    a = possible[0]
    return Resolution(a.status, ids, a.unit_version_id if a.status == "in_force" else None)
