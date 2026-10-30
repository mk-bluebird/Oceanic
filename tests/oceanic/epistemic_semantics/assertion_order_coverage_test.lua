-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.epistemic_semantics.assertion_order_coverage")

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

local function assertion(property, value, source)
    return {
        scope = "Synthetic reach / declared season",
        property = property,
        value = value,
        source = source or "Synthetic participant declaration"
    }
end

local function frame(...)
    return {assertions = {...}}
end

local function relation(left, right)
    local result = M.compare(left, right)
    assert(result.ok)
    return result.value.relation
end

local function coverage(fields, states)
    return M.coverage({
        field_set_version = "synthetic-1",
        intent_interpretation = "synthetic description",
        denominator_scope = "registered_required_fields",
        required_fields = fields,
        states = states
    })
end

test("ordering_and_duplicates_are_equivalent", function()
    local a = assertion("collection", "not_collected")
    local b = assertion("knowledge", "unknown")
    assert(relation(frame(a, b), frame(b, a, a))
        == "equivalent_assertion_sets")
end)

test("compatible_addition_is_not_merit", function()
    local a = assertion("collection", "not_collected")
    local b = assertion("knowledge", "unknown")
    local result = M.compare(frame(a), frame(a, b))
    assert(result.ok)
    assert(result.value.relation == "right_extends_left")
    assert(not result.value.scientific_merit_assessed)
end)

test("conflicting_addition_blocks_comparison", function()
    local a = assertion("collection", "not_collected")
    local b = assertion("collection", "collected")
    assert(relation(frame(a), frame(a, b))
        == "blocked_by_declared_conflict")
end)

test("different_scopes_do_not_conflict", function()
    local a = assertion("collection", "not_collected")
    local b = assertion("collection", "collected")
    b.scope = "Synthetic reach / another season"
    assert(relation(frame(a), frame(a, b)) == "right_extends_left")
end)

test("provenance_change_is_not_serialization_equivalence", function()
    local a = assertion("knowledge", "unknown", "Synthetic source A")
    local b = assertion("knowledge", "unknown", "Synthetic source B")
    assert(relation(frame(a), frame(b)) == "incomparable")
end)

test("finite_subset_order_laws", function()
    local a = assertion("collection", "not_collected")
    local b = assertion("knowledge", "unknown")
    local c = assertion("availability", "withheld")
    local frames = {
        frame(), frame(a), frame(a, b), frame(a, b, c)
    }

    local function le(left, right)
        local r = relation(left, right)
        return r == "equivalent_assertion_sets"
            or r == "right_extends_left"
    end

    for _, x in ipairs(frames) do
        assert(le(x, x))
        for _, y in ipairs(frames) do
            if le(x, y) and le(y, x) then
                assert(relation(x, y) == "equivalent_assertion_sets")
            end
            for _, z in ipairs(frames) do
                if le(x, y) and le(y, z) then assert(le(x, z)) end
            end
        end
    end
end)

test("coverage_retains_declared_non_applicability", function()
    local result = coverage({"a", "b", "c"}, {
        a = "supplied",
        b = "declared_not_applicable"
    })
    assert(result.ok)
    local value = result.value
    assert(value.required_count == 3)
    assert(value.declared_count == 2)
    assert(value.supplied_count == 1)
    assert(value.counts.declared_not_applicable == 1)
    assert(math.abs(value.ratios.declaration - 2 / 3) <= 1e-12)
end)

test("zero_denominator_is_explicitly_undefined", function()
    local result = coverage({}, {})
    assert(result.ok)
    assert(result.value.ratios.status == "undefined")
    assert(result.value.ratios.declaration == nil)
    assert(result.value.ratios.supplied == nil)
end)

test("new_absent_requirement_changes_denominator", function()
    local a = coverage({"a"}, {a = "supplied"})
    local b = coverage({"a", "b"}, {a = "supplied"})
    assert(a.ok and b.ok)
    assert(a.value.ratios.supplied == 1)
    assert(b.value.ratios.supplied == 0.5)
end)

test("unknown_state_field_is_not_ignored", function()
    local result = coverage({"a"}, {b = "supplied"})
    assert(not result.ok)
    assert(result.error.code == "E_UNKNOWN_FIELD")
end)

test("applicable_denominator_requires_review_reference", function()
    local result = M.coverage({
        field_set_version = "synthetic-1",
        intent_interpretation = "synthetic description",
        denominator_scope = "reviewed_applicable_required_fields",
        required_fields = {},
        states = {}
    })
    assert(not result.ok)
    assert(result.error.code == "E_REVIEW_REFERENCE")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
