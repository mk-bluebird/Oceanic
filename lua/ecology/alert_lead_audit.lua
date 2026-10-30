-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Times are hours on one common declared clock.
-- Local timing audit only; no alert delivery or ecological control.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}
local TIMES={
    "latest_observation_hour","data_available_hour",
    "alert_issued_hour","alert_received_hour",
    "onset_earliest_hour","onset_latest_hour"
}

function M.evaluate(x)
    local required={"schema_version","required_lead_hours"}
    for _,key in ipairs(TIMES) do required[#required+1]=key end
    local r=V.record(x,required,{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    for _,key in ipairs(TIMES) do
        if not V.finite(x[key]) then
            return V.fail("E_FINITE","input." .. key)
        end
    end
    if not V.finite(x.required_lead_hours) or x.required_lead_hours<0 then
        return V.fail("E_NONNEGATIVE","input.required_lead_hours")
    end
    if x.latest_observation_hour>x.data_available_hour
        or x.data_available_hour>x.alert_issued_hour
        or x.alert_issued_hour>x.alert_received_hour then
        return V.fail("E_ALERT_CHRONOLOGY","input")
    end
    if x.onset_earliest_hour>x.onset_latest_hour then
        return V.fail("E_ONSET_INTERVAL","input")
    end

    local lower=x.onset_earliest_hour-x.alert_received_hour
    local upper=x.onset_latest_hour-x.alert_received_hour
    local acquisition=x.data_available_hour-x.latest_observation_hour
    local processing=x.alert_issued_hour-x.data_available_hour
    local delivery=x.alert_received_hour-x.alert_issued_hour

    for _,value in ipairs({lower,upper,acquisition,processing,delivery}) do
        if not V.finite(value) then return V.fail("E_NUMERIC_RANGE","input") end
    end

    local status
    if lower>=x.required_lead_hours then
        status="screen_lead_target_met_across_onset_interval"
    elseif upper<x.required_lead_hours then
        status="screen_lead_target_missed_across_onset_interval"
    else
        status="screen_lead_target_unresolved_with_onset_uncertainty"
    end

    local copied={}
    for _,key in ipairs(TIMES) do copied[key]=x[key] end
    return V.ok({
        module_version=M.VERSION,schema_version=1,
        status=status,
        timing_inputs=copied,
        required_lead_hours=x.required_lead_hours,
        delivered_lead_lower_hours=lower,
        delivered_lead_upper_hours=upper,
        observation_to_availability_hours=acquisition,
        availability_to_issue_hours=processing,
        issue_to_receipt_hours=delivery,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            clock_alignment_verified=false,
            event_onset_adjudication_verified=false,
            forecast_used_only_available_data_verified=false,
            false_alarm_rate_estimated=false,
            missed_event_rate_estimated=false,
            intervention_effectiveness_estimated=false,
            alert_delivery_performed=false,
            external_action_performed=false
        }
    })
end

return M
