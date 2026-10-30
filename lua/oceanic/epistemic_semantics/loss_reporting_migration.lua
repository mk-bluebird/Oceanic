-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Migration planning only. No I/O, storage, or source mutation.

local M = {
    VERSION = "1.0.0",
    POLICY_VERSION = "research-migration-policy-1"
}

local SOURCE_FIELDS = {"subject", "response", "spatial_scope"}
local TARGET_FIELDS = {
    "subject", "response", "spatial_scope", "evidence_basis"
}

local SOURCE_SET = {}
for _, field in ipairs(SOURCE_FIELDS) do SOURCE_SET[field] = true end

local EXTENSIONS = {
    display_hint = "ignore",
    provenance_note = "quarantine",
    governance_change = "require_review"
}

local EXTENSION_ORDER = {
    "display_hint", "provenance_note", "governance_change"
}

local TAGS = {
    supplied = true,
    unknown = true,
    not_collected = true,
    withheld = true,
    declared_not_applicable = true,
    unavailable = true
}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "loss_reporting_migration." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, required, optional, path)
    if not plain(value) then return fail("E_RECORD", path) end
    local allowed = {}

    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return fail("E_REQUIRED_MEMBER", path)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end

    for key in next, value do
        if not allowed[key] then return fail("E_UNKNOWN_MEMBER", path) end
    end
    return ok(true)
end

local function text(value)
    return type(value) == "string"
        and #value > 0 and #value <= 4000
        and not value:match("^[ \t\r\n]*$")
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function declaration(value, path)
    local checked = shape(value, {"tag"}, {"text"}, path)
    if not checked.ok then return checked end

    if type(value.tag) ~= "string" or not TAGS[value.tag] then
        return fail("E_DECLARATION_TAG", path)
    end

    if value.tag == "supplied" then
        if not text(value.text) then return fail("E_TEXT", path) end
    elseif rawget(value, "text") ~= nil then
        return fail("E_UNEXPECTED_CONTENT", path)
    end

    return ok(true)
end

function M.plan(input)
    local checked = shape(input, {
        "source_schema_version", "target_schema_version",
        "policy_version", "frame", "extensions"
    }, {}, "input")
    if not checked.ok then return checked end

    if input.source_schema_version ~= 1
        or input.target_schema_version ~= 2 then
        return fail("E_VERSION_ROUTE", "input")
    end
    if input.policy_version ~= M.POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end
    if not plain(input.frame) or not plain(input.extensions) then
        return fail("E_RECORD", "input")
    end

    for field in next, input.frame do
        if type(field) ~= "string" or not SOURCE_SET[field] then
            return fail("E_UNKNOWN_MEMBER", "input.frame")
        end
    end

    for key, value in next, input.extensions do
        if type(key) ~= "string" or not EXTENSIONS[key] then
            return fail("E_EXTENSION_REJECTED", "input.extensions")
        end
        if not text(value) then
            return fail("E_EXTENSION_VALUE", "input.extensions")
        end
    end

    local candidate = {schema_version = 2, frame = {}}
    local preserved, ambiguities, losses, quarantined, reviews = {}, {}, {}, {}, {}
    local new_gaps, unresolved_fields = {}, {}

    for _, field in ipairs(SOURCE_FIELDS) do
        local value = rawget(input.frame, field)
        if value ~= nil then
            checked = declaration(value, "input.frame." .. field)
            if not checked.ok then return checked end

            if value.tag == "unavailable" then
                ambiguities[#ambiguities + 1] = {
                    field = field,
                    code = "A_LEGACY_UNAVAILABLE",
                    possible_tags = {
                        "unknown", "not_collected", "withheld"
                    }
                }
                unresolved_fields[field] = true
            else
                local converted = {tag = value.tag}
                if value.tag == "supplied" then
                    converted.text = value.text
                end
                candidate.frame[field] = converted
                preserved[#preserved + 1] = field
            end
        end
    end

    for _, key in ipairs(EXTENSION_ORDER) do
        if rawget(input.extensions, key) ~= nil then
            local mode = EXTENSIONS[key]
            if mode == "ignore" then
                losses[#losses + 1] = {
                    registered_key = key,
                    code = "L_EXTENSION_VALUE_OMITTED"
                }
            elseif mode == "quarantine" then
                quarantined[#quarantined + 1] = {
                    registered_key = key,
                    code = "Q_SEPARATE_HANDLING_REQUIRED",
                    content_retained_here = false
                }
            else
                reviews[#reviews + 1] = {
                    registered_key = key,
                    code = "R_GOVERNANCE_EXTENSION"
                }
            end
        end
    end

    for _, field in ipairs(TARGET_FIELDS) do
        if candidate.frame[field] == nil and not unresolved_fields[field] then
            new_gaps[#new_gaps + 1] = {
                field = field,
                origin = SOURCE_SET[field]
                    and "previously_undeclared"
                    or "new_target_requirement"
            }
        end
    end

    local blocked = #ambiguities > 0 or #quarantined > 0 or #reviews > 0
    local candidates = {}
    if not blocked then candidates[1] = candidate end

    local outcome
    if blocked then
        outcome = "review_required"
    elseif #losses > 0 then
        outcome = "lossy_candidate"
    else
        outcome = "declaration_preserving_candidate"
    end

    return ok({
        outcome = outcome,
        source_schema_version = 1,
        target_schema_version = 2,
        policy_version = M.POLICY_VERSION,
        candidates = candidates,
        preserved_fields = preserved,
        ambiguities = ambiguities,
        losses = losses,
        quarantine_notices = quarantined,
        review_requirements = reviews,
        gaps = new_gaps,
        semantic_equivalence_established = false,
        source_modified = false,
        original_retention_authorized = false,
        migration_execution_authorized = false
    })
end

return M
