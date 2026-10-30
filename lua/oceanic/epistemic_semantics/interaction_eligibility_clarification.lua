-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- No I/O, persistence, networking, callbacks, or actuation.

local M = {VERSION = "1.0.0"}

local REGISTRY_VERSION = "1.0.0"
local ELIGIBILITY_POLICY_VERSION = "1.0.0"
local STOPPING_POLICY_VERSION = "1.0.0"

local INTENTS = {
    "describe", "compare", "explain", "forecast", "design_monitoring"
}

local INTENT_SET = {}
for _, intent in ipairs(INTENTS) do INTENT_SET[intent] = true end

local CRITERIA = {
    "comparison_prerequisites",
    "forecast_prerequisites",
    "alignment_prerequisites"
}

local CRITERION_SET = {}
for _, criterion in ipairs(CRITERIA) do
    CRITERION_SET[criterion] = true
end

local VALUES = {pass = true, fail = true, undetermined = true}

local CANDIDATES = {
    clarify_common_response = true,
    clarify_forecast_horizon = true,
    clarify_alignment = true
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
            message_key = "interaction_eligibility_clarification." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, required, optional, path)
    if not plain(value) then return fail("E_RECORD", path) end
    local allowed = {}

    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return fail("E_REQUIRED", path .. "." .. key)
        end
    end

    for _, key in ipairs(optional) do allowed[key] = true end

    for key in next, value do
        if not allowed[key] then return fail("E_UNKNOWN_FIELD", path) end
    end
    return ok(true)
end

local function array(value, maximum, path)
    if not plain(value) then return fail("E_ARRAY", path) end
    local count, highest = 0, 0

    for key in next, value do
        count = count + 1
        if count > maximum or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > maximum then
            return fail("E_ARRAY", path)
        end
        if key > highest then highest = key end
    end

    if count ~= highest then return fail("E_ARRAY", path) end
    return ok(count)
end

