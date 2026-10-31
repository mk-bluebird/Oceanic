-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
-- Lua 5.4. Local declaration screening; no I/O, networking, or actuation.

local M = {}

local SCHEMA_VERSION = "0.1.0"
local MODULE_VERSION = "0.2.0"
local ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local LIMITS = {
    case_text_bytes = 4096,
    component_text_bytes = 2048,
    component_count = 128
}

local CASE_FIELDS = {
    "case_name",
    "family",
    "scenario_status",
    "slice",
    "evaluation_use",
    "tested_property",
    "expectation_basis",
    "non_conclusions",
    "components"
}

local CASE_TEXT_FIELDS = {
    "case_name",
    "tested_property",
    "expectation_basis",
    "non_conclusions"
}

local COMPONENT_FIELDS = {
    "description",
    "origin",
    "basis",
    "verification_status"
}

local FAMILIES = {
    anchored_development = true,
    cross_context_stress = true
}

local SLICES = {
    A = true,
    B = true,
    C = true
}

local EVALUATION_USES = {
    development = true,
    evaluation_candidate = true
}

local ORIGINS = {
    source_reported = true,
    invented = true,
    derived = true
}

local VERIFICATION_STATES = {
    not_verified = true,
    reviewed_declaration = true
}

local function field_set(fields)
    local result = {}
    for _, field in ipairs(fields) do
        result[field] = true
    end
    return result
end

local CASE_FIELD_SET = field_set(CASE_FIELDS)
local COMPONENT_FIELD_SET = field_set(COMPONENT_FIELDS)

local function envelope(ok, value, code, path, args)
    return {
        ok = ok,
        schema_version = SCHEMA_VERSION,
        module_version = MODULE_VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            path = path or "",
            message_key = code or "",
            args = args or {}
        }
    }
end

local function fail(code, path, args)
    return envelope(false, false, code, path, args)
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function child_path(parent, field)
    if parent == "" then
        return field
    end
    return parent .. "." .. field
end

local function exact_fields(value, fields, allowed, path)
    if not plain(value) then
        return false, path, "plain_table_required"
    end

    for _, field in ipairs(fields) do
        if rawget(value, field) == nil then
            return false, child_path(path, field), "missing_field"
        end
    end

    for key in next, value do
        if not allowed[key] then
            return false, path, "unexpected_field"
        end
    end

    return true
end

local function valid_text(value, limit)
    if type(value) ~= "string" then
        return false, "string_required"
    end
    if #value == 0 then
        return false, "empty_text"
    end
    if #value > limit then
        return false, "byte_limit_exceeded"
    end
    if value:find("[%z\1-\31\127]") then
        return false, "control_character"
    end
    if utf8.len(value) == nil then
        return false, "invalid_utf8"
    end
    if not value:find("%S") then
        return false, "blank_text"
    end
    return true
end

local function enum_member(value, allowed)
    return type(value) == "string" and allowed[value] == true
end

local function sequence_length(value)
    if not plain(value) then
        return nil, "plain_sequence_required"
    end

    local count = 0
    for key in next, value do
        if type(key) ~= "number"
            or key ~= key
            or key < 1
            or key > LIMITS.component_count
            or key % 1 ~= 0 then
            return nil, "invalid_sequence_key"
        end
        count = count + 1
    end

    if count == 0 then
        return nil, "empty_sequence"
    end

    for position = 1, count do
        if rawget(value, position) == nil then
            return nil, "sequence_gap"
        end
    end

    return count
end

local function interpretation_limits()
    return {
        {
            code = "R_PROVENANCE_DECLARED",
            message = "Declaration completeness is checked, not accuracy."
        },
        {
            code = "R_REVIEW_AUTHENTICITY",
            message = "reviewed_declaration does not authenticate a review."
        },
        {
            code = "R_HELDOUT",
            message = "Evaluation status does not establish held-out integrity."
        },
        {
            code = "R_SYNTHETIC",
            message = "Synthetic status does not imply non-sensitivity."
        },
        {
            code = "R_EXPECTATION",
            message = "An expectation basis is recorded, not scientifically validated."
        },
        {
            code = "R_PERMISSION",
            message = "No storage, indexing, synchronization, or publication is authorized."
        }
    }
end

