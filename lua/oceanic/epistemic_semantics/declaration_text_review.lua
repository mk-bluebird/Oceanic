-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later. Standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Local text-policy inspection only.
-- No normalization, text echo, I/O, logging, networking, or storage.
-- Returned tables are fresh copies, not immutable objects.

if type(utf8) ~= "table" or type(utf8.codes) ~= "function" then
    error("ENV_UTF8_LIBRARY_REQUIRED", 0)
end

local M = {
    VERSION = "1.0.0"
}

local CONTRACT_VERSION = "1.0.0"
local PLACEHOLDER_VERSION = "1.0.0"
local WHITESPACE_VERSION = "1.0.0"
local CONTROL_POLICY_VERSION = "1.0.0"
local MAX_BYTES = 4000

local PLACEHOLDER_ORDER = {
    "TODO",
    "TBD",
    "<placeholder>"
}

local PLACEHOLDERS = {}
for _, item in ipairs(PLACEHOLDER_ORDER) do
    PLACEHOLDERS[item] = true
end

-- Explicit, versioned set. No runtime Unicode database is consulted.
local WHITESPACE = {
    [0x0009] = true,
    [0x000A] = true,
    [0x000B] = true,
    [0x000C] = true,
    [0x000D] = true,
    [0x0020] = true,
    [0x0085] = true,
    [0x00A0] = true,
    [0x1680] = true,
    [0x2000] = true,
    [0x2001] = true,
    [0x2002] = true,
    [0x2003] = true,
    [0x2004] = true,
    [0x2005] = true,
    [0x2006] = true,
    [0x2007] = true,
    [0x2008] = true,
    [0x2009] = true,
    [0x200A] = true,
    [0x2028] = true,
    [0x2029] = true,
    [0x202F] = true,
    [0x205F] = true,
    [0x3000] = true
}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code)
    return {
        ok = false,
        error = {
            code = code,
            path = "text",
            message_key = "declaration_text_review." .. code,
            args = {}
        }
    }
end

local function metadata()
    return {
        contract_version = CONTRACT_VERSION,
        placeholder_rule_version = PLACEHOLDER_VERSION,
        whitespace_rule_version = WHITESPACE_VERSION,
        control_policy_version = CONTROL_POLICY_VERSION
    }
end

local function validate_string(text)
    if type(text) ~= "string" then
        return fail("E_TEXT_TYPE")
    end
    if #text > MAX_BYTES then
        return fail("E_TEXT_LIMIT")
    end

    local valid = pcall(function()
        for _, codepoint in utf8.codes(text) do
            if codepoint > 0x10FFFF
                or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
                error("invalid_scalar", 0)
            end
        end
    end)

    if not valid then
        return fail("E_TEXT_UTF8")
    end

    return ok(true)
end

function M.describe()
    local result = metadata()
    result.maximum_bytes = MAX_BYTES
    result.placeholder_matching = "exact_bytes"
    result.normalization_performed = false
    result.case_folding_performed = false
    result.text_returned = false
    result.c1_policy = "accept_with_review"
    result.ascii_control_policy =
        "reject_except_tab_carriage_return_line_feed"
    result.zero_width_characters_classified_as_whitespace = false
    return ok(result)
end

function M.list_placeholders()
    local items = {}
    for i, item in ipairs(PLACEHOLDER_ORDER) do
        items[i] = item
    end
    return ok({
        placeholder_rule_version = PLACEHOLDER_VERSION,
        matching = "exact_bytes",
        items = items
    })
end

function M.contains_placeholder(text)
    local result = validate_string(text)
    if not result.ok then return result end

    return ok({
        placeholder_rule_version = PLACEHOLDER_VERSION,
        registered = PLACEHOLDERS[text] == true
    })
end

function M.inspect(text)
    local result = validate_string(text)
    if not result.ok then return result end

    local codepoint_count = 0
    local whitespace_only = #text > 0
    local non_ascii_whitespace = false
    local contains_c1 = false
    local forbidden_ascii_control = false

    for _, codepoint in utf8.codes(text) do
        codepoint_count = codepoint_count + 1

        if not WHITESPACE[codepoint] then
            whitespace_only = false
        elseif codepoint > 0x7F then
            non_ascii_whitespace = true
        end

        if codepoint >= 0x80 and codepoint <= 0x9F then
            contains_c1 = true
        end

        if codepoint == 0x7F
            or (codepoint < 0x20
                and codepoint ~= 0x09
                and codepoint ~= 0x0A
                and codepoint ~= 0x0D) then
            forbidden_ascii_control = true
        end
    end

    local decision
    if forbidden_ascii_control then
        decision = "reject_ascii_control"
    elseif #text == 0 then
        decision = "reject_empty"
    elseif whitespace_only and not non_ascii_whitespace then
        decision = "reject_ascii_whitespace_only"
    else
        decision = "accept"
    end

    local reviews = {}
    if whitespace_only and non_ascii_whitespace then
        reviews[#reviews + 1] = "R_UNICODE_WHITESPACE_ONLY"
    end
    if contains_c1 then
        reviews[#reviews + 1] = "R_C1_CONTROL_PRESENT"
    end
    if PLACEHOLDERS[text] then
        reviews[#reviews + 1] = "R_REGISTERED_PLACEHOLDER_TEXT"
    end

    local value = metadata()
    value.policy_decision = decision
    value.byte_count = #text
    value.codepoint_count = codepoint_count
    value.whitespace_only = whitespace_only
    value.contains_c1_control = contains_c1
    value.registered_placeholder = PLACEHOLDERS[text] == true
    value.review_codes = reviews
    value.assessment_scope = "text_policy_only"
    value.scientific_support_assessed = false
    value.semantic_equivalence_assessed = false
    return ok(value)
end

return M
