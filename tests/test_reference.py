from dataclasses import replace
from datetime import date, datetime, timezone
import math
import pytest
from reference.retrieval import Scope, validate_vector, build_queries, reciprocal_rank_fusion
from reference.evidence import Evidence, VerificationContext, EvidenceError, text_hash, verify_citation, require_legal_authority
from reference.temporal import Applicability, resolve

D = date.fromisoformat
T = lambda s: datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
CTX = VerificationContext("run-1", "release-1", "tenant-1", "workspace-1")

def item(text="SYNTHETIC ONLY. A blue fixture needs review."):
    start = text.index("A blue") if "A blue" in text else 0
    quote = text[start:]
    return Evidence("E1", CTX.run_id, CTX.release_id, None, None,
                    "public_authority", "span-1", text, text_hash(text),
                    start, len(text), text_hash(quote), "a"*64)

def check(e, quote=None, context=CTX, authorized=True, handle="E1"):
    if quote is None:
        quote=e.unit_text[e.char_start:e.char_end]
    return verify_citation(handle,quote,{"E1":e},context,lambda _: authorized)

def assertion(**changes):
    a=Applicability("a1","v1","scope","IN","in_force",D("2020-01-01"),D("2021-01-01"),
                    T("2022-01-01"),None,True,True)
    return replace(a,**changes)

def temporal(items, law="2020-06-01", known="2023-01-01", **extra):
    return resolve(items,law_date=D(law),known_at=T(known),scope_key="scope",territory_key="IN",**extra)

# Retrieval: these tests inspect request structure, not an actual search engine.
def test_public_both_branches_have_identical_filters():
    s=Scope("embed-v1",release_id="r1",source_ids=("s1",))
    a,b=build_queries("fixture",[1,0],s,dimensions=2)
    assert a["query"]["bool"]["filter"] == b["query"]["knn"]["embedding"]["filter"]["bool"]["filter"]
    assert {"term":{"restricted":False}} in a["query"]["bool"]["filter"]
    assert {"term":{"is_synthetic":False}} in a["query"]["bool"]["filter"]
    assert "embedding" in a["_source"]["excludes"]

def test_private_scope_has_tenant_workspace_revision_inside_knn():
    s=Scope("e",tenant_id="t",workspace_id="w",acl_revision=2)
    a,b=build_queries("fixture",[1,0],s,dimensions=2)
    f=b["query"]["knn"]["embedding"]["filter"]["bool"]["filter"]
    for key,value in (("tenant_id","t"),("workspace_id","w"),("acl_revision",2),("state","active")):
        assert {"term":{key:value}} in f
    assert f==a["query"]["bool"]["filter"]

def test_empty_source_set_is_fail_closed():
    assert {"match_none":{}} in Scope("e",release_id="r").filters()

@pytest.mark.parametrize("s",[
    Scope("e"), Scope("e",tenant_id="t"), Scope("e",workspace_id="w"),
    Scope("e",tenant_id="t",workspace_id="w",acl_revision=0),
    Scope("e",tenant_id="t",workspace_id="w",acl_revision=1,release_id="r"),
    Scope("",release_id="r"), Scope("e",language="unknown",release_id="r")])
def test_invalid_scope_rejected(s):
    with pytest.raises(ValueError): s.filters()

@pytest.mark.parametrize("vec,dim",[([1],2),([0,0],2),([math.nan,0],2),([math.inf,0],2),([True,1],2),(["1",0],2),([],0)])
def test_bad_vectors_rejected(vec,dim):
    with pytest.raises(ValueError): validate_vector(vec,dim)

def test_good_vector():
    assert validate_vector([1,2],2)==[1.0,2.0]

@pytest.mark.parametrize("q,k",[("",80),(" ",80),("x"*12001,80),("x",0),("x",201),("x",True)])
def test_bad_query_budget(q,k):
    with pytest.raises(ValueError): build_queries(q,[1],Scope("e",release_id="r"),dimensions=1,candidates=k)

def test_rrf_duplicates_do_not_add_votes_or_shift_rank():
    assert reciprocal_rank_fusion([["a","a","b"]])==reciprocal_rank_fusion([["a","b"]])

def test_rrf_repeated_evidence_across_branches_increases_rank():
    result=reciprocal_rank_fusion([["a","b"],["b","c"]])
    assert result[0][0]=="b"
    assert result[0][1]==pytest.approx(1/62+1/61)

def test_rrf_tie_breaks_by_stable_id():
    assert [x[0] for x in reciprocal_rank_fusion([["b"],["a"]])]==["a","b"]

def test_rrf_empty():
    assert reciprocal_rank_fusion([])==[]

@pytest.mark.parametrize("kwargs",[{"constant":0},{"limit":0}])
def test_rrf_invalid_config(kwargs):
    with pytest.raises(ValueError): reciprocal_rank_fusion([["a"]],**kwargs)

