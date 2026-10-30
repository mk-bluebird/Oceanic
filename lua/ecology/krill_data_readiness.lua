-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, identity verification, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local requirements screen only; no I/O or management action.

local M = {VERSION = "1.0.0"}
local STREAMS = {"krill_acoustics", "predator_use", "fishery_activity"}

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "krill_readiness." .. code,
        args = {}, category = "validation"
    }}
end

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function record(v, fields, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(v, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    for key in pairs(v) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", path) end
    end
end

function M.evaluate(x)
    local e = record(x, {
        "schema_version", "decision_time_s", "requirements", "streams"
    }, "input")
    if e then return e end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if not finite(x.decision_time_s) then
        return bad("E_FINITE", "input.decision_time_s")
    end

    local policy = x.requirements
    e = record(policy, {
        "maximum_oldest_age_s", "maximum_delivery_lag_s",
        "maximum_window_s", "maximum_cell_width_m",
        "minimum_coverage_fraction"
    }, "input.requirements")
    if e then return e end
    for _, key in ipairs({
        "maximum_oldest_age_s", "maximum_delivery_lag_s",
        "maximum_window_s", "maximum_cell_width_m"
    }) do
        if not finite(policy[key]) or policy[key] < 0 then
            return bad("E_NONNEGATIVE", "input.requirements." .. key)
        end
    end
    if policy.maximum_cell_width_m == 0 then
        return bad("E_POSITIVE", "input.requirements.maximum_cell_width_m")
    end
    if not finite(policy.minimum_coverage_fraction)
        or policy.minimum_coverage_fraction < 0
        or policy.minimum_coverage_fraction > 1 then
        return bad("E_FRACTION", "input.requirements.minimum_coverage_fraction")
    end
    e = record(x.streams, STREAMS, "input.streams")
    if e then return e end

    local results, all_meet = {}, true
    for _, name in ipairs(STREAMS) do
        local row = x.streams[name]
        local path = "input.streams." .. name
        e = record(row, {
            "window_start_s", "window_end_s", "available_at_s",
            "cell_width_m", "coverage_fraction"
        }, path)
        if e then return e end
        for _, key in ipairs({
            "window_start_s", "window_end_s", "available_at_s",
            "cell_width_m", "coverage_fraction"
        }) do
            if not finite(row[key]) then return bad("E_FINITE", path .. "." .. key) end
        end
        if row.window_start_s > row.window_end_s
            or row.window_end_s > row.available_at_s
            or row.available_at_s > x.decision_time_s then
            return bad("E_TIME_ORDER", path)
        end
        if row.cell_width_m <= 0 then
            return bad("E_POSITIVE", path .. ".cell_width_m")
        end
        if row.coverage_fraction < 0 or row.coverage_fraction > 1 then
            return bad("E_FRACTION", path .. ".coverage_fraction")
        end

        local oldest = x.decision_time_s - row.window_start_s
        local newest = x.decision_time_s - row.window_end_s
        local delivery = row.available_at_s - row.window_end_s
        local duration = row.window_end_s - row.window_start_s
        if not finite(oldest) or not finite(newest)
            or not finite(delivery) or not finite(duration) then
            return bad("E_NUMERIC_RANGE", path)
        end

        local unmet = {}
        if oldest > policy.maximum_oldest_age_s then
            unmet[#unmet + 1] = "oldest_data_age"
        end
        if delivery > policy.maximum_delivery_lag_s then
            unmet[#unmet + 1] = "delivery_lag"
        end
        if duration > policy.maximum_window_s then
            unmet[#unmet + 1] = "aggregation_window"
        end
        if row.cell_width_m > policy.maximum_cell_width_m then
            unmet[#unmet + 1] = "cell_width"
        end
        if row.coverage_fraction < policy.minimum_coverage_fraction then
            unmet[#unmet + 1] = "coverage"
        end

        if #unmet > 0 then all_meet = false end
        results[name] = {
            status = #unmet == 0 and "screen_declared_requirements_met"
                or "screen_declared_requirements_unmet",
            oldest_age_s = oldest, newest_age_s = newest,
            delivery_lag_s = delivery, aggregation_window_s = duration,
            cell_width_m = row.cell_width_m,
            coverage_fraction = row.coverage_fraction,
            unmet_requirements = unmet
        }
    end

    local copied_policy = {}
    for key, value in pairs(policy) do copied_policy[key] = value end
    return {ok = true, value = {
        module_version = M.VERSION, schema_version = 1,
        status = all_meet and "screen_all_stream_requirements_met"
            or "screen_data_requirements_unmet",
        decision_time_s = x.decision_time_s,
        requirements = copied_policy,
        streams = results,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false, grants_authority = false
        },
        interpretation_limits = {
            ecological_requirements_validated = false,
            native_resolution_verified = false,
            coverage_definitions_verified = false,
            interstream_alignment_verified = false,
            measurements_assimilated = false,
            predator_impact_established = false,
            management_decision_authorized = false,
            external_action_performed = false
        }
    }}
end

return M
