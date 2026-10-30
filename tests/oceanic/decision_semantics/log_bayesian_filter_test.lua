-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.decision_semantics.log_bayesian_filter")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local total, failures = 0, 0
local NI = -math.huge

local function close(a, b)
    return math.abs(a - b) <= 1e-10
end

local function test(name, fn)
    total = total + 1
    local passed, detail = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then
        failures = failures + 1
        local safe = type(detail) == "string" and detail
            or "non_string_test_failure"
        safe = safe:gsub("[%z\1-\31\127]", " "):sub(1, 300)
        io.write("DETAIL\t", name, "\t", safe, "\n")
    end
end

local function fixture()
    return {
        log_prior = {math.log(0.8), math.log(0.2)},
        log_transition = {
            {math.log(0.5), math.log(0.5)},
            {math.log(0.1), math.log(0.9)}
        },
        log_likelihood = {math.log(0.2), math.log(0.8)},
        likelihood_kind = "probability",
        observation_measure = "synthetic discrete observation"
    }
end

test("ordinary_filter_matches_finite_example", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    assert(close(math.exp(result.value.log_predicted[1]), 0.42))
    assert(close(result.value.posterior[1], 21 / 137))
    assert(close(result.value.posterior[2], 116 / 137))
end)

test("tiny_observation_probability_remains_representable", function()
    local input = fixture()
    input.log_likelihood = {-1000, -1000}
    local result = M.evaluate(input)
    assert(result.ok)
    assert(close(result.value.log_normalizer, -1000))
    assert(close(result.value.posterior[1], 0.42))
end)

test("support_mismatch_is_not_all_likelihoods_zero", function()
    local input = {
        log_prior = {0, NI},
        log_transition = {{0, NI}, {NI, 0}},
        log_likelihood = {NI, 0},
        likelihood_kind = "probability",
        observation_measure = "synthetic discrete observation"
    }
    local result = M.evaluate(input)
    assert(not result.ok)
    assert(result.error.code == "E_ZERO_PREDICTIVE_SUPPORT")
end)

test("relative_weight_does_not_claim_marginal_evidence", function()
    local input = fixture()
    input.likelihood_kind = "relative_weight"
    input.log_likelihood = {2, 3}
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.normalizer_interpretation
        == "log_weight_normalizer_only")
end)

test("density_values_may_exceed_one", function()
    local input = fixture()
    input.likelihood_kind = "density"
    input.log_likelihood = {math.log(2), math.log(4)}
    input.observation_measure = "synthetic measurement unit"
    local result = M.evaluate(input)
    assert(result.ok)
end)

test("positive_log_probability_is_rejected", function()
    local input = fixture()
    input.log_likelihood = {0.1, -1}
    local result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_LIKELIHOOD")
end)

test("linear_output_underflow_is_reported", function()
    local input = fixture()
    input.log_likelihood = {0, -1000}
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.linear_output_underflow_count == 1)
    assert(result.value.log_posterior[2] > NI)
    assert(result.value.posterior[2] == 0)
end)

test("missing_and_unknown_members_are_distinct", function()
    local input = fixture()
    input.likelihood_kind = nil
    local result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_MISSING_MEMBER")

    input = fixture()
    input.synthetic_extra = true
    result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_UNKNOWN_MEMBER")
end)

test("dimension_mismatch_is_explicit", function()
    local input = fixture()
    input.log_likelihood = {0}
    local result = M.evaluate(input)
    assert(not result.ok)
    assert(result.error.code == "E_DIMENSION_MISMATCH")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
