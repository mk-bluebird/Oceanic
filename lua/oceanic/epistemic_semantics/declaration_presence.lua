-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later. Standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local classification only; no I/O or persistent storage.

local M = {
    VERSION = "1.0.0",
    NULL_POLICY_VERSION = "1.0.0",
    PLACEHOLDER_RULE_VERSION = "1.0.0"
}

local NULL = {}
M.NULL = NULL

local TAGS = {
    supplied = true,
    unknown = true,
    not_collected = true,
    withheld = true,
    declared_not_applicable = true
}

local PLACEHOLDERS = {
    ["TODO"] = true,
    ["TBD"] = true,
    ["<placeholder>"] = true
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
            message_key = "declaration_presence." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed, path)
    if not plain(value) then
        return fail("E_RECORD", path)
    end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 2 or not allowed[key] then
            return fail("E_UNKNOWN_FIELD", path)
        end
    end
    return ok(true)
end

local function validate_text(value)
    if type(value) ~= "string" then
        return fail("E_TEXT_TYPE", "slot.value.text")
    end
    if #value > 4000 then
        return fail("E_TEXT_LIMIT", "slot.value.text")
    end
    if #value == 0 or value:match("^[ \t\r\n]*$") then
        return fail("E_TEXT_EMPTY", "slot.value.text")
    end
    if utf8.len(value) == nil then
        return fail("E_TEXT_UTF8", "slot.value.text")
    end
    for i = 1, #value do
        local b = value:byte(i)
        if b == 127 or
            (b < 32 and b ~= 9 and b ~= 10 and b ~= 13) then
            return fail("E_TEXT_CONTROL", "slot.value.text")
        end
    end
    return ok(true)
end

local function classification(kind, declared, supplied, review)
    return ok({
        classification = kind,
        declaration_present = declared,
        content_supplied = supplied,
        review_codes = review or {},
        null_policy_version = M.NULL_POLICY_VERSION,
        placeholder_rule_version = M.PLACEHOLDER_RULE_VERSION,
        scientific_support_assessed = false
    })
end

function M.classify(slot)
    local result = shape(
        slot, {present = true, value = true}, "slot")
    if not result.ok then return result end

    if type(slot.present) ~= "boolean" then
        return fail("E_PRESENCE_TYPE", "slot.present")
    end

    local value = rawget(slot, "value")

    if not slot.present then
        if value ~= nil then
            return fail("E_ABSENT_WITH_VALUE", "slot")
        end
        return classification("absent", false, false)
    end

    if value == nil then
        return fail("E_PRESENT_WITHOUT_VALUE", "slot.value")
    end

    if rawequal(value, NULL) then
        return classification(
            "explicit_null", true, false,
            {"R_EXPLICIT_NULL_UNRESOLVED"})
    end

    result = shape(value, {tag = true, text = true}, "slot.value")
    if not result.ok then return result end

    if type(value.tag) ~= "string" or not TAGS[value.tag] then
        return fail("E_DECLARATION_TAG", "slot.value.tag")
    end

    if value.tag ~= "supplied" then
        if rawget(value, "text") ~= nil then
            return fail("E_UNEXPECTED_CONTENT", "slot.value")
        end
        return classification(value.tag, true, false)
    end

    result = validate_text(value.text)
    if not result.ok then return result end

    if PLACEHOLDERS[value.text] then
        return classification(
            "supplied", true, true,
            {"R_REGISTERED_PLACEHOLDER_TEXT"})
    end

    return classification("supplied", true, true)
end

function M.from_table(record, key)
    if not plain(record) then
        return fail("E_RECORD", "input")
    end
    if type(key) ~= "string" then
        return fail("E_FIELD_NAME_TYPE", "field")
    end

    local value = rawget(record, key)
    if value == nil then
        return M.classify({present = false})
    end
    return M.classify({present = true, value = value})
end

return M
