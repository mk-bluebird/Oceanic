-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.epistemic_semantics.diagnostic_partition_intents")

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

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if rawget(a, key) == nil then return false end
    end
    return true
end

local function member(items, expected)
    for _, item in ipairs(items) do
        if item == expected then return true end
    end
    return false
end

local function inspect_no_marker(value, marker)
    if type(value) == "string" then
        assert(not value:find(marker, 1, true))
    elseif type(value) == "table" then
        for key, item in pairs(value) do
            inspect_no_marker(key, marker)
            inspect_no_marker(item, marker)
        end
    end
end

test("paired_unknown_keys_have_identical_envelopes", function()
    local function rejected(marker)
        return M.partition({
            required_fields = {"subject"},
            states = {[marker] = "supplied"}
        })
    end

    local a = rejected("SYNTHETIC_PRIVATE_KEY_A_7821")
    local b = rejected("SYNTHETIC_PRIVATE_KEY_B_9134")
    assert(not a.ok and not b.ok)
    assert(equal(a, b))
    assert(a.error.path == "input.states")
    assert(next(a.error.args) == nil)
    inspect_no_marker(a, "SYNTHETIC_PRIVATE_KEY_A_7821")
    inspect_no_marker(b, "SYNTHETIC_PRIVATE_KEY_B_9134")
end)

test("diagnostic_location_is_registered", function()
    local a = M.unknown_field_error("declaration")
    assert(not a.ok)
    assert(a.error.path == "input.frame.declaration")

    local b = M.unknown_field_error("SYNTHETIC_UNREGISTERED_PATH")
    assert(not b.ok and b.error.code == "E_DIAGNOSTIC_LOCATION")
    assert(b.error.path == "input")
end)

test("declared_partition_reconciles_additional_fields", function()
    local result = M.partition({
        required_fields = {"subject", "response"},
        states = {
            subject = "declared_not_applicable",
            evidence_basis = "unknown"
        }
    })
    assert(result.ok)
    local v = result.value
    assert(v.required_count == 2)
    assert(v.required_declared_count == 1)
    assert(v.recognized_declared_count == 2)
    assert(v.required_partition.declared_not_applicable[1] == "subject")
    assert(v.required_partition.absent[1] == "response")
    assert(v.additional_declared_fields[1] == "evidence_basis")
    assert(#v.declared_partition.absent == 0)
end)

test("all_two_field_state_combinations_partition_correctly", function()
    local states = {
        "supplied", "unknown", "not_collected",
        "withheld", "declared_not_applicable", "absent"
    }
    local cases = 0

    for _, left in ipairs(states) do
        for _, right in ipairs(states) do
            local result = M.partition({
                required_fields = {"subject", "response"},
                states = {subject = left, response = right}
            })
            assert(result.ok)
            local v = result.value
            local seen, count = {}, 0

            for _, category in ipairs(states) do
                for _, field in ipairs(v.required_partition[category]) do
                    assert(not seen[field])
                    seen[field] = true
                    count = count + 1
                end
            end

            assert(count == 2 and seen.subject and seen.response)
            local expected = (left ~= "absent" and 1 or 0)
                + (right ~= "absent" and 1 or 0)
            assert(v.required_declared_count == expected)
            assert(v.recognized_declared_count == expected)
            cases = cases + 1
        end
    end

    assert(cases == 36)
end)

test("composite_order_is_invariant", function()
    local a = M.compose({"forecast", "compare"})
    local b = M.compose({"compare", "forecast"})
    assert(a.ok and b.ok and equal(a.value, b.value))
end)

test("duplicate_parser_input_is_rejected", function()
    local result = M.compose({"compare", "compare"})
    assert(not result.ok)
    assert(result.error.code == "E_INTENT_DUPLICATE")
end)

test("composite_requirement_is_not_atomic_union", function()
    local a = M.compose({"compare"})
    local b = M.compose({"forecast"})
    local combined = M.compose({"compare", "forecast"})
    assert(a.ok and b.ok and combined.ok)

    assert(not member(a.value.required_fields, "forecast_alignment"))
    assert(not member(b.value.required_fields, "forecast_alignment"))
    assert(member(combined.value.required_fields, "forecast_alignment"))

    local rule = combined.value.interaction_records[1]
    assert(rule.rule_code == "R_COMPARE_FORECAST_ALIGNMENT")
    assert(rule.satisfaction == "not_assessed")
end)

test("atomic_union_can_leave_composite_gap", function()
    local a = M.compose({"compare"}).value
    local b = M.compose({"forecast"}).value
    local combined = M.compose({"compare", "forecast"}).value
    local states = {}

    for _, field in ipairs(a.required_fields) do states[field] = "supplied" end
    for _, field in ipairs(b.required_fields) do states[field] = "supplied" end

    local result = M.partition({
        required_fields = combined.required_fields,
        states = states
    })
    assert(result.ok)
    assert(result.value.required_partition.absent[1] == "forecast_alignment")
end)

test("empty_denominator_is_undefined", function()
    local result = M.partition({required_fields = {}, states = {}})
    assert(result.ok)
    assert(result.value.ratios.status == "undefined")
    assert(result.value.ratios.declaration == nil)
end)

test("registry_outputs_are_detached", function()
    local first = M.describe()
    first.value.registered_fields[1] = "changed"
    assert(M.describe().value.registered_fields[1] == "subject")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
