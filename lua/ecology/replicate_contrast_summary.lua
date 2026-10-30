-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, identity verification, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local arithmetic only; no I/O, storage, fitting, or external actions.

local M = {VERSION = "1.0.0"}
local HARD_LIMIT = 10000

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "replicate_summary." .. code,
        args = {}, category = "validation"
    }}
end

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

function M.evaluate(x)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", "input")
    end
    local fields = {"schema_version", "independence_declaration", "contrasts"}
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(x, key) == nil then return bad("E_MISSING", "input." .. key) end
    end
    for key in pairs(x) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", "input") end
    end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if x.independence_declaration ~= "independent_units_common_estimand" then
        return bad("E_DESIGN_DECLARATION", "input.independence_declaration")
    end
    local values = x.contrasts
    if type(values) ~= "table" or getmetatable(values) ~= nil then
        return bad("E_SEQUENCE", "input.contrasts")
    end

    local count, highest = 0, 0
    for key in pairs(values) do
        if not finite(key) or key % 1 ~= 0 or key < 1 or key > HARD_LIMIT then
            return bad("E_SEQUENCE_INDEX", "input.contrasts")
        end
        count, highest = count + 1, math.max(highest, key)
    end
    if count == 0 then return bad("E_EMPTY", "input.contrasts") end
    if count ~= highest then return bad("E_SEQUENCE_GAP", "input.contrasts") end

    local mean, m2, copied = 0, 0, {}
    for i = 1, count do
        local value = values[i]
        if not finite(value) then
            return bad("E_FINITE", "input.contrasts[" .. i .. "]")
        end
        local delta = value - mean
        mean = mean + delta / i
        m2 = m2 + delta * (value - mean)
        if not finite(mean) or not finite(m2) then
            return bad("E_NUMERIC_RANGE", "input.contrasts")
        end
        copied[i] = value
    end
    if m2 < 0 then return bad("E_NEGATIVE_VARIANCE", "input.contrasts") end

    local result = {
        module_version = M.VERSION,
        schema_version = 1,
        status = count >= 2 and "screen_replicated_contrast_summary"
            or "screen_single_contrast_no_variance",
        count = count,
        mean = mean,
        contrasts = copied,
        independence_declaration = x.independence_declaration,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            grants_authority = false,
            establishes_consent = false
        },
        interpretation_limits = {
            independence_verified = false,
            common_estimand_verified = false,
            confidence_interval_computed = false,
            causal_effect_established = false,
            ecological_recovery_established = false,
            external_action_authorized = false
        }
    }
    if count >= 2 then
        result.sample_variance = m2 / (count - 1)
        result.standard_error = math.sqrt(result.sample_variance / count)
    end
    return {ok = true, value = result}
end

return M
