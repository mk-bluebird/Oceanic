-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.evaluation_semantics.retrieval_grammar_referral")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local total, failures = 0, 0

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

local function fixture()
    return {
        protocol_version = "synthetic-1",
        source_snapshot_version = "synthetic-snapshot-1",
        split = "held_out",
        threshold = 0.5,
        threshold_frozen_declared = true,
        rows = {
            {retrieval = "adequate", answer = "correct", uncertainty = 0.1},
            {retrieval = "adequate", answer = "incorrect", uncertainty = 0.2},
            {retrieval = "inadequate", answer = "incorrect", uncertainty = 0.8},
            {retrieval = "inadequate", answer = "correct", uncertainty = 0.9}
        }
    }
end

test("retrieval_and_correctness_are_not_conflated", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    local counts = result.value.retrieval_answer_counts
    assert(counts.adequate.incorrect == 1)
    assert(counts.inadequate.correct == 1)
    assert(not result.value.causal_failure_attribution_established)
end)

test("coverage_and_risk_are_reported_together", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    assert(result.value.coverage.value == 0.5)
    assert(result.value.retained_reviewed_error.value == 0.5)
    assert(result.value.referral_fraction.value == 0.5)
end)

test("unreviewed_retained_answers_remain_visible", function()
    local input = fixture()
    input.rows[1].answer = "unreviewed"
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.retained.unreviewed == 1)
    assert(result.value.retained_label_coverage.value == 0.5)
end)

test("no_retained_records_gives_undefined_risk", function()
    local input = fixture()
    input.threshold = -1
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.coverage.value == 0)
    assert(result.value.retained_reviewed_error.status == "undefined")
end)

test("grammar_diagnostics_are_not_truth_probabilities", function()
    local result = M.grammar_diagnostics({
        grammar_version = "synthetic-grammar-1",
        steps = {
            {rule_probabilities = {0.5, 0.5}, selected_rule = 1},
            {rule_probabilities = {0.25, 0.75}, selected_rule = 2}
        }
    })
    assert(result.ok)
    assert(math.abs(result.value.derivation_log_probability
        - math.log(0.375)) <= 1e-12)
    assert(not result.value.truth_probability_computed)
end)

test("selected_zero_probability_rule_is_rejected", function()
    local result = M.grammar_diagnostics({
        grammar_version = "synthetic-grammar-1",
        steps = {
            {rule_probabilities = {1, 0}, selected_rule = 2}
        }
    })
    assert(not result.ok)
    assert(result.error.code == "E_SELECTED_ZERO_PROBABILITY")
end)

test("empty_evaluation_has_undefined_coverage", function()
    local input = fixture()
    input.rows = {}
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.coverage.status == "undefined")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
