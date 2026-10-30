-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0.
-- Retain credit in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, identity verification, or authority.
-- Numerical reference candidate; no statistical inference or I/O.

local M = {VERSION = "1.0.0"}
local LIMIT = 10000

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "variance_reference." .. code,
        args = {}, category = "validation"
    }}
end

local function finite(x)
    return type(x) == "number" and x == x
        and x > -math.huge and x < math.huge
end

local function add(sum, correction, value)
    local next_sum = sum + value
    if not finite(next_sum) then return nil end
    local adjustment
    if math.abs(sum) >= math.abs(value) then
        adjustment = (sum - next_sum) + value
    else
        adjustment = (value - next_sum) + sum
    end
    local next_correction = correction + adjustment
    if not finite(next_correction) then return nil end
    return next_sum, next_correction
end

function M.compute(values)
    if type(values) ~= "table" or getmetatable(values) ~= nil then
        return bad("E_SEQUENCE", "values")
    end
    local n, highest = 0, 0
    for key in pairs(values) do
        if not finite(key) or key % 1 ~= 0 or key < 1 or key > LIMIT then
            return bad("E_SEQUENCE_INDEX", "values")
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n < 2 then return bad("E_SAMPLE_SIZE", "values") end
    if n ~= highest then return bad("E_SEQUENCE_GAP", "values") end

    for i = 1, n do
        if not finite(values[i]) then
            return bad("E_FINITE", "values[" .. i .. "]")
        end
    end

    local anchor, sum, correction = values[1], 0, 0
    local shifted = {}
    for i = 1, n do
        local z = values[i] - anchor
        if not finite(z) then return bad("E_NUMERIC_RANGE", "values") end
        shifted[i] = z
        local next_sum, next_correction = add(sum, correction, z)
        if next_sum == nil then return bad("E_NUMERIC_RANGE", "values") end
        sum, correction = next_sum, next_correction
    end

    local shifted_mean = (sum + correction) / n
    if not finite(shifted_mean) then
        return bad("E_NUMERIC_RANGE", "values")
    end

    local square_sum, square_correction = 0, 0
    local residual_sum, residual_correction = 0, 0
    for i = 1, n do
        local residual = shifted[i] - shifted_mean
        local squared = residual * residual
        if not finite(residual) or not finite(squared) then
            return bad("E_NUMERIC_RANGE", "values")
        end
        local a, b = add(square_sum, square_correction, squared)
        if a == nil then return bad("E_NUMERIC_RANGE", "values") end
        square_sum, square_correction = a, b
        a, b = add(residual_sum, residual_correction, residual)
        if a == nil then return bad("E_NUMERIC_RANGE", "values") end
        residual_sum, residual_correction = a, b
    end

    local residual_total = residual_sum + residual_correction
    local centering = residual_total * (residual_total / n)
    local m2 = (square_sum + square_correction) - centering
    local mean = anchor + shifted_mean
    if not finite(mean) or not finite(m2) then
        return bad("E_NUMERIC_RANGE", "values")
    end
    if m2 < 0 then return bad("E_NEGATIVE_M2", "values") end

    return {ok = true, value = {
        module_version = M.VERSION,
        status = "screen_numerical_reference_summary",
        count = n,
        mean = mean,
        sample_variance = m2 / (n - 1),
        standard_error_under_independence =
            math.sqrt((m2 / (n - 1)) / n),
        arithmetic = "shifted_compensated_corrected_two_pass",
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            grants_authority = false,
            establishes_consent = false
        },
        interpretation_limits = {
            correctly_rounded_result_certified = false,
            independence_verified = false,
            numerical_underflow_excluded = false,
            statistical_model_fitted = false,
            ecological_effect_established = false,
            external_action_performed = false
        }
    }}
end

return M
