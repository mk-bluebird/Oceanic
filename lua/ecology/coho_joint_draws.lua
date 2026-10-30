-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Version 1.0.0; schema 1.
-- Retain this attribution notice in derivative distributions.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or operational authority.
-- Local arithmetic only; no RNG, I/O, persistence, or external actions.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}
local HARD_DRAWS, HARD_STAGES = 10000, 100
local HARD_VALUES = 200000

local function problem(code, path)
    return {code = code, field_path = path,
        message_key = "coho_draws." .. code, category = "validation"}
end

local function finite(v)
    -- NaN is the only number unequal to itself.
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function text(v)
    return type(v) == "string" and v:match("%S") ~= nil
end

local function record(v, fields, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return false, problem("E_RECORD", path)
    end
    for key in pairs(fields) do
        if rawget(v, key) == nil then
            return false, problem("E_MISSING", path .. "." .. key)
        end
    end
    for key in pairs(v) do
        if not fields[key] then
            return false, problem("E_UNKNOWN_FIELD",
                path .. "[" .. tostring(key) .. "]")
        end
    end
    return true
end

local function sequence(v, limit, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return nil, problem("E_SEQUENCE", path)
    end
    local n, highest = 0, 0
    for key in pairs(v) do
        if type(key) ~= "number" then
            return nil, problem("E_INDEX_TYPE", path)
        end
        if not finite(key) or key % 1 ~= 0 then
            return nil, problem("E_INDEX_INTEGER", path)
        end
        if key < 1 then return nil, problem("E_INDEX_POSITIVE", path) end
        if key > limit then return nil, problem("E_CAPACITY", path) end
        n, highest = n + 1, math.max(highest, key)
    end
    if n == 0 then return nil, problem("E_EMPTY", path) end
    if n ~= highest then return nil, problem("E_SEQUENCE_GAP", path) end
    return n
end

local function quantile(sorted, p)
    -- Linear interpolation at index 1 + (n - 1) * p.
    local index = 1 + (#sorted - 1) * p
    local lower = math.floor(index)
    local upper = math.ceil(index)
    local weight = index - lower
    return sorted[lower] * (1 - weight) + sorted[upper] * weight
end

local function summary(values)
    local sorted, mean = {}, 0
    for i, value in ipairs(values) do
        sorted[i] = value
        mean = mean + (value - mean) / i
    end
    table.sort(sorted)
    return {
        mean = mean,
        q025 = quantile(sorted, 0.025),
        median = quantile(sorted, 0.5),
        q975 = quantile(sorted, 0.975)
    }
end

function M.evaluate(x)
    local ok, e = record(x, {
        schema_version = true, scope = true, cohort_count = true,
        draw_basis = true, draw_capacity = true,
        stage_names = true, draws = true
    }, "input")
    if not ok then return nil, e end
    if x.schema_version ~= M.SCHEMA_VERSION then
        return nil, problem("E_SCHEMA_VERSION", "input.schema_version")
    end
    if not text(x.scope) then return nil, problem("E_TEXT", "input.scope") end
    local bases = {
        synthetic = true, posterior = true,
        bootstrap = true, sensitivity = true
    }
    if not bases[x.draw_basis] then
        return nil, problem("E_DRAW_BASIS", "input.draw_basis")
    end
    if not finite(x.cohort_count) or x.cohort_count < 1
        or x.cohort_count % 1 ~= 0
        or x.cohort_count > 9007199254740991 then
        return nil, problem("E_COHORT", "input.cohort_count")
    end
    if not finite(x.draw_capacity) or x.draw_capacity % 1 ~= 0
        or x.draw_capacity < 1 then
        return nil, problem("E_CAPACITY_CONFIG", "input.draw_capacity")
    end
    if x.draw_capacity > HARD_DRAWS then
        return nil, problem("E_HARD_LIMIT", "input.draw_capacity")
    end

    local stages
    stages, e = sequence(x.stage_names, HARD_STAGES, "input.stage_names")
    if not stages then return nil, e end
    local names, seen = {}, {}
    for i = 1, stages do
        local name = x.stage_names[i]
        if not text(name) then
            return nil, problem("E_TEXT", "input.stage_names[" .. i .. "]")
        end
        if seen[name] then
            return nil, problem("E_DUPLICATE_STAGE",
                "input.stage_names[" .. i .. "]")
        end
        names[i], seen[name] = name, true
    end

    local count
    count, e = sequence(x.draws, x.draw_capacity, "input.draws")
    if not count then return nil, e end
    if count * stages * 2 > HARD_VALUES then
        return nil, problem("E_HARD_VALUE_LIMIT", "input.draws")
    end

    local baseline, scenario, gains = {}, {}, {}
    local positive, negative, zero = 0, 0, 0

    for r = 1, count do
        local row, path = x.draws[r], "input.draws[" .. r .. "]"
        ok, e = record(row, {baseline = true, scenario = true}, path)
        if not ok then return nil, e end
        local totals = {}
        for _, key in ipairs({"baseline", "scenario"}) do
            local n
            n, e = sequence(row[key], stages, path .. "." .. key)
            if not n then return nil, e end
            if n ~= stages then
                return nil, problem("E_STAGE_COUNT", path .. "." .. key)
            end
            local total = x.cohort_count
            for j = 1, stages do
                local value = row[key][j]
                local field = path .. "." .. key .. "[" .. j .. "]"
                if not finite(value) or value < 0 or value > 1 then
                    return nil, problem("E_PROBABILITY", field)
                end
                total = total * value
            end
            totals[key] = total
        end
        local gain = totals.scenario - totals.baseline
        baseline[r], scenario[r], gains[r] =
            totals.baseline, totals.scenario, gain
        if gain > 0 then positive = positive + 1
        elseif gain < 0 then negative = negative + 1
        else zero = zero + 1 end
    end

    return {
        schema_version = M.SCHEMA_VERSION,
        module_version = M.VERSION,
        status = "screen_joint_draw_summary",
        scope = x.scope,
        cohort_count = x.cohort_count,
        stage_names = names,
        draw_basis = x.draw_basis,
        draw_count = count,
        units = "expected_terminal_individuals_per_starting_cohort",
        baseline = summary(baseline),
        scenario = summary(scenario),
        gain = summary(gains),
        positive_gain_fraction = positive / count,
        negative_gain_fraction = negative / count,
        zero_gain_fraction = zero / count,
        interpretation_limits = {
            draws_generated_here = false,
            input_dependence_verified = false,
            inferential_interval_certified = false,
            probability_of_benefit_certified = false,
            causal_attribution_established = false,
            external_action_authorized = false,
            input_fingerprint_available = false,
            floating_point_underflow_possible = true
        }
    }
end

return M
