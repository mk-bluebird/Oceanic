-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 2.0.0; schema 2.
-- Public contract: {ok=true,value=...} or {ok=false,error=...}.
-- Text profile: fixed ASCII vocabulary only; no raw observation text.
-- No UTF-8 library dependency, normalization, storage, logging, or telemetry.
-- Attribution retention: copy this notice into derivatives.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, identity verification, or operational authority.

local M = {VERSION = "2.0.0", SCHEMA_VERSION = 2}
local SET_VERSION = 1

local REQUIRED = {
    "question", "observed_time", "subject",
    "result", "method", "effort", "uncertainty"
}
local OPTIONAL = {"units", "interpretation", "follow_up"}
local STATES = {
    supplied = true, unknown = true,
    not_collected = true, withheld = true
}

local function failure(code, path, args)
    return {
        code = code, field_path = path,
        message_key = "evidence_state." .. code,
        args = args or {}, category = "validation"
    }
end

local function safe_actual(value)
    local kind = type(value)
    if kind == "number" or kind == "boolean" then
        return tostring(value)
    end
    return "<" .. kind .. ">"
end

local function validate_record(value, required, optional, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return failure("E_RECORD", path, {expected_type = "plain_table"})
    end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return failure("E_MISSING", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end

    local unknown = false
    for key in pairs(value) do
        if not allowed[key] then unknown = true end
    end
    if unknown then return failure("E_UNKNOWN_FIELD", path) end
end

local function validate_states(entry)
    local fields = {}
    for _, key in ipairs(REQUIRED) do fields[#fields + 1] = key end
    for _, key in ipairs(OPTIONAL) do fields[#fields + 1] = key end
    local e = validate_record(entry, {}, fields, "input.entry_states")
    if e then return e end

    for _, key in ipairs(fields) do
        local value = entry[key]
        if value ~= nil then
            if type(value) ~= "string" or not STATES[value] then
                return failure("E_FIELD_STATE", "input.entry_states." .. key,
                    {actual_type = type(value)})
            end
        end
    end
end

local function validate_extensions(value)
    if value == nil then return end
    local e = validate_record(value, {}, {"source_kind", "entry_channel"},
        "input.extensions")
    if e then return e end
    local source = {synthetic = true, community_observation = true}
    local channel = {offline = true, online = true, assisted = true}
    if value.source_kind ~= nil then
        if type(value.source_kind) ~= "string"
            or not source[value.source_kind] then
            return failure("E_EXTENSION_ENUM", "input.extensions.source_kind")
        end
    end
    if value.entry_channel ~= nil then
        if type(value.entry_channel) ~= "string"
            or not channel[value.entry_channel] then
            return failure("E_EXTENSION_ENUM", "input.extensions.entry_channel")
        end
    end
end

local function base_output()
    return {
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        required_set_version = SET_VERSION,
        text_profile = "fixed_ascii_vocabulary_no_observation_text",
        publication_permission = "not_established",
        fingerprint_method = "none",
        extension_storage_hint =
            "caller_governed_retention_not_required_by_this_module",
        scope_notes = {
            completeness_screen_only = true,
            raw_content_validation_performed = false,
            taxonomy_classification_performed = false,
            sensitive_location_review_performed = false,
            record_linkage_managed_by_restricted_caller = true,
            corrections_and_supersession_managed_by_caller = true
        },
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            disclaimer = "Credit establishes no identity, consent, or authority.",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            scientific_accuracy_verified = false,
            upstream_state_assignment_verified = false,
            consent_declaration_verified = false,
            sensitivity_review_verified = false,
            location_anonymity_established = false,
            publication_authorized = false,
            legal_status_assessed = false,
            persistence_performed = false,
            logging_performed = false,
            telemetry_emitted = false,
            external_action_performed = false
        }
    }
end

function M.evaluate(input)
    local e = validate_record(input, {
        "schema_version", "entry_states",
        "sensitivity_declaration", "consent_to_review"
    }, {"extensions"}, "input")
    if e then return {ok = false, error = e} end

    if input.schema_version ~= M.SCHEMA_VERSION then
        return {ok = false, error = failure("E_SCHEMA_VERSION",
            "input.schema_version", {
                expected = M.SCHEMA_VERSION,
                actual = safe_actual(input.schema_version)
            })}
    end
    local consent = input.consent_to_review
    if consent ~= "granted" and consent ~= "declined" and consent ~= "unknown" then
        return {ok = false, error = failure("E_REVIEW_PERMISSION",
            "input.consent_to_review")}
    end
    local sensitivity = input.sensitivity_declaration
    if sensitivity ~= "unknown" and sensitivity ~= "sensitive"
        and sensitivity ~= "self_declared_low" then
        return {ok = false, error = failure("E_SENSITIVITY",
            "input.sensitivity_declaration")}
    end

    -- No completeness assessment or extension processing without permission.
    if consent ~= "granted" then
        local out = base_output()
        out.status = "screen_review_permission_not_granted"
        out.consent_to_review = consent
        return {ok = true, value = out}
    end

    e = validate_states(input.entry_states)
    if e then return {ok = false, error = e} end
    e = validate_extensions(input.extensions)
    if e then return {ok = false, error = e} end

    local names, field_states, missing = {}, {}, {}
    local counts = {supplied = 0, unknown = 0, not_collected = 0, withheld = 0}
    for i, key in ipairs(REQUIRED) do
        names[i] = key
        local state = input.entry_states[key] or "not_collected"
        field_states[key] = state
        counts[state] = counts[state] + 1
        if state ~= "supplied" then missing[#missing + 1] = key end
    end

    local optional_supplied, optional_accounted = 0, 0
    for _, key in ipairs(OPTIONAL) do
        local state = input.entry_states[key] or "not_collected"
        if state == "supplied" then optional_supplied = optional_supplied + 1 end
        if state ~= "not_collected" then
            optional_accounted = optional_accounted + 1
        end
    end

    local out = base_output()
    out.status = counts.supplied == #REQUIRED
        and "screen_required_states_supplied"
        or "screen_incomplete_draft"
    out.consent_to_review = consent
    out.sensitivity_declaration = sensitivity
    out.review_projection = {
        required_set_version = SET_VERSION,
        required_field_names = names,
        completeness_scope = "required_fields_only",
        required_field_count = #REQUIRED,
        supplied_required_count = counts.supplied,
        required_state_counts = counts,
        required_field_states = field_states,
        not_supplied_required_fields = missing,
        supplied_completeness = counts.supplied / #REQUIRED,
        accounted_completeness = 1 - counts.not_collected / #REQUIRED,
        optional_supplied_count = optional_supplied,
        optional_accounted_count = optional_accounted
    }
    return {ok = true, value = out}
end

return M
