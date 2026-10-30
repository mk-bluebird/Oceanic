-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.decision_semantics.finite_information_belief")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local failures, total = 0, 0

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

local function close(a, b)
    return math.abs(a - b) <= 1e-10
end

local function decision()
    return {
        prior = {0.5, 0.5},
        signal_given_state = {{0.9, 0.1}, {0.1, 0.9}},
        losses = {{0, 10}, {10, 0}},
        feasible_actions = {true, true},
        costs = {
            screening = 0.25,
            review = 0.5,
            accessibility = 0.25,
            other = 0
        },
        loss_unit = "synthetic common loss units"
    }
end

test("evsi_and_costs_are_separate", function()
    local result = M.evsi(decision())
    assert(result.ok)
    assert(close(result.value.baseline_expected_loss, 5))
    assert(close(result.value.gross_evsi, 4))
    assert(close(result.value.expected_net_benefit_of_sampling, 3))
end)

test("one_feasible_action_has_zero_information_value", function()
    local input = decision()
    input.feasible_actions = {true, false}
    local result = M.evsi(input)
    assert(result.ok)
    assert(close(result.value.gross_evsi, 0))
    assert(close(result.value.expected_net_benefit_of_sampling, -1))
end)

test("no_feasible_action_is_not_repaired_by_score", function()
    local input = decision()
    input.feasible_actions = {false, false}
    local result = M.evsi(input)
    assert(not result.ok and result.error.code == "E_NO_FEASIBLE_ACTION")
end)

test("transition_and_conditioning_are_distinct", function()
    local result = M.filter({
        prior = {0.8, 0.2},
        transition = {{0.5, 0.5}, {0.1, 0.9}},
        likelihood = {0.2, 0.8}
    })
    assert(result.ok)
    assert(close(result.value.predicted[1], 0.42))
    assert(close(result.value.predicted[2], 0.58))
    assert(close(result.value.posterior[1], 21 / 137))
    assert(close(result.value.posterior[2], 116 / 137))
    assert(not result.value.imaging_performed)
end)

test("zero_likelihood_does_not_invent_posterior", function()
    local result = M.filter({
        prior = {0.5, 0.5},
        transition = {{1, 0}, {0, 1}},
        likelihood = {0, 0}
    })
    assert(not result.ok and result.error.code == "E_ZERO_LIKELIHOOD")
end)

test("recovery_counterexample_is_reported", function()
    local result = M.recovery({
        original_models = {true, false, false},
        contracted_models = {true, true, true},
        proposition_models = {true, true, false}
    })
    assert(result.ok)
    assert(not result.value.recovery_subset_condition)
    assert(result.value.counterexample_world_positions[1] == 2)
    assert(result.value.contraction_inclusion_condition)
    assert(result.value.contraction_success_condition)
end)

test("inconsistent_restoration_is_explicit", function()
    local result = M.recovery({
        original_models = {true, false},
        contracted_models = {true, true},
        proposition_models = {false, false}
    })
    assert(result.ok)
    assert(result.value.recovery_subset_condition)
    assert(result.value.recovery_vacuous_from_inconsistency)
    assert(not result.value.restored_consistent)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
