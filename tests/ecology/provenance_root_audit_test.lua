-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.provenance_root_audit")
local failures=0

local function test(name,fn)
    local ok,detail=pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures=failures+1
        io.write("DETAIL\t",name,"\t",
            tostring(detail):gsub("[%z\1-\31\127]"," "):sub(1,500),"\n")
    end
end

local function fixture()
    return {
        schema_version=1,
        documents={
            {path="evidence/field.md",version="synthetic-1",
                basis="observation",upstream_paths={}},
            {path="evidence/summary-a.md",version="synthetic-1",
                basis="derived",upstream_paths={"evidence/field.md"}},
            {path="evidence/summary-b.md",version="synthetic-1",
                basis="derived",upstream_paths={"evidence/field.md"}}
        },
        selected_paths={"evidence/summary-a.md","evidence/summary-b.md"}
    }
end

test("two_summaries_do_not_create_two_roots",function()
    local r=M.evaluate(fixture())
    assert(r.ok and r.value.documented_observation_root_count==1)
    assert(not r.value.interpretation_limits.statistical_independence_established)
end)

test("unknown_origin_is_not_independent_evidence",function()
    local x=fixture()
    x.documents[1].basis="unresolved"
    local r=M.evaluate(x)
    assert(r.ok and r.value.documented_observation_root_count==0)
    assert(r.value.unresolved_terminal_count==1)
end)

test("cycles_and_missing_references_rejected",function()
    local x=fixture()
    x.documents[1].basis="derived"
    x.documents[1].upstream_paths={"evidence/summary-a.md"}
    assert(M.evaluate(x).error.code=="E_DERIVATION_CYCLE")
    x=fixture()
    x.documents[2].upstream_paths={"evidence/absent.md"}
    assert(M.evaluate(x).error.code=="E_UNRESOLVED_REFERENCE")
end)

test("derived_material_requires_lineage",function()
    local x=fixture()
    x.documents[2].upstream_paths={}
    assert(M.evaluate(x).error.code=="E_DERIVATION_REQUIRED")
end)

test("output_does_not_alias_input",function()
    local x=fixture()
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.roots.observation[1].version="changed"
    assert(x.documents[1].version=="synthetic-1")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
