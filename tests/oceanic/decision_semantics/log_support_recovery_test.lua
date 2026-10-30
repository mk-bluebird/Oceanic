-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.decision_semantics.log_support_recovery")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local NI = -math.huge
local total, failures = 0, 0

local function test(name, fn)
    total = total + 1
    local passed, detail = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then
        failures = failures + 1
        local message = type(detail) == "string"
            and detail or "non_string_failure"
        message = message:gsub("[%z\1-\31\127]", " "):sub(1, 300)
        io.write("DETAIL\t", name, "\t", message, "\n")
    end
end

local function evaluate(original, restored, threshold)
    return M.evaluate({
        log_original = original,
        log_restored = restored,
        log_mass_threshold = threshold
    })
end

test("same_support_does_not_require_same_distribution", function()
    local result = evaluate(
        {math.log(0.5), math.log(0.5)},
        {math.log(0.9), math.log(0.1)},
        NI)
    assert(result.ok)
    assert(result.value.exact_support_inclusion)
    assert(result.value.outside_mass == 0)
    assert(not result.value.agm_recovery_established)
end)

test("threshold_pass_is_not_exact_recovery", function()
    local result = evaluate(
        {0, NI},
        {math.log(0.99), math.log(0.01)},
        math.log(0.02))
    assert(result.ok)
    assert(not result.value.exact_support_inclusion)
    assert(result.value.outside_mass_within_declared_threshold)
    assert(math.abs(result.value.outside_mass - 0.01) <= 1e-12)
end)

test("zero_threshold_rejects_positive_outside_mass", function()
    local result = evaluate(
        {0, NI},
        {math.log(0.99), math.log(0.01)},
        NI)
    assert(result.ok)
    assert(not result.value.outside_mass_within_declared_threshold)
end)

test("tiny_positive_support_is_retained_in_log_form", function()
    local result = evaluate({0, NI}, {0, -1000}, -900)
    assert(result.ok)
    assert(not result.value.exact_support_inclusion)
    assert(result.value.log_outside_mass == -1000)
    assert(result.value.linear_mass_underflow)
    assert(result.value.outside_mass_within_declared_threshold)
end)

test("empty_restored_support_is_rejected", function()
    local result = evaluate({0, NI}, {NI, NI}, NI)
    assert(not result.ok)
    assert(result.error.code == "E_EMPTY_DISTRIBUTION_SUPPORT")
end)

test("world_array_size_mismatch_is_explicit", function()
    local result = evaluate({0}, {0, NI}, NI)
    assert(not result.ok)
    assert(result.error.code == "E_WORLD_UNIVERSE_SIZE_MISMATCH")
end)

test("invalid_normalization_is_not_silently_repaired", function()
    local result = evaluate({0, 0}, {0, NI}, NI)
    assert(not result.ok)
    assert(result.error.code == "E_DISTRIBUTION_NORMALIZATION")
end)

test("unknown_input_key_is_not_echoed", function()
    local marker = "SYNTHETIC_PRIVATE_MARKER_5924"
    local input = {
        log_original = {0},
        log_restored = {0},
        log_mass_threshold = NI
    }
    input[marker] = true

    local result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_UNKNOWN_MEMBER")

    local function scan(value)
        if type(value) == "string" then
            assert(not value:find(marker, 1, true))
        elseif type(value) == "table" then
            for key, item in pairs(value) do
                scan(key)
                scan(item)
            end
        end
    end

    scan(result)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
