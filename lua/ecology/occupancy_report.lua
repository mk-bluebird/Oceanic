-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Retain attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local numeric = require("lua.ecology.occupancy_numeric")
local M = {VERSION = "2.0.0", SCHEMA_VERSION = 2}

local function good(v)
    return {ok = true, value = v}
end

local function bad(code, path, args)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "occupancy." .. code,
        args = args or {path = path},
        category = "validation"
    }}
end

local function utf8_text(v, maximum)
    if type(v) ~= "string" or #v == 0 or #v > maximum then return false end
    if utf8.len(v) == nil then return false end
    for _, cp in utf8.codes(v) do
        if cp < 32 or (cp >= 127 and cp <= 159) then return false end
    end
    return true
end

function M.evaluate(x)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", "input")
    end
    local fields = {
        "schema_version", "scope", "psi_form", "psi",
        "history", "detection", "visit_capacity",
        "closure_status", "extensions"
    }
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(x, key) == nil then
            return bad("E_MISSING", "input." .. key)
        end
    end
    for key in pairs(x) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", "input") end
    end
    if x.schema_version ~= M.SCHEMA_VERSION then
        return bad("E_SCHEMA_VERSION", "input.schema_version",
            {path = "input.schema_version", expected = M.SCHEMA_VERSION})
    end
    if not utf8_text(x.scope, 1000) then
        return bad("E_UTF8_TEXT", "input.scope",
            {path = "input.scope", maximum_bytes = 1000})
    end
    if x.psi_form ~= "scalar_site_probability" then
        return bad("E_PSI_FORM", "input.psi_form")
    end
    if x.closure_status ~= "unknown"
        and x.closure_status ~= "documented_violation"
        and x.closure_status ~= "assessed_no_violation_detected" then
        return bad("E_CLOSURE_STATUS", "input.closure_status")
    end
    if type(x.extensions) ~= "table"
        or getmetatable(x.extensions) ~= nil then
        return bad("E_EXTENSIONS", "input.extensions")
    end

    local extensions, keys = {}, {}
    for key in pairs(x.extensions) do
        if type(key) ~= "string" or #key > 80
            or not key:match("^[A-Za-z][A-Za-z0-9_]*$") then
            return bad("E_EXTENSION_KEY", "input.extensions")
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    if #keys > 32 then return bad("E_EXTENSION_LIMIT", "input.extensions") end
    for _, key in ipairs(keys) do
        if not utf8_text(x.extensions[key], 1000) then
            return bad("E_EXTENSION_VALUE", "input.extensions")
        end
        extensions[key] = x.extensions[key]
    end

    local ll, code, path = numeric.log_likelihood(
        x.psi, x.history, x.detection, x.visit_capacity)
    if ll == nil then
        return bad(code, path, {
            path = path, probability_minimum = 0, probability_maximum = 1,
            hard_visit_limit = numeric.HARD_VISITS
        })
    end

    local history, detection = {}, {}
    for i = 1, #x.history do
        history[i], detection[i] = x.history[i], x.detection[i]
    end
    local impossible = ll == -math.huge
    local value = {
        schema_version = M.SCHEMA_VERSION,
        module_version = M.VERSION,
        numeric_module_version = numeric.VERSION,
        status = impossible and "screen_zero_likelihood"
            or "screen_finite_log_likelihood",
        log_likelihood_encoding = impossible and "negative_infinity"
            or "finite_number",
        scope = x.scope, psi_form = x.psi_form, psi = x.psi,
        history = history, detection = detection,
        visit_capacity = x.visit_capacity,
        hard_visit_limit = numeric.HARD_VISITS,
        extensions = extensions,
        text_profile = "valid_utf8_no_C0_C1_controls_not_normalized",
        assumptions = {
            closure_required = true,
            closure_status = x.closure_status,
            misspecification_risk = "not_quantified",
            false_positive_probability_assumed_zero = true,
            conditional_visit_independence_assumed = true
        },
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            grants_authority = false,
            establishes_consent = false,
            establishes_verified_identity = false
        },
        interpretation_limits = {
            boundary_probabilities_supported = true,
            covariate_link_evaluated = false,
            prior_aware_api_supported = false,
            posterior_computed = false,
            input_order_preserved = true,
            visits_fingerprint_available = false,
            parameters_fitted = false,
            identifiability_verified = false,
            power_calculated = false,
            external_action_authorized = false
        }
    }
    if not impossible then value.log_likelihood = ll end
    return good(value)
end

return M
