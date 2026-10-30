-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivative distributions:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Local structural screening only; no storage, logging, or publication.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}

local REQUIRED = {
    "question", "observed_time", "subject",
    "result", "method", "effort", "uncertainty"
}
local OPTIONAL = {"units", "interpretation", "follow_up"}
local TOP = {
    "schema_version", "entry", "sensitivity", "extensions"
}

local function good(value)
    return {ok = true, value = value}
end

local function bad(code, path, args)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "evidence_log." .. code,
        args = args or {path = path},
        category = "validation"
    }}
end

local function utf8_text(value, maximum)
    if type(value) ~= "string" or #value < 1 or #value > maximum then
        return false
    end
    if utf8.len(value) == nil then return false end
    local visible = false
    for _, cp in utf8.codes(value) do
        if cp < 32 or (cp >= 127 and cp <= 159) then return false end
        if cp > 32 then visible = true end
    end
    return visible
end

local function record(value, required, optional, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end
    local unknown = false
    for key in pairs(value) do
        if not allowed[key] then unknown = true end
    end
    if unknown then return bad("E_UNKNOWN_FIELD", path) end
    return good(true)
end

function M.evaluate(input)
    local r = record(input, TOP, {}, "input")
    if not r.ok then return r end
    if input.schema_version ~= M.SCHEMA_VERSION then
        return bad("E_SCHEMA_VERSION", "input.schema_version",
            {path = "input.schema_version", expected = M.SCHEMA_VERSION})
    end
    if input.sensitivity ~= "unknown"
        and input.sensitivity ~= "sensitive"
        and input.sensitivity ~= "reviewed_low" then
        return bad("E_SENSITIVITY", "input.sensitivity")
    end

    local allowed_entry = {}
    for _, key in ipairs(REQUIRED) do allowed_entry[#allowed_entry + 1] = key end
    for _, key in ipairs(OPTIONAL) do allowed_entry[#allowed_entry + 1] = key end
    r = record(input.entry, {}, allowed_entry, "input.entry")
    if not r.ok then return r end

    -- Missing or false means unavailable. An explicit "unknown" remains
    -- supplied text, not a scientifically validated uncertainty statement.
    for _, key in ipairs(allowed_entry) do
        local value = input.entry[key]
        if value ~= nil and value ~= false and not utf8_text(value, 2000) then
            return bad("E_TEXT", "input.entry." .. key,
                {path = "input.entry." .. key, maximum_bytes = 2000})
        end
    end

    if type(input.extensions) ~= "table"
        or getmetatable(input.extensions) ~= nil then
        return bad("E_EXTENSIONS", "input.extensions")
    end
    local keys = {}
    for key in pairs(input.extensions) do
        if type(key) ~= "string" or #key > 80
            or not key:match("^[A-Za-z][A-Za-z0-9_]*$") then
            return bad("E_EXTENSION_KEY", "input.extensions")
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    if #keys > 32 then
        return bad("E_EXTENSION_LIMIT", "input.extensions", {maximum = 32})
    end
    for _, key in ipairs(keys) do
        if not utf8_text(input.extensions[key], 1000) then
            return bad("E_EXTENSION_VALUE", "input.extensions",
                {maximum_bytes = 1000})
        end
    end

    local supplied, missing = 0, {}
    for _, key in ipairs(REQUIRED) do
        local value = input.entry[key]
        if value == nil or value == false then
            missing[#missing + 1] = key
        else
            supplied = supplied + 1
        end
    end

    return good({
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = #missing == 0
            and "screen_required_fields_supplied"
            or "screen_evidence_fields_missing",
        completeness = supplied / #REQUIRED,
        required_field_count = #REQUIRED,
        supplied_required_count = supplied,
        missing_required_fields = missing,
        sensitivity_declaration = input.sensitivity,
        review_projection = {
            content = "structural_completeness_only",
            required_field_count = #REQUIRED,
            supplied_required_count = supplied,
            missing_required_fields = (function()
                local copy = {}
                for i, key in ipairs(missing) do copy[i] = key end
                return copy
            end)()
        },
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            scientific_accuracy_verified = false,
            method_compatibility_verified = false,
            location_anonymity_established = false,
            legal_status_assessed = false,
            publication_authorized = false,
            external_action_performed = false,
            persistence_performed = false
        }
    })
end

return M
