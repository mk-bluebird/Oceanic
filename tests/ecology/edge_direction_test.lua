-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m=require("lua.ecology.edge_direction")
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
        source="Synthetic disperser",source_class="taxon",
        relation="disperses_seeds",
        target="Synthetic plant",target_class="taxon",
        scope="Synthetic relationship fixture",
        evidence_reference="Synthetic fixture only",
        output_form="inverse"
    }
end

test("inverse_preserves_assertion_metadata",function()
    local x=fixture()
    local r=m.translate(x)
    assert(r.ok)
    assert(r.value.edge.source==x.target)
    assert(r.value.edge.relation=="seeds_dispersed_by")
    assert(r.value.edge.scope==x.scope)
    assert(not r.value.interpretation_limits.reciprocal_effect_inferred)
end)

test("round_trip_returns_original_edge",function()
    local x=fixture()
    local first=m.translate(x).value.edge
    local back={
        schema_version=1,
        source=first.source,source_class=first.source_class,
        relation=first.relation,
        target=first.target,target_class=first.target_class,
        scope=first.scope,evidence_reference=first.evidence_reference,
        output_form="canonical"
    }
    local r=m.translate(back)
    assert(r.ok)
    for _,key in ipairs({
        "source","source_class","relation","target","target_class",
        "scope","evidence_reference"
    }) do
        assert(r.value.edge[key]==x[key],key)
    end
end)

test("canonicalization_is_idempotent",function()
    local x=fixture()
    x.output_form="canonical"
    local a=m.translate(x).value.edge
    assert(a.source==x.source and a.relation==x.relation)
end)

test("endpoint_classes_and_unknown_predicates",function()
    local x=fixture()
    x.target_class="compartment"
    assert(m.translate(x).error.code=="E_ENDPOINT_CLASS")
    x=fixture()
    x.relation="mutualism"
    assert(m.translate(x).error.code=="E_RELATION")
end)

test("output_does_not_modify_input",function()
    local x=fixture()
    local r=m.translate(x)
    assert(r.ok)
    r.value.edge.source="Changed"
    assert(x.source=="Synthetic disperser")
    assert(x.relation=="disperses_seeds")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
