-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later.
-- Local structural and declaration-compatibility screening only.
-- No I/O, networking, storage, retrieval, or actuation.
--
-- Credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.

local M = {
    VERSION = "1.0.0",
    SCHEMA_VERSION = 1,
    RULE_SET_VERSION = "1.0.0"
}

local MAX_RECORDS = 32
local MAX_TEXT_BYTES = 4000

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "declaration_compatibility." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function record(value, required, optional, path)
    if not plain(value) then
        return fail("E_RECORD", path)
    end

    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return fail("E_REQUIRED_FIELD", path .. "." .. key)
        end
    end
    for _, key in ipairs(optional) do
        allowed[key] = true
    end

    local count = 0
    local limit = #required + #optional
    for key in next, value do
        count = count + 1
        if count > limit or not allowed[key] then
            return fail("E_UNKNOWN_FIELD", path)
        end
    end
    return ok(true)
end

local function enum(value, values, path)
    if type(value) ~= "string" then
        return fail("E_ENUM", path)
    end
    for _, candidate in ipairs(values) do
        if value == candidate then
            return ok(true)
        end
    end
    return fail("E_ENUM", path)
end

local function text(value, limit, path)
    if type(value) ~= "string" then
        return fail("E_TEXT_TYPE", path)
    end
    if #value == 0 or not value:find("%S") then
        return fail("E_TEXT_EMPTY", path)
    end
    if #value > limit then
        return fail("E_TEXT_LIMIT", path)
    end
    if utf8.len(value) == nil then
        return fail("E_TEXT_UTF8", path)
    end
    for i = 1, #value do
        local byte = value:byte(i)
        if byte == 127 or
            (byte < 32 and byte ~= 9 and byte ~= 10 and byte ~= 13) then
            return fail("E_TEXT_CONTROL", path)
        end
    end
    return ok(true)
end

local function tagged(value, values, path)
    local result = record(value, {"tag"}, {}, path)
    if not result.ok then return result end
    return enum(value.tag, values, path .. ".tag")
end

local function array_length(value, path)
    if not plain(value) then
        return fail("E_ARRAY", path)
    end

    local count, maximum = 0, 0
    for key in next, value do
        count = count + 1
        if count > MAX_RECORDS then
            return fail("E_RECORD_LIMIT", path)
        end
        if type(key) ~= "number" or key % 1 ~= 0 or
            key < 1 or key > MAX_RECORDS then
            return fail("E_ARRAY", path)
        end
        if key > maximum then maximum = key end
    end

    if maximum ~= count then
        return fail("E_ARRAY", path)
    end
    return ok(count)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in next, value do
        result[key] = copy(item)
    end
    return result
end

local function validate_record(value, path)
    local result = record(value, {
        "target", "availability", "collection",
        "knowledge", "applicability", "permission"
    }, {}, path)
    if not result.ok then return result end

    result = record(value.target,
        {"role", "kind", "label"}, {}, path .. ".target")
    if not result.ok then return result end

    result = enum(value.target.role, {
        "field_content", "supporting_evidence"
    }, path .. ".target.role")
    if not result.ok then return result end

    result = enum(value.target.kind, {
        "proposition", "measured_record", "description"
    }, path .. ".target.kind")
    if not result.ok then return result end

    result = text(value.target.label, 160, path .. ".target.label")
    if not result.ok then return result end

    result = record(value.availability,
        {"tag"}, {"text"}, path .. ".availability")
    if not result.ok then return result end

    result = enum(value.availability.tag, {
        "supplied", "withheld", "unspecified"
    }, path .. ".availability.tag")
    if not result.ok then return result end

    if value.availability.tag == "supplied" then
        result = text(value.availability.text,
            MAX_TEXT_BYTES, path .. ".availability.text")
        if not result.ok then return result end
    elseif rawget(value.availability, "text") ~= nil then
        return fail("E_UNEXPECTED_CONTENT", path .. ".availability")
    end

    result = tagged(value.collection, {
        "collected", "not_collected", "unknown", "unspecified"
    }, path .. ".collection")
    if not result.ok then return result end

    result = record(value.knowledge,
        {"tag", "basis"}, {}, path .. ".knowledge")
    if not result.ok then return result end

    result = enum(value.knowledge.tag, {
        "known", "unknown", "unspecified"
    }, path .. ".knowledge.tag")
    if not result.ok then return result end

    result = enum(value.knowledge.basis, {
        "same_target_measurement", "inference",
        "source_report", "unspecified"
    }, path .. ".knowledge.basis")
    if not result.ok then return result end

    result = tagged(value.applicability, {
        "applicable", "declared_not_applicable", "unresolved"
    }, path .. ".applicability")
    if not result.ok then return result end

    result = record(value.permission, {
        "tag", "operation", "purpose"
    }, {}, path .. ".permission")
    if not result.ok then return result end

    result = enum(value.permission.tag, {
        "permitted", "not_permitted", "undetermined"
    }, path .. ".permission.tag")
    if not result.ok then return result end

    result = enum(value.permission.operation, {
        "analysis", "storage", "publication", "translation"
    }, path .. ".permission.operation")
    if not result.ok then return result end

    return text(value.permission.purpose,
        160, path .. ".permission.purpose")
