-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no identity verification, consent, or authority.
-- Conditional constant-input box model; no I/O or external actions.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.

local M = {VERSION = "1.0.0"}
local FIELDS = {
    "schema_version", "volume_m3", "exchange_m3_s",
    "gas_exchange_s_inv", "initial_oxygen_g_m3",
    "critical_oxygen_g_m3", "saturation_oxygen_g_m3",
    "inflow_oxygen_g_m3", "production_g_m3_s", "respiration_g_m3_s"
}

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "oxygen_box." .. code,
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
    local allowed = {}
    for _, key in ipairs(FIELDS) do
        allowed[key] = true
        if rawget(x, key) == nil then return bad("E_MISSING", "input." .. key) end
    end
    for key in pairs(x) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", "input") end
    end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    for i = 2, #FIELDS do
        local key = FIELDS[i]
        if not finite(x[key]) or x[key] < 0 then
            return bad("E_NONNEGATIVE_FINITE", "input." .. key)
        end
    end
    if x.volume_m3 == 0 then return bad("E_POSITIVE_VOLUME", "input.volume_m3") end

    local r = x.exchange_m3_s / x.volume_m3
    local k = x.gas_exchange_s_inv
    local b = r + k
    local net = x.production_g_m3_s - x.respiration_g_m3_s
    if not finite(r) or not finite(b) or not finite(net) then
        return bad("E_NUMERIC_RANGE", "input")
    end

    local c0, critical = x.initial_oxygen_g_m3, x.critical_oxygen_g_m3
    local status, crossing, equilibrium, relaxation
    if b > 0 then
        equilibrium = net / b
            + (k / b) * x.saturation_oxygen_g_m3
            + (r / b) * x.inflow_oxygen_g_m3
        relaxation = 1 / b
        if not finite(equilibrium) or not finite(relaxation) then
            return bad("E_NUMERIC_RANGE", "input")
        end
    end

    if c0 <= critical then
        status, crossing = "screen_threshold_already_reached", 0
    elseif b == 0 then
        if net < 0 then
            crossing = (c0 - critical) / (-net)
            status = "screen_finite_linear_crossing"
        else
            status = "screen_no_downward_crossing"
        end
    elseif equilibrium < critical then
        local numerator = c0 - equilibrium
        local denominator = critical - equilibrium
        if not finite(numerator) or not finite(denominator) then
            return bad("E_NUMERIC_RANGE", "input")
        end
        crossing = (math.log(numerator) - math.log(denominator)) / b
        status = "screen_finite_exponential_crossing"
    elseif equilibrium == critical then
        status = "screen_asymptotic_approach_no_finite_crossing"
    else
        status = "screen_no_downward_crossing"
    end

    if crossing ~= nil and (not finite(crossing) or crossing < 0) then
        return bad("E_NUMERIC_RANGE", "input")
    end

    local out = {
        module_version = M.VERSION, schema_version = 1,
        status = status,
        exchange_rate_s_inv = r,
        relaxation_rate_s_inv = b,
        net_metabolism_g_m3_s = net,
        finite_crossing_time_available = crossing ~= nil,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false, grants_authority = false
        },
        interpretation_limits = {
            constant_volume_assumed = true,
            well_mixed_assumed = true,
            constant_inputs_assumed = true,
            biological_threshold_verified = false,
            negative_equilibrium_not_physically_sustainable =
                equilibrium ~= nil and equilibrium < 0,
            critical_slowing_down_established = false,
            field_forecast_validated = false,
            ecological_collapse_established = false,
            external_action_performed = false
        }
    }
    if crossing ~= nil then out.crossing_time_s = crossing end
    if equilibrium ~= nil then out.mathematical_equilibrium_g_m3 = equilibrium end
    if relaxation ~= nil then out.relaxation_time_s = relaxation end
    return {ok = true, value = out}
end

return M
