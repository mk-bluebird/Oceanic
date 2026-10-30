-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Synthetic fixtures only.

local M = require("lua.oceanic.epistemic_semantics.declaration_compatibility")
local failures, total = 0, 0

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not equal(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function fixture()
    return {
        target = {
            role = "field_content",
            kind = "proposition",
            label = "Synthetic recruitment hypothesis"
        },
        availability = {
            tag = "supplied",
            text = "Recruitment may be limited."
        },
        collection = {tag = "not_collected"},
        knowledge = {tag = "unknown", basis = "unspecified"},
        applicability = {tag = "unresolved"},
        permission = {
            tag = "undetermined",
            operation = "analysis",
            purpose = "Synthetic compatibility test"
        }
    }
end

local function evaluate(records)
    return M.evaluate({schema_version = 1, records = records})
end

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

test("supplied_proposition_without_measurements_is_coherent", function()
    local result = evaluate({fixture()})
    assert(result.ok)
    assert(result.value.outcome == "no_declared_conflict")
end)

test("supplied_measurement_not_collected_conflicts", function()
    local item = fixture()
    item.target.kind = "measured_record"
    local result = evaluate({item})
    assert(result.ok)
    assert(result.value.conflicts[1].code
        == "C_SUPPLIED_MEASUREMENT_NOT_COLLECTED")
end)

test("different_targets_preserve_scope", function()
    local proposition = fixture()
    local evidence = fixture()
    evidence.target.role = "supporting_evidence"
    evidence.target.kind = "measured_record"
    evidence.target.label = "Synthetic recruitment counts"
    evidence.availability = {tag = "unspecified"}
    local result = evaluate({proposition, evidence})
    assert(result.ok and #result.value.conflicts == 0)
end)

test("higher_order_measurement_basis_conflicts", function()
    local item = fixture()
    item.knowledge = {
        tag = "known",
        basis = "same_target_measurement"
    }
    local result = evaluate({item})
    assert(result.ok)
    assert(result.value.conflicts[1].code
        == "C_KNOWN_FROM_UNCOLLECTED_TARGET")
end)

test("inference_basis_does_not_require_target_collection", function()
    local item = fixture()
    item.knowledge = {tag = "known", basis = "inference"}
    local result = evaluate({item})
    assert(result.ok and #result.value.conflicts == 0)
end)

test("withheld_has_no_required_reason", function()
    local item = fixture()
    item.availability = {tag = "withheld"}
    local result = evaluate({item})
    assert(result.ok and #result.value.conflicts == 0)
end)

test("withheld_payload_is_rejected", function()
    local item = fixture()
    item.availability = {tag = "withheld", text = "Synthetic content"}
    local result = evaluate({item})
    assert(not result.ok)
    assert(result.error.code == "E_UNEXPECTED_CONTENT")
end)

test("same_target_collection_conflict_is_detected", function()
    local left, right = fixture(), fixture()
    right.collection = {tag = "collected"}
    local result = evaluate({left, right})
    assert(result.ok)
    assert(result.value.conflicts[1].code
        == "C_COLLECTION_DECLARATIONS_CONFLICT")
end)

test("permission_does_not_authorize_action", function()
    local item = fixture()
    item.permission.tag = "permitted"
    local result = evaluate({item})
    assert(result.ok)
    assert(not result.value.permission_declarations[1]
        .action_authorized_here)
end)

test("input_is_preserved_and_output_is_detached", function()
    local input = {schema_version = 1, records = {fixture()}}
    local before = clone(input)
    local result = M.evaluate(input)
    assert(result.ok and equal(input, before))
    result.value.records[1].target.label = "Changed output"
    assert(equal(input, before))
end)

test("empty_frame_does_not_establish_completeness", function()
    local result = evaluate({})
    assert(result.ok and result.value.record_count == 0)
    assert(not result.value.interpretation_limits.completeness_established)
end)

test("availability_collection_matrix_has_expected_conflicts", function()
    local availability = {"supplied", "withheld", "unspecified"}
    local collection = {
        "collected", "not_collected", "unknown", "unspecified"
    }
    local cases, conflicts = 0, 0
    for _, available in ipairs(availability) do
        for _, collected in ipairs(collection) do
            local item = fixture()
            item.target.kind = "measured_record"
            item.availability = {tag = available}
            if available == "supplied" then
                item.availability.text = "Synthetic measured record"
            end
            item.collection = {tag = collected}
            local result = evaluate({item})
            assert(result.ok)
            cases = cases + 1
            if #result.value.conflicts > 0 then
                conflicts = conflicts + 1
            end
        end
    end
    assert(cases == 12 and conflicts == 1)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
