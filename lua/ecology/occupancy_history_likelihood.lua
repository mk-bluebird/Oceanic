-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; version 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no identity verification, consent, or authority.
-- Local likelihood evaluation; no fitting, RNG, I/O, or actuation.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}
local MAX_VISITS = 1000

local function good(value)
    return {ok = true, value = value, error = false}
end

local function bad(code, path)
    return {ok = false, value = false, error = {
        code = code, field_path = path,
        message_key = "occupancy_history." .. code,
        args = {}, category = "validation"
    }}
end

local function probability(v)
    -- Open-interval, finite probability; excludes NaN and infinities.
    return type(v) == "number" and v == v and v > 0 and v < 1
end

local function text(v)
    if type(v) ~= "string" or #v < 1 or #v > 500
        or not v:match("%S") then return false end
    for i = 1, #v do
        local b = v:byte(i)
        if b < 32 or b > 126 then return false end
    end
    return true
end

local function sequence(v, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return bad("E_SEQUENCE", path)
    end
    local n, highest, invalid = 0, 0, false
    for key in pairs(v) do
        if type(key) ~= "number" or key ~= key
            or key < 1 or key > MAX_VISITS or key % 1 ~= 0 then
            invalid = true
        else
            n, highest = n + 1, math.max(highest, key)
        end
    end
    if invalid then return bad("E_SEQUENCE_INDEX", path) end
    if n == 0 then return bad("E_EMPTY", path) end
    if n ~= highest then return bad("E_SEQUENCE_GAP", path) end
    return good(n)
end

local function log_add(a, b)
    local larger, smaller = math.max(a, b), math.min(a, b)
    return larger + math.log(1 + math.exp(smaller - larger))
end

function M.evaluate(x)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", "input")
    end
    local fields = {
        "schema_version", "scope", "psi", "detection", "history"
    }
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(x, key) == nil then
            return bad("E_MISSING", "input." .. key)
        end
    end
    local unknown = false
    for key in pairs(x) do
        if not allowed[key] then unknown = true end
    end
    if unknown then return bad("E_UNKNOWN_FIELD", "input") end
    if x.schema_version ~= M.SCHEMA_VERSION then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if not text(x.scope) then return bad("E_TEXT", "input.scope") end
    if not probability(x.psi) then
        return bad("E_OPEN_PROBABILITY", "input.psi")
    end

    local hr = sequence(x.history, "input.history")
    if not hr.ok then return hr end
    local pr = sequence(x.detection, "input.detection")
    if not pr.ok then return pr end
    if hr.value ~= pr.value then
        return bad("E_VISIT_COUNT", "input.detection")
    end

    local any_detection, conditional_log = false, 0
    local history, detection = {}, {}
    for i = 1, hr.value do
        local y, p = x.history[i], x.detection[i]
        if type(y) ~= "number" or (y ~= 0 and y ~= 1) then
            return bad("E_BINARY", "input.history[" .. i .. "]")
        end
        if not probability(p) then
            return bad("E_OPEN_PROBABILITY",
                "input.detection[" .. i .. "]")
        end
        any_detection = any_detection or y == 1
        conditional_log = conditional_log
            + (y == 1 and math.log(p) or math.log(1 - p))
        history[i], detection[i] = y, p
    end

    local occupied_component = math.log(x.psi) + conditional_log
    local log_likelihood
    if any_detection then
        log_likelihood = occupied_component
    else
        log_likelihood = log_add(math.log(1 - x.psi),
            occupied_component)
    end

    return good({
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = "screen_ordered_history_log_likelihood",
        scope = x.scope,
        psi = x.psi,
        history = history,
        detection = detection,
        visit_count = hr.value,
        log_likelihood = log_likelihood,
        likelihood_representation = "ordered_history_not_binomial_count",
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        assumptions = {
            closure_required = true,
            false_positive_probability_assumed_zero = true,
            conditional_visit_independence_assumed = true
        },
        interpretation_limits = {
            parameters_fitted = false,
            identifiability_verified = false,
            spatial_dependence_modeled = false,
            power_calculated = false,
            functional_mutualism_established = false,
            external_action_authorized = false
        }
    })
end

return M
