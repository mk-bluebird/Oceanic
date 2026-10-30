-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local test disposition only; no I/O, fitting, or external actions.

local M = {VERSION = "1.0.0"}
local MAX_CHECKS = 100

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "conditional_warning." .. code,
        args = {}, category = "validation"
    }}
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

function M.evaluate(x)
    local e = record(x, {
        "schema_version", "protocol_frozen_before_outcome",
        "assumption_checks", "event_status",
        "observation_adequacy", "precursor_status"
    }, "input")
    if e then return e end
    if x.schema_version ~= 1 then return bad("E_SCHEMA_VERSION", "input.schema_version") end
    if type(x.protocol_frozen_before_outcome) ~= "boolean" then
        return bad("E_BOOLEAN", "input.protocol_frozen_before_outcome")
    end

    local checks = x.assumption_checks
    if type(checks) ~= "table" or getmetatable(checks) ~= nil then
        return bad("E_SEQUENCE", "input.assumption_checks")
    end
    local n, highest = 0, 0
    for key in pairs(checks) do
        if type(key) ~= "number" or key ~= key or key % 1 ~= 0
            or key < 1 or key > MAX_CHECKS then
            return bad("E_SEQUENCE_INDEX", "input.assumption_checks")
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n == 0 then return bad("E_EMPTY", "input.assumption_checks") end
    if n ~= highest then return bad("E_SEQUENCE_GAP", "input.assumption_checks") end

    local failed, unknown = {}, {}
    for i = 1, n do
        local value = checks[i]
        if value ~= "met" and value ~= "not_met" and value ~= "unknown" then
            return bad("E_ASSUMPTION_STATE", "input.assumption_checks[" .. i .. "]")
        end
        if value == "not_met" then failed[#failed + 1] = i end
        if value == "unknown" then unknown[#unknown + 1] = i end
    end

    if x.event_status ~= "confirmed" and x.event_status ~= "absent"
        and x.event_status ~= "uncertain" then
        return bad("E_EVENT_STATUS", "input.event_status")
    end
    if x.observation_adequacy ~= "adequate"
        and x.observation_adequacy ~= "inadequate"
        and x.observation_adequacy ~= "unknown" then
        return bad("E_OBSERVATION_STATUS", "input.observation_adequacy")
    end
    if x.precursor_status ~= "present" and x.precursor_status ~= "absent"
        and x.precursor_status ~= "not_assessable" then
        return bad("E_PRECURSOR_STATUS", "input.precursor_status")
    end

    local status
    if not x.protocol_frozen_before_outcome then
        status = "screen_exploratory_protocol"
    elseif #failed > 0 then
        status = "screen_ineligible_assumptions"
    elseif #unknown > 0 then
        status = "screen_eligibility_unresolved"
    elseif x.event_status == "absent" then
        status = "screen_nonevent_for_separate_false_alarm_analysis"
    elseif x.event_status == "uncertain" then
        status = "screen_event_unresolved"
    elseif x.observation_adequacy ~= "adequate"
        or x.precursor_status == "not_assessable" then
        status = "screen_inconclusive_observation"
    elseif x.precursor_status == "absent" then
        status = "screen_candidate_counterexample_to_strict_claim"
    else
        status = "screen_eligible_event_consistent_with_claim"
    end

    return {ok = true, value = {
        module_version = M.VERSION, schema_version = 1,
        status = status,
        failed_assumption_positions = failed,
        unknown_assumption_positions = unknown,
        assumption_count = n,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false, grants_authority = false
        },
        interpretation_limits = {
            protocol_freeze_verified = false,
            assumption_measurements_verified = false,
            event_adjudication_verified = false,
            observation_power_verified = false,
            statistical_falsification_performed = false,
            universal_claim_confirmed = false,
            external_action_performed = false
        }
    }}
end

return M
