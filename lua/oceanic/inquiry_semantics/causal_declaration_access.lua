-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local research calculations only.
-- No I/O, persistence, networking, identity inference, or actuation.

local M = {VERSION = "1.0.0"}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "causal_declaration_access." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
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

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function probability(value)
    return finite(value) and value >= 0 and value <= 1
end

local function array_length(value, maximum, empty_allowed)
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
    if count ~= highest or (count == 0 and not empty_allowed) then
        return nil
    end
    return count
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 2000
        and not value:match("^[ \t\r\n]*$")
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function choice(value, allowed)
    return type(value) == "string" and allowed[value] == true
end

local function ratio(numerator, denominator)
    local result = {
        numerator = numerator,
        denominator = denominator,
        status = denominator > 0 and "defined" or "undefined"
    }
    if denominator > 0 then result.value = numerator / denominator end
    return result
end

function M.binary_causal_comparison(input)
    if not shape(input, {
        "p_z1", "p_x1_given_z", "p_y1_given_xz"
    }) or not probability(input.p_z1)
        or array_length(input.p_x1_given_z, 2, false) ~= 2
        or array_length(input.p_y1_given_xz, 2, false) ~= 2 then
        return fail("E_CAUSAL_MODEL", "input")
    end

    for z = 1, 2 do
        if not probability(input.p_x1_given_z[z]) then
            return fail("E_ASSIGNMENT_PROBABILITY", "input.p_x1_given_z")
        end
    end

    for x = 1, 2 do
        if array_length(input.p_y1_given_xz[x], 2, false) ~= 2 then
            return fail("E_OUTCOME_DIMENSION", "input.p_y1_given_xz")
        end
        for z = 1, 2 do
            if not probability(input.p_y1_given_xz[x][z]) then
                return fail("E_OUTCOME_PROBABILITY", "input.p_y1_given_xz")
            end
        end
    end

    local pz = {1 - input.p_z1, input.p_z1}
    local observational, interventional = {}, {}

    for x = 1, 2 do
        local joint_yx, px, do_y = 0, 0, 0
        for z = 1, 2 do
            local assigned = x == 2
                and input.p_x1_given_z[z]
                or (1 - input.p_x1_given_z[z])
            local outcome = input.p_y1_given_xz[x][z]
            px = px + pz[z] * assigned
            joint_yx = joint_yx + pz[z] * assigned * outcome
            do_y = do_y + pz[z] * outcome
        end
        observational[x] = ratio(joint_yx, px)
        interventional[x] = do_y
    end

    return ok({
        binary_index_order = {"0", "1"},
        observational_p_y1_given_x = observational,
        interventional_p_y1_given_do_x = interventional,
        interventional_risk_difference =
            interventional[2] - interventional[1],
        assumed_graph = "Z_to_X_Z_to_Y_X_to_Y",
        causal_graph_verified = false,
        confounding_control_verified = false,
        positivity_verified_for_empirical_estimation = false,
        intervention_authorized = false,
        assessment_scope = "supplied_binary_causal_model"
    })
end

function M.prediction_comparison(input)
    if not shape(input, {"outcomes", "baseline", "augmented"}) then
        return fail("E_PREDICTION_INPUT", "input")
    end

    local n = array_length(input.outcomes, 1000, false)
    if not n or array_length(input.baseline, 1000, false) ~= n
        or array_length(input.augmented, 1000, false) ~= n then
        return fail("E_PREDICTION_DIMENSION", "input")
    end

    local baseline_loss, augmented_loss = 0, 0
    for i = 1, n do
        local y = input.outcomes[i]
        if (y ~= 0 and y ~= 1)
            or not probability(input.baseline[i])
            or not probability(input.augmented[i]) then
            return fail("E_PREDICTION_VALUE", "input")
        end
        baseline_loss = baseline_loss + (input.baseline[i] - y)^2
        augmented_loss = augmented_loss + (input.augmented[i] - y)^2
    end

    baseline_loss = baseline_loss / n
    augmented_loss = augmented_loss / n

    return ok({
        record_count = n,
        score = "mean_binary_brier_loss",
        baseline_loss = baseline_loss,
        augmented_loss = augmented_loss,
        loss_reduction = baseline_loss - augmented_loss,
        held_out_separation_verified = false,
        temporal_alignment_verified = false,
        uncertainty_interval_computed = false,
        causal_effect_established = false
    })
end

function M.record_declaration(input)
    if not shape(input, {"speech_act", "proposition", "scope"})
        or not choice(input.speech_act, {
            assertion = true,
            belief_report = true,
            knowledge_claim = true
        })
        or not text(input.proposition)
        or not text(input.scope) then
        return fail("E_DECLARATION", "input")
    end

    return ok({
        speech_act = input.speech_act,
        proposition = input.proposition,
        scope = input.scope,
        record_semantics = "supplied_declaration_only",
        actual_belief_inferred = false,
        factive_knowledge_asserted = false,
        proposition_truth_verified = false,
        authority_established = false
    })
end

function M.access_summary(input)
    if not shape(input, {"protocol_version", "tasks"})
        or not text(input.protocol_version) then
        return fail("E_ACCESS_INPUT", "input")
    end

    local n = array_length(input.tasks, 1000, true)
    if n == nil then return fail("E_TASKS", "input.tasks") end

    local completion = {completed = 0, not_completed = 0, abandoned = 0}
    local errors = {yes = 0, no = 0, unreviewed = 0}
    local disclosure = {yes = 0, no = 0, unreviewed = 0}
    local correction = {
        not_requested = 0,
        succeeded = 0,
        unsuccessful = 0,
        unavailable = 0,
        unresolved = 0
    }
    local burden_reports = 0

    for _, task in ipairs(input.tasks) do
        if not shape(task, {
            "completion", "interpretation_error", "unwanted_disclosure",
            "correction", "voluntary_burden"
        }) then
            return fail("E_TASK_RECORD", "input.tasks")
        end

        if not choice(task.completion, {
            completed = true, not_completed = true, abandoned = true
        }) or not choice(task.interpretation_error, {
            yes = true, no = true, unreviewed = true
        }) or not choice(task.unwanted_disclosure, {
            yes = true, no = true, unreviewed = true
        }) or not choice(task.correction, {
            not_requested = true, succeeded = true, unsuccessful = true,
            unavailable = true, unresolved = true
        }) then
            return fail("E_TASK_STATUS", "input.tasks")
        end

        local burden = task.voluntary_burden
        if burden ~= "not_provided" then
            if not finite(burden) or burden < 0 or burden > 10 then
                return fail("E_BURDEN_REPORT", "input.tasks")
            end
            burden_reports = burden_reports + 1
        end

        completion[task.completion] = completion[task.completion] + 1
        errors[task.interpretation_error] =
            errors[task.interpretation_error] + 1
        disclosure[task.unwanted_disclosure] =
            disclosure[task.unwanted_disclosure] + 1
        correction[task.correction] = correction[task.correction] + 1
    end

    return ok({
        protocol_version = input.protocol_version,
        task_count = n,
        completion_counts = completion,
        completion_fraction = ratio(completion.completed, n),
        interpretation_error_counts = errors,
        unwanted_disclosure_counts = disclosure,
        correction_counts = correction,
        voluntary_burden_report_count = burden_reports,
        burden_reporting_scale = "optional_0_to_10_protocol_defined",
        burden_score_aggregated = false,
        competence_rank_computed = false,
        latency_collected = false,
        disability_or_health_inferred = false,
        participant_count_estimated = false,
        consent_verified = false,
        accessibility_certified = false
    })
end

return M
