-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 2.0.0; schema 1.
-- Retain this credit notice in copies and derivative distributions.
-- Sovereign-attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Attribution is credit only: no authority, consent, or identity verification.
-- Local interval screening only; no I/O, persistence, or external actions.

local M = { VERSION = "2.0.0", SCHEMA_VERSION = 1 }

local function describe(v)
    local t = type(v)
    if t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    end
    if t == "string" then
        return "string(length=" .. #v .. ")"
    end
    return "<" .. t .. ">"
end

local function err(code, path, value)
    return {
        code = code,
        path = path,
        value_description = describe(value),
        message_key = "ecology." .. code,
        category = "validation"
    }
end

local function finite(v)
    -- NaN is the only numeric value unequal to itself.
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function text(v)
    return type(v) == "string" and v:match("%S") ~= nil
end

local function record(v, required, optional, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return err("E_RECORD", path, v)
    end
    for key in pairs(required) do
        if rawget(v, key) == nil then
            return err("E_MISSING", path .. "." .. key, nil)
        end
    end
    for key in pairs(v) do
        if not required[key] and not optional[key] then
            return err("E_UNKNOWN_FIELD",
                path .. "[" .. tostring(key) .. "]", v[key])
        end
    end
end

local function sequence(v, limit, path)
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return nil, err("E_SEQUENCE", path, v)
    end
    local count, highest = 0, 0
    for key in pairs(v) do
        if type(key) ~= "number" then
            return nil, err("E_INDEX_TYPE", path, key)
        end
        if not finite(key) or key % 1 ~= 0 then
            return nil, err("E_INDEX_INTEGER", path, key)
        end
        if key < 1 then
            return nil, err("E_INDEX_POSITIVE", path, key)
        end
        if key > limit then
            return nil, err("E_SIZE_LIMIT", path, key)
        end
        count = count + 1
        highest = math.max(highest, key)
    end
    if count == 0 then
        return nil, err("E_EMPTY", path, count)
    end
    -- Nonempty sequences have exactly the integer keys 1 through count.
    if highest ~= count then
        return nil, err("E_SEQUENCE_GAP", path, highest)
    end
    return count
end

local function extensions(v, path)
    if v == nil then return end
    if type(v) ~= "table" or getmetatable(v) ~= nil then
        return err("E_EXTENSIONS", path, v)
    end
    for key, value in pairs(v) do
        if not text(key) or not text(value) then
            return err("E_EXTENSION_TEXT", path, value)
        end
    end
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for key, value in pairs(v) do out[key] = copy(value) end
    return out
end

local function in_domain(v, domain)
    if domain == "positive" then return v > 0 end
    if domain == "unit_interval" then return v >= 0 and v <= 1 end
    return domain == "real"
end

function M.evaluate(input)
    local e = record(input, {
        schema_version = true, scope = true, max_metrics = true,
        required_domains = true, allow_synthetic = true, metrics = true
    }, {extensions = true}, "input")
    if e then return nil, e end

    if input.schema_version ~= M.SCHEMA_VERSION then
        return nil, err("E_SCHEMA_VERSION",
            "input.schema_version", input.schema_version)
    end
    if not text(input.scope) then
        return nil, err("E_TEXT", "input.scope", input.scope)
    end
    if not finite(input.max_metrics) or input.max_metrics % 1 ~= 0
        or input.max_metrics < 1 or input.max_metrics > 10000 then
        return nil, err("E_LIMIT_RANGE", "input.max_metrics",
            input.max_metrics)
    end
    if type(input.allow_synthetic) ~= "boolean" then
        return nil, err("E_BOOLEAN", "input.allow_synthetic",
            input.allow_synthetic)
    end
    e = extensions(input.extensions, "input.extensions")
    if e then return nil, e end

    local n, se = sequence(input.required_domains,
        input.max_metrics, "input.required_domains")
    if se then return nil, se end
    local expected = {}
    for i = 1, n do
        local domain = input.required_domains[i]
        if not text(domain) then
            return nil, err("E_TEXT",
                "input.required_domains[" .. i .. "]", domain)
        end
        if expected[domain] then
            return nil, err("E_DUPLICATE_DOMAIN",
                "input.required_domains[" .. i .. "]", domain)
        end
        expected[domain] = true
    end

    local m
    m, se = sequence(input.metrics, input.max_metrics, "input.metrics")
    if se then return nil, se end

    local results, failing, unresolved, seen = {}, {}, {}, {}
    local provenance = {
        literature = true, policy = true,
        precision_based = true, synthetic = true
    }
    local modes = {two_sided = true, lower_only = true, upper_only = true}

    for i = 1, m do
        local x = input.metrics[i]
        local path = "input.metrics[" .. i .. "]"
        e = record(x, {
            schema_version = true, domain_name = true, metric_domain = true,
            units = true, estimate = true, interval_lower = true,
            interval_upper = true, interval_basis = true, bounds_mode = true,
            bounds_provenance = true, bounds_basis = true
        }, {
            acceptable_lower = true, acceptable_upper = true,
            extensions = true
        }, path)
        if e then return nil, e end
        if x.schema_version ~= M.SCHEMA_VERSION then
            return nil, err("E_SCHEMA_VERSION",
                path .. ".schema_version", x.schema_version)
        end
        for _, key in ipairs({
            "domain_name", "units", "interval_basis", "bounds_basis"
        }) do
            if not text(x[key]) then
                return nil, err("E_TEXT", path .. "." .. key, x[key])
            end
        end
        if not expected[x.domain_name] then
            return nil, err("E_UNEXPECTED_DOMAIN",
                path .. ".domain_name", x.domain_name)
        end
        if seen[x.domain_name] then
            return nil, err("E_DUPLICATE_DOMAIN",
                path .. ".domain_name", x.domain_name)
        end
        seen[x.domain_name] = true
        if x.metric_domain ~= "positive"
            and x.metric_domain ~= "unit_interval"
            and x.metric_domain ~= "real" then
            return nil, err("E_METRIC_DOMAIN",
                path .. ".metric_domain", x.metric_domain)
        end
        if not modes[x.bounds_mode] then
            return nil, err("E_BOUNDS_MODE",
                path .. ".bounds_mode", x.bounds_mode)
        end
        if not provenance[x.bounds_provenance] then
            return nil, err("E_PROVENANCE",
                path .. ".bounds_provenance", x.bounds_provenance)
        end
        e = extensions(x.extensions, path .. ".extensions")
        if e then return nil, e end

        local needs_lower = x.bounds_mode ~= "upper_only"
        local needs_upper = x.bounds_mode ~= "lower_only"
        for _, spec in ipairs({
            {"acceptable_lower", needs_lower},
            {"acceptable_upper", needs_upper}
        }) do
            if spec[2] and x[spec[1]] == nil then
                return nil, err("E_MISSING", path .. "." .. spec[1], nil)
            elseif not spec[2] and x[spec[1]] ~= nil then
                return nil, err("E_UNUSED_BOUND",
                    path .. "." .. spec[1], x[spec[1]])
            end
        end

        for _, key in ipairs({
            "estimate", "interval_lower", "interval_upper",
            "acceptable_lower", "acceptable_upper"
        }) do
            if x[key] ~= nil then
                if not finite(x[key]) then
                    return nil, err("E_FINITE", path .. "." .. key, x[key])
                end
                if not in_domain(x[key], x.metric_domain) then
                    return nil, err("E_DOMAIN", path .. "." .. key, x[key])
                end
            end
        end

        if x.interval_lower > x.estimate
            or x.estimate > x.interval_upper then
            return nil, err("E_INTERVAL_ORDER", path, x.estimate)
        end
        if needs_lower and needs_upper
            and x.acceptable_lower >= x.acceptable_upper then
            return nil, err("E_BOUNDS_ORDER", path, x.acceptable_lower)
        end

        local within = (not needs_lower
            or x.interval_lower >= x.acceptable_lower)
            and (not needs_upper
            or x.interval_upper <= x.acceptable_upper)
        local outside = (needs_lower
            and x.interval_upper < x.acceptable_lower)
            or (needs_upper and x.interval_lower > x.acceptable_upper)

        local status
        if x.bounds_provenance == "synthetic"
            and not input.allow_synthetic then
            status = "screen_excluded_synthetic_bounds"
            unresolved[#unresolved + 1] = x.domain_name
        elseif within then
            status = "screen_within_bounds"
        elseif outside then
            status = "screen_outside_bounds"
            failing[#failing + 1] = x.domain_name
        else
            status = "screen_unresolved_overlap"
            unresolved[#unresolved + 1] = x.domain_name
        end
        results[#results + 1] = {
            domain_name = x.domain_name, status = status, input = copy(x)
        }
    end

    for _, domain in ipairs(input.required_domains) do
        if not seen[domain] then
            unresolved[#unresolved + 1] = domain
            results[#results + 1] = {
                domain_name = domain, status = "screen_missing_domain",
                input = false
            }
        end
    end

    local all_within = #failing == 0 and #unresolved == 0
    local status = "screen_all_required_within_bounds"
    if #failing > 0 then
        status = "screen_required_domain_outside_bounds"
    elseif #unresolved > 0 then
        status = "screen_joint_unresolved"
    end

    return {
        module_version = M.VERSION,
        schema_version = M.SCHEMA_VERSION,
        status = status,
        all_required_screens_within = all_within,
        failing_domains = failing,
        unresolved_domains = unresolved,
        screens = results,
        input = copy(input),
        interpretation_limits = {
            logical_conjunction_only = true,
            interval_generation_not_verified = true,
            preregistration_not_verified = true,
            joint_statistical_inference_performed = false,
            habitat_function_certified = false,
            external_action_authorized = false
        }
    }
end

return M
