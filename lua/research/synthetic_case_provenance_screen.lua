-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4 standard library.
-- screen(case)
--
-- Exact case fields:
-- case_name, family, scenario_status, slice, evaluation_use,
-- tested_property, expectation_basis, non_conclusions, components
--
-- family: anchored_development | cross_context_stress
-- scenario_status: synthetic
-- slice: A | B | C
-- evaluation_use: development | evaluation_candidate
-- components: nonempty sequence of plain tables with exact fields:
--   description, origin, basis, verification_status
-- origin: source_reported | invented | derived
-- verification_status: not_verified | reviewed_declaration
--
-- Review declarations are not authenticated.
-- No files, networking, storage, publication, or actuation.

local M = {}
local VERSION = "0.1.0"

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

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value, limit)
    return type(value) == "string" and #value > 0 and #value <= limit
        and value:find("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function exact_fields(value, fields)
    if not plain(value) then return false end
    local allowed = {}
    for _, field in ipairs(fields) do
        allowed[field] = true
        if rawget(value, field) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function sequence_length(value)
    if not plain(value) then return nil end
    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key < 1 or key > 128
            or key % 1 ~= 0 then return nil end
        count = count + 1
    end
    for position = 1, count do
        if rawget(value, position) == nil then return nil end
    end
    return count
end

local function screen_impl(case)
    local fields = {
        "case_name", "family", "scenario_status", "slice",
        "evaluation_use", "tested_property", "expectation_basis",
        "non_conclusions", "components"
    }
    if not exact_fields(case, fields) then
        return fail("E_CASE_FIELDS", "case")
    end

    for _, field in ipairs({
        "case_name", "tested_property", "expectation_basis", "non_conclusions"
    }) do
        if not text(case[field], 4096) then
            return fail("E_TEXT", field)
        end
    end

    if case.family ~= "anchored_development"
        and case.family ~= "cross_context_stress" then
        return fail("E_FAMILY", "family")
    end
    if case.scenario_status ~= "synthetic" then
        return fail("E_SYNTHETIC_STATUS", "scenario_status")
    end
    if case.slice ~= "A" and case.slice ~= "B" and case.slice ~= "C" then
        return fail("E_SLICE", "slice")
    end
    if case.evaluation_use ~= "development"
        and case.evaluation_use ~= "evaluation_candidate" then
        return fail("E_EVALUATION_USE", "evaluation_use")
    end

    local count = sequence_length(case.components)
    if not count or count == 0 then
        return fail("E_COMPONENTS", "components")
    end

    local origins = {source_reported = 0, invented = 0, derived = 0}
    local component_fields = {
        "description", "origin", "basis", "verification_status"
    }

    for position = 1, count do
        local component = case.components[position]
        if not exact_fields(component, component_fields) then
            return fail("E_COMPONENT_FIELDS", "components")
        end
        if not text(component.description, 2048)
            or not text(component.basis, 2048) then
            return fail("E_COMPONENT_TEXT", "components")
        end
        if type(component.origin) ~= "string"
            or origins[component.origin] == nil then
            return fail("E_ORIGIN", "components.origin")
        end
        if component.verification_status ~= "not_verified"
            and component.verification_status ~= "reviewed_declaration" then
            return fail("E_VERIFICATION", "components.verification_status")
        end
        origins[component.origin] = origins[component.origin] + 1
    end

    return envelope(true, {
        status = "provenance_declarations_present",
        component_count = count,
        component_origin_counts = origins,
        evaluation_use_declared = case.evaluation_use,
        source_accuracy_verified = false,
        expectation_correctness_verified = false,
        heldout_status_verified = false,
        ecological_validity_established = false,
        publication_authorized = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
    })
end

function M.screen(case)
    local ok, result = pcall(screen_impl, case)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end

function M.self_test()
    local function fixture()
        return {
            case_name = "Synthetic hazard-summary mutation",
            family = "anchored_development",
            scenario_status = "synthetic",
            slice = "B",
            evaluation_use = "development",
            tested_property = "Effect-measure declaration drift",
            expectation_basis = "One changed structured field must be flagged.",
            non_conclusions =
                "No source verification or ecological validation is established.",
            components = {
                {
                    description = "Hazard-ratio wording",
                    origin = "source_reported",
                    basis = "Supplied conversation; original passage not checked here.",
                    verification_status = "not_verified"
                },
                {
                    description = "Risk-ratio substitution",
                    origin = "invented",
                    basis = "Deliberate synthetic mutation.",
                    verification_status = "not_verified"
                }
            }
        }
    end

    local case = fixture()
    local a = M.screen(case)
    if not a.ok or a.value.component_origin_counts.invented ~= 1 then
        return fail("E_SELF_TEST", "baseline")
    end

    local bad = fixture()
    bad.scenario_status = "observed"
    local b = M.screen(bad)
    if b.ok or b.error.code ~= "E_SYNTHETIC_STATUS" then
        return fail("E_SELF_TEST", "synthetic_status")
    end

    local missing = fixture()
    missing.components[1].basis = nil
    local c = M.screen(missing)
    if c.ok or c.error.code ~= "E_COMPONENT_FIELDS" then
        return fail("E_SELF_TEST", "missing_basis")
    end

    local again = M.screen(case)
    if not again.ok or again.value.component_count ~= a.value.component_count
        or case.components[1].origin ~= "source_reported" then
        return fail("E_SELF_TEST", "repeat_nonmutation")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        field_validation = "not_performed"
    })
end

return M
