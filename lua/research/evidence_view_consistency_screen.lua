-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4 standard library.
--
-- screen({
--   canonical = projection,
--   human_projection = projection,
--   machine_projection = projection,
--   evidence_projection = projection
-- })
--
-- Each projection contains exactly:
-- card_version, claim_text, evidence_category, analysis_unit,
-- effect_measure, spatial_support, temporal_support, limitation_codes
--
-- Scalar fields are nonempty bounded strings.
-- limitation_codes is a plain contiguous sequence of unique strings.
-- Limitation ordering is ignored; scalar text uses exact equality.
--
-- This checks declared projections, not arbitrary prose semantics.
-- No I/O, networking, persistence, publication, or external actions.

local M = {}
local VERSION = "0.1.0"

local scalar_fields = {
    "card_version", "claim_text", "evidence_category", "analysis_unit",
    "effect_measure", "spatial_support", "temporal_support"
}
local view_names = {
    "human_projection", "machine_projection", "evidence_projection"
}
local allowed = {limitation_codes = true}
for _, key in ipairs(scalar_fields) do allowed[key] = true end

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
    return type(value) == "string"
        and #value > 0 and #value <= limit
        and value:find("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function validate_projection(p, path)
    if not plain(p) then return nil, fail("E_PROJECTION", path) end
    for key in next, p do
        if not allowed[key] then return nil, fail("E_FIELD", path) end
    end
    for _, key in ipairs(scalar_fields) do
        if not text(rawget(p, key), 4096) then
            return nil, fail("E_TEXT", path .. "." .. key)
        end
    end

    local codes = rawget(p, "limitation_codes")
    if not plain(codes) then
        return nil, fail("E_LIMITATIONS", path .. ".limitation_codes")
    end

    local count = 0
    for key in next, codes do
        if type(key) ~= "number" or key < 1 or key > 128
            or key % 1 ~= 0 then
            return nil, fail("E_SEQUENCE", path .. ".limitation_codes")
        end
        count = count + 1
    end

    local sorted, seen = {}, {}
    for position = 1, count do
        local value = rawget(codes, position)
        if not text(value, 128) then
            return nil, fail("E_LIMITATIONS", path .. ".limitation_codes")
        end
        if seen[value] then
            return nil, fail("E_DUPLICATE", path .. ".limitation_codes")
        end
        seen[value] = true
        sorted[position] = value
    end
    table.sort(sorted)
    return sorted, nil
end

local function same_sequence(a, b)
    if #a ~= #b then return false end
    for position = 1, #a do
        if a[position] ~= b[position] then return false end
    end
    return true
end

local function screen_impl(config)
    if not plain(config) then return fail("E_CONFIG", "config") end

    local config_fields = {
        canonical = true, human_projection = true,
        machine_projection = true, evidence_projection = true
    }
    for key in next, config do
        if not config_fields[key] then return fail("E_FIELD", "config") end
    end

    local canonical_codes, failure =
        validate_projection(rawget(config, "canonical"), "canonical")
    if failure then return failure end

    local findings = {}
    for _, view in ipairs(view_names) do
        local projection = rawget(config, view)
        local codes
        codes, failure = validate_projection(projection, view)
        if failure then return failure end

        for _, field in ipairs(scalar_fields) do
            if projection[field] ~= config.canonical[field] then
                findings[#findings + 1] = {
                    code = "W_PROJECTED_FIELD_DIFFERS",
                    path = view .. "." .. field,
                    message_key = "projected_field_requires_review",
                    args = {view = view, field = field}
                }
            end
        end

        if not same_sequence(codes, canonical_codes) then
            findings[#findings + 1] = {
                code = "W_LIMITATION_SET_DIFFERS",
                path = view .. ".limitation_codes",
                message_key = "limitation_set_requires_review",
                args = {view = view, field = "limitation_codes"}
            }
        end
    end

    local status = #findings == 0
        and "no_projected_drift_detected" or "projected_drift_detected"

    return envelope(true, {
        status = status,
        findings = findings,
        finding_count = #findings,
        canonical_scientific_validity_verified = false,
        source_fidelity_verified = false,
        prose_semantic_equivalence_verified = false,
        authorization_enforced = false,
        automatic_correction_performed = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_PROJECTIONS",
                message = "Only supplied structured projections are compared."
            },
            {
                code = "R_EXACT_TEXT",
                message = "Faithful paraphrases may differ under exact text comparison."
            },
            {
                code = "R_CANONICAL",
                message = "Canonical content may itself be incorrect."
            },
            {
                code = "R_PERMISSION",
                message = "No permission decision or enforcement is implemented."
            }
        }
    })
end

function M.screen(config)
    local ok, result = pcall(screen_impl, config)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end

function M.self_test()
    local function projection()
        return {
            card_version = "0.1.0",
            claim_text = "Synthetic tissue-level hazard estimate.",
            evidence_category = "statistical_estimate",
            analysis_unit = "tissue_region",
            effect_measure = "hazard_ratio",
            spatial_support = "synthetic_study_sites",
            temporal_support = "synthetic_event_window",
            limitation_codes = {"R_SITE_SCOPE", "R_NO_TRANSFER"}
        }
    end

    local function fixture()
        return {
            canonical = projection(),
            human_projection = projection(),
            machine_projection = projection(),
            evidence_projection = projection()
        }
    end

    local matched = fixture()
    local a = M.screen(matched)
    if not a.ok or a.value.finding_count ~= 0 then
        return fail("E_SELF_TEST", "matched")
    end

    local changed = fixture()
    changed.human_projection.effect_measure = "risk_ratio"
    local b = M.screen(changed)
    if not b.ok or b.value.finding_count ~= 1
        or b.value.findings[1].path ~= "human_projection.effect_measure" then
        return fail("E_SELF_TEST", "effect_measure_drift")
    end

    local reordered = fixture()
    reordered.machine_projection.limitation_codes =
        {"R_NO_TRANSFER", "R_SITE_SCOPE"}
    local c = M.screen(reordered)
    if not c.ok or c.value.finding_count ~= 0 then
        return fail("E_SELF_TEST", "limitation_order")
    end

    local stale = fixture()
    stale.machine_projection.card_version = "0.0.9"
    local d = M.screen(stale)
    if not d.ok or d.value.finding_count ~= 1 then
        return fail("E_SELF_TEST", "stale_version")
    end

    local repeated = M.screen(matched)
    if not repeated.ok or repeated.value.finding_count ~= 0
        or matched.canonical.effect_measure ~= "hazard_ratio" then
        return fail("E_SELF_TEST", "repeat_nonmutation")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        semantic_detector_accuracy_measured = false,
        permission_enforcement_tested = false
    })
end

return M
