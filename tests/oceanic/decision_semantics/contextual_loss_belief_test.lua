-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.decision_semantics.contextual_loss_belief")

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

local function close(a, b)
    return math.abs(a - b) <= 1e-10
end

local function update(rate, losses)
    return M.loss_update({
        operation_registry_version = "1.0.0",
        prior = {0.5, 0.5},
        losses = losses,
        learning_rate = rate,
        loss_scale = "synthetic dimensionless loss",
        calibration = {
            status = "unvalidated",
            criterion = "none"
        }
    })
end

test("same_current_prior_different_context_changes_prediction", function()
    local input = {
        operation_registry_version = "1.0.0",
        prior = {0.5, 0.5},
        context_index = 1,
        transition_kernels = {
            {{0.9, 0.1}, {0.9, 0.1}},
            {{0.2, 0.8}, {0.2, 0.8}}
        }
    }

    local first = M.predict(input)
    input.context_index = 2
    local second = M.predict(input)

    assert(first.ok and second.ok)
    assert(close(first.value.predicted[1], 0.9))
    assert(close(second.value.predicted[1], 0.2))
    assert(not first.value.context_inferred)
end)

test("zero_learning_rate_preserves_prior", function()
    local result = update(0, {0, 100})
    assert(result.ok)
    assert(close(result.value.posterior[1], 0.5))
    assert(close(result.value.posterior[2], 0.5))
end)

test("loss_scale_and_rate_transform_together", function()
    local first = update(0.5, {0, 2})
    local second = update(0.25, {0, 4})
    assert(first.ok and second.ok)
    assert(close(first.value.posterior[1], second.value.posterior[1]))
end)

test("loss_update_is_not_claimed_to_be_km_or_agm", function()
    local result = update(1, {0, 1})
    assert(result.ok)
    assert(result.value.operation_code == "generalized_loss_update")
    assert(not result.value.km_update_performed)
    assert(not result.value.agm_revision_performed)
    assert(not result.value.calibration_verified)
end)

test("zero_prior_support_is_not_reintroduced", function()
    local result = M.loss_update({
        operation_registry_version = "1.0.0",
        prior = {1, 0},
        losses = {100, 0},
        learning_rate = 1,
        loss_scale = "synthetic dimensionless loss",
        calibration = {status = "unvalidated", criterion = "none"}
    })
    assert(result.ok)
    assert(result.value.posterior[2] == 0)
end)

test("unsupported_operation_registry_is_rejected", function()
    local result = M.predict({
        operation_registry_version = "future",
        prior = {1},
        context_index = 1,
        transition_kernels = {{{1}}}
    })
    assert(not result.ok)
    assert(result.error.code == "E_OPERATION_REGISTRY_VERSION")
end)

test("invalid_calibration_combination_is_rejected", function()
    local result = M.loss_update({
        operation_registry_version = "1.0.0",
        prior = {0.5, 0.5},
        losses = {0, 1},
        learning_rate = 1,
        loss_scale = "synthetic dimensionless loss",
        calibration = {
            status = "external_calibration_declared",
            criterion = "none"
        }
    })
    assert(not result.ok)
    assert(result.error.code == "E_CALIBRATION_COMBINATION")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