local function screen_impl(case)
    local accepted, path, reason = exact_fields(
        case, CASE_FIELDS, CASE_FIELD_SET, ""
    )
    if not accepted then
        return fail("E_CASE_FIELDS", path == "" and "case" or path, {
            reason = reason
        })
    end

    for _, field in ipairs(CASE_TEXT_FIELDS) do
        local valid, text_reason = valid_text(
            rawget(case, field), LIMITS.case_text_bytes
        )
        if not valid then
            return fail("E_TEXT", field, {
                reason = text_reason,
                max_bytes = LIMITS.case_text_bytes
            })
        end
    end

    if not enum_member(case.family, FAMILIES) then
        return fail("E_FAMILY", "family")
    end
    if case.scenario_status ~= "synthetic" then
        return fail("E_SYNTHETIC_STATUS", "scenario_status")
    end
    if not enum_member(case.slice, SLICES) then
        return fail("E_SLICE", "slice")
    end
    if not enum_member(case.evaluation_use, EVALUATION_USES) then
        return fail("E_EVALUATION_USE", "evaluation_use")
    end

    local count, sequence_reason = sequence_length(case.components)
    if not count then
        return fail("E_COMPONENTS", "components", {
            reason = sequence_reason,
            max_components = LIMITS.component_count
        })
    end

    local origin_counts = {
        source_reported = 0,
        invented = 0,
        derived = 0
    }
    local verification_counts = {
        not_verified = 0,
        reviewed_declaration = 0
    }

    for position = 1, count do
        local component = rawget(case.components, position)
        local component_path = "components[" .. position .. "]"

        accepted, path, reason = exact_fields(
            component,
            COMPONENT_FIELDS,
            COMPONENT_FIELD_SET,
            component_path
        )
        if not accepted then
            return fail("E_COMPONENT_FIELDS", path, {
                reason = reason
            })
        end

        for _, field in ipairs({"description", "basis"}) do
            local valid, text_reason = valid_text(
                rawget(component, field), LIMITS.component_text_bytes
            )
            if not valid then
                return fail(
                    "E_COMPONENT_TEXT",
                    child_path(component_path, field),
                    {
                        reason = text_reason,
                        max_bytes = LIMITS.component_text_bytes
                    }
                )
            end
        end

        if not enum_member(component.origin, ORIGINS) then
            return fail(
                "E_ORIGIN",
                child_path(component_path, "origin")
            )
        end

        if not enum_member(
            component.verification_status, VERIFICATION_STATES
        ) then
            return fail(
                "E_VERIFICATION",
                child_path(component_path, "verification_status")
            )
        end

        origin_counts[component.origin] =
            origin_counts[component.origin] + 1

        verification_counts[component.verification_status] =
            verification_counts[component.verification_status] + 1
    end

    return envelope(true, {
        status = "provenance_declarations_present",
        case_name = case.case_name,
        family_declared = case.family,
        scenario_status_declared = case.scenario_status,
        slice_declared = case.slice,
        evaluation_use_declared = case.evaluation_use,
        component_count = count,
        component_origin_counts = origin_counts,
        component_verification_declaration_counts = verification_counts,
        input_provenance = "caller_supplied_not_verified",
        source_accuracy_verified = false,
        expectation_correctness_verified = false,
        review_authenticity_verified = false,
        heldout_status_verified = false,
        ecological_validity_established = false,
        storage_authorized = false,
        indexing_authorized = false,
        synchronization_authorized = false,
        publication_authorized = false,
        external_actions = "none",
        attribution = ATTRIBUTION,
        interpretation_limits = interpretation_limits()
    })
end