local function finite_nonnegative(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

local function bounded_integer(value)
    return finite_nonnegative(value)
        and value % 1 == 0
        and value <= 1000
end

function M.interactions(input)
    local result = shape(input,
        {"registry_version", "intents"}, {}, "input")
    if not result.ok then return result end

    if input.registry_version ~= REGISTRY_VERSION then
        return fail("E_REGISTRY_VERSION", "input.registry_version")
    end

    result = array(input.intents, #INTENTS, "input.intents")
    if not result.ok then return result end
    if result.value == 0 then
        return fail("E_INTENTS_EMPTY", "input.intents")
    end

    local selected, canonical = {}, {}
    for _, intent in ipairs(input.intents) do
        if type(intent) ~= "string" or not INTENT_SET[intent] then
            return fail("E_INTENT_VALUE", "input.intents")
        end
        if selected[intent] then
            return fail("E_INTENT_DUPLICATE", "input.intents")
        end
        selected[intent] = true
    end

    for _, intent in ipairs(INTENTS) do
        if selected[intent] then canonical[#canonical + 1] = intent end
    end

    local records = {}
    if selected.compare and selected.forecast then
        records[1] = {
            rule_code = "R_COMPARE_FORECAST_ALIGNMENT",
            rule_version = "1.0.0",
            triggering_intents = {"compare", "forecast"},
            introduced_requirements = {"forecast_alignment"},
            assessment_status = "not_assessed"
        }
    end

    return ok({
        registry_version = REGISTRY_VERSION,
        canonical_intents = canonical,
        interaction_records = records,
        scientific_support_assessed = false,
        retention_authorized = false
    })
end

function M.eligibility(input)
    local result = shape(input,
        {"policy_version", "decision", "assessments"}, {}, "input")
    if not result.ok then return result end

    if input.policy_version ~= ELIGIBILITY_POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end
    if input.decision ~= "proceed_to_comparative_forecast_evaluation" then
        return fail("E_DECISION", "input.decision")
    end
    if not plain(input.assessments) then
        return fail("E_RECORD", "input.assessments")
    end

    for criterion, value in next, input.assessments do
        if type(criterion) ~= "string" or not CRITERION_SET[criterion] then
            return fail("E_CRITERION", "input.assessments")
        end
        if type(value) ~= "string" or not VALUES[value] then
            return fail("E_ASSESSMENT_VALUE", "input.assessments")
        end
    end

    local overall = "pass"
    local failed, unresolved, missing = {}, {}, {}

    for _, criterion in ipairs(CRITERIA) do
        local value = rawget(input.assessments, criterion)
        if value == nil then
            missing[#missing + 1] = criterion
            unresolved[#unresolved + 1] = criterion
            if overall ~= "fail" then overall = "undetermined" end
        elseif value == "fail" then
            failed[#failed + 1] = criterion
            overall = "fail"
        elseif value == "undetermined" then
            unresolved[#unresolved + 1] = criterion
            if overall ~= "fail" then overall = "undetermined" end
        end
    end

    return ok({
        policy_version = ELIGIBILITY_POLICY_VERSION,
        decision = input.decision,
        analytical_eligibility = overall,
        failed_criteria = failed,
        unresolved_criteria = unresolved,
        missing_assessments = missing,
        assessment_basis = "supplied_prerequisite_assessments",
        assessments_independently_verified = false,
        participation_assessed = false,
        permission_assessed = false,
        action_authorized = false
    })
end

function M.next_clarification(input)
    local result = shape(input, {
        "policy_version", "participant_preference",
        "asked_count", "maximum_questions",
        "burden_used", "burden_limit", "candidates"
    }, {}, "input")
    if not result.ok then return result end

    if input.policy_version ~= STOPPING_POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end

    local preference = input.participant_preference
    if preference ~= "continue" and preference ~= "pause"
        and preference ~= "stop" then
        return fail("E_PREFERENCE", "input.participant_preference")
    end

    if not bounded_integer(input.asked_count)
        or not bounded_integer(input.maximum_questions) then
        return fail("E_QUESTION_COUNT", "input")
    end

    if not finite_nonnegative(input.burden_used)
        or not finite_nonnegative(input.burden_limit) then
        return fail("E_BURDEN_VALUE", "input")
    end

    result = array(input.candidates, 3, "input.candidates")
    if not result.ok then return result end

    local seen = {}
    for _, candidate in ipairs(input.candidates) do
        result = shape(candidate,
            {"code", "request_permission", "burden_cost"},
            {}, "input.candidates")
        if not result.ok then return result end

        if type(candidate.code) ~= "string"
            or not CANDIDATES[candidate.code] then
            return fail("E_CANDIDATE", "input.candidates")
        end
        if seen[candidate.code] then
            return fail("E_CANDIDATE_DUPLICATE", "input.candidates")
        end
        seen[candidate.code] = true

        local permission = candidate.request_permission
        if permission ~= "allowed" and permission ~= "not_allowed"
            and permission ~= "undetermined" then
            return fail("E_REQUEST_PERMISSION", "input.candidates")
        end
        if not finite_nonnegative(candidate.burden_cost) then
            return fail("E_BURDEN_VALUE", "input.candidates")
        end
    end

    local action, reason, candidate_code
    local next_candidate = input.candidates[1]

    if preference == "stop" then
        action, reason = "stop", "participant_requested_stop"
    elseif preference == "pause" then
        action, reason = "pause", "participant_requested_pause"
    elseif not next_candidate then
        action, reason = "stop", "no_candidates"
    elseif input.asked_count >= input.maximum_questions then
        action, reason = "stop", "question_limit_reached"
    elseif next_candidate.request_permission ~= "allowed" then
        action, reason = "defer", "request_not_explicitly_allowed"
    elseif input.burden_used > input.burden_limit
        or next_candidate.burden_cost >
            input.burden_limit - input.burden_used then
        action, reason = "stop", "burden_limit_reached"
    else
        action, reason = "propose_question", "within_declared_limits"
        candidate_code = next_candidate.code
    end

    return ok({
        policy_version = STOPPING_POLICY_VERSION,
        action = action,
        reason = reason,
        candidate_code = candidate_code,
        candidate_ordering = "caller_supplied",
        burden_units = "caller_defined_planning_units",
        optimality_claimed = false,
        decision_value_estimated = false,
        preference_inferred = false,
        permission_independently_verified = false,
        request_executed = false
    })
end

return M
