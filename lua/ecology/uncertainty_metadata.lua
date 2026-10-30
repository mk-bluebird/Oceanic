-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Metadata validation only; no estimation, publication, or external action.

local V = require("lua.ecology.validation")
local M = {VERSION = "1.0.0"}
local KINDS = {
    "not_quantified", "qualitative_assessment", "measurement_bound",
    "confidence_interval", "credible_interval", "sensitivity_range"
}

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "kind", "basis"
    }, {
        "estimate", "lower", "upper", "units",
        "method", "level", "assessment_label"
    }, "input")
    if not r.ok then return r end
    if x.schema_version ~= 1 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version", {
            expected=1, actual=V.describe(x.schema_version)
        })
    end
    r = V.enum(x.kind, KINDS, "E_UNCERTAINTY_KIND", "input.kind")
    if not r.ok then return r end
    r = V.text(x.basis, 1000, "input.basis")
    if not r.ok then return r end

    local interval = x.kind == "measurement_bound"
        or x.kind == "confidence_interval"
        or x.kind == "credible_interval"
        or x.kind == "sensitivity_range"
    local probabilistic_level = x.kind == "confidence_interval"
        or x.kind == "credible_interval"

    if interval then
        for _, key in ipairs({"estimate", "lower", "upper", "units", "method"}) do
            if rawget(x, key) == nil then
                return V.fail("E_MISSING", "input." .. key, {field=key})
            end
        end
        for _, key in ipairs({"estimate", "lower", "upper"}) do
            if not V.finite(x[key]) then
                return V.fail("E_FINITE", "input." .. key,
                    {actual_type=type(x[key])})
            end
        end
        if x.lower > x.upper then
            return V.fail("E_INTERVAL_ORDER", "input.lower")
        end
        for _, key in ipairs({"units", "method"}) do
            r = V.text(x[key], 500, "input." .. key)
            if not r.ok then return r end
        end
        if x.assessment_label ~= nil then
            return V.fail("E_UNUSED_FIELD", "input.assessment_label")
        end
    else
        for _, key in ipairs({"estimate", "lower", "upper", "units", "level"}) do
            if x[key] ~= nil then return V.fail("E_UNUSED_FIELD", "input." .. key) end
        end
        if x.kind == "qualitative_assessment" then
            for _, key in ipairs({"method", "assessment_label"}) do
                if x[key] == nil then return V.fail("E_MISSING", "input." .. key) end
                r = V.text(x[key], 500, "input." .. key)
                if not r.ok then return r end
            end
        elseif x.method ~= nil or x.assessment_label ~= nil then
            return V.fail("E_UNUSED_FIELD", "input")
        end
    end

    if probabilistic_level then
        if x.level == nil then return V.fail("E_MISSING", "input.level") end
        if not V.finite(x.level) or x.level <= 0 or x.level >= 1 then
            return V.fail("E_LEVEL", "input.level", {
                minimum_exclusive=0, maximum_exclusive=1
            })
        end
    elseif x.level ~= nil then
        return V.fail("E_UNUSED_FIELD", "input.level")
    end

    local copied = {}
    for _, key in ipairs({
        "kind", "basis", "estimate", "lower", "upper",
        "units", "method", "level", "assessment_label"
    }) do
        if x[key] ~= nil then copied[key] = x[key] end
    end

    return V.ok({
        module_version=M.VERSION,
        schema_version=1,
        status="screen_uncertainty_metadata_valid",
        uncertainty=copied,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            disclaimer="Credit establishes no identity, consent, or authority.",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            uncertainty_method_verified=false,
            interval_coverage_verified=false,
            posterior_calibration_verified=false,
            community_permission_verified=false,
            accessibility_conformance_verified=false,
            publication_authorized=false,
            external_action_performed=false
        }
    })
end

return M
