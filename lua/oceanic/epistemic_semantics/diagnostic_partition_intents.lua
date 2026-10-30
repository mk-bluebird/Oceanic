-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local structural accounting; no logging, storage, networking, or action.

local M = {
    VERSION = "1.0.0",
    FIELD_SET_VERSION = "1.0.0",
    INTERACTION_RULE_VERSION = "1.0.0",
    PATH_TAXONOMY_VERSION = "1.0.0"
}

local CORE = {
    "subject", "relationship", "response",
    "spatial_scope", "temporal_scope",
    "measurement_basis", "evidence_basis"
}

local INTENTS = {
    "describe", "compare", "explain",
    "forecast", "design_monitoring"
}

local ALL_FIELDS = {
    "subject", "relationship", "response",
    "spatial_scope", "temporal_scope",
    "measurement_basis", "evidence_basis",
    "comparison_basis", "competing_explanations",
    "event_definition", "issue_time",
    "forecast_horizon", "evaluation_basis",
    "sampling_basis", "forecast_alignment"
}

local ATOMIC = {
    describe = {},
    compare = {"comparison_basis"},
    explain = {"competing_explanations"},
    forecast = {
        "event_definition", "issue_time",
        "forecast_horizon", "evaluation_basis"
    },
    design_monitoring = {"sampling_basis"}
}

local STATES = {
    "supplied", "unknown", "not_collected",
    "withheld", "declared_not_applicable", "absent"
}

local PATHS = {
    top_level = "input",
    frame = "input.frame",
    declaration = "input.frame.declaration",
    intents = "input.intents",
    required_fields = "input.required_fields",
    states = "input.states"
}

