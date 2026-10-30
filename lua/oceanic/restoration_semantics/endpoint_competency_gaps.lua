-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Supplied-review organization only; no I/O, storage, or actuation.

local M = {VERSION = "1.0.0"}
local MAX = 64

local ENDPOINTS = {
    "implementation", "structure", "survival", "function",
    "reproduction", "recruitment", "persistence"
}

local ENDPOINT_SET = {}
for _, name in ipairs(ENDPOINTS) do ENDPOINT_SET[name] = true end

local VERDICTS = {
    met = true, not_met = true,
    undetermined = true, not_assessed = true
}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "endpoint_competency_gaps." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, keys)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(keys) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function text(value)
    return type(value) == "string"
        and #value > 0 and #value <= 1000
        and not value:match("^[ \t\r\n]*$")
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function list_set(value)
    if not plain(value) then return nil end
    local count, highest = 0, 0

    for key in next, value do
        count = count + 1
        if count > MAX or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > MAX then
            return nil
        end
        if key > highest then highest = key end
    end

    if count ~= highest then return nil end

    local set = {}
    for _, item in ipairs(value) do
        if not text(item) or set[item] then return nil end
        set[item] = true
    end
    return set
end

local function choice(value, allowed)
    return type(value) == "string" and allowed[value] == true
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in next, value do result[key] = copy(item) end
    return result
end

local function difference(required, represented)
    local missing = {}
    for _, concept in ipairs(required) do
        if not represented[concept] then
            missing[#missing + 1] = concept
        end
    end
    table.sort(missing)
    return missing
end

function M.gap(input)
    if not shape(input, {
        "checklist_version", "required_concepts", "represented_concepts"
    }) or not text(input.checklist_version) then
        return fail("E_GAP_INPUT", "input")
    end

    local required = list_set(input.required_concepts)
    local represented = list_set(input.represented_concepts)
    if not required or not represented then
        return fail("E_CONCEPT_LIST", "input")
    end

    local missing = difference(input.required_concepts, represented)

    return ok({
        checklist_version = input.checklist_version,
        missing_concepts = missing,
        checklist_gap_empty = #missing == 0,
        actual_relevant_vocabulary_complete = "not_established",
        omission_probability_computed = false,
        contributor_awareness_assessed = false,
        assessment_scope = "supplied_checklist_difference"
    })
end

function M.restoration(input)
    if not shape(input, {
        "intended_outcome", "endpoints", "continuing_pressure_review"
    }) or not text(input.intended_outcome)
        or not plain(input.endpoints) then
        return fail("E_RESTORATION_INPUT", "input")
    end

    for key in next, input.endpoints do
        if type(key) ~= "string" or not ENDPOINT_SET[key] then
            return fail("E_ENDPOINT", "input.endpoints")
        end
    end

    local pressure = input.continuing_pressure_review
    if not choice(pressure, {
        reviewed = true, concern = true, unreviewed = true
    }) then
        return fail("E_PRESSURE_REVIEW", "input.continuing_pressure_review")
    end

    local records, unmet, unresolved = {}, {}, {}

    for _, name in ipairs(ENDPOINTS) do
        local supplied = rawget(input.endpoints, name)
        if supplied == nil then
            records[#records + 1] = {
                endpoint = name, verdict = "not_assessed"
            }
            unresolved[#unresolved + 1] = name
        else
            if not shape(supplied, {
                "verdict", "response_definition", "observation_period", "reason"
            }) or not choice(supplied.verdict, VERDICTS)
                or not text(supplied.response_definition)
                or not text(supplied.observation_period)
                or not text(supplied.reason) then
                return fail("E_ENDPOINT_REVIEW", "input.endpoints")
            end

            local record = copy(supplied)
            record.endpoint = name
            records[#records + 1] = record

            if supplied.verdict == "not_met" then
                unmet[#unmet + 1] = name
            elseif supplied.verdict == "undetermined"
                or supplied.verdict == "not_assessed" then
                unresolved[#unresolved + 1] = name
            end
        end
    end

    return ok({
        intended_outcome = input.intended_outcome,
        endpoint_reviews = records,
        declared_unmet_endpoints = unmet,
        unresolved_endpoints = unresolved,
        continuing_pressure_review = pressure,
        bottleneck_identified = false,
        overall_success_score_computed = false,
        endpoint_substitution_performed = false,
        scientific_judgments_verified = false,
        intervention_recommended = false
    })
end

function M.competency(input)
    if not shape(input, {
        "protocol_version", "split",
        "required_concepts", "represented_concepts",
        "model_applicability", "evidence_sufficiency",
        "acceptance_criteria", "partial_answer_supported"
    }) or not text(input.protocol_version) then
        return fail("E_COMPETENCY_INPUT", "input")
    end

    if input.split ~= "development" and input.split ~= "held_out" then
        return fail("E_SPLIT", "input.split")
    end

    local required = list_set(input.required_concepts)
    local represented = list_set(input.represented_concepts)
    if not required or not represented then
        return fail("E_CONCEPT_LIST", "input")
    end
    if #input.required_concepts == 0 then
        return fail("E_EMPTY_REQUIREMENTS", "input.required_concepts")
    end

    if not choice(input.model_applicability, {
        supported = true, concern = true, undetermined = true
    }) or not choice(input.evidence_sufficiency, {
        sufficient = true, partial = true, insufficient = true
    }) or not choice(input.acceptance_criteria, {
        pass = true, fail = true, undetermined = true
    }) or type(input.partial_answer_supported) ~= "boolean" then
        return fail("E_REVIEW_STATUS", "input")
    end

    local missing = difference(input.required_concepts, represented)
    local outcome

    if #missing > 0 then
        outcome = "representation_failure"
    elseif input.model_applicability == "supported"
        and input.evidence_sufficiency == "sufficient"
        and input.acceptance_criteria == "pass" then
        outcome = "answer_supported"
    elseif input.model_applicability == "supported"
        and input.evidence_sufficiency ~= "insufficient"
        and input.partial_answer_supported then
        outcome = "qualified_partial_answer"
    else
        outcome = "insufficient_basis"
    end

    return ok({
        protocol_version = input.protocol_version,
        split = input.split,
        outcome = outcome,
        missing_required_concepts = missing,
        supplied_model_applicability = input.model_applicability,
        supplied_evidence_sufficiency = input.evidence_sufficiency,
        supplied_acceptance_criteria = input.acceptance_criteria,
        partial_answer_support_declared = input.partial_answer_supported,
        labels_independently_verified = false,
        held_out_separation_verified = false,
        actual_vocabulary_complete = "not_established",
        assessment_scope = "supplied_competency_review"
    })
end

return M
