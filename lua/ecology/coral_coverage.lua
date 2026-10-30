-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Retain this attribution notice in derivatives.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Local calculations only; no I/O, persistence, or external actions.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}
local HARD_CLASSES, HARD_TOTAL = 10000, 1000000

local function success(value)
    return {ok = true, value = value, error = false}
end

local function failure(code, path, args, category)
    return {
        ok = false, value = false,
        error = {
            code = code, field_path = path,
            message_key = "coral_coverage." .. code,
            args = args or {},
            category = category or "validation"
        }
    }
end

local function finite(v)
    -- Reject NaN and both infinities; no numeric coercion is performed.
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function integer(v, low, high)
    return finite(v) and v % 1 == 0 and v >= low and v <= high
end

local function ascii(v, maximum)
    if type(v) ~= "string" or #v == 0 or #v > maximum then
        return false
    end
    if not v:match("%S") then return false end
    for i = 1, #v do
        local byte = v:byte(i)
        if byte < 32 or byte > 126 then return false end
    end
    return true
end

local function key_args(key)
    local kind = type(key)
    if kind == "number" then
        return {key_type = kind, numeric_key = tostring(key)}
    end
    return {
        key_type = kind,
        key_length = kind == "string" and #key or 0
    }
end

local function sequence(v, limit, path)
    if not integer(limit, 1, HARD_CLASSES) then
        return failure("E_LIMIT", path, {maximum = HARD_CLASSES})
    end
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return failure("E_SEQUENCE", path, {expected = "plain_table"})
    end

    local wrong_type, fractional, nonpositive, over
    local count, highest = 0, 0
    for key in pairs(v) do
        if type(key) ~= "number" then
            wrong_type = true
        elseif not finite(key) or key % 1 ~= 0 then
            if fractional == nil or key < fractional then fractional = key end
        elseif key < 1 then
            if nonpositive == nil or key < nonpositive then nonpositive = key end
        elseif key > limit then
            if over == nil or key < over then over = key end
        else
            count = count + 1
            highest = math.max(highest, key)
        end
    end

    -- Error-category precedence is fixed, independent of table iteration.
    if wrong_type then
        return failure("E_INDEX_TYPE", path, {expected = "numeric_index"})
    end
    if fractional ~= nil then
        return failure("E_INDEX_INTEGER", path, key_args(fractional))
    end
    if nonpositive ~= nil then
        return failure("E_INDEX_POSITIVE", path, key_args(nonpositive))
    end
    if over ~= nil then
        return failure("E_CAPACITY", path,
            {numeric_key = tostring(over), maximum = limit})
    end
    if count == 0 then return failure("E_EMPTY", path) end
    if highest ~= count then
        local missing = 1
        while rawget(v, missing) ~= nil do missing = missing + 1 end
        return failure("E_SEQUENCE_GAP", path,
            {missing_index = missing, highest_index = highest})
    end
    return success(count)
end

local SCHEMA = {
    {name = "schema_version", kind = "integer", low = 1, high = 1},
    {name = "scope", kind = "text", maximum = 240},
    {name = "sampling_model", kind = "enum", values = {
        "multinomial_abundance", "curated_inventory",
        "clustered_unmodeled", "size_biased_unmodeled", "unknown"
    }},
    {name = "sampling_basis", kind = "text", maximum = 1000},
    {name = "class_capacity", kind = "integer", low = 1, high = HARD_CLASSES},
    {name = "counts", kind = "sequence", limit_field = "class_capacity"},
    {name = "extensions", kind = "extensions"}
}

