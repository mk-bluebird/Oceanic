-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Local finite-model research operations.
-- No I/O, storage, history retrieval, networking, or actuation.
-- No KM update, AGM revision, or calibration estimator is implemented.

local M = {VERSION = "1.0.0"}
local REGISTRY_VERSION = "1.0.0"
local MAX_STATES = 16
local MAX_CONTEXTS = 8
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
            message_key = "contextual_loss_belief." .. code,
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

local function shape(value, required)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function length(value, maximum)
    if not plain(value) then return nil end
    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > maximum or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > maximum then
            return nil
        end
        if key > highest then highest = key end
    end
    if count == 0 or highest ~= count then return nil end
    return count
end

local function probabilities(value, n)
    if length(value, MAX_STATES) ~= n then return false end
    local total = 0
    for i = 1, n do
        if not finite(value[i]) or value[i] < 0 or value[i] > 1 then
            return false
        end
        total = total + value[i]
    end
    return math.abs(total - 1) <= TOL
end

local function label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 160
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
end

local function metadata(operation)
    return {
        operation_code = operation,
        operation_registry_version = REGISTRY_VERSION,
        km_update_performed = false,
        agm_revision_performed = false,
        scientific_support_assessed = false,
        authorization_assessed = false
    }
end

function M.predict(input)
    if not shape(input, {
        "operation_registry_version", "prior",
        "context_index", "transition_kernels"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end
    if input.operation_registry_version ~= REGISTRY_VERSION then
        return fail("E_OPERATION_REGISTRY_VERSION", "input")
    end

    local n = length(input.prior, MAX_STATES)
    if not n or not probabilities(input.prior, n) then
        return fail("E_PRIOR", "input.prior")
    end

    local contexts = length(input.transition_kernels, MAX_CONTEXTS)
    if not contexts then
        return fail("E_CONTEXT_KERNELS", "input.transition_kernels")
    end

    local selected = input.context_index
    if type(selected) ~= "number" or selected % 1 ~= 0
        or selected < 1 or selected > contexts then
        return fail("E_CONTEXT_INDEX", "input.context_index")
    end

    for c = 1, contexts do
        local kernel = input.transition_kernels[c]
        if length(kernel, MAX_STATES) ~= n then
            return fail("E_TRANSITION_DIMENSION", "input.transition_kernels")
        end
        for i = 1, n do
            if not probabilities(kernel[i], n) then
                return fail("E_TRANSITION_ROW", "input.transition_kernels")
            end
        end
    end

    local predicted = {}
    local kernel = input.transition_kernels[selected]
    for j = 1, n do
        predicted[j] = 0
        for i = 1, n do
            predicted[j] = predicted[j] + input.prior[i] * kernel[i][j]
        end
    end

    local result = metadata("context_conditioned_transition_prediction")
    result.predicted = predicted
    result.context_position_used = selected
    result.context_inferred = false
    result.context_sufficiency_verified = false
    result.history_retained = false
    return ok(result)
end

function M.loss_update(input)
    if not shape(input, {
        "operation_registry_version", "prior", "losses",
        "learning_rate", "loss_scale", "calibration"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end
    if input.operation_registry_version ~= REGISTRY_VERSION then
        return fail("E_OPERATION_REGISTRY_VERSION", "input")
    end

    local n = length(input.prior, MAX_STATES)
    if not n or not probabilities(input.prior, n) then
        return fail("E_PRIOR", "input.prior")
    end

    if length(input.losses, MAX_STATES) ~= n then
        return fail("E_LOSS_DIMENSION", "input.losses")
    end
    if not finite(input.learning_rate) or input.learning_rate < 0 then
        return fail("E_LEARNING_RATE", "input.learning_rate")
    end
    if not label(input.loss_scale) then
        return fail("E_LOSS_SCALE", "input.loss_scale")
    end

    local calibration = input.calibration
    if not shape(calibration, {"status", "criterion"}) then
        return fail("E_CALIBRATION_SHAPE", "input.calibration")
    end
    if calibration.status ~= "unvalidated"
        and calibration.status ~= "external_calibration_declared" then
        return fail("E_CALIBRATION_STATUS", "input.calibration")
    end
    if calibration.criterion ~= "none"
        and calibration.criterion ~= "held_out_prediction"
        and calibration.criterion ~= "repeated_sampling_coverage"
        and calibration.criterion ~= "robustness_target" then
        return fail("E_CALIBRATION_CRITERION", "input.calibration")
    end
    if (calibration.status == "unvalidated"
            and calibration.criterion ~= "none")
        or (calibration.status == "external_calibration_declared"
            and calibration.criterion == "none") then
        return fail("E_CALIBRATION_COMBINATION", "input.calibration")
    end

    local log_weights, maximum = {}, NI

    for i = 1, n do
        local loss = input.losses[i]
        if not finite(loss) or loss < 0 then
            return fail("E_LOSS_VALUE", "input.losses")
        end

        local penalty = input.learning_rate * loss
        if not finite(penalty) then
            return fail("E_NUMERIC_RANGE", "input.losses")
        end

        local value = input.prior[i] == 0
            and NI or math.log(input.prior[i]) - penalty

        if value ~= NI and not finite(value) then
            return fail("E_NUMERIC_RANGE", "input.losses")
        end
        log_weights[i] = value
        if value > maximum then maximum = value end
    end

    local total = 0
    for i = 1, n do
        total = total + math.exp(log_weights[i] - maximum)
    end

    local shifted_normalizer = math.log(total)
    local posterior, log_posterior = {}, {}
    local underflow_count = 0

    for i = 1, n do
        if log_weights[i] == NI then
            log_posterior[i], posterior[i] = NI, 0
        else
            log_posterior[i] =
                (log_weights[i] - maximum) - shifted_normalizer
            posterior[i] = math.exp(log_posterior[i])
            if posterior[i] == 0 then
                underflow_count = underflow_count + 1
            end
        end
    end

    local result = metadata("generalized_loss_update")
    result.posterior = posterior
    result.log_posterior = log_posterior
    result.learning_rate = input.learning_rate
    result.loss_scale = input.loss_scale
    result.calibration_declaration = {
        status = calibration.status,
        criterion = calibration.criterion
    }
    result.calibration_verified = false
    result.likelihood_interpretation_established = false
    result.linear_output_underflow_count = underflow_count
    result.input_probability_tolerance = TOL
    result.numerical_error_bound_established = false
    return ok(result)
end

return M
