-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later. Standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local nominal comparison and coverage; no I/O or storage.

if type(utf8) ~= "table" or type(utf8.len) ~= "function" then
    error("ENV_UTF8_LIBRARY_REQUIRED", 0)
end

local M = {
    VERSION = "1.0.0",
    RULE_SET_VERSION = "1.0.0"
}

local LIMIT = 128

local VALUES = {
    availability = {
        supplied = true, withheld = true, unspecified = true
    },
    collection = {
        collected = true, not_collected = true,
        unknown = true, unspecified = true
    },
    knowledge = {
        known = true, unknown = true, unspecified = true
    },
    applicability = {
        applicable = true,
        declared_not_applicable = true,
        unresolved = true
    }
}

local STATES = {
    "supplied", "unknown", "not_collected", "withheld",
    "declared_not_applicable", "absent"
}

local STATE_SET = {}
for _, state in ipairs(STATES) do STATE_SET[state] = true end

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "assertion_order_coverage." .. code,
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
            return fail("E_REQUIRED_FIELD", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end

    for key in next, value do
        if not allowed[key] then return fail("E_UNKNOWN_FIELD", path) end
    end
    return ok(true)
end

local function text(value)
    if type(value) ~= "string" or #value == 0 or #value > 512 then
        return false
    end
    if value:match("^[ \t\r\n]*$") or utf8.len(value) == nil then
        return false
    end
    for i = 1, #value do
        local byte = value:byte(i)
        if byte < 32 or byte == 127 then return false end
    end
    return true
end

local function array(value, path)
    if not plain(value) then return fail("E_ARRAY", path) end

    local count, maximum = 0, 0
    for key in next, value do
        count = count + 1
        if count > LIMIT or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > LIMIT then
            return fail("E_ARRAY", path)
        end
        if key > maximum then maximum = key end
    end

    if count ~= maximum then return fail("E_ARRAY", path) end
    return ok(count)
end

local function tuple_key(parts)
    local output = {}
    for i, part in ipairs(parts) do
        output[i] = tostring(#part) .. ":" .. part
    end
    return table.concat(output)
end

local function canonical(frame)
    local result = shape(frame, {"assertions"}, {}, "frame")
    if not result.ok then return result end

    result = array(frame.assertions, "frame.assertions")
    if not result.ok then return result end

    local set, selected, conflicts = {}, {}, {}

    for i = 1, result.value do
        local assertion = frame.assertions[i]
        local path = "frame.assertions[" .. i .. "]"

        local checked = shape(assertion,
            {"scope", "property", "value", "source"}, {}, path)
        if not checked.ok then return checked end

        if not text(assertion.scope) or not text(assertion.source) then
            return fail("E_ASSERTION_TEXT", path)
        end

        if type(assertion.property) ~= "string"
            or not VALUES[assertion.property] then
            return fail("E_PROPERTY", path .. ".property")
        end

        if type(assertion.value) ~= "string"
            or not VALUES[assertion.property][assertion.value] then
            return fail("E_NOMINAL_VALUE", path .. ".value")
        end

        local group = tuple_key({
            assertion.scope, assertion.property
        })

        local first = selected[group]
        if first and first.value ~= assertion.value then
            conflicts[#conflicts + 1] = {
                code = "C_SINGLE_VALUED_PROPERTY",
                first_position = first.position,
                second_position = i
            }
        elseif not first then
            selected[group] = {
                value = assertion.value,
                position = i
            }
        end

        set[tuple_key({
            assertion.scope,
            assertion.property,
            assertion.value,
            assertion.source
        })] = true
    end

    return ok({set = set, conflicts = conflicts})
end

local function subset(left, right)
    for key in next, left do
        if not right[key] then return false end
    end
    return true
end

function M.compare(left, right)
    local a = canonical(left)
    if not a.ok then return a end

    local b = canonical(right)
    if not b.ok then return b end

    local relation
    if #a.value.conflicts > 0 or #b.value.conflicts > 0 then
        relation = "blocked_by_declared_conflict"
    else
        local ab = subset(a.value.set, b.value.set)
        local ba = subset(b.value.set, a.value.set)

        if ab and ba then
            relation = "equivalent_assertion_sets"
        elseif ab then
            relation = "right_extends_left"
        elseif ba then
            relation = "left_extends_right"
        else
            relation = "incomparable"
        end
    end

    return ok({
        relation = relation,
        left_conflicts = a.value.conflicts,
        right_conflicts = b.value.conflicts,
        rule_set_version = M.RULE_SET_VERSION,
        comparison_scope = "recorded_assertion_preservation",
        scientific_merit_assessed = false,
        permission_assessed = false
    })
end

function M.coverage(input)
    local result = shape(input, {
        "field_set_version", "intent_interpretation",
        "denominator_scope", "required_fields", "states"
    }, {"applicability_review_reference"}, "input")
    if not result.ok then return result end

    if not text(input.field_set_version)
        or not text(input.intent_interpretation) then
        return fail("E_METADATA", "input")
    end

    local scope = input.denominator_scope
    if scope ~= "registered_required_fields"
        and scope ~= "reviewed_applicable_required_fields" then
        return fail("E_DENOMINATOR_SCOPE", "input.denominator_scope")
    end

    if scope == "reviewed_applicable_required_fields"
        and not text(input.applicability_review_reference) then
        return fail("E_REVIEW_REFERENCE", "input")
    end

    if scope == "registered_required_fields"
        and rawget(input, "applicability_review_reference") ~= nil then
        return fail("E_UNEXPECTED_REVIEW_REFERENCE", "input")
    end

    result = array(input.required_fields, "input.required_fields")
    if not result.ok then return result end
    local count = result.value

    if not plain(input.states) then
        return fail("E_RECORD", "input.states")
    end

    local fields, partition, counts = {}, {}, {}
    for _, state in ipairs(STATES) do
        partition[state], counts[state] = {}, 0
    end

    for i = 1, count do
        local field = input.required_fields[i]
        if not text(field) then
            return fail("E_FIELD_NAME", "input.required_fields")
        end
        if fields[field] then
            return fail("E_DUPLICATE_FIELD", "input.required_fields")
        end
        fields[field] = true
    end

    for field, state in next, input.states do
        if not fields[field] then
            return fail("E_UNKNOWN_FIELD", "input.states")
        end
        if type(state) ~= "string" or not STATE_SET[state] then
            return fail("E_DECLARATION_STATE", "input.states")
        end
    end

    for i = 1, count do
        local field = input.required_fields[i]
        local state = rawget(input.states, field) or "absent"
        local bucket = partition[state]
        bucket[#bucket + 1] = field
        counts[state] = counts[state] + 1
    end

    local declared = count - counts.absent
    local supplied = counts.supplied
    local ratios

    if count == 0 then
        ratios = {
            status = "undefined",
            reason = "zero_denominator"
        }
    else
        ratios = {
            status = "defined",
            declaration = declared / count,
            supplied = supplied / count
        }
    end

    return ok({
        field_set_version = input.field_set_version,
        intent_interpretation = input.intent_interpretation,
        denominator_scope = scope,
        applicability_review_reference =
            input.applicability_review_reference,
        applicability_review_verified = false,
        required_count = count,
        declared_count = declared,
        supplied_count = supplied,
        counts = counts,
        partition = partition,
        ratios = ratios,
        assessment_scope = "representation_coverage_only"
    })
end

return M