local FIELD_SET, INTENT_SET, STATE_SET = {}, {}, {}
for _, name in ipairs(ALL_FIELDS) do FIELD_SET[name] = true end
for _, name in ipairs(INTENTS) do INTENT_SET[name] = true end
for _, name in ipairs(STATES) do STATE_SET[name] = true end

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, location)
    return {
        ok = false,
        error = {
            code = code,
            path = PATHS[location] or "input",
            message_key = "diagnostic_partition_intents." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function array(value, maximum, location)
    if not plain(value) then return fail("E_ARRAY", location) end

    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > maximum or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > maximum then
            return fail("E_ARRAY", location)
        end
        if key > highest then highest = key end
    end

    if count ~= highest then return fail("E_ARRAY", location) end
    return ok(count)
end

local function copy_array(items)
    local result = {}
    for i, item in ipairs(items) do result[i] = item end
    return result
end

local function buckets()
    local result = {}
    for _, state in ipairs(STATES) do result[state] = {} end
    return result
end

function M.unknown_field_error(location)
    if type(location) ~= "string" or not PATHS[location] then
        return fail("E_DIAGNOSTIC_LOCATION", "top_level")
    end
    return fail("E_UNKNOWN_FIELD", location)
end

function M.compose(raw_intents)
    local checked = array(raw_intents, #INTENTS, "intents")
    if not checked.ok then return checked end
    if checked.value == 0 then
        return fail("E_INTENTS_EMPTY", "intents")
    end

    local selected = {}
    for _, intent in ipairs(raw_intents) do
        if type(intent) ~= "string" or not INTENT_SET[intent] then
            return fail("E_INTENT_VALUE", "intents")
        end
        if selected[intent] then
            return fail("E_INTENT_DUPLICATE", "intents")
        end
        selected[intent] = true
    end

    local canonical, required = {}, {}
    for _, field in ipairs(CORE) do required[field] = true end

    for _, intent in ipairs(INTENTS) do
        if selected[intent] then
            canonical[#canonical + 1] = intent
            for _, field in ipairs(ATOMIC[intent]) do
                required[field] = true
            end
        end
    end

    local interactions = {}
    if selected.compare and selected.forecast then
        required.forecast_alignment = true
        interactions[1] = {
            rule_code = "R_COMPARE_FORECAST_ALIGNMENT",
            triggering_intents = {"compare", "forecast"},
            introduced_fields = {"forecast_alignment"},
            satisfaction = "not_assessed"
        }
    end

    local ordered = {}
    for _, field in ipairs(ALL_FIELDS) do
        if required[field] then ordered[#ordered + 1] = field end
    end

    return ok({
        canonical_intents = canonical,
        required_fields = ordered,
        interaction_records = interactions,
        field_set_version = M.FIELD_SET_VERSION,
        interaction_rule_version = M.INTERACTION_RULE_VERSION,
        requirements_satisfied = "not_assessed",
        authority_assessed = false
    })
end

function M.partition(input)
    if not plain(input) then
        return fail("E_RECORD", "top_level")
    end

    for key in next, input do
        if key ~= "required_fields" and key ~= "states" then
            return fail("E_UNKNOWN_FIELD", "top_level")
        end
    end

    if rawget(input, "required_fields") == nil then
        return fail("E_REQUIRED_FIELDS_MISSING", "required_fields")
    end
    if rawget(input, "states") == nil then
        return fail("E_STATES_MISSING", "states")
    end

    local checked = array(
        input.required_fields, #ALL_FIELDS, "required_fields")
    if not checked.ok then return checked end

    if not plain(input.states) then
        return fail("E_RECORD", "states")
    end

    local required_set = {}
    for _, field in ipairs(input.required_fields) do
        if type(field) ~= "string" or not FIELD_SET[field] then
            return fail("E_FIELD_VALUE", "required_fields")
        end
        if required_set[field] then
            return fail("E_FIELD_DUPLICATE", "required_fields")
        end
        required_set[field] = true
    end

    local entries = 0
    for field, state in next, input.states do
        entries = entries + 1
        if entries > #ALL_FIELDS then
            return fail("E_FIELD_LIMIT", "states")
        end
        if type(field) ~= "string" or not FIELD_SET[field] then
            return fail("E_UNKNOWN_FIELD", "states")
        end
        if type(state) ~= "string" or not STATE_SET[state] then
            return fail("E_STATE_VALUE", "states")
        end
    end

    local required_partition = buckets()
    local declared_partition = buckets()
    local additional, required_declared, declared_total = {}, 0, 0
    local supplied = 0

    for _, field in ipairs(ALL_FIELDS) do
        local state = rawget(input.states, field) or "absent"

        if required_set[field] then
            local bucket = required_partition[state]
            bucket[#bucket + 1] = field

            if state ~= "absent" then
                required_declared = required_declared + 1
            end
            if state == "supplied" then supplied = supplied + 1 end
        end

        if state ~= "absent" then
            local bucket = declared_partition[state]
            bucket[#bucket + 1] = field
            declared_total = declared_total + 1

            if not required_set[field] then
                additional[#additional + 1] = field
            end
        end
    end

    local count = #input.required_fields
    local ratios

    if count == 0 then
        ratios = {status = "undefined", reason = "zero_denominator"}
    else
        ratios = {
            status = "defined",
            declaration = required_declared / count,
            supplied = supplied / count
        }
    end

    return ok({
        field_set_version = M.FIELD_SET_VERSION,
        ordering = "registry_order",
        required_count = count,
        required_declared_count = required_declared,
        recognized_declared_count = declared_total,
        required_partition = required_partition,
        declared_partition = declared_partition,
        additional_declared_fields = additional,
        ratios = ratios,
        denominator_scope = "submitted_registered_field_subset",
        denominator_provenance_verified = false,
        assessment_scope = "declaration_accounting_only"
    })
end

function M.describe()
    return ok({
        module_version = M.VERSION,
        field_set_version = M.FIELD_SET_VERSION,
        interaction_rule_version = M.INTERACTION_RULE_VERSION,
        path_taxonomy_version = M.PATH_TAXONOMY_VERSION,
        registered_fields = copy_array(ALL_FIELDS),
        registered_states = copy_array(STATES),
        registered_intents = copy_array(INTENTS),
        diagnostics_accept_rejected_keys = false
    })
end

return M
