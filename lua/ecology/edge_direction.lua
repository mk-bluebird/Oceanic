-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Proposed project vocabulary; no external ontology mapping claimed.
-- Local translation only; no I/O or biological inference.

local M = {VERSION = "1.0.0"}

local RULES = {
    {"consumes", "consumed_by",
        {taxon=true}, {taxon=true, compartment=true}},
    {"habitat_support", "habitat_supported_by",
        {taxon=true, habitat=true}, {taxon=true}},
    {"pollinates", "pollinated_by",
        {taxon=true}, {taxon=true}},
    {"disperses_seeds", "seeds_dispersed_by",
        {taxon=true}, {taxon=true}},
    {"transfers_nutrients", "receives_nutrients_from",
        {compartment=true}, {compartment=true}}
}

local LOOKUP = {}
for _, rule in ipairs(RULES) do
    LOOKUP[rule[1]] = {rule=rule, reversed=false}
    LOOKUP[rule[2]] = {rule=rule, reversed=true}
end

local function bad(code, path)
    return {ok=false, error={
        code=code, field_path=path,
        message_key="edge_direction." .. code,
        args={}, category="validation"
    }}
end

local function text(v)
    if type(v) ~= "string" or #v < 1 or #v > 500
        or not v:match("%S") then return false end
    for i=1,#v do
        local b=v:byte(i)
        if b < 32 or b > 126 then return false end
    end
    return true
end

function M.translate(x)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", "input")
    end
    local fields = {
        "schema_version", "source", "source_class",
        "relation", "target", "target_class",
        "scope", "evidence_reference", "output_form"
    }
    local allowed={}
    for _, key in ipairs(fields) do
        allowed[key]=true
        if rawget(x,key)==nil then return bad("E_MISSING","input." .. key) end
    end
    for key in pairs(x) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD","input") end
    end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION","input.schema_version")
    end
    for _, key in ipairs({
        "source","source_class","relation","target","target_class",
        "scope","evidence_reference","output_form"
    }) do
        if not text(x[key]) then return bad("E_TEXT","input." .. key) end
    end
    if x.output_form ~= "canonical" and x.output_form ~= "inverse" then
        return bad("E_OUTPUT_FORM","input.output_form")
    end

    local entry=LOOKUP[x.relation]
    if not entry then return bad("E_RELATION","input.relation") end
    local rule=entry.rule
    local source,target=x.source,x.target
    local source_class,target_class=x.source_class,x.target_class

    if entry.reversed then
        source,target=target,source
        source_class,target_class=target_class,source_class
    end
    if not rule[3][source_class] or not rule[4][target_class] then
        return bad("E_ENDPOINT_CLASS","input")
    end

    local relation=rule[1]
    if x.output_form=="inverse" then
        source,target=target,source
        source_class,target_class=target_class,source_class
        relation=rule[2]
    end

    return {ok=true,value={
        module_version=M.VERSION,
        schema_version=1,
        status="screen_relation_direction_translated",
        edge={
            source=source,source_class=source_class,
            relation=relation,
            target=target,target_class=target_class,
            scope=x.scope,evidence_reference=x.evidence_reference
        },
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            biological_assertion_verified=false,
            evidence_reference_verified=false,
            reciprocal_effect_inferred=false,
            energy_flux_estimated=false,
            external_ontology_alignment_verified=false,
            external_action_performed=false
        }
    }}
end

return M