local function protected_call(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        return fail("E_INTERNAL", "", {
            reason = "unexpected_internal_failure"
        })
    end
    return result
end

function M.screen(case)
    return protected_call(screen_impl, case)
end

function M.contract()
    local required_case_fields = {}
    local required_component_fields = {}

    for position, field in ipairs(CASE_FIELDS) do
        required_case_fields[position] = field
    end
    for position, field in ipairs(COMPONENT_FIELDS) do
        required_component_fields[position] = field
    end

    return envelope(true, {
        runtime = "Lua 5.4",
        required_case_fields = required_case_fields,
        required_component_fields = required_component_fields,
        families = {
            "anchored_development",
            "cross_context_stress"
        },
        scenario_status = {"synthetic"},
        slices = {"A", "B", "C"},
        evaluation_uses = {
            "development",
            "evaluation_candidate"
        },
        origins = {
            "source_reported",
            "invented",
            "derived"
        },
        verification_states = {
            "not_verified",
            "reviewed_declaration"
        },
        limits = {
            case_text_bytes = LIMITS.case_text_bytes,
            component_text_bytes = LIMITS.component_text_bytes,
            component_count = LIMITS.component_count
        },
        text_policy = {
            encoding = "UTF-8",
            length_unit = "bytes",
            control_policy = "reject_C0_and_DEL",
            whitespace_policy = "reject_ASCII_whitespace_only",
            unicode_normalization_performed = false
        },
        success_discriminator = "ok",
        failure_value_sentinel = false,
        missing_values_substituted = false,
        external_actions = "none",
        attribution = ATTRIBUTION
    })
end

local function fixture()
    return {
        case_name = "Synthetic hazard-summary mutation",
        family = "anchored_development",
        scenario_status = "synthetic",
        slice = "B",
        evaluation_use = "development",
        tested_property = "Effect-measure declaration drift",
        expectation_basis =
            "Contract: one changed structured field must be flagged.",
        non_conclusions =
            "No source verification or ecological validation is established.",
        components = {
            {
                description = "Source hazard-ratio wording",
                origin = "source_reported",
                basis = "Supplied conversation; original passage not checked.",
                verification_status = "not_verified"
            },
            {
                description = "Invented risk-ratio substitution",
                origin = "invented",
                basis = "Deliberate synthetic mutation.",
                verification_status = "not_verified"
            }
        }
    }
end

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copied = {}
    for key, item in next, value do
        copied[key] = deep_copy(item)
    end
    return copied
end

local function deep_equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in next, a do
        if not deep_equal(value, rawget(b, key)) then
            return false
        end
    end
    for key in next, b do
        if rawget(a, key) == nil then
            return false
        end
    end
    return true
end

local function self_test_impl()
    local test_count = 0

    local function check(condition, name)
        if not condition then
            return fail("E_SELF_TEST", name, {
                test_name = name
            })
        end
        test_count = test_count + 1
        return nil
    end

    local input = fixture()
    local before = deep_copy(input)
    local first = M.screen(input)

    local failure = check(
        first.ok
            and first.value.component_count == 2
            and first.value.component_origin_counts.source_reported == 1
            and first.value.component_origin_counts.invented == 1,
        "baseline"
    )
    if failure then return failure end

    failure = check(deep_equal(input, before), "success_nonmutation")
    if failure then return failure end

    failure = check(
        deep_equal(first, M.screen(input)),
        "complete_envelope_determinism"
    )
    if failure then return failure end

    first.value.component_origin_counts.invented = 99
    first.value.interpretation_limits[1].code = "MODIFIED"
    local fresh = M.screen(input)

    failure = check(
        fresh.ok
            and fresh.value.component_origin_counts.invented == 1
            and fresh.value.interpretation_limits[1].code
                == "R_PROVENANCE_DECLARED",
        "output_isolation"
    )
    if failure then return failure end

    local tests = {
        {
            name = "missing_case_field",
            mutate = function(c) c.expectation_basis = nil end,
            code = "E_CASE_FIELDS",
            path = "expectation_basis"
        },
        {
            name = "unexpected_case_field",
            mutate = function(c) c.extra = true end,
            code = "E_CASE_FIELDS",
            path = "case"
        },
        {
            name = "case_text_type",
            mutate = function(c) c.case_name = 1 end,
            code = "E_TEXT",
            path = "case_name"
        },
        {
            name = "blank_text",
            mutate = function(c) c.case_name = "   " end,
            code = "E_TEXT",
            path = "case_name"
        },
        {
            name = "control_character",
            mutate = function(c) c.case_name = "bad\ntext" end,
            code = "E_TEXT",
            path = "case_name"
        },
        {
            name = "invalid_utf8",
            mutate = function(c) c.case_name = string.char(255) end,
            code = "E_TEXT",
            path = "case_name"
        },
        {
            name = "case_text_limit",
            mutate = function(c)
                c.case_name = string.rep("x", LIMITS.case_text_bytes + 1)
            end,
            code = "E_TEXT",
            path = "case_name"
        },
        {
            name = "family",
            mutate = function(c) c.family = "other" end,
            code = "E_FAMILY",
            path = "family"
        },
        {
            name = "synthetic_status",
            mutate = function(c) c.scenario_status = "observed" end,
            code = "E_SYNTHETIC_STATUS",
            path = "scenario_status"
        },
        {
            name = "slice",
            mutate = function(c) c.slice = "D" end,
            code = "E_SLICE",
            path = "slice"
        },
        {
            name = "evaluation_use",
            mutate = function(c) c.evaluation_use = "held_out_verified" end,
            code = "E_EVALUATION_USE",
            path = "evaluation_use"
        },
        {
            name = "empty_components",
            mutate = function(c) c.components = {} end,
            code = "E_COMPONENTS",
            path = "components"
        },
        {
            name = "sequence_gap",
            mutate = function(c)
                c.components[3] = c.components[2]
                c.components[2] = nil
            end,
            code = "E_COMPONENTS",
            path = "components"
        },
        {
            name = "sequence_key_type",
            mutate = function(c) c.components.extra = true end,
            code = "E_COMPONENTS",
            path = "components"
        },
        {
            name = "missing_component_basis",
            mutate = function(c) c.components[1].basis = nil end,
            code = "E_COMPONENT_FIELDS",
            path = "components[1].basis"
        },
        {
            name = "unexpected_component_field",
            mutate = function(c) c.components[1].extra = true end,
            code = "E_COMPONENT_FIELDS",
            path = "components[1]"
        },
        {
            name = "component_text",
            mutate = function(c) c.components[1].description = "" end,
            code = "E_COMPONENT_TEXT",
            path = "components[1].description"
        },
        {
            name = "component_origin",
            mutate = function(c) c.components[1].origin = "observed" end,
            code = "E_ORIGIN",
            path = "components[1].origin"
        },
        {
            name = "review_state",
            mutate = function(c)
                c.components[1].verification_status = "verified"
            end,
            code = "E_VERIFICATION",
            path = "components[1].verification_status"
        }
    }

    for _, test in ipairs(tests) do
        local candidate = fixture()
        test.mutate(candidate)
        local snapshot = deep_copy(candidate)
        local result = M.screen(candidate)

        failure = check(
            not result.ok
                and result.value == false
                and result.error.present
                and result.error.code == test.code
                and result.error.path == test.path,
            test.name
        )
        if failure then return failure end

        failure = check(
            deep_equal(candidate, snapshot),
            test.name .. "_nonmutation"
        )
        if failure then return failure end
    end

    local metatable_case = setmetatable(fixture(), {})
    local metatable_result = M.screen(metatable_case)

    failure = check(
        not metatable_result.ok
            and metatable_result.error.code == "E_CASE_FIELDS",
        "case_metatable_rejected"
    )
    if failure then return failure end

    local nested_metatable = fixture()
    setmetatable(nested_metatable.components[1], {})
    local nested_result = M.screen(nested_metatable)

    failure = check(
        not nested_result.ok
            and nested_result.error.code == "E_COMPONENT_FIELDS"
            and nested_result.error.path == "components[1]",
        "component_metatable_rejected"
    )
    if failure then return failure end

    local boundary = fixture()
    boundary.case_name = string.rep("x", LIMITS.case_text_bytes)
    local boundary_result = M.screen(boundary)

    failure = check(boundary_result.ok, "inclusive_text_limit")
    if failure then return failure end

    local maximum = fixture()
    maximum.components = {}
    for position = 1, LIMITS.component_count do
        maximum.components[position] = {
            description = "Synthetic derived component",
            origin = "derived",
            basis = "Synthetic derivation declaration.",
            verification_status = "not_verified"
        }
    end

    local maximum_result = M.screen(maximum)
    failure = check(
        maximum_result.ok
            and maximum_result.value.component_count == LIMITS.component_count
            and maximum_result.value.component_origin_counts.derived
                == LIMITS.component_count,
        "maximum_component_count"
    )
    if failure then return failure end

    maximum.components[LIMITS.component_count + 1] = {
        description = "Excess component",
        origin = "invented",
        basis = "Synthetic boundary test.",
        verification_status = "not_verified"
    }
    local excess = M.screen(maximum)

    failure = check(
        not excess.ok and excess.error.code == "E_COMPONENTS",
        "excess_component_count"
    )
    if failure then return failure end

    local reviewed = fixture()
    reviewed.family = "cross_context_stress"
    reviewed.slice = "A"
    reviewed.evaluation_use = "evaluation_candidate"
    reviewed.components[1].verification_status = "reviewed_declaration"
    local reviewed_result = M.screen(reviewed)

    failure = check(
        reviewed_result.ok
            and reviewed_result.value
                .component_verification_declaration_counts.reviewed_declaration == 1
            and not reviewed_result.value.review_authenticity_verified
            and not reviewed_result.value.heldout_status_verified
            and not reviewed_result.value.publication_authorized,
        "declarations_do_not_grant_verification_or_authority"
    )
    if failure then return failure end

    local internal = protected_call(function()
        error("Synthetic internal failure.", 0)
    end)

    failure = check(
        not internal.ok
            and internal.error.code == "E_INTERNAL"
            and internal.error.path == "",
        "internal_failure_sanitized"
    )
    if failure then return failure end

    local contract = M.contract()
    contract.value.required_case_fields[1] = "MODIFIED"
    contract.value.limits.component_count = 1
    local fresh_contract = M.contract()

    failure = check(
        fresh_contract.value.required_case_fields[1] == "case_name"
            and fresh_contract.value.limits.component_count == 128,
        "contract_output_isolation"
    )
    if failure then return failure end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        passed_check_count = test_count,
        field_validation = "not_performed",
        scientific_validation = "not_performed",
        attribution = ATTRIBUTION,
        external_actions = "none"
    })
end

function M.self_test()
    return protected_call(self_test_impl)
end

return M
