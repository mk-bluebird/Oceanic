-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Version 1.0.0; input/output schema 1.
-- Retain this credit notice in copies and derivative distributions.
-- Sovereign-attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; no consent, verified identity, or operational authority.
-- Local deterministic cohort accounting; no I/O or external actions.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}

local function failure(code, path, value)
    local kind = type(value)
    local safe_value = kind == "number" and tostring(value)
        or "<" .. kind .. ">"
    return nil, {
        code = code,
        field_path = path,
        value_description = safe_value,
        message_key = "coho." .. code,
        category = "validation"
    }
end

local function finite(x)
    -- NaN is unequal to itself.
    return type(x) == "number" and x == x
        and x > -math.huge and x < math.huge
end

local function text(x)
    return type(x) == "string" and x:match("%S") ~= nil
end

local function check_record(x, required, optional, path)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return failure("E_RECORD", path, x)
    end
    for key in pairs(required) do
        if rawget(x, key) == nil then
            return failure("E_MISSING", path .. "." .. key, nil)
        end
    end
    for key in pairs(x) do
        if not required[key] and not optional[key] then
            return failure("E_UNKNOWN_FIELD",
                path .. "[" .. tostring(key) .. "]", x[key])
        end
    end
    return true
end

function M.evaluate(x)
    local ok, e = check_record(x, {
        schema_version = true, scope = true, cohort_count = true,
        max_stages = true, stages = true,
        scenario_stage = true, survival_increment = true,
        scenario_basis = true, provenance_kind = true
    }, {cost = true, cost_unit = true}, "input")
    if not ok then return nil, e end

    if x.schema_version ~= M.SCHEMA_VERSION then
        return failure("E_SCHEMA_VERSION", "input.schema_version",
            x.schema_version)
    end
    for _, key in ipairs({"scope", "scenario_stage", "scenario_basis"}) do
        if not text(x[key]) then
            return failure("E_TEXT", "input." .. key, x[key])
        end
    end
    local kinds = {literature = true, field_estimate = true, synthetic = true}
    if not kinds[x.provenance_kind] then
        return failure("E_PROVENANCE", "input.provenance_kind",
            x.provenance_kind)
    end
    if not finite(x.cohort_count) or x.cohort_count < 1
        or x.cohort_count % 1 ~= 0 or x.cohort_count > 9007199254740991 then
        return failure("E_COHORT_COUNT", "input.cohort_count", x.cohort_count)
    end
    if not finite(x.max_stages) or x.max_stages % 1 ~= 0
        or x.max_stages < 1 or x.max_stages > 1000 then
        return failure("E_STAGE_LIMIT", "input.max_stages", x.max_stages)
    end
    if not finite(x.survival_increment) or x.survival_increment < 0
        or x.survival_increment > 1 then
        return failure("E_INCREMENT", "input.survival_increment",
            x.survival_increment)
    end
    if type(x.stages) ~= "table" or getmetatable(x.stages) ~= nil then
        return failure("E_SEQUENCE", "input.stages", x.stages)
    end

    local n, highest = 0, 0
    for key in pairs(x.stages) do
        if type(key) ~= "number" then
            return failure("E_INDEX_TYPE", "input.stages", key)
        end
        if not finite(key) or key % 1 ~= 0 then
            return failure("E_INDEX_INTEGER", "input.stages", key)
        end
        if key < 1 then
            return failure("E_INDEX_POSITIVE", "input.stages", key)
        end
        if key > x.max_stages then
            return failure("E_STAGE_LIMIT", "input.stages", key)
        end
        n, highest = n + 1, math.max(highest, key)
    end
    if n == 0 then return failure("E_EMPTY", "input.stages", n) end
    if n ~= highest then
        return failure("E_SEQUENCE_GAP", "input.stages", highest)
    end

    local stages, seen, selected = {}, {}, nil
    local product, other_product = 1, 1

    for i = 1, n do
        local row = x.stages[i]
        local path = "input.stages[" .. i .. "]"
        ok, e = check_record(row, {
            name = true, survival = true, evidence_basis = true
        }, {}, path)
        if not ok then return nil, e end
        for _, key in ipairs({"name", "evidence_basis"}) do
            if not text(row[key]) then
                return failure("E_TEXT", path .. "." .. key, row[key])
            end
        end
        if seen[row.name] then
            return failure("E_DUPLICATE_STAGE", path .. ".name", row.name)
        end
        seen[row.name] = true
        if not finite(row.survival) or row.survival < 0
            or row.survival > 1 then
            return failure("E_PROBABILITY", path .. ".survival", row.survival)
        end
        stages[i] = {
            name = row.name, survival = row.survival,
            evidence_basis = row.evidence_basis
        }
        product = product * row.survival
        if row.name == x.scenario_stage then
            selected = row.survival
        else
            other_product = other_product * row.survival
        end
    end

    if selected == nil then
        return failure("E_UNKNOWN_STAGE", "input.scenario_stage",
            x.scenario_stage)
    end
    if selected + x.survival_increment > 1 then
        return failure("E_SCENARIO_PROBABILITY", "input.survival_increment",
            x.survival_increment)
    end

    local has_cost = x.cost ~= nil or x.cost_unit ~= nil
    if has_cost then
        if x.cost == nil then return failure("E_MISSING", "input.cost", nil) end
        if x.cost_unit == nil then
            return failure("E_MISSING", "input.cost_unit", nil)
        end
        if not finite(x.cost) or x.cost <= 0 then
            return failure("E_COST", "input.cost", x.cost)
        end
        if not text(x.cost_unit) then
            return failure("E_TEXT", "input.cost_unit", x.cost_unit)
        end
    end

    local baseline = x.cohort_count * product
    local gain = x.cohort_count * other_product * x.survival_increment
    local gain_per_cost = false
    if has_cost then
        gain_per_cost = gain / x.cost
        if not finite(gain_per_cost) then
            return failure("E_NUMERIC_RANGE", "input.cost", x.cost)
        end
    end

    return {
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = "screen_deterministic_scenario",
        scope = x.scope,
        units = "expected_terminal_individuals_per_starting_cohort",
        cohort_count = x.cohort_count,
        stages = stages,
        scenario = {
            stage = x.scenario_stage,
            survival_increment = x.survival_increment,
            basis = x.scenario_basis,
            provenance_kind = x.provenance_kind,
            cost = has_cost and x.cost or false,
            cost_unit = has_cost and x.cost_unit or false
        },
        baseline_expected = baseline,
        scenario_expected = baseline + gain,
        incremental_expected = gain,
        incremental_per_cost = gain_per_cost,
        interpretation_limits = {
            causal_attribution_established = false,
            uncertainty_propagated = false,
            density_dependence_modeled = false,
            long_term_population_growth_estimated = false,
            external_action_authorized = false,
            synthetic_inputs = x.provenance_kind == "synthetic"
        }
    }
end

return M
