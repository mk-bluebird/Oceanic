-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4, standard library only.
--
-- API:
--   screen({
--       source = {
--           analysis_unit, effect_measure, outcome,
--           population_scope, time_scope
--       },
--       claim = { same five fields },
--       bridge_declared = boolean
--   })
--
-- Each field is a bounded nonempty string.
-- Use the exact token "unknown" for unresolved metadata.
-- Labels should come from a reviewed vocabulary.
-- Equality of text is not semantic equivalence.
--
-- No parsing, source access, storage, networking, publication, or actuation.

local M = {}
local SCHEMA_VERSION = "1.0.0"
local MODULE_VERSION = "1.0.0"

local fields = {
    "analysis_unit",
    "effect_measure",
    "outcome",
    "population_scope",
    "time_scope"
}

local allowed = {}
for _, field in ipairs(fields) do
    allowed[field] = true
end

local function envelope(ok, value, code, path, message)
    return {
        ok = ok,
        schema_version = SCHEMA_VERSION,
        module_version = MODULE_VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            path = path or "",
            message = message or ""
        }
    }
end

local function fail(code, path, message)
    return envelope(false, false, code, path, message)
end

local function plain_table(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function valid_text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 512
        and value:find("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function validate_frame(frame, path)
    if not plain_table(frame) then
        return fail("E_FRAME", path, "Expected a plain metadata table.")
    end

    for key in next, frame do
        if not allowed[key] then
            return fail("E_FIELD", path,
                "Unexpected metadata field.")
        end
    end

    for _, field in ipairs(fields) do
        if not valid_text(rawget(frame, field)) then
            return fail("E_TEXT", path .. "." .. field,
                "Supply bounded metadata text or the token unknown.")
        end
    end

    return nil
end

local function screen_impl(config)
    if not plain_table(config) then
        return fail("E_CONFIG", "", "Expected a plain configuration table.")
    end

    for key in next, config do
        if key ~= "source" and key ~= "claim"
            and key ~= "bridge_declared" then
            return fail("E_FIELD", "", "Unexpected configuration field.")
        end
    end

    local failure = validate_frame(rawget(config, "source"), "source")
    if failure then return failure end

    failure = validate_frame(rawget(config, "claim"), "claim")
    if failure then return failure end

    if type(rawget(config, "bridge_declared")) ~= "boolean" then
        return fail("E_BOOLEAN", "bridge_declared",
            "Supply a logical declaration.")
    end

    local comparisons = {}
    local mismatches = 0
    local unresolved = 0

    for _, field in ipairs(fields) do
        local source_value = rawget(config.source, field)
        local claim_value = rawget(config.claim, field)
        local state

        if source_value == "unknown" or claim_value == "unknown" then
            state = "metadata_unresolved"
            unresolved = unresolved + 1
        elseif source_value ~= claim_value then
            state = "declared_mismatch"
            mismatches = mismatches + 1
        else
            state = "declared_match"
        end

        comparisons[#comparisons + 1] = {
            field = field,
            source_value = source_value,
            claim_value = claim_value,
            comparison_state = state
        }
    end

    local review_status = "no_declared_mismatch_detected"
    if mismatches > 0 then
        review_status = "mismatch_requires_review"
    elseif unresolved > 0 then
        review_status = "metadata_review_required"
    end

    return envelope(true, {
        status = "structural_screen_only",
        review_status = review_status,
        comparisons = comparisons,
        declared_mismatch_count = mismatches,
        unresolved_field_count = unresolved,
        bridge_declared = config.bridge_declared,
        bridge_verified = false,
        scientific_validity_established = false,
        source_fidelity_verified = false,
        retrieval_approval_granted = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_TEXT_EQUALITY",
                message = "Text equality does not establish semantic equivalence."
            },
            {
                code = "R_VALID_INFERENCE",
                message = "A mismatch may be supported by a valid analysis."
            },
            {
                code = "R_NO_BRIDGE_VERIFICATION",
                message = "A declared bridge never clears a mismatch automatically."
            },
            {
                code = "R_NO_SCIENTIFIC_PASS",
                message = "No mismatch detected is not scientific approval."
            }
        }
    })
end

function M.screen(config)
    local ok, result = pcall(screen_impl, config)
    if not ok then
        return fail("E_INTERNAL", "",
            "Unexpected internal failure; inspect locally.")
    end
    return result
end

function M.self_test()
    local function frame(unit, measure)
        return {
            analysis_unit = unit,
            effect_measure = measure,
            outcome = "tissue_death",
            population_scope = "specified_study_colonies",
            time_scope = "specified_observation_period"
        }
    end

    local matched = {
        source = frame("tissue_region", "hazard_ratio"),
        claim = frame("tissue_region", "hazard_ratio"),
        bridge_declared = false
    }

    local a = M.screen(matched)
    if not a.ok
        or a.value.review_status ~= "no_declared_mismatch_detected" then
        return fail("E_SELF_TEST", "matched", "Matched case failed.")
    end

    local changed = {
        source = frame("tissue_region", "hazard_ratio"),
        claim = frame("colony", "risk_ratio"),
        bridge_declared = true
    }

    local b = M.screen(changed)
    if not b.ok or b.value.declared_mismatch_count ~= 2
        or b.value.review_status ~= "mismatch_requires_review"
        or b.value.bridge_verified ~= false then
        return fail("E_SELF_TEST", "mismatch",
            "Mismatch or bridge-declaration behavior failed.")
    end

    local unknown = {
        source = frame("unknown", "hazard_ratio"),
        claim = frame("tissue_region", "hazard_ratio"),
        bridge_declared = false
    }

    local c = M.screen(unknown)
    if not c.ok or c.value.unresolved_field_count ~= 1 then
        return fail("E_SELF_TEST", "unknown",
            "Unknown metadata was not preserved.")
    end

    local again = M.screen(matched)
    if not again.ok
        or again.value.review_status ~= a.value.review_status
        or matched.source.analysis_unit ~= "tissue_region" then
        return fail("E_SELF_TEST", "determinism_nonmutation",
            "Determinism or non-mutation check failed.")
    end

    local invalid = M.screen(false)
    if invalid.ok or invalid.error.code ~= "E_CONFIG" then
        return fail("E_SELF_TEST", "invalid_config",
            "Invalid configuration was not rejected.")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        detector_precision_measured = false,
        detector_recall_measured = false,
        field_validation = "not_performed"
    })
end

return M
