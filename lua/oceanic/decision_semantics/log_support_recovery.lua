-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Local finite-distribution diagnostics only.
-- No contraction, expansion, I/O, storage, networking, or actuation.
-- Natural logarithms; -math.huge denotes exact zero.

local M = {VERSION = "1.0.0"}
local MAX = 64
local TOL = 1e-10
local NI = -math.huge

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "log_support_recovery." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > NI
        and value < math.huge
end

local function log_value(value)
    return value == NI or finite(value)
end

local function length(value, path)
    if not plain(value) then return fail("E_ARRAY_TYPE", path) end

    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > MAX then return fail("E_DIMENSION_LIMIT", path) end
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
            return fail("E_ARRAY_SHAPE", path)
        end
        if key > MAX then return fail("E_DIMENSION_LIMIT", path) end
        if key > highest then highest = key end
    end

    if count == 0 or count ~= highest then
        return fail("E_ARRAY_SHAPE", path)
    end
    return ok(count)
end

local function lse(values)
    local maximum = NI
    for i = 1, #values do
        if values[i] > maximum then maximum = values[i] end
    end
    if maximum == NI then return NI end

    local sum = 0
    for i = 1, #values do
        sum = sum + math.exp(values[i] - maximum)
    end

    local result = maximum + math.log(sum)
    if not finite(result) then return nil end
    return result
end

local function validate_distribution(values, n, path)
    for i = 1, n do
        if not log_value(values[i]) or values[i] > 0 then
            return fail("E_LOG_PROBABILITY", path)
        end
    end

    local total = lse(values)
    if total == NI then
        return fail("E_EMPTY_DISTRIBUTION_SUPPORT", path)
    end
    if total == nil or math.abs(total) > TOL then
        return fail("E_DISTRIBUTION_NORMALIZATION", path)
    end
    return ok(total)
end

function M.evaluate(input)
    if not plain(input) then return fail("E_INPUT_TYPE", "input") end

    local allowed = {
        log_original = true,
        log_restored = true,
        log_mass_threshold = true
    }

    for _, key in ipairs({
        "log_original", "log_restored", "log_mass_threshold"
    }) do
        if rawget(input, key) == nil then
            return fail("E_MISSING_MEMBER", "input")
        end
    end

    for key in next, input do
        if not allowed[key] then
            return fail("E_UNKNOWN_MEMBER", "input")
        end
    end

    local a = length(input.log_original, "input.log_original")
    if not a.ok then return a end

    local b = length(input.log_restored, "input.log_restored")
    if not b.ok then return b end

    if a.value ~= b.value then
        return fail("E_WORLD_UNIVERSE_SIZE_MISMATCH", "input")
    end

    local n = a.value
    local checked = validate_distribution(
        input.log_original, n, "input.log_original")
    if not checked.ok then return checked end

    local restored_check = validate_distribution(
        input.log_restored, n, "input.log_restored")
    if not restored_check.ok then return restored_check end

    local threshold = input.log_mass_threshold
    if not log_value(threshold) or threshold > 0 then
        return fail("E_LOG_THRESHOLD", "input.log_mass_threshold")
    end

    local outside_logs = {}
    local original_support, restored_support, outside_count = 0, 0, 0

    for i = 1, n do
        local original = input.log_original[i]
        local restored = input.log_restored[i]

        if original > NI then original_support = original_support + 1 end
        if restored > NI then restored_support = restored_support + 1 end

        if original == NI and restored > NI then
            outside_count = outside_count + 1
            outside_logs[#outside_logs + 1] = restored
        end
    end

    local outside_log_mass = lse(outside_logs)
    if outside_log_mass == nil then
        return fail("E_LOG_NUMERIC_RANGE", "input.log_restored")
    end

    local linear_mass = outside_log_mass == NI
        and 0 or math.exp(outside_log_mass)

    return ok({
        module_version = M.VERSION,
        world_universe_size = n,
        shared_world_mapping_verified = false,
        original_support_count = original_support,
        restored_support_count = restored_support,
        outside_support_count = outside_count,
        exact_support_inclusion = outside_count == 0,
        log_outside_mass = outside_log_mass,
        outside_mass = linear_mass,
        linear_mass_underflow =
            outside_log_mass > NI and linear_mass == 0,
        log_mass_threshold = threshold,
        outside_mass_within_declared_threshold =
            outside_log_mass <= threshold,
        distribution_normalization_tolerance = TOL,
        input_probabilities_renormalized = false,
        contraction_operator_assessed = false,
        expansion_operator_assessed = false,
        agm_recovery_established = false,
        ecological_risk_assessed = false,
        threshold_authority_verified = false,
        assessment_scope = "finite_support_and_mass_diagnostic"
    })
end

return M