local function validate_record(v, schema, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return failure("E_RECORD", path, {expected = "plain_table"})
    end
    local allowed = {}
    for _, field in ipairs(schema) do
        allowed[field.name] = true
        if rawget(v, field.name) == nil then
            return failure("E_MISSING", path .. "." .. field.name)
        end
    end

    -- Non-string keys have fixed priority. String keys are sorted.
    local unknown = {}
    local nonstring = false
    for key in pairs(v) do
        if type(key) ~= "string" then nonstring = true
        elseif not allowed[key] then unknown[#unknown + 1] = key end
    end
    if nonstring then
        return failure("E_FIELD_KEY_TYPE", path, {expected = "string"})
    end
    table.sort(unknown)
    if #unknown > 0 then
        return failure("E_UNKNOWN_FIELD", path, key_args(unknown[1]))
    end

    for _, field in ipairs(schema) do
        local value, p = v[field.name], path .. "." .. field.name
        if field.kind == "integer" then
            if not integer(value, field.low, field.high) then
                return failure("E_INTEGER", p,
                    {minimum = field.low, maximum = field.high})
            end
        elseif field.kind == "text" then
            if not ascii(value, field.maximum) then
                return failure("E_ASCII_TEXT", p,
                    {maximum_bytes = field.maximum})
            end
        elseif field.kind == "enum" then
            local accepted = false
            for _, option in ipairs(field.values) do
                if value == option then accepted = true end
            end
            if not accepted then return failure("E_ENUM", p) end
        elseif field.kind == "sequence" then
            local r = sequence(value, v[field.limit_field], p)
            if not r.ok then return r end
        elseif field.kind == "extensions" then
            if type(value) ~= "table" or getmetatable(value) ~= nil then
                return failure("E_EXTENSIONS", p)
            end
            local keys = {}
            for key in pairs(value) do
                if not ascii(key, 80) then
                    return failure("E_EXTENSION_KEY", p)
                end
                keys[#keys + 1] = key
            end
            table.sort(keys)
            if #keys > 32 then
                return failure("E_EXTENSION_LIMIT", p, {maximum = 32})
            end
            for _, key in ipairs(keys) do
                if not ascii(value[key], 240) then
                    return failure("E_EXTENSION_VALUE", p,
                        {maximum_bytes = 240})
                end
            end
        else
            return failure("E_INTERNAL_SCHEMA", p, {}, "internal")
        end
    end
    return success(true)
end

function M.evaluate(input)
    local checked = validate_record(input, SCHEMA, "input")
    if not checked.ok then return checked end
    if input.sampling_model ~= "multinomial_abundance" then
        return failure("E_SAMPLING_INCOMPATIBLE", "input.sampling_model",
            {required_model = "multinomial_abundance"}, "domain")
    end

    local counts, total, f1, f2 = {}, 0, 0, 0
    for i, count in ipairs(input.counts) do
        if not integer(count, 1, HARD_TOTAL) then
            return failure("E_COUNT", "input.counts[" .. i .. "]",
                {minimum = 1, maximum = HARD_TOTAL})
        end
        total = total + count
        if total > HARD_TOTAL then
            return failure("E_TOTAL_LIMIT", "input.counts",
                {maximum = HARD_TOTAL})
        end
        counts[i] = count
        if count == 1 then f1 = f1 + 1 end
        if count == 2 then f2 = f2 + 1 end
    end
    if total < 2 then
        return failure("E_INSUFFICIENT_SAMPLE", "input.counts",
            {minimum_total = 2}, "insufficient_data")
    end

    local coverage, branch
    if f1 == 0 then
        coverage, branch = 1, "no_singletons"
    elseif f2 > 0 then
        local numerator = (total - 1) * f1
        coverage = 1 - (f1 / total) * numerator / (numerator + 2 * f2)
        branch = "positive_doubletons"
    else
        local numerator = (total - 1) * (f1 - 1)
        coverage = 1 - (f1 / total) * numerator / (numerator + 2)
        branch = "zero_doubletons"
    end

    local correction = (total - 1) / total
    local unseen
    if f2 > 0 then
        unseen = correction * f1 * f1 / (2 * f2)
    else
        unseen = correction * f1 * (f1 - 1) / 2
    end

    local metadata = {}
    for key, value in pairs(input.extensions) do metadata[key] = value end

    return success({
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = "screen_abundance_coverage_estimate",
        scope = input.scope,
        sampling_model = input.sampling_model,
        sampling_basis = input.sampling_basis,
        counts = counts,
        extensions = metadata,
        sample_total = total,
        observed_genotypes = #counts,
        singletons = f1,
        doubletons = f2,
        sample_coverage = coverage,
        coverage_branch = branch,
        richness_lower_bound_estimate = #counts + unseen,
        estimator_variant = "Chao_Appendix_G_finite_sample",
        limits = {
            maximum_classes = HARD_CLASSES,
            declared_class_capacity = input.class_capacity,
            maximum_sample_total = HARD_TOTAL
        },
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            establishes_identity = false,
            establishes_consent = false,
            grants_authority = false,
            persistent_storage_performed = false
        },
        interpretation_limits = {
            sampling_design_verified = false,
            confidence_interval_computed = false,
            rarefaction_performed = false,
            small_sample_stability_verified = false,
            biological_recovery_established = false,
            external_action_authorized = false
        }
    })
end

return M
