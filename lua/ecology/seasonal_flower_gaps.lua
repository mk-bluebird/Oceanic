-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only: no authority, consent, or identity verification.
-- Local screening only; no I/O, persistence, or external actions.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}
local HARD_BINS = 400

local function good(value)
    return {ok = true, value = value, error = false}
end

local function bad(code, path, args)
    return {ok = false, value = false, error = {
        code = code, field_path = path,
        message_key = "flower_gaps." .. code,
        args = args or {}, category = "validation"
    }}
end

local function finite(x)
    -- Reject NaN and both infinities; never coerce strings.
    return type(x) == "number" and x == x
        and x > -math.huge and x < math.huge
end

local function integer(x, low, high)
    return finite(x) and x % 1 == 0 and x >= low and x <= high
end

local function text(x)
    if type(x) ~= "string" or #x < 1 or #x > 500
        or not x:match("%S") then return false end
    for i = 1, #x do
        local b = x:byte(i)
        if b < 32 or b > 126 then return false end
    end
    return true
end

local function record(x, required, optional, path)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(x, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end
    local unknown, nonstring = {}, false
    for key in pairs(x) do
        if type(key) ~= "string" then nonstring = true
        elseif not allowed[key] then unknown[#unknown + 1] = key end
    end
    if nonstring then return bad("E_FIELD_KEY_TYPE", path) end
    table.sort(unknown)
    if #unknown > 0 then
        return bad("E_UNKNOWN_FIELD", path,
            {key_length = #unknown[1]})
    end
    return good(true)
end

local function sequence(x, limit)
    if not integer(limit, 1, HARD_BINS) then
        return bad("E_CAPACITY_CONFIG", "input.bin_capacity",
            {minimum = 1, maximum = HARD_BINS})
    end
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_SEQUENCE", "input.bins")
    end
    local count, highest = 0, 0
    local type_error, integer_error, positive_error, capacity_error
    for key in pairs(x) do
        if type(key) ~= "number" then type_error = true
        elseif not finite(key) or key % 1 ~= 0 then integer_error = true
        elseif key < 1 then positive_error = true
        elseif key > limit then capacity_error = true
        else
            count = count + 1
            highest = math.max(highest, key)
        end
    end
    if type_error then return bad("E_INDEX_TYPE", "input.bins") end
    if integer_error then return bad("E_INDEX_INTEGER", "input.bins") end
    if positive_error then return bad("E_INDEX_POSITIVE", "input.bins") end
    if capacity_error then
        return bad("E_CAPACITY", "input.bins", {maximum = limit})
    end
    if count == 0 then return bad("E_EMPTY", "input.bins") end
    if count ~= highest then return bad("E_SEQUENCE_GAP", "input.bins") end
    return good(count)
end

function M.evaluate(x)
    local r = record(x, {
        "schema_version", "scope", "units", "reference_basis",
        "availability_basis", "bin_capacity", "bins"
    }, {}, "input")
    if not r.ok then return r end
    if x.schema_version ~= M.SCHEMA_VERSION then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    for _, key in ipairs({
        "scope", "units", "reference_basis", "availability_basis"
    }) do
        if not text(x[key]) then return bad("E_TEXT", "input." .. key) end
    end

    r = sequence(x.bins, x.bin_capacity)
    if not r.ok then return r end
    local count = r.value
    local results, previous_end = {}, nil
    local total_days, known_days = 0, 0
    local certain_gap_days, possible_gap_days = 0, 0
    local weighted_lower, weighted_upper = 0, 0

    for i = 1, count do
        local b, path = x.bins[i], "input.bins[" .. i .. "]"
        r = record(b, {"start_day", "end_day", "reference", "known"},
            {"lower", "upper"}, path)
        if not r.ok then return r end
        for _, key in ipairs({"start_day", "end_day"}) do
            if not integer(b[key], 0, 1000000) then
                return bad("E_DAY", path .. "." .. key)
            end
        end
        if b.end_day < b.start_day then return bad("E_DAY_ORDER", path) end
        if previous_end ~= nil and b.start_day ~= previous_end + 1 then
            return bad("E_TIME_CONTIGUITY", path .. ".start_day",
                {expected = previous_end + 1})
        end
        if not finite(b.reference) or b.reference <= 0 then
            return bad("E_REFERENCE", path .. ".reference")
        end
        if type(b.known) ~= "boolean" then
            return bad("E_BOOLEAN", path .. ".known")
        end

        local days = b.end_day - b.start_day + 1
        local item = {
            start_day = b.start_day, end_day = b.end_day,
            reference = b.reference, known = b.known,
            status = "screen_unknown",
            shortfall_lower = false, shortfall_upper = false,
            availability_lower = false, availability_upper = false
        }

        if b.known then
            for _, key in ipairs({"lower", "upper"}) do
                if b[key] == nil then return bad("E_MISSING", path .. "." .. key) end
                if not finite(b[key]) or b[key] < 0 then
                    return bad("E_AVAILABILITY", path .. "." .. key)
                end
            end
            if b.lower > b.upper then return bad("E_INTERVAL_ORDER", path) end
            local lo = b.upper >= b.reference and 0
                or 1 - b.upper / b.reference
            local hi = b.lower >= b.reference and 0
                or 1 - b.lower / b.reference

            item.shortfall_lower, item.shortfall_upper = lo, hi
            item.availability_lower, item.availability_upper = b.lower, b.upper
            if b.upper < b.reference then
                item.status = "screen_shortfall_throughout_interval"
                certain_gap_days = certain_gap_days + days
            elseif b.lower < b.reference then
                item.status = "screen_reference_crossing"
            else
                item.status = "screen_reference_met"
            end
            if b.lower < b.reference then
                possible_gap_days = possible_gap_days + days
            end
            known_days = known_days + days
            weighted_lower = weighted_lower + lo * days
            weighted_upper = weighted_upper + hi * days
        elseif b.lower ~= nil or b.upper ~= nil then
            return bad("E_UNKNOWN_WITH_VALUES", path)
        end

        total_days = total_days + days
        previous_end = b.end_day
        results[i] = item
    end

    local has_known = known_days > 0
    return good({
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = known_days == total_days
            and "screen_flower_window_assessed" or "screen_flower_window_incomplete",
        scope = x.scope, units = x.units,
        reference_basis = x.reference_basis,
        availability_basis = x.availability_basis,
        bins = results,
        total_days = total_days, known_days = known_days,
        unknown_days = total_days - known_days,
        time_coverage_fraction = known_days / total_days,
        certain_gap_days_among_known = certain_gap_days,
        possible_gap_days_among_known = possible_gap_days,
        known_days_mean_shortfall_lower =
            has_known and weighted_lower / known_days or false,
        known_days_mean_shortfall_upper =
            has_known and weighted_upper / known_days or false,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            grants_authority = false, establishes_consent = false,
            establishes_verified_identity = false
        },
        interpretation_limits = {
            reference_validity_verified = false,
            spatial_accessibility_estimated = false,
            nesting_assessed = false, overwintering_assessed = false,
            annual_cycle_completeness_established = false,
            colony_persistence_estimated = false,
            external_action_authorized = false
        }
    })
end

return M
