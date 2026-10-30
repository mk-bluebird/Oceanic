-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Retain credit in derivatives. Credit grants no consent or authority.
-- Audit only: no species selection, evidence fetching, I/O, or actuation.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.

local M = {VERSION = "1.0.0"}
local ROLES = {
    "primary_producer", "habitat_builder", "consumer_regulator",
    "pollinator", "seed_disperser", "nutrient_connector", "decomposer"
}
local HABITATS = {"land", "freshwater", "marine"}
local ROLE_SET, HABITAT_SET = {}, {}
for _, v in ipairs(ROLES) do ROLE_SET[v] = true end
for _, v in ipairs(HABITATS) do HABITAT_SET[v] = true end
local utf8lib = utf8

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "shortlist." .. code,
        args = {}, category = "validation"
    }}
end

local function integer(v, lo, hi)
    return type(v) == "number" and v == v
        and v >= lo and v <= hi and v % 1 == 0
end

local function text(v)
    if type(v) ~= "string" or #v < 1 or #v > 1000 then return false end
    if utf8lib.len(v) == nil then return false end
    local content = false
    for _, cp in utf8lib.codes(v) do
        if cp < 32 or (cp >= 127 and cp <= 159) then return false end
        if cp > 32 then content = true end
    end
    return content
end

local function record(v, fields, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(v, key) == nil then return bad("E_MISSING", path .. "." .. key) end
    end
    for key in pairs(v) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", path) end
    end
end

local function sequence(v, maximum, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return nil, bad("E_SEQUENCE", path)
    end
    local n, highest = 0, 0
    for key in pairs(v) do
        if not integer(key, 1, maximum) then
            return nil, bad("E_SEQUENCE_INDEX", path)
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n ~= highest then return nil, bad("E_SEQUENCE_GAP", path) end
    return n
end

function M.evaluate(x)
    if type(utf8lib) ~= "table" or type(utf8lib.len) ~= "function"
        or type(utf8lib.codes) ~= "function" then
        return bad("E_ENVIRONMENT", "environment.utf8")
    end
    local e = record(x, {
        "schema_version", "protocol_version", "target_count",
        "role_minimums", "habitat_minimums", "species"
    }, "input")
    if e then return e end
    if x.schema_version ~= 1 then return bad("E_SCHEMA_VERSION", "input.schema_version") end
    if not text(x.protocol_version) then return bad("E_TEXT", "input.protocol_version") end
    if not integer(x.target_count, 1, 100) then
        return bad("E_TARGET_COUNT", "input.target_count")
    end

    local role_counts, habitat_counts = {}, {}
    for _, role in ipairs(ROLES) do role_counts[role] = 0 end
    for _, habitat in ipairs(HABITATS) do habitat_counts[habitat] = 0 end

    for _, spec in ipairs({
        {name = "role_minimums", allowed = ROLE_SET, order = ROLES},
        {name = "habitat_minimums", allowed = HABITAT_SET, order = HABITATS}
    }) do
        local v = x[spec.name]
        if type(v) ~= "table" or getmetatable(v) ~= nil then
            return bad("E_RECORD", "input." .. spec.name)
        end
        for key in pairs(v) do
            if not spec.allowed[key] then
                return bad("E_UNKNOWN_CATEGORY", "input." .. spec.name)
            end
        end
        for _, key in ipairs(spec.order) do
            if v[key] ~= nil and not integer(v[key], 0, 100) then
                return bad("E_MINIMUM", "input." .. spec.name .. "." .. key)
            end
        end
    end

    local n
    n, e = sequence(x.species, 100, "input.species")
    if not n then return e end
    local seen_names, names = {}, {}

    for i = 1, n do
        local row, path = x.species[i], "input.species[" .. i .. "]"
        e = record(row, {"name", "roles", "habitats", "evidence_reference"}, path)
        if e then return e end
        if not text(row.name) then return bad("E_TEXT", path .. ".name") end
        if not text(row.evidence_reference) then
            return bad("E_TEXT", path .. ".evidence_reference")
        end
        if seen_names[row.name] then return bad("E_DUPLICATE_SPECIES", path) end
        seen_names[row.name], names[i] = true, row.name

        for _, spec in ipairs({
            {name = "roles", allowed = ROLE_SET, counts = role_counts, limit = #ROLES},
            {name = "habitats", allowed = HABITAT_SET, counts = habitat_counts, limit = #HABITATS}
        }) do
            local size
            size, e = sequence(row[spec.name], spec.limit, path .. "." .. spec.name)
            if not size then return e end
            if size == 0 then return bad("E_EMPTY_CATEGORY_SET", path .. "." .. spec.name) end
            local seen = {}
            for j = 1, size do
                local value = row[spec.name][j]
                if type(value) ~= "string" or not spec.allowed[value] then
                    return bad("E_CATEGORY", path .. "." .. spec.name .. "[" .. j .. "]")
                end
                if seen[value] then return bad("E_DUPLICATE_CATEGORY", path .. "." .. spec.name) end
                seen[value] = true
                spec.counts[value] = spec.counts[value] + 1
            end
        end
    end

    local unmet = {}
    if n ~= x.target_count then unmet[#unmet + 1] = "target_count" end
    local required_roles, required_habitats = {}, {}
    for _, role in ipairs(ROLES) do
        local minimum = x.role_minimums[role] or 0
        required_roles[role] = minimum
        if role_counts[role] < minimum then unmet[#unmet + 1] = "role:" .. role end
    end
    for _, habitat in ipairs(HABITATS) do
        local minimum = x.habitat_minimums[habitat] or 0
        required_habitats[habitat] = minimum
        if habitat_counts[habitat] < minimum then unmet[#unmet + 1] = "habitat:" .. habitat end
    end
    table.sort(names)

    return {ok = true, value = {
        module_version = M.VERSION, schema_version = 1,
        protocol_version = x.protocol_version,
        status = #unmet == 0 and "screen_coverage_requirements_met"
            or "screen_coverage_requirements_unmet",
        target_count = x.target_count, actual_count = n,
        names_alphabetical = names,
        role_counts = role_counts, habitat_counts = habitat_counts,
        role_minimums = required_roles, habitat_minimums = required_habitats,
        unmet_requirements = unmet,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            grants_authority = false, establishes_consent = false
        },
        interpretation_limits = {
            scientific_role_assignments_verified = false,
            evidence_references_verified = false,
            candidate_selection_reproduced = false,
            taxonomic_names_reconciled = false,
            life_value_ranked = false,
            conservation_priority_established = false,
            external_action_performed = false
        }
    }}
end

return M
