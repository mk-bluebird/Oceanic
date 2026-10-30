-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Local descriptive audit; no I/O, persistence, or ecological action.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.

local M = {VERSION = "1.0.0"}
local MAX_INTERVALS = 10000

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "pollinator_gap." .. code,
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

function M.evaluate(x)
    local e = record(x, {"schema_version", "intervals"}, {}, "input")
    if e then return e end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if type(x.intervals) ~= "table" or getmetatable(x.intervals) ~= nil then
        return bad("E_SEQUENCE", "input.intervals")
    end

    local n, highest = 0, 0
    for key in pairs(x.intervals) do
        if not finite(key) or key % 1 ~= 0 or key < 1
            or key > MAX_INTERVALS then
            return bad("E_SEQUENCE_INDEX", "input.intervals")
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n == 0 then return bad("E_EMPTY", "input.intervals") end
    if n ~= highest then return bad("E_SEQUENCE_GAP", "input.intervals") end

    local observed, unknown, active, gap = 0, 0, 0, 0
    local current_gap, longest_gap, previous_end = 0, 0, nil
    local optional = {
        "bee_activity_index", "floral_resource", "floral_reference"
    }

    for i = 1, n do
        local row, path = x.intervals[i], "input.intervals[" .. i .. "]"
        e = record(row, {"start_day", "end_day", "observed"}, optional, path)
        if e then return e end
        if not finite(row.start_day) or not finite(row.end_day)
            or row.end_day <= row.start_day then
            return bad("E_TIME_INTERVAL", path)
        end
        if previous_end ~= nil and row.start_day ~= previous_end then
            return bad("E_TIME_CONTIGUITY", path .. ".start_day")
        end
        if type(row.observed) ~= "boolean" then
            return bad("E_BOOLEAN", path .. ".observed")
        end
        local duration = row.end_day - row.start_day
        if not finite(duration) then return bad("E_NUMERIC_RANGE", path) end

        if row.observed then
            for _, key in ipairs(optional) do
                if row[key] == nil then return bad("E_MISSING", path .. "." .. key) end
                if not finite(row[key]) or row[key] < 0 then
                    return bad("E_NONNEGATIVE", path .. "." .. key)
                end
            end
            if row.floral_reference == 0 then
                return bad("E_POSITIVE_REFERENCE", path .. ".floral_reference")
            end
            observed = observed + duration
            local is_gap = row.bee_activity_index > 0
                and row.floral_resource < row.floral_reference
            if row.bee_activity_index > 0 then active = active + duration end
            if is_gap then
                gap = gap + duration
                current_gap = current_gap + duration
                longest_gap = math.max(longest_gap, current_gap)
            else
                current_gap = 0
            end
        else
            for _, key in ipairs(optional) do
                if row[key] ~= nil then
                    return bad("E_UNKNOWN_WITH_VALUES", path)
                end
            end
            unknown = unknown + duration
            -- Unknown periods cannot establish continuity of a gap.
            current_gap = 0
        end

        if not finite(observed) or not finite(unknown) or not finite(active)
            or not finite(gap) or not finite(current_gap) then
            return bad("E_NUMERIC_RANGE", path)
        end
        previous_end = row.end_day
    end

    local total = observed + unknown
    if not finite(total) then return bad("E_NUMERIC_RANGE", "input.intervals") end
    local out = {
        module_version = M.VERSION, schema_version = 1,
        status = active > 0 and "screen_observed_active_period_gaps"
            or "screen_no_observed_activity_positive_period",
        observed_days = observed,
        unknown_days = unknown,
        observed_active_days = active,
        recorded_gap_days = gap,
        longest_contiguous_recorded_gap_days = longest_gap,
        observation_time_coverage = observed / total,
        interval_assumption = "constant_classification_within_each_interval",
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false, grants_authority = false
        },
        interpretation_limits = {
            floral_reference_validated = false,
            detection_corrected = false,
            spatial_accessibility_evaluated = false,
            nutritional_deficit_established = false,
            fitness_effect_established = false,
            climate_attribution_established = false,
            external_action_performed = false
        }
    }
    if active > 0 then out.observed_active_gap_fraction = gap / active end
    return {ok = true, value = out}
end

return M