def test_rrf_bad_id():
    with pytest.raises(ValueError): reciprocal_rank_fusion([[""]])

# Evidence integrity does not establish substantive legal correctness.
def test_exact_quote_passes():
    assert check(item()).handle=="E1"

@pytest.mark.parametrize("text",["न्याय — केवल परीक्षण।", "Synthetic 🙂 text", "Cafe\u0301 — synthetic", "A blue fixture\nneeds review."])
def test_unicode_code_point_spans(text):
    assert check(item(text)).unit_text==text

@pytest.mark.parametrize("change",[
    {"run_id":"different"},{"release_id":"different"},{"active":False},
    {"handle":"E2"},{"unit_text_sha256":"0"*64},{"excerpt_sha256":"0"*64},
    {"char_start":-1},{"char_end":10000},{"char_end":0},
    {"source_class":"model_memory"},{"artifact_sha256":"not-a-hash"},
    {"tenant_id":"tenant-1"}
])
def test_invalid_evidence_blocked(change):
    with pytest.raises(EvidenceError): check(replace(item(),**change))

@pytest.mark.parametrize("handle",["E0","E2","CASE-X","E1; DROP TABLE"])
def test_fabricated_handles_blocked(handle):
    with pytest.raises(EvidenceError): check(item(),handle=handle)

def test_wrong_quote_blocked():
    with pytest.raises(EvidenceError): check(item(),quote="A red fixture needs review.")

def test_revoked_acl_blocks_even_valid_quote():
    with pytest.raises(EvidenceError): check(item(),authorized=False)

def test_private_scope_valid():
    e=replace(item(),source_class="private_upload",release_id=None,tenant_id=CTX.tenant_id,workspace_id=CTX.workspace_id)
    assert check(e)==e

@pytest.mark.parametrize("field,value",[("tenant_id","other"),("workspace_id","other"),("release_id","r")])
def test_private_scope_mismatch(field,value):
    e=replace(item(),source_class="private_upload",release_id=None,tenant_id=CTX.tenant_id,workspace_id=CTX.workspace_id)
    with pytest.raises(EvidenceError):check(replace(e,**{field:value}))

def test_private_document_cannot_alone_establish_law():
    e=replace(item(),source_class="private_upload",release_id=None,tenant_id=CTX.tenant_id,workspace_id=CTX.workspace_id)
    with pytest.raises(EvidenceError):require_legal_authority("legal_proposition",[e])
    require_legal_authority("user_provided_fact",[e])

def test_public_authority_type_gate_only():
    require_legal_authority("legal_proposition",[item()])

# Dates: deliberately synthetic assertions, not Indian-law examples.
@pytest.mark.parametrize("law,expected",[("2019-12-31","unknown"),("2020-01-01","in_force"),("2020-12-31","in_force"),("2021-01-01","unknown")])
def test_half_open_legal_bounds(law,expected):
    assert temporal([assertion()],law=law).status==expected

def test_not_known_yet_is_excluded():
    assert temporal([assertion()],known="2021-01-01").status=="unknown"

def test_recorded_interval_boundary_selects_new_assertion():
    old=assertion(recorded_to=T("2023-01-01"))
    new=assertion(assertion_id="a2",unit_version_id="v2",recorded_from=T("2023-01-01"))
    assert temporal([old,new],known="2022-12-31").unit_version_id=="v1"
    assert temporal([old,new],known="2023-01-01").unit_version_id=="v2"

def test_unknown_commencement_not_invented():
    assert temporal([assertion(valid_from=None,status="unknown")]).status=="needs_review"

def test_conflicting_intervals_need_review():
    assert temporal([assertion(),assertion(assertion_id="a2",unit_version_id="v2")]).status=="conflict"

def test_unresolved_conditions_do_not_qualify():
    assert temporal([assertion(conditions_satisfied=False)]).status=="needs_review"

def test_unapproved_assertion_not_used():
    assert temporal([assertion(approved=False)]).status=="unknown"

@pytest.mark.parametrize("change",[{"scope_key":"other"},{"territory_key":"OTHER"}])
def test_other_territory_or_scope_excluded(change):
    assert temporal([assertion(**change)]).status=="unknown"

def test_repealed_version_not_returned_as_in_force():
    result=temporal([assertion(status="repealed")])
    assert result.status=="repealed" and result.unit_version_id is None

@pytest.mark.parametrize("change",[{"valid_to":D("2019-01-01")},{"recorded_to":T("2021-01-01")},{"recorded_from":datetime(2022,1,1)}])
def test_invalid_temporal_intervals_rejected(change):
    with pytest.raises(ValueError): temporal([assertion(**change)])

def test_naive_known_time_rejected():
    with pytest.raises(ValueError):resolve([assertion()],law_date=D("2020-01-01"),known_at=datetime(2023,1,1),scope_key="scope",territory_key="IN")
