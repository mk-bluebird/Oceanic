-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 2.0.0.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, identity verification, or authority.
--
-- psi and detection values are probabilities on [0,1], NOT logits.
-- A future regression adapter must declare and apply its link separately.
--
-- log_likelihood(psi, history, detection, capacity):
-- success: log_lik, nil, nil
-- invalid input: nil, stable_error_code, field_path
-- Exact zero likelihood is -math.huge, not a validation error.
-- No result tables are allocated by this numerical interface.
-- No priors, fitting, RNG, I/O, or external actions.

local M = {VERSION = "2.0.0", HARD_VISITS = 10000}
local NEG_INF = -math.huge

local function finite(v)
    -- Reject NaN and both infinities.
    return type(v) == "number" and v == v
        and v > NEG_INF and v < math.huge
end

local function probability(v)
    return finite(v) and v >= 0 and v <= 1
end

local function validate_sequence(v, capacity, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return nil, "E_SEQUENCE", path
    end

    local n, highest = 0, 0
    local wrong_type, fractional, nonpositive, over = false, false, false, false

    for key in pairs(v) do
        if type(key) ~= "number" then
            wrong_type = true
        elseif not finite(key) or key % 1 ~= 0 then
            fractional = true
        elseif key < 1 then
            nonpositive = true
        elseif key > capacity then
            over = true
        else
            n = n + 1
            highest = math.max(highest, key)
        end
    end

    if wrong_type then return nil, "E_INDEX_TYPE", path end
    if fractional then return nil, "E_INDEX_INTEGER", path end
    if nonpositive then return nil, "E_INDEX_POSITIVE", path end
    if over then return nil, "E_DECLARED_CAPACITY", path end
    if n == 0 then return nil, "E_EMPTY", path end
    if n ~= highest then return nil, "E_SEQUENCE_GAP", path end
    return n
end

local function log1p_local(x)
    -- Domain here: x > -1, finite.
    -- Correct for rounding in 1+x; retain tiny x when 1+x rounds to 1.
    local u = 1 + x
    if u == 1 then return x end
    return math.log(u) * (x / (u - 1))
end

local function log_probability(p)
    if p == 0 then return NEG_INF end
    return math.log(p)
end

local function log_complement(p)
    if p == 1 then return NEG_INF end
    if p == 0 then return 0 end
    return log1p_local(-p)
end

local function log_add_nonpositive(a, b)
    -- Internal domain: finite nonpositive values or -infinity.
    if a == NEG_INF then return b end
    if b == NEG_INF then return a end
    local larger = math.max(a, b)
    local smaller = math.min(a, b)
    return larger + log1p_local(math.exp(smaller - larger))
end

function M.log_likelihood(psi, history, detection, capacity)
    if not finite(capacity) or capacity % 1 ~= 0 or capacity < 1 then
        return nil, "E_CAPACITY_CONFIG", "input.visit_capacity"
    end
    if capacity > M.HARD_VISITS then
        return nil, "E_HARD_VISIT_LIMIT", "input.visit_capacity"
    end
    if not probability(psi) then
        return nil, "E_PROBABILITY", "input.psi"
    end

    local n, code, path = validate_sequence(history, capacity, "input.history")
    if not n then return nil, code, path end
    local m
    m, code, path = validate_sequence(detection, capacity, "input.detection")
    if not m then return nil, code, path end
    if n ~= m then return nil, "E_VISIT_COUNT", "input.detection" end

    local any_detection = false
    local conditional_log = 0

    for i = 1, n do
        local y, p = history[i], detection[i]
        if type(y) ~= "number" or (y ~= 0 and y ~= 1) then
            return nil, "E_BINARY", "input.history[" .. i .. "]"
        end
        if not probability(p) then
            return nil, "E_PROBABILITY", "input.detection[" .. i .. "]"
        end

        local contribution
        if y == 1 then
            any_detection = true
            contribution = log_probability(p)
        else
            contribution = log_complement(p)
        end
        conditional_log = conditional_log + contribution
    end

    local occupied = log_probability(psi) + conditional_log
    if any_detection then return occupied, nil, nil end

    local result = log_add_nonpositive(log_complement(psi), occupied)
    -- A probability cannot exceed 1; remove positive roundoff only here.
    if result > 0 then result = 0 end
    return result, nil, nil
end

return M