end

local function same_target(left, right)
    return left.target.role == right.target.role
        and left.target.kind == right.target.kind
        and left.target.label == right.target.label
end

function M.evaluate(input)
    local result = record(input,
        {"schema_version", "records"}, {}, "input")
    if not result.ok then return result end

    if input.schema_version ~= M.SCHEMA_VERSION then
        return fail("E_SCHEMA_VERSION", "input.schema_version")
    end

    result = array_length(input.records, "input.records")
    if not result.ok then return result end
    local count = result.value

    for i = 1, count do
        result = validate_record(
            input.records[i], "input.records[" .. i .. "]")
        if not result.ok then return result end
    end

    local conflicts, reviews, permissions = {}, {}, {}

    local function add(list, code, first, second)
        local item = {
            code = code,
            record_positions = {first}
        }
        if second then
            item.record_positions[2] = second
        end
        list[#list + 1] = item
    end

    for i = 1, count do
        local item = input.records[i]

        if item.target.kind == "measured_record"
            and item.availability.tag == "supplied"
            and item.collection.tag == "not_collected" then
            add(conflicts, "C_SUPPLIED_MEASUREMENT_NOT_COLLECTED", i)
        end

        if item.knowledge.tag == "known"
            and item.knowledge.basis == "same_target_measurement"
            and item.collection.tag == "not_collected" then
            add(conflicts, "C_KNOWN_FROM_UNCOLLECTED_TARGET", i)
        end

        if item.knowledge.tag == "known"
            and item.knowledge.basis == "unspecified" then
            add(reviews, "R_KNOWLEDGE_BASIS_UNSPECIFIED", i)
        end

        if item.applicability.tag == "declared_not_applicable" then
            add(reviews, "R_APPLICABILITY_NOT_REVIEWED", i)
        end

        permissions[#permissions + 1] = {
            record_position = i,
            declared_status = item.permission.tag,
            operation = item.permission.operation,
            authority_assessed_here = false,
            action_authorized_here = false
        }
    end

    for i = 1, count do
        for j = i + 1, count do
            local left, right = input.records[i], input.records[j]
            if same_target(left, right) then
                local lc, rc = left.collection.tag, right.collection.tag
                if (lc == "collected" and rc == "not_collected")
                    or (lc == "not_collected" and rc == "collected") then
                    add(conflicts, "C_COLLECTION_DECLARATIONS_CONFLICT", i, j)
                end

                local la, ra = left.availability.tag, right.availability.tag
                if (la == "supplied" and ra == "withheld")
                    or (la == "withheld" and ra == "supplied") then
                    add(conflicts, "C_AVAILABILITY_DECLARATIONS_CONFLICT", i, j)
                end

                local lp, rp = left.permission, right.permission
                if lp.operation == rp.operation and lp.purpose == rp.purpose
                    and ((lp.tag == "permitted" and rp.tag == "not_permitted")
                    or (lp.tag == "not_permitted" and rp.tag == "permitted")) then
                    add(conflicts, "C_PERMISSION_DECLARATIONS_CONFLICT", i, j)
                end
            end
        end
    end

    return ok({
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        rule_set_version = M.RULE_SET_VERSION,
        outcome = #conflicts > 0
            and "incompatible_declarations"
            or "no_declared_conflict",
        record_count = count,
        records = copy(input.records),
        conflicts = conflicts,
        review_items = reviews,
        permission_declarations = permissions,
        assessment_scope = "declared_compatibility_only",
        interpretation_limits = {
            semantic_independence_proven = false,
            scientific_support_assessed = false,
            truth_assessed = false,
            authority_assessed = false,
            completeness_established = false
        }
    })
end

return M
