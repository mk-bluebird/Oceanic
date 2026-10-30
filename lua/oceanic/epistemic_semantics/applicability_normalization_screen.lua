-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Standalone research contract; not an adapter to an existing pipeline.
-- No I/O, networking, storage, callbacks, or actuation.

if type(utf8) ~= "table" or type(utf8.len) ~= "function" then
    error("ENV_UTF8_LIBRARY_REQUIRED", 0)
end

local M = {
    VERSION = "1.0.0",
    CONTRACT_VERSION = "research-three-field-1"
}

local FIELDS = {"subject", "response", "spatial_scope"}
local INTENTS = {"describe", "compare"}
local FIELD_SET = {}
local INTENT_SET = {}

for _, name in ipairs(FIELDS) do FIELD_SET[name] = true end
for _, name in ipairs(INTENTS) do INTENT_SET[name] = true end

local TAGS = {
    supplied = true,
    unknown = true,
    not_collected = true,
    withheld = true,
    declared_not_applicable = true
}

local ERRORS = {
    E_RECORD = true,
    E_REQUIRED = true,
    E_UNKNOWN_FIELD = true,
    E_ARRAY = true,
    E_DUPLICATE = true,
    E_SCHEMA = true,
    E_INTENT = true,
    E_FIELD = true,
    E_TAG = true,
    E_TEXT = true,
    E_UNEXPECTED_CONTENT = true,
    E_REVIEW = true,
    E_NOT_NORMALIZED = true
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
            message_key = "applicability_normalization_screen." .. code,
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
            return fail("E_REQUIRED", path .. "." .. key)
        end
    end

    for _, key in ipairs(optional) do allowed[key] = true end

    for key in next, value do
        if not allowed[key] then return fail("E_UNKNOWN_FIELD", path) end
    end
    return ok(true)
end

local function array(value, maximum, path)
    if not plain(value) then return fail("E_ARRAY", path) end
    local count, highest = 0, 0

    for key in next, value do
        count = count + 1
        if count > maximum or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > maximum then
            return fail("E_ARRAY", path)
        end
        if key > highest then highest = key end
    end

    if count ~= highest then return fail("E_ARRAY", path) end
    return ok(count)
end

local function text(value, limit)
    if type(value) ~= "string" or #value == 0 or #value > limit
        or value:match("^[ \t\r\n]*$")
        or utf8.len(value) == nil then
        return false
    end

    for i = 1, #value do
        local b = value:byte(i)
        if b == 127 or
            (b < 32 and b ~= 9 and b ~= 10 and b ~= 13) then
            return false
        end
    end
    return true
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local output = {}
    for key, item in next, value do output[key] = copy(item) end
    return output
end

local function validate(input)
    local r = shape(input,
        {"schema_version", "intents", "fields"}, {}, "input")
    if not r.ok then return r end

    if input.schema_version ~= 1 then
        return fail("E_SCHEMA", "input.schema_version")
    end

    r = array(input.intents, #INTENTS, "input.intents")
    if not r.ok then return r end
    if r.value == 0 then return fail("E_INTENT", "input.intents") end

    local intent_seen = {}
    for _, intent in ipairs(input.intents) do
        if type(intent) ~= "string" or not INTENT_SET[intent] then
            return fail("E_INTENT", "input.intents")
        end
        if intent_seen[intent] then
            return fail("E_DUPLICATE", "input.intents")
        end
        intent_seen[intent] = true
    end

    r = array(input.fields, #FIELDS, "input.fields")
    if not r.ok then return r end

    local field_seen = {}
    for _, field in ipairs(input.fields) do
        r = shape(field, {"name", "declaration"}, {"review"}, "input.fields")
        if not r.ok then return r end

        if type(field.name) ~= "string" or not FIELD_SET[field.name] then
            return fail("E_FIELD", "input.fields")
        end
        if field_seen[field.name] then
            return fail("E_DUPLICATE", "input.fields")
        end
        field_seen[field.name] = true

        local path = "input.fields." .. field.name
        r = shape(field.declaration, {"tag"}, {"text"}, path .. ".declaration")
        if not r.ok then return r end

        local declaration = field.declaration
        if type(declaration.tag) ~= "string" or not TAGS[declaration.tag] then
            return fail("E_TAG", path .. ".declaration.tag")
        end

        if declaration.tag == "supplied" then
            if not text(declaration.text, 4000) then
                return fail("E_TEXT", path .. ".declaration.text")
            end
        elseif rawget(declaration, "text") ~= nil then
            return fail("E_UNEXPECTED_CONTENT", path .. ".declaration")
        end

        if rawget(field, "review") ~= nil then
            local review = field.review
            r = shape(review, {
                "schema_version", "decision", "policy_version",
                "authority_reference", "question_scope"
            }, {}, path .. ".review")
            if not r.ok then return r end

            if review.schema_version ~= 1
                or (review.decision ~= "applicable"
                    and review.decision ~= "not_applicable"
                    and review.decision ~= "unresolved")
                or not text(review.policy_version, 160)
                or not text(review.authority_reference, 160)
                or not text(review.question_scope, 160) then
                return fail("E_REVIEW", path .. ".review")
            end
        end
    end
    return ok(true)
end

function M.normalize(input)
    local r = validate(input)
    if not r.ok then return r end

    local output = {schema_version = 1, intents = {}, fields = {}}
    local present_intents, fields = {}, {}

    for _, intent in ipairs(input.intents) do present_intents[intent] = true end
    for _, field in ipairs(input.fields) do fields[field.name] = field end

    for _, intent in ipairs(INTENTS) do
        if present_intents[intent] then
            output.intents[#output.intents + 1] = intent
        end
    end

    for _, name in ipairs(FIELDS) do
        if fields[name] then
            output.fields[#output.fields + 1] = copy(fields[name])
        end
    end

    return ok(output)
end

local function canonical_order(input, normalized)
    for i, intent in ipairs(input.intents) do
        if intent ~= normalized.intents[i] then return false end
    end
    for i, field in ipairs(input.fields) do
        if field.name ~= normalized.fields[i].name then return false end
    end
    return true
end

function M.review_projection(input)
    local r = M.normalize(input)
    if not r.ok then return r end

    local by_name = {}
    for _, field in ipairs(r.value.fields) do by_name[field.name] = field end

    local retained, excluded, unresolved, unreviewed = {}, {}, {}, {}
    local divergences = {}

    for _, name in ipairs(FIELDS) do
        local field = by_name[name]
        local review = field and field.review

        if not review then
            retained[#retained + 1] = name
            unreviewed[#unreviewed + 1] = name
        elseif review.decision == "not_applicable" then
            excluded[#excluded + 1] = name
        else
            retained[#retained + 1] = name
            if review.decision == "unresolved" then
                unresolved[#unresolved + 1] = name
            end
        end

        if review and review.decision == "applicable"
            and field.declaration.tag == "declared_not_applicable" then
            divergences[#divergences + 1] = {
                field = name,
                code = "R_DECLARATION_REVIEW_DIVERGENCE"
            }
        end
    end

    return ok({
        registered_required_fields = copy(FIELDS),
        recorded_retained_fields = retained,
        recorded_excluded_fields = excluded,
        unresolved_review_fields = unresolved,
        unreviewed_fields = unreviewed,
        divergences = divergences,
        authority_verified = false,
        applicability_justified = false,
        denominator_change_authorized = false,
        assessment_scope = "submitted_review_projection_only"
    })
end

function M.screen(input)
    local normalized = M.normalize(input)
    if not normalized.ok then return normalized end

    if not canonical_order(input, normalized.value) then
        return fail("E_NOT_NORMALIZED", "input")
    end

    local by_name, clarifications = {}, {}
    for _, field in ipairs(input.fields) do by_name[field.name] = field end

    local declared, supplied = 0, 0

    for _, name in ipairs(FIELDS) do
        local field = by_name[name]
        local tag = field and field.declaration.tag or "absent"

        if field then declared = declared + 1 end
        if tag == "supplied" then
            supplied = supplied + 1
        else
            clarifications[#clarifications + 1] = {
                field = name,
                declaration_tag = tag,
                message_key = "applicability_normalization_screen.clarify",
                args = {field = name, declaration_tag = tag},
                participation_required = false
            }
        end
    end

    return ok({
        outcome = supplied == #FIELDS
            and "structurally_accepted"
            or "accepted_with_clarifications",
        contract_version = M.CONTRACT_VERSION,
        required_count = #FIELDS,
        declared_count = declared,
        supplied_count = supplied,
        denominator_scope = "registered_required_fields",
        declaration_ratio = declared / #FIELDS,
        supplied_ratio = supplied / #FIELDS,
        clarifications = clarifications,
        assessment_scope = "structural_only",
        scientific_support_assessed = false,
        authority_assessed = false
    })
end

function M.evaluate(input)
    local normalized = M.normalize(input)
    if not normalized.ok then return normalized end
    return M.screen(normalized.value)
end

function M.message_contracts()
    local errors = {}
    for code in next, ERRORS do errors[#errors + 1] = code end
    table.sort(errors)

    return ok({
        contract_version = M.CONTRACT_VERSION,
        error_codes = errors,
        error_argument_roles = {},
        clarification_message_key =
            "applicability_normalization_screen.clarify",
        clarification_argument_roles = {"field", "declaration_tag"},
        argument_values = "registered_names_and_tags_only",
        rendering_supplied = false
    })
end

return M
