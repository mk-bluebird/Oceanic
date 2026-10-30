-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local finite-state calculation only; no I/O, storage, or actuation.
--
-- Inputs use natural logarithms. -math.huge denotes exact zero.
-- Log inputs cannot recover information already lost before this call.

local M = {VERSION = "1.0.0"}
local MAX = 32
local TOL = 1e-10
local NEG_INF = -math.huge

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "log_bayesian_filter." .. code,
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
        and value > NEG_INF
        and value < math.huge
end

local function log_value(value)
    return value == NEG_INF or finite(value)
end

local function shape(value)
    if not plain(value) then
        return fail("E_INPUT_TYPE", "input")
    end

    local required = {
        "log_prior", "log_transition", "log_likelihood",
        "likelihood_kind", "observation_measure"
    }
    local allowed = {}

    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return fail("E_MISSING_MEMBER", "input")
        end
    end

    for key in next, value do
        if not allowed[key] then
            return fail("E_UNKNOWN_MEMBER", "input")
        end
    end
    return ok(true)
end

local function array_length(value, path)
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

    if count == 0 or highest ~= count then
        return fail("E_ARRAY_SHAPE", path)
    end
    return ok(count)
end

local function lse(values)
    local maximum = NEG_INF
    for i = 1, #values do
        if values[i] > maximum then maximum = values[i] end
    end
    if maximum == NEG_INF then return NEG_INF end

    local total = 0
    for i = 1, #values do
        total = total + math.exp(values[i] - maximum)
    end

    local result = maximum + math.log(total)
    if not finite(result) then return nil end
    return result
end

local function log_probability_vector(values, n)
    for i = 1, n do
        if not log_value(values[i]) or values[i] > 0 then
            return false
        end
    end
    local normalizer = lse(values)
    return normalizer ~= nil
        and normalizer ~= NEG_INF
        and math.abs(normalizer) <= TOL
end

local function add_logs(left, right)
    if left == NEG_INF or right == NEG_INF then return NEG_INF end
    local result = left + right
    if not finite(result) then return nil end
    return result
end

local function label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 120
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
end

function M.describe()
    return ok({
        module_version = M.VERSION,
        max_dimension = MAX,
        log_base = "natural",
        probability_log_sum_tolerance = TOL,
        supported_likelihood_kinds = {
            "probability", "density", "relative_weight"
        }
    })
end

function M.evaluate(input)
    local checked = shape(input)
    if not checked.ok then return checked end

    local size = array_length(input.log_prior, "input.log_prior")
    if not size.ok then return size end
    local n = size.value

    if not log_probability_vector(input.log_prior, n) then
        return fail("E_PRIOR", "input.log_prior")
    end

    size = array_length(input.log_transition, "input.log_transition")
    if not size.ok then return size end
    if size.value ~= n then
        return fail("E_DIMENSION_MISMATCH", "input.log_transition")
    end

    for i = 1, n do
        local row = input.log_transition[i]
        size = array_length(row, "input.log_transition")
        if not size.ok then return size end
        if size.value ~= n then
            return fail("E_DIMENSION_MISMATCH", "input.log_transition")
        end
        if not log_probability_vector(row, n) then
            return fail("E_TRANSITION", "input.log_transition")
        end
    end

    size = array_length(input.log_likelihood, "input.log_likelihood")
    if not size.ok then return size end
    if size.value ~= n then
        return fail("E_DIMENSION_MISMATCH", "input.log_likelihood")
    end

    local kind = input.likelihood_kind
    if kind ~= "probability" and kind ~= "density"
        and kind ~= "relative_weight" then
        return fail("E_LIKELIHOOD_KIND", "input.likelihood_kind")
    end

    if not label(input.observation_measure) then
        return fail("E_OBSERVATION_MEASURE", "input.observation_measure")
    end

    for j = 1, n do
        local value = input.log_likelihood[j]
        if not log_value(value) or (kind == "probability" and value > 0) then
            return fail("E_LIKELIHOOD", "input.log_likelihood")
        end
    end

    local predicted, joint = {}, {}

    for j = 1, n do
        local terms = {}
        for i = 1, n do
            terms[i] = add_logs(
                input.log_prior[i], input.log_transition[i][j])
            if terms[i] == nil then
                return fail("E_LOG_NUMERIC_RANGE", "input.log_transition")
            end
        end

        predicted[j] = lse(terms)
        if predicted[j] == nil then
            return fail("E_LOG_NUMERIC_RANGE", "input.log_transition")
        end

        joint[j] = add_logs(predicted[j], input.log_likelihood[j])
        if joint[j] == nil then
            return fail("E_LOG_NUMERIC_RANGE", "input.log_likelihood")
        end
    end

    local normalizer = lse(joint)
    if normalizer == nil then
        return fail("E_LOG_NUMERIC_RANGE", "input.log_likelihood")
    end
    if normalizer == NEG_INF then
        return fail("E_ZERO_PREDICTIVE_SUPPORT", "input.log_likelihood")
    end

    local log_posterior, posterior = {}, {}
    local lost_linear_components = 0

    for j = 1, n do
        if joint[j] == NEG_INF then
            log_posterior[j] = NEG_INF
            posterior[j] = 0
        else
            local value = joint[j] - normalizer
            if not finite(value) then
                return fail("E_LOG_NUMERIC_RANGE", "input")
            end
            log_posterior[j] = value
            posterior[j] = math.exp(value)

            if posterior[j] == 0 then
                lost_linear_components = lost_linear_components + 1
            end
        end
    end

    local meaning = ({
        probability = "model_declared_log_marginal_probability",
        density = "model_declared_log_marginal_density",
        relative_weight = "log_weight_normalizer_only"
    })[kind]

    return ok({
        module_version = M.VERSION,
        max_dimension = MAX,
        state_count = n,
        log_predicted = predicted,
        log_posterior = log_posterior,
        posterior = posterior,
        log_normalizer = normalizer,
        normalizer_interpretation = meaning,
        likelihood_kind = kind,
        observation_measure = input.observation_measure,
        likelihood_model_verified = false,
        model_comparison_authorized_by_result = false,
        linear_output_underflow_count = lost_linear_components,
        numerical_error_bound_established = false,
        operation_semantics = "transition_prediction_then_conditioning",
        imaging_performed = false,
        agm_revision_performed = false,
        km_update_performed = false,
        governance_authorization_assessed = false
    })
end

return M
