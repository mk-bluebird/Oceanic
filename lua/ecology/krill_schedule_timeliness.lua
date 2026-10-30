-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no identity verification, consent, or authority.
-- Local scheduling calculation; no forecasts, I/O, or external actions.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.

local M = {VERSION = "1.0.0"}
local DELAYS = {
    "reporting_delay_days", "analysis_delay_days",
    "decision_delay_days", "implementation_delay_days"
}
local ASSUMPTION =
    "uniform_onset_periodic_surveys_perfect_detection_fixed_delays"

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "krill_schedule." .. code,
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
    local fields = {
        "schema_version", "assumption_profile",
        "survey_interval_days", "actionable_horizon_days"
    }
    for _, key in ipairs(DELAYS) do fields[#fields + 1] = key end

    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(x, key) == nil then
            return bad("E_MISSING", "input." .. key)
        end
    end
    for key in pairs(x) do
        if not allowed[key] then return bad("E_UNKNOWN_FIELD", "input") end
    end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if x.assumption_profile ~= ASSUMPTION then
        return bad("E_ASSUMPTION_PROFILE", "input.assumption_profile")
    end
    if not finite(x.survey_interval_days) or x.survey_interval_days <= 0 then
        return bad("E_POSITIVE_INTERVAL", "input.survey_interval_days")
    end
    if not finite(x.actionable_horizon_days)
        or x.actionable_horizon_days < 0 then
        return bad("E_NONNEGATIVE", "input.actionable_horizon_days")
    end

    local lag, copied = 0, {}
    for _, key in ipairs(DELAYS) do
        if not finite(x[key]) or x[key] < 0 then
            return bad("E_NONNEGATIVE", "input." .. key)
        end
        lag = lag + x[key]
        copied[key] = x[key]
        if not finite(lag) then return bad("E_NUMERIC_RANGE", "input") end
    end

    local interval = x.survey_interval_days
    local horizon = x.actionable_horizon_days
    local worst = interval + lag
    if not finite(worst) then return bad("E_NUMERIC_RANGE", "input") end

    local probability
    if horizon <= lag then
        probability = 0
    elseif horizon >= worst then
        probability = 1
    else
        probability = (horizon - lag) / interval
    end

    local status
    if probability == 0 then
        status = "screen_no_schedule_probability_within_horizon"
    elseif probability == 1 then
        status = "screen_all_schedule_phases_within_horizon"
    else
        status = "screen_some_schedule_phases_within_horizon"
    end

    return {ok = true, value = {
        module_version = M.VERSION,
        schema_version = 1,
        status = status,
        assumption_profile = ASSUMPTION,
        survey_interval_days = interval,
        actionable_horizon_days = horizon,
        delays = copied,
        post_survey_delay_days = lag,
        mean_total_delay_days = interval / 2 + lag,
        worst_case_total_delay_days = worst,
        conditional_schedule_timeliness = probability,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            ecological_horizon_validated = false,
            onset_distribution_verified = false,
            detection_performance_verified = false,
            variable_delays_modeled = false,
            spatial_resolution_evaluated = false,
            breeding_failure_probability_estimated = false,
            intervention_effectiveness_estimated = false,
            management_action_authorized = false,
            external_action_performed = false
        }
    }}
end

return M
