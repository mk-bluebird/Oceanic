-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, identity verification, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local descriptive arithmetic; no I/O, fitting, or external actions.

local M = {VERSION = "1.0.0"}
local CELLS = {
    "impact_before", "impact_after",
    "reference_before", "reference_after"
}

local function bad(code, path, args)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "restoration_contrast." .. code,
        args = args or {}, category = "validation"
    }}
end

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function text(v)
    if type(v) ~= "string" or #v < 1 or #v > 500
        or not v:match("%S") then return false end
    for i = 1, #v do
        local b = v:byte(i)
        if b < 32 or b > 126 then return false end
    end
    return true
end

local function record(v, fields, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(v, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    for key in pairs(v) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", path) end
    end
end

function M.evaluate(x)
    local e = record(x, {
        "schema_version", "scope", "metric", "units",
        "endpoint_class", "mode", "measurements"
    }, "input")
    if e then return e end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version", {expected = 1})
    end
    for _, key in ipairs({"scope", "metric", "units"}) do
        if not text(x[key]) then return bad("E_TEXT", "input." .. key) end
    end
    if x.endpoint_class ~= "activity"
        and x.endpoint_class ~= "structure"
        and x.endpoint_class ~= "function" then
        return bad("E_ENDPOINT_CLASS", "input.endpoint_class")
    end
    if x.mode ~= "additive" and x.mode ~= "log_ratio_of_ratios" then
        return bad("E_MODE", "input.mode")
    end
    e = record(x.measurements, CELLS, "input.measurements")
    if e then return e end

    local copied = {}
    for _, key in ipairs(CELLS) do
        local value = x.measurements[key]
        local path = "input.measurements." .. key
        if not finite(value) then return bad("E_FINITE", path) end
        if x.mode == "log_ratio_of_ratios" and value <= 0 then
            return bad("E_POSITIVE_REQUIRED", path, {minimum_exclusive = 0})
        end
        copied[key] = value
    end

    local focal_change, reference_change, contrast
    if x.mode == "additive" then
        focal_change = copied.impact_after - copied.impact_before
        reference_change = copied.reference_after - copied.reference_before
    else
        focal_change = math.log(copied.impact_after)
            - math.log(copied.impact_before)
        reference_change = math.log(copied.reference_after)
            - math.log(copied.reference_before)
    end
    contrast = focal_change - reference_change
    if not finite(focal_change) or not finite(reference_change)
        or not finite(contrast) then
        return bad("E_NUMERIC_RANGE", "input.measurements")
    end

    return {ok = true, value = {
        schema_version = 1,
        module_version = M.VERSION,
        status = "screen_descriptive_restoration_contrast",
        scope = x.scope, metric = x.metric,
        input_units = x.units,
        contrast_units = x.mode == "additive"
            and x.units or "dimensionless_log_ratio",
        endpoint_class = x.endpoint_class,
        mode = x.mode,
        measurements = copied,
        focal_change = focal_change,
        reference_change = reference_change,
        contrast = contrast,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            endpoint_class_verified = false,
            uncertainty_estimated = false,
            replication_assessed = false,
            reference_comparability_verified = false,
            causal_effect_established = false,
            functional_recovery_established = false,
            method_superiority_established = false,
            external_action_authorized = false
        }
    }}
end

return M
