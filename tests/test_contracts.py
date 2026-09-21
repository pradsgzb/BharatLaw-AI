"""Contract/fixture structural validation; not database or OpenSearch execution."""
from pathlib import Path
import copy, hashlib, json, re
import pytest, yaml
from jsonschema import Draft202012Validator, FormatChecker

ROOT=Path(__file__).resolve().parents[1]
SCHEMAS=["legal_document","research_request","answer"]
EXAMPLES={"legal_document":"synthetic_document","research_request":"synthetic_research_request","answer":"synthetic_answer"}

def load(path):return json.loads((ROOT/path).read_text())

def walk(value):
    yield value
    if isinstance(value,dict):
        for v in value.values():yield from walk(v)
    elif isinstance(value,list):
        for v in value:yield from walk(v)

@pytest.mark.parametrize("name",SCHEMAS)
def test_schema_and_example(name):
    schema=load(f"contracts/{name}.schema.json")
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema,format_checker=FormatChecker()).validate(load(f"examples/{EXAMPLES[name]}.json"))

@pytest.mark.parametrize("name",SCHEMAS)
def test_unknown_top_level_fields_rejected(name):
    example=load(f"examples/{EXAMPLES[name]}.json");example["untrusted_extension"]=True
    assert not Draft202012Validator(load(f"contracts/{name}.schema.json")).is_valid(example)

@pytest.mark.parametrize("path",sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob("*.json")))
def test_all_json_parse(path):
    load(path)

@pytest.mark.parametrize("path",sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob("*.yaml")))
def test_all_yaml_parse(path):
    assert yaml.safe_load((ROOT/path).read_text()) is not None

def test_fixture_text_and_quote_hashes():
    doc=load("examples/synthetic_document.json")
    assert doc["is_synthetic"] is True and doc["representation_kind"]=="synthetic_fixture"
    for unit in doc["units"]:
        assert hashlib.sha256(unit["exact_text"].encode()).hexdigest()==unit["text_sha256"]
        for span in unit["spans"]:
            assert 0<=span["char_start"]<span["char_end"]<=len(unit["exact_text"])
            quote=unit["exact_text"][span["char_start"]:span["char_end"]]
            assert hashlib.sha256(quote.encode()).hexdigest()==span["quote_sha256"]

def test_fixture_answer_has_only_declared_evidence_and_exact_quote():
    a=load("examples/synthetic_answer.json");d=load("examples/synthetic_document.json")
    handles={x["handle"] for x in a["citations"]}
    for c in a["claims"]:
        assert set(c["supporting_evidence"]+c["contrary_evidence"])<=handles
    u=d["units"][0];s=u["spans"][0]
    assert a["citations"][0]["excerpt"]==u["exact_text"][s["char_start"]:s["char_end"]]
    assert a["verification"]["lawyer_reviewed"] is False

def test_openapi_local_refs_resolve_and_no_duplicate_operation_ids():
    api=yaml.safe_load((ROOT/"contracts/openapi.yaml").read_text())
    assert api["openapi"].startswith("3.1")
    for value in walk(api):
        if isinstance(value,dict) and "$ref" in value:
            ref=value["$ref"]
            assert ref.startswith("#/")
            node=api
            for key in ref[2:].split("/"):
                node=node[key.replace("~1","/").replace("~0","~")]
    ids=[]
    for path,item in api["paths"].items():
        placeholders=set(re.findall(r"\{([^}]+)\}",path))
        for method,operation in item.items():
            if method not in {"get","post","put","patch","delete","head","options"}:continue
            ids.append(operation["operationId"])
            params=item.get("parameters",[])+operation.get("parameters",[])
            actual={p["name"] for p in params if p.get("in")=="path" and p.get("required") is True}
            assert placeholders==actual
            assert operation.get("responses")
    assert len(ids)==len(set(ids))

def test_all_v1_routes_have_authenticated_security_and_tenant_selector():
    api=yaml.safe_load((ROOT/"contracts/openapi.yaml").read_text())
    assert api["security"]
    for path,item in api["paths"].items():
        if path.startswith("/v1/"):
            assert {"$ref":"#/components/parameters/TenantSelector"} in item["parameters"]
            for method,operation in item.items():
                if method in {"get","post","put","patch","delete"}:
                    assert operation.get("security",api["security"])
                    assert operation.get("x-required-permission")

@pytest.mark.parametrize("filename",["public_chunks.index.json","private_chunks.index.json"])
def test_vector_mappings_are_strict_and_lucene(filename):
    m=load("opensearch/"+filename)["mappings"]
    assert m["dynamic"]=="strict"
    assert m["properties"]["embedding"]["dimension"]==1024
    assert m["properties"]["embedding"]["method"]["engine"]=="lucene"
    assert m["properties"]["source_text"]["index"] is False

def test_private_mapping_has_workspace_boundary():
    p=load("opensearch/private_chunks.index.json")["mappings"]["properties"]
    assert {"tenant_id","workspace_id","acl_revision","state"}<=p.keys()

def test_source_and_provider_registers_fail_closed():
    src=yaml.safe_load((ROOT/"config/source-register.example.yaml").read_text())
    assert all(not s["enabled"] and s["policy_status"]=="pending" for s in src["sources"])
    assert all(v is False for v in src["permission_defaults"].values())
    assert load("config/provider-register.example.json")["profiles"]==[]

def test_reference_sql_has_unique_table_names_and_required_groups():
    # This is text/consistency inspection ONLY, not a SQL parser or execution.
    sql=(ROOT/"db/reference_schema.sql").read_text()
    tables=re.findall(r"CREATE TABLE bl\.(\w+)\s*\(",sql)
    assert len(tables)==len(set(tables))
    assert {"source_spans","applicability_assertions","release_legal_edges","release_unit_versions","claim_evidence","deletion_requests","legal_holds"}<=set(tables)
    assert "FORCE ROW LEVEL SECURITY" in sql
    assert "synthetic_fixture" in sql
