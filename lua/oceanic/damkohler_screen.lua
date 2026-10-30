-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; schema 1.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, or authority.
-- Local dimensionless calculation only; no I/O or external action.

local M = {}

local function failure(code, path)
    return {
        ok = false,
        error = {
            code = code,
            field_path = path,
            message_key = "oceanic." .. code,
            args = {},
            category = "validation"
        }
    }
end

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function M.evaluate(input)
    if type(input) ~= "table" or getmetatable(input) ~= nil then
        return failure("E_RECORD", "input")
    end

    local fields = {
        "schema_version", "volume_m3", "exchange_m3_s",
        "reaction_rate_s_inv", "first_order_applicability"
    }
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(input, key) == nil then
            return failure("E_MISSING", "input." .. key)
        end
    end
    for key in pairs(input) do
        if not allowed[key] then
            return failure("E_UNKNOWN_FIELD", "input")
        end
    end

    if input.schema_version ~= 1 then
        return failure("E_SCHEMA_VERSION", "input.schema_version")
    end
    for _, key in ipairs({
        "volume_m3", "exchange_m3_s", "reaction_rate_s_inv"
    }) do
        if not finite(input[key]) or input[key] < 0 then
            return failure("E_NONNEGATIVE_FINITE", "input." .. key)
        end
    end
    if input.volume_m3 == 0 then
        return failure("E_POSITIVE_VOLUME", "input.volume_m3")
    end

    local applicability = input.first_order_applicability
    if applicability ~= "declared_applicable"
        and applicability ~= "not_applicable"
        and applicability ~= "unassessed" then
        return failure("E_APPLICABILITY", "input.first_order_applicability")
    end

    local out = {
        schema_version = 1,
        quantity = "Damkohler_first_order_exchange",
        units = "dimensionless",
        status = "screen_applicability_unresolved",
        interpretation_limits = {
            first_order_assumption_verified = false,
            exchange_definition_verified = false,
            dynamical_similarity_established = false,
            depletion_predicted = false,
            external_action_performed = false
        },
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        }
    }

    if applicability == "not_applicable" then
        out.status = "screen_group_not_applicable"
    elseif applicability == "declared_applicable" then
        if input.exchange_m3_s == 0 then
            out.status = "screen_undefined_zero_exchange"
        else
            local turnover = input.volume_m3 / input.exchange_m3_s
            local value = input.reaction_rate_s_inv * turnover
            if not finite(turnover) or not finite(value) then
                return failure("E_NUMERIC_RANGE", "input")
            end
            out.status = "screen_dimensionless_group_computed"
            out.turnover_time_s = turnover
            out.value = value
        end
    end

    return {ok = true, value = out}
end

return M
