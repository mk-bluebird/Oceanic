-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Finite-model decision support only; no I/O, storage, or actuation.

local M = {VERSION = "1.0.0"}
local MAX = 32
local TOL = 1e-10

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "finite_information_belief." .. code,
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
        and value > -math.huge
        and value < math.huge
end

local function shape(value, keys)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(keys) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function length(value)
    if not plain(value) then return nil end
    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > MAX or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > MAX then
            return nil
        end
        if key > highest then highest = key end
    end
    if count == 0 or count ~= highest then return nil end
    return count
end

local function vector(value, n, kind)
    if length(value) ~= n then return false end
    for i = 1, n do
        if kind == "boolean" then
            if type(value[i]) ~= "boolean" then return false end
        elseif not finite(value[i]) or value[i] < 0 then
            return false
        elseif kind == "probability" and value[i] > 1 then
            return false
        end
    end
    return true
end

local function probability_vector(value, n)
    if not vector(value, n, "probability") then return false end
    local sum = 0
    for i = 1, n do sum = sum + value[i] end
    return math.abs(sum - 1) <= TOL
end

local function matrix(value, rows, columns, stochastic)
    if length(value) ~= rows then return false end
    for i = 1, rows do
        if stochastic then
            if not probability_vector(value[i], columns) then
                return false
            end
        elseif not vector(value[i], columns, "nonnegative") then
            return false
        end
    end
    return true
end

local function unit_label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 80
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
end

local function best_action(weights, losses, feasible, n, actions)
    local best, position = math.huge, nil
    for a = 1, actions do
        if feasible[a] then
            local risk = 0
            for j = 1, n do
                risk = risk + weights[j] * losses[a][j]
            end
            if not finite(risk) then return nil end
            if position == nil or risk < best then
                best, position = risk, a
            end
        end
    end
    return best, position
end

function M.evsi(input)
    if not shape(input, {
        "prior", "signal_given_state", "losses",
        "feasible_actions", "costs", "loss_unit"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end

    local n = length(input.prior)
    local actions = length(input.losses)
    if not n or not actions
        or not probability_vector(input.prior, n)
        or not matrix(input.losses, actions, n, false)
        or not vector(input.feasible_actions, actions, "boolean") then
        return fail("E_DECISION_MODEL", "input")
    end

    local signals = plain(input.signal_given_state)
        and length(rawget(input.signal_given_state, 1)) or nil

    if not signals
        or not matrix(input.signal_given_state, n, signals, true) then
        return fail("E_SIGNAL_MODEL", "input.signal_given_state")
    end

    if not shape(input.costs, {
        "screening", "review", "accessibility", "other"
    }) or not unit_label(input.loss_unit) then
        return fail("E_COST_MODEL", "input.costs")
    end

    local cost_total = 0
    for _, key in ipairs({
        "screening", "review", "accessibility", "other"
    }) do
        local cost = input.costs[key]
        if not finite(cost) or cost < 0 then
            return fail("E_COST_VALUE", "input.costs")
        end
        cost_total = cost_total + cost
    end

    if not finite(cost_total) then
        return fail("E_NUMERIC_RANGE", "input.costs")
    end

    local feasible_count = 0
    for _, allowed in ipairs(input.feasible_actions) do
        if allowed then feasible_count = feasible_count + 1 end
    end
    if feasible_count == 0 then
        return fail("E_NO_FEASIBLE_ACTION", "input.feasible_actions")
    end

    local baseline, baseline_action = best_action(
        input.prior, input.losses, input.feasible_actions, n, actions)
    if baseline == nil then return fail("E_NUMERIC_RANGE", "input.losses") end

    local after, signal_results = 0, {}

    for s = 1, signals do
        local joint, probability = {}, 0
        for j = 1, n do
            joint[j] = input.prior[j] * input.signal_given_state[j][s]
            probability = probability + joint[j]
        end

        if probability == 0 then
            signal_results[s] = {
                probability = 0,
                status = "impossible_under_model"
            }
        else
            local contribution, action = best_action(
                joint, input.losses, input.feasible_actions, n, actions)
            if contribution == nil then
                return fail("E_NUMERIC_RANGE", "input.losses")
            end
            after = after + contribution
            signal_results[s] = {
                probability = probability,
                action_position = action,
                expected_loss_contribution = contribution
            }
        end
    end

    local gross = baseline - after
    if not finite(after) or not finite(gross)
        or not finite(gross - cost_total) then
        return fail("E_NUMERIC_RANGE", "input")
    end

    return ok({
        baseline_expected_loss = baseline,
        baseline_action_position = baseline_action,
        expected_loss_after_information = after,
        gross_evsi = gross,
        total_cost = cost_total,
        expected_net_benefit_of_sampling = gross - cost_total,
        signal_results = signal_results,
        loss_unit = input.loss_unit,
        probability_tolerance = TOL,
        feasibility_verified = false,
        governance_authorization_assessed = false,
        recommendation_issued = false
    })
end

function M.filter(input)
    if not shape(input, {"prior", "transition", "likelihood"}) then
        return fail("E_INPUT_SHAPE", "input")
    end

    local n = length(input.prior)
    if not n or not probability_vector(input.prior, n)
        or not matrix(input.transition, n, n, true)
        or not vector(input.likelihood, n, "nonnegative") then
        return fail("E_STATE_SPACE_MODEL", "input")
    end

    local predicted, posterior, scale = {}, {}, 0

    for j = 1, n do
        predicted[j] = 0
        for i = 1, n do
            predicted[j] = predicted[j]
                + input.prior[i] * input.transition[i][j]
        end
        posterior[j] = predicted[j] * input.likelihood[j]
        scale = scale + posterior[j]
    end

    if not finite(scale) then return fail("E_NUMERIC_RANGE", "input") end
    if scale == 0 then return fail("E_ZERO_LIKELIHOOD", "input.likelihood") end

    for j = 1, n do posterior[j] = posterior[j] / scale end

    return ok({
        predicted = predicted,
        posterior = posterior,
        likelihood_normalizer = scale,
        operation = "transition_prediction_then_conditioning",
        likelihood_scale = "caller_declared_mass_density_or_relative_weight",
        regime_change_inferred = false,
        observation_change_inferred = false,
        imaging_performed = false
    })
end

function M.recovery(input)
    if not shape(input, {
        "original_models", "contracted_models", "proposition_models"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end

    local n = length(input.original_models)
    if not n
        or not vector(input.original_models, n, "boolean")
        or not vector(input.contracted_models, n, "boolean")
        or not vector(input.proposition_models, n, "boolean") then
        return fail("E_MODEL_MASK", "input")
    end

    local witnesses = {}
    local inclusion, success = true, false
    local restored_count, original_count = 0, 0

    for i = 1, n do
        local original = input.original_models[i]
        local contracted = input.contracted_models[i]
        local proposition = input.proposition_models[i]

        if original then original_count = original_count + 1 end
        if original and not contracted then inclusion = false end
        if contracted and not proposition then success = true end

        if contracted and proposition then
            restored_count = restored_count + 1
            if not original then witnesses[#witnesses + 1] = i end
        end
    end

    return ok({
        recovery_subset_condition = #witnesses == 0,
        counterexample_world_positions = witnesses,
        contraction_inclusion_condition = inclusion,
        contraction_success_condition = success,
        original_consistent = original_count > 0,
        restored_consistent = restored_count > 0,
        recovery_vacuous_from_inconsistency = restored_count == 0,
        universe_scope = "caller_supplied_finite_worlds",
        complete_propositional_universe_verified = false,
        agm_operator_verified = false
    })
end

return M
