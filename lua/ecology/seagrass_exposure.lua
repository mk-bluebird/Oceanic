-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Local exposure arithmetic; no forecasting, I/O, or external actions.

local M = {VERSION = "1.0.0"}
local MAX_INTERVALS = 10000

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "seagrass_exposure." .. code,
        args = {}, category = "validation"
    }}
end

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function record(v, required, optional, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(v, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end
    for key in pairs(v) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", path) end
    end
end

local function positive_linear_area(a, b, hours)
    if a <= 0 and b <= 0 then return 0 end
    if a >= 0 and b >= 0 then return (a / 2 + b / 2) * hours end
    if a > 0 then
        return (a / 2) * (a / (a - b)) * hours
    end
    return (b / 2) * (b / (b - a)) * hours
end

function M.evaluate(x)
    local e = record(x, {
        "schema_version", "temperature_reference_c",
        "oxygen_reference_mg_l", "intervals"
    }, {}, "input")
    if e then return e end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if not finite(x.temperature_reference_c) then
        return bad("E_FINITE", "input.temperature_reference_c")
    end
    if not finite(x.oxygen_reference_mg_l) or x.oxygen_reference_mg_l < 0 then
        return bad("E_OXYGEN", "input.oxygen_reference_mg_l")
    end
    if type(x.intervals) ~= "table" or getmetatable(x.intervals) ~= nil then
        return bad("E_SEQUENCE", "input.intervals")
    end

    local n, highest = 0, 0
    for key in pairs(x.intervals) do
        if not finite(key) or key % 1 ~= 0 or key < 1 or key > MAX_INTERVALS then
            return bad("E_SEQUENCE_INDEX", "input.intervals")
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n == 0 then return bad("E_EMPTY", "input.intervals") end
    if n ~= highest then return bad("E_SEQUENCE_GAP", "input.intervals") end

    local heat, oxygen_deficit, measured, unknown = 0, 0, 0, 0
    local previous_end
    local endpoints = {
        "temperature_start_c", "temperature_end_c",
        "oxygen_start_mg_l", "oxygen_end_mg_l"
    }

    for i = 1, n do
        local row = x.intervals[i]
        local path = "input.intervals[" .. i .. "]"
        e = record(row, {"start_hour", "end_hour", "measured"}, endpoints, path)
        if e then return e end
        if not finite(row.start_hour) or not finite(row.end_hour)
            or row.end_hour <= row.start_hour then
            return bad("E_TIME_INTERVAL", path)
        end
        if previous_end ~= nil and row.start_hour ~= previous_end then
            return bad("E_TIME_CONTIGUITY", path .. ".start_hour")
        end
        if type(row.measured) ~= "boolean" then
            return bad("E_BOOLEAN", path .. ".measured")
        end
        local hours = row.end_hour - row.start_hour
        if not finite(hours) then return bad("E_NUMERIC_RANGE", path) end

        if row.measured then
            for _, key in ipairs(endpoints) do
                if row[key] == nil then return bad("E_MISSING", path .. "." .. key) end
                if not finite(row[key]) then return bad("E_FINITE", path .. "." .. key) end
            end
            if row.oxygen_start_mg_l < 0 or row.oxygen_end_mg_l < 0 then
                return bad("E_OXYGEN", path)
            end
            local a = row.temperature_start_c - x.temperature_reference_c
            local b = row.temperature_end_c - x.temperature_reference_c
            local c = x.oxygen_reference_mg_l - row.oxygen_start_mg_l
            local d = x.oxygen_reference_mg_l - row.oxygen_end_mg_l
            if not finite(a) or not finite(b) or not finite(c) or not finite(d)
                or not finite(a - b) or not finite(c - d) then
                return bad("E_NUMERIC_RANGE", path)
            end
            heat = heat + positive_linear_area(a, b, hours)
            oxygen_deficit = oxygen_deficit + positive_linear_area(c, d, hours)
            measured = measured + hours
        else
            for _, key in ipairs(endpoints) do
                if row[key] ~= nil then return bad("E_UNKNOWN_WITH_VALUES", path) end
            end
            unknown = unknown + hours
        end
        if not finite(heat) or not finite(oxygen_deficit)
            or not finite(measured) or not finite(unknown) then
            return bad("E_NUMERIC_RANGE", path)
        end
        previous_end = row.end_hour
    end

    local total = measured + unknown
    if not finite(total) then return bad("E_NUMERIC_RANGE", "input.intervals") end
    local out = {
        module_version = M.VERSION, schema_version = 1,
        status = unknown == 0 and "screen_exposure_window_complete"
            or "screen_exposure_window_incomplete",
        measured_hours = measured, unknown_hours = unknown,
        time_coverage_fraction = measured / total,
        temperature_reference_c = x.temperature_reference_c,
        oxygen_reference_mg_l = x.oxygen_reference_mg_l,
        integration_assumption = "linear_within_measured_intervals",
        exposure_available = measured > 0,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            grants_authority = false, establishes_consent = false
        },
        interpretation_limits = {
            biological_thresholds_verified = false,
            disease_risk_estimated = false,
            future_refugia_established = false,
            hypoxia_event_certified = false,
            fish_kill_forecast_produced = false,
            joint_stressor_effect_estimated = false,
            external_action_performed = false
        }
    }
    if measured > 0 then
        out.measured_heat_degree_hours = heat
        out.measured_oxygen_deficit_mg_l_hours = oxygen_deficit
    end
    return {ok = true, value = out}
end

return M
