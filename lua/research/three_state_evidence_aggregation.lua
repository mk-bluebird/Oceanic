-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; no verification, consent, or authorization.
--
-- Lua 5.4 standard library.
-- aggregate(states, operation)
-- states: plain contiguous sequence containing:
--   "equivalent", "unresolved", "mismatch"
-- operation: "all" or "any"
--
-- "all" is strong Kleene conjunction.
-- "any" is strong Kleene disjunction.
-- Empty inputs return not_applicable, not a vacuous pass.
-- No files, networking, storage, or actuation.

local M = {}
local VERSION = "1.0.0"
local rank = {mismatch = 1, unresolved = 2, equivalent = 3}

local function envelope(ok, value, code, path)
    return {
        ok = ok,
        schema_version = VERSION,
        module_version = VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            path = path or "",
            message_key = code or ""
        }
    }
end

local function fail(code, path)
    return envelope(false, false, code, path)
end

local function aggregate_impl(states, operation)
    if operation ~= "all" and operation ~= "any" then
        return fail("E_OPERATION", "operation")
    end
    if type(states) ~= "table" or getmetatable(states) ~= nil then
        return fail("E_SEQUENCE", "states")
    end

    local count = 0
    for key in next, states do
        if type(key) ~= "number" or key ~= key
            or key < 1 or key > 100000 or key % 1 ~= 0 then
            return fail("E_SEQUENCE", "states")
        end
        count = count + 1
    end

    local profile = {}
    local counts = {equivalent = 0, unresolved = 0, mismatch = 0}
    local aggregate_rank = operation == "all" and 3 or 1

    for position = 1, count do
        local value = rawget(states, position)
        if type(value) ~= "string" or rank[value] == nil then
            return fail("E_STATE", "states")
        end
        profile[position] = value
        counts[value] = counts[value] + 1

        if operation == "all" then
            aggregate_rank = math.min(aggregate_rank, rank[value])
        else
            aggregate_rank = math.max(aggregate_rank, rank[value])
        end
    end

    local result = "not_applicable"
    if count > 0 then
        local names = {"mismatch", "unresolved", "equivalent"}
        result = names[aggregate_rank]
    end

    return envelope(true, {
        status = "logical_aggregation_only",
        operation = operation,
        semantics = "strong_kleene_truth_order",
        aggregate_state = result,
        profile = profile,
        counts = counts,
        input_count = count,
        statistical_error_control_verified = false,
        ecological_equivalence_established = false,
        management_interchangeability_established = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
    })
end

function M.aggregate(states, operation)
    local ok, result = pcall(aggregate_impl, states, operation)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end

function M.self_test()
    local names = {"mismatch", "unresolved", "equivalent"}
    local tested_profiles = 0

    for length = 1, 3 do
        for encoded = 0, 3^length - 1 do
            local states = {}
            local value = encoded
            local has_mismatch = false
            local has_unresolved = false
            local has_equivalent = false

            for j = 1, length do
                local position = value % 3 + 1
                value = math.floor(value / 3)
                states[j] = names[position]
                has_mismatch = has_mismatch or position == 1
                has_unresolved = has_unresolved or position == 2
                has_equivalent = has_equivalent or position == 3
            end

            local expected_all = has_mismatch and "mismatch"
                or (has_unresolved and "unresolved" or "equivalent")
            local expected_any = has_equivalent and "equivalent"
                or (has_unresolved and "unresolved" or "mismatch")

            local a = M.aggregate(states, "all")
            local b = M.aggregate(states, "any")

            if not a.ok or not b.ok
                or a.value.aggregate_state ~= expected_all
                or b.value.aggregate_state ~= expected_any then
                return fail("E_SELF_TEST", "truth_tables")
            end

            local reversed = {}
            for j = 1, length do
                reversed[j] = states[length-j+1]
            end
            local permutation = M.aggregate(reversed, "all")
            if not permutation.ok
                or permutation.value.aggregate_state ~= expected_all then
                return fail("E_SELF_TEST", "permutation")
            end

            a.value.profile[1] = "modified_output"
            if states[1] == "modified_output" then
                return fail("E_SELF_TEST", "output_aliasing")
            end

            tested_profiles = tested_profiles + 1
        end
    end

    local empty = M.aggregate({}, "all")
    if not empty.ok
        or empty.value.aggregate_state ~= "not_applicable" then
        return fail("E_SELF_TEST", "empty_not_pass")
    end

    local invalid = M.aggregate({"other"}, "all")
    if invalid.ok or invalid.error.code ~= "E_STATE" then
        return fail("E_SELF_TEST", "invalid_state")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        enumerated_profiles = tested_profiles,
        expected_profile_count = 39,
        field_validation = "not_performed",
        statistical_simulation_performed = false
    })
end

return M
