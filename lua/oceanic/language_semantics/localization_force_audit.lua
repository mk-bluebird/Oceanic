-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- No identity, consent, authorization, or authority is established.
-- Local metadata audit; no rendering, storage, networking, or actuation.

local M = {VERSION = "1.0.0"}

local PURPOSES = {
    clarification_request = true,
    limitation_notice = true,
    error_report = true,
    forecast_notice = true,
    action_directive = true
}

local FEATURES = {
    "negation", "uncertainty", "evidential_status",
    "agency", "severity", "request_force"
}

local REVIEW = {
    preserved = true,
    concern = true,
    not_reviewed = true,
    not_applicable = true
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
            message_key = "localization_force_audit." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, keys)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(keys) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function label(value, maximum)
    return type(value) == "string"
        and #value > 0 and #value <= maximum
        and not value:find("[%z\1-\31\127]")
end

local function role_set(value)
    if not plain(value) then return nil end
    local count, highest, seen = 0, 0, {}
    for key in next, value do
        count = count + 1
        if count > 16 or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > 16 then
            return nil
        end
        if key > highest then highest = key end
    end
    if count ~= highest then return nil end

    for _, role in ipairs(value) do
        if not label(role, 64)
            or not role:match("^[a-z][a-z0-9_]*$")
            or seen[role] then
            return nil
        end
        seen[role] = true
    end
    return seen
end

local function entry(value)
    if not shape(value, {"locale", "purpose", "roles", "template"})
        or not label(value.locale, 64)
        or type(value.purpose) ~= "string"
        or not PURPOSES[value.purpose]
        or not label(value.template, 4000) then
        return nil
    end

    local roles = role_set(value.roles)
    if not roles then return nil end

    local used = {}
    local remainder = value.template:gsub(
        "%%{([a-z][a-z0-9_]*)}", function(role)
            used[role] = true
            return ""
        end)

    -- This small template grammar reserves %, {, and }.
    if remainder:find("[%%{}]") then return nil end

    for role in pairs(used) do
        if not roles[role] then return nil end
    end
    for role in pairs(roles) do
        if not used[role] then return nil end
    end
    return roles
end

function M.evaluate(input)
    if not shape(input, {
        "registry_version", "base", "target",
        "semantic_review", "fallback_available"
    }) or input.registry_version ~= "1.0.0" then
        return fail("E_INPUT_CONTRACT", "input")
    end

    local base_roles = entry(input.base)
    local target_roles = entry(input.target)
    if not base_roles then return fail("E_BASE_ENTRY", "input.base") end
    if not target_roles then return fail("E_TARGET_ENTRY", "input.target") end

    if type(input.fallback_available) ~= "boolean" then
        return fail("E_FALLBACK_DECLARATION", "input.fallback_available")
    end

    if not shape(input.semantic_review, FEATURES) then
        return fail("E_SEMANTIC_REVIEW", "input.semantic_review")
    end

    local concerns, unreviewed, declared_na = {}, {}, {}
    for _, feature in ipairs(FEATURES) do
        local status = input.semantic_review[feature]
        if type(status) ~= "string" or not REVIEW[status] then
            return fail("E_REVIEW_STATUS", "input.semantic_review")
        end
        if status == "concern" then
            concerns[#concerns + 1] = feature
        elseif status == "not_reviewed" then
            unreviewed[#unreviewed + 1] = feature
        elseif status == "not_applicable" then
            declared_na[#declared_na + 1] = feature
        end
    end

    local role_match = true
    for role in pairs(base_roles) do
        if not target_roles[role] then role_match = false end
    end
    for role in pairs(target_roles) do
        if not base_roles[role] then role_match = false end
    end

    return ok({
        registry_version = input.registry_version,
        declared_purpose_matches =
            input.base.purpose == input.target.purpose,
        argument_roles_match = role_match,
        mechanical_conformance =
            role_match and input.base.purpose == input.target.purpose,
        semantic_concerns = concerns,
        unreviewed_semantic_features = unreviewed,
        declared_not_applicable_features = declared_na,
        fallback_availability_declared = input.fallback_available,
        fallback_behavior_tested = false,
        semantic_equivalence_verified = false,
        reviewer_qualifications_verified = false,
        escaping_or_rendering_assessed = false,
        assessment_scope = "metadata_and_review_record_only"
    })
end

return M
