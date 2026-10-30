-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local evaluation only; no I/O, storage, retrieval, or referral execution.

local M = {VERSION = "1.0.0"}
local MAX_ROWS = 1000
local MAX_STEPS = 128
local MAX_RULES = 32
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
            message_key = "retrieval_grammar_referral." .. code,
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
        and value > -math.huge and value < math.huge
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

local function length(value, maximum, allow_empty)
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
    if count ~= highest or (count == 0 and not allow_empty) then
        return nil
    end
    return count
end

local function label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 160
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
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

function M.grammar_diagnostics(input)
    if not shape(input, {"grammar_version", "steps"})
        or not label(input.grammar_version) then
        return fail("E_GRAMMAR_INPUT", "input")
    end

    local count = length(input.steps, MAX_STEPS, false)
    if not count then return fail("E_STEPS", "input.steps") end

    local log_probability, entropy_sum = 0, 0

    for _, step in ipairs(input.steps) do
        if not shape(step, {"rule_probabilities", "selected_rule"}) then
            return fail("E_STEP", "input.steps")
        end

        local rules = length(step.rule_probabilities, MAX_RULES, false)
        if not rules then return fail("E_RULES", "input.steps") end

        local selected = step.selected_rule
        if type(selected) ~= "number" or selected % 1 ~= 0
            or selected < 1 or selected > rules then
            return fail("E_SELECTED_RULE", "input.steps")
        end

        local sum, entropy = 0, 0
        for _, probability in ipairs(step.rule_probabilities) do
            if not finite(probability) or probability < 0
                or probability > 1 then
                return fail("E_RULE_PROBABILITY", "input.steps")
            end
            sum = sum + probability
            if probability > 0 then
                entropy = entropy
                    - probability * math.log(probability) / math.log(2)
            end
        end

        if math.abs(sum - 1) > TOL then
            return fail("E_RULE_NORMALIZATION", "input.steps")
        end

        local chosen = step.rule_probabilities[selected]
        if chosen == 0 then
            return fail("E_SELECTED_ZERO_PROBABILITY", "input.steps")
        end

        log_probability = log_probability + math.log(chosen)
        entropy_sum = entropy_sum + entropy
    end

    return ok({
        grammar_version = input.grammar_version,
        step_count = count,
        derivation_log_probability = log_probability,
        mean_selected_rule_surprisal_bits =
            -log_probability / (count * math.log(2)),
        sum_local_rule_entropies_bits = entropy_sum,
        grammar_validity_verified = false,
        full_grammar_entropy_computed = false,
        truth_probability_computed = false,
        calibration_established = false
    })
end

function M.evaluate(input)
    if not shape(input, {
        "protocol_version", "source_snapshot_version",
        "split", "threshold", "threshold_frozen_declared", "rows"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end

    if not label(input.protocol_version)
        or not label(input.source_snapshot_version) then
        return fail("E_METADATA", "input")
    end

    if input.split ~= "development" and input.split ~= "held_out" then
        return fail("E_SPLIT", "input.split")
    end
    if not finite(input.threshold) then
        return fail("E_THRESHOLD", "input.threshold")
    end
    if type(input.threshold_frozen_declared) ~= "boolean" then
        return fail("E_THRESHOLD_DECLARATION", "input")
    end

    local count = length(input.rows, MAX_ROWS, true)
    if count == nil then return fail("E_ROWS", "input.rows") end

    local table_counts = {
        adequate = {correct = 0, incorrect = 0, unreviewed = 0},
        inadequate = {correct = 0, incorrect = 0, unreviewed = 0},
        unreviewed = {correct = 0, incorrect = 0, unreviewed = 0}
    }

    local retained = {
        correct = 0, incorrect = 0, unreviewed = 0, total = 0
    }
    local referred = {
        correct = 0, incorrect = 0, unreviewed = 0, total = 0
    }

    for _, row in ipairs(input.rows) do
        if not shape(row, {"retrieval", "answer", "uncertainty"})
            or type(row.retrieval) ~= "string"
            or not table_counts[row.retrieval]
            or type(row.answer) ~= "string"
            or table_counts[row.retrieval][row.answer] == nil
            or not finite(row.uncertainty) then
            return fail("E_ROW", "input.rows")
        end

        local cell = table_counts[row.retrieval]
        cell[row.answer] = cell[row.answer] + 1

        local group = row.uncertainty <= input.threshold
            and retained or referred
        group.total = group.total + 1
        group[row.answer] = group[row.answer] + 1
    end

    local a = table_counts.adequate
    local b = table_counts.inadequate
    local jointly_reviewed = a.correct + a.incorrect
        + b.correct + b.incorrect

    local decomposition
    if jointly_reviewed == 0 then
        decomposition = {status = "undefined"}
    else
        local adequate_total = a.correct + a.incorrect
        local inadequate_total = b.correct + b.incorrect

        decomposition = {
            status = "defined",
            jointly_reviewed_count = jointly_reviewed,
            empirical_p_adequate =
                ratio(adequate_total, jointly_reviewed),
            empirical_p_correct_given_adequate =
                ratio(a.correct, adequate_total),
            empirical_p_correct_given_inadequate =
                ratio(b.correct, inadequate_total),
            correct_adequate_joint_fraction =
                ratio(a.correct, jointly_reviewed),
            correct_inadequate_joint_fraction =
                ratio(b.correct, jointly_reviewed),
            empirical_correct_fraction =
                ratio(a.correct + b.correct, jointly_reviewed)
        }
    end

    local known_errors = retained.incorrect + referred.incorrect

    return ok({
        module_version = M.VERSION,
        protocol_version = input.protocol_version,
        source_snapshot_version = input.source_snapshot_version,
        split = input.split,
        threshold = input.threshold,
        threshold_frozen_declared = input.threshold_frozen_declared,
        threshold_freeze_verified = false,
        evaluated_count = count,
        retrieval_answer_counts = table_counts,
        decomposition = decomposition,
        retained = retained,
        referred = referred,
        coverage = ratio(retained.total, count),
        referral_fraction = ratio(referred.total, count),
        retained_reviewed_error =
            ratio(retained.incorrect, retained.correct + retained.incorrect),
        retained_label_coverage =
            ratio(retained.correct + retained.incorrect, retained.total),
        known_error_referral_fraction =
            ratio(referred.incorrect, known_errors),
        labels_independently_verified = false,
        causal_failure_attribution_established = false,
        uncertainty_calibrated = false,
        referral_executed = false,
        participation_eligibility_assessed = false
    })
end

return M
