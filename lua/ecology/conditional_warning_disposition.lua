-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 2.0.0; schema 2; gate order 2.
-- Retain credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local disposition screen; no I/O, protocol retrieval, or external action.

local V = require("lua.ecology.validation")
local M = {VERSION = "2.0.0", SCHEMA_VERSION = 2, GATE_ORDER_VERSION = 2}

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "scope", "protocol_reference",
        "protocol_frozen_before_outcome", "assumption_checks",
        "event_status", "observation_adequacy", "precursor_status"
    }, {"extensions"}, "input")
    if not r.ok then return r end

    if x.schema_version ~= 2 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version",
            {expected = 2, actual = V.describe(x.schema_version)})
    end
    r = V.text(x.scope, 500, "input.scope")
    if not r.ok then return r end
    if type(x.protocol_frozen_before_outcome) ~= "boolean" then
        return V.fail("E_BOOLEAN", "input.protocol_frozen_before_outcome",
            {actual_type = type(x.protocol_frozen_before_outcome)})
    end

    local p = x.protocol_reference
    r = V.record(p, {
        "repository", "path", "version", "declared_check_count",
        "freeze_time_s", "outcome_inspection_time_s"
    }, {}, "input.protocol_reference")
    if not r.ok then return r end
    r = V.enum(p.repository, {
        "mk-bluebird/Augmented-Hub", "mk-bluebird/Skynet"
    }, "E_REPOSITORY", "input.protocol_reference.repository")
    if not r.ok then return r end

    for _, key in ipairs({"path", "version"}) do
        r = V.text(p[key], 500, "input.protocol_reference." .. key)
        if not r.ok then return r end
    end
    if p.path:sub(1,1) == "/" or p.path:find("\\", 1, true)
        or p.path:find("//", 1, true) or p.path:sub(-1) == "/" then
        return V.fail("E_RELATIVE_PATH", "input.protocol_reference.path")
    end
    for segment in p.path:gmatch("[^/]+") do
        if segment == "." or segment == ".." or segment:find(":", 1, true) then
            return V.fail("E_RELATIVE_PATH", "input.protocol_reference.path")
        end
    end

    local maximum = V.limit("assumption_checks")
    if not V.finite(p.declared_check_count) or p.declared_check_count % 1 ~= 0
        or p.declared_check_count < 1 or p.declared_check_count > maximum then
        return V.fail("E_CHECK_COUNT", "input.protocol_reference.declared_check_count",
            {minimum = 1, maximum = maximum})
    end
    if not V.finite(p.outcome_inspection_time_s) then
        return V.fail("E_TIMESTAMP", "input.protocol_reference.outcome_inspection_time_s")
    end
    if p.freeze_time_s ~= false and not V.finite(p.freeze_time_s) then
        return V.fail("E_TIMESTAMP", "input.protocol_reference.freeze_time_s")
    end
    if x.protocol_frozen_before_outcome then
        if p.freeze_time_s == false then
            return V.fail("E_FREEZE_TIME_REQUIRED", "input.protocol_reference.freeze_time_s")
        end
        if p.freeze_time_s > p.outcome_inspection_time_s then
            return V.fail("E_FREEZE_CHRONOLOGY", "input.protocol_reference.freeze_time_s")
        end
    end

    r = V.sequence(x.assumption_checks, maximum, "input.assumption_checks")
    if not r.ok then return r end
    if r.value ~= p.declared_check_count then
        return V.fail("E_CHECK_COUNT_MISMATCH", "input.assumption_checks",
            {actual = r.value, expected = p.declared_check_count})
    end

    local failed, unknown, copied_checks = {}, {}, {}
    for i, value in ipairs(x.assumption_checks) do
        r = V.enum(value, {"met", "not_met", "unknown"},
            "E_ASSUMPTION_STATE", "input.assumption_checks[" .. i .. "]")
        if not r.ok then return r end
        copied_checks[i] = value
        if value == "not_met" then failed[#failed + 1] = i end
        if value == "unknown" then unknown[#unknown + 1] = i end
    end

    for _, spec in ipairs({
        {"event_status", {"confirmed", "absent", "uncertain"}, "E_EVENT_STATUS"},
        {"observation_adequacy", {"adequate", "inadequate", "unknown"}, "E_OBSERVATION_STATUS"},
        {"precursor_status", {"present", "absent", "not_assessable"}, "E_PRECURSOR_STATUS"}
    }) do
        r = V.enum(x[spec[1]], spec[2], spec[3], "input." .. spec[1])
        if not r.ok then return r end
    end

    local extensions = {}
    if x.extensions ~= nil then
        r = V.record(x.extensions, {}, {"tolerance_reference"}, "input.extensions")
        if not r.ok then return r end
        if x.extensions.tolerance_reference ~= nil then
            r = V.text(x.extensions.tolerance_reference, 500,
                "input.extensions.tolerance_reference")
            if not r.ok then return r end
            extensions.tolerance_reference = x.extensions.tolerance_reference
        end
    end

    local gates = {
        {"protocol_freeze", not x.protocol_frozen_before_outcome,
            "screen_exploratory_protocol"},
        {"failed_assumptions", #failed > 0, "screen_ineligible_assumptions"},
        {"unknown_assumptions", #unknown > 0, "screen_eligibility_unresolved"},
        {"event_uncertain", x.event_status == "uncertain", "screen_event_unresolved"},
        {"observation_adequacy", x.observation_adequacy ~= "adequate",
            "screen_inconclusive_observation"},
        {"precursor_assessability", x.precursor_status == "not_assessable",
            "screen_inconclusive_precursor"},
        {"nonevent", x.event_status == "absent",
            "screen_nonevent_for_separate_false_alarm_analysis"},
        {"precursor_absent", x.precursor_status == "absent",
            "screen_candidate_counterexample_to_strict_claim"},
        {"precursor_present", true, "screen_eligible_event_consistent_with_claim"}
    }
    local applied, status, selected = {}, nil, nil
    for priority, gate in ipairs(gates) do
        local winner = status == nil and gate[2]
        if winner then status, selected = gate[3], gate[1] end
        applied[priority] = {
            name = gate[1], priority = priority,
            triggered = gate[2], selected = winner,
            status_if_selected = gate[3]
        }
    end

    local protocol = {}
    for key, value in pairs(p) do protocol[key] = value end
    return V.ok({
        module_version = M.VERSION, schema_version = 2,
        validator_version = V.VERSION,
        gate_order_version = M.GATE_ORDER_VERSION,
        status = status, selected_gate = selected,
        applied_gates = applied, scope = x.scope,
        protocol_reference = protocol, extensions = extensions,
        assumption_checks = copied_checks,
        failed_assumption_positions = failed,
        unknown_assumption_positions = unknown,
        declared_check_count = p.declared_check_count,
        usable_for_separate_false_alarm_analysis =
            selected == "nonevent",
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            disclaimer = "Credit establishes no identity, consent, or authority.",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            protocol_freeze_declaration_trusted_without_verification = true,
            assumption_protocol_reference_echoed = true,
            protocol_content_retrieved = false,
            assumption_state_values_consistent_with_protocol = false,
            event_adjudication_authority_verified = false,
            observation_power_verified = false,
            fingerprint_available = false,
            statistical_falsification_performed = false,
            universal_claim_confirmed = false,
            external_action_performed = false
        }
    })
end

return M
