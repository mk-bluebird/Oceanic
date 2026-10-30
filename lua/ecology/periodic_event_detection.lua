-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local scheduling calculation; no I/O or monitoring deployment.

local V = require("lua.ecology.validation")
local M = {VERSION = "1.0.0"}
local MAX_GUARANTEED_VISITS = 10000
local PROFILE =
    "periodic_visits_uniform_onset_independent_detection_full_window"

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "assumption_profile",
        "visit_interval_days", "event_duration_days",
        "per_visit_detection"
    }, {}, "input")
    if not r.ok then return r end
    if x.schema_version ~= 1 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version",
            {expected=1, actual=V.describe(x.schema_version)})
    end
    if x.assumption_profile ~= PROFILE then
        return V.fail("E_ASSUMPTION_PROFILE", "input.assumption_profile")
    end
    if not V.finite(x.visit_interval_days) or x.visit_interval_days <= 0 then
        return V.fail("E_POSITIVE_INTERVAL", "input.visit_interval_days")
    end
    if not V.finite(x.event_duration_days) or x.event_duration_days < 0 then
        return V.fail("E_NONNEGATIVE_DURATION", "input.event_duration_days")
    end
    local p = x.per_visit_detection
    if not V.finite(p) or p < 0 or p > 1 then
        return V.fail("E_PROBABILITY", "input.per_visit_detection",
            {minimum=0, maximum=1})
    end

    local ratio = x.event_duration_days / x.visit_interval_days
    if not V.finite(ratio) then
        return V.fail("E_NUMERIC_RANGE", "input.event_duration_days")
    end
    local n = math.floor(ratio)
    if n > MAX_GUARANTEED_VISITS then
        return V.fail("E_COMPUTATION_CAPACITY", "input.event_duration_days",
            {guaranteed_visits=n, maximum=MAX_GUARANTEED_VISITS})
    end
    local fraction = ratio - n
    local detection = 0
    for _ = 1, n do
        detection = detection + (1 - detection) * p
    end
    detection = detection + (1 - detection) * fraction * p

    return V.ok({
        module_version=M.VERSION,
        schema_version=1,
        status="screen_conditional_periodic_event_detection",
        assumption_profile=PROFILE,
        visit_interval_days=x.visit_interval_days,
        event_duration_days=x.event_duration_days,
        per_visit_detection=p,
        guaranteed_visits=n,
        extra_visit_probability=fraction,
        expected_visits_during_event=ratio,
        conditional_detection_probability=detection,
        conditional_miss_probability=1-detection,
        computational_limit_guaranteed_visits=MAX_GUARANTEED_VISITS,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            event_duration_validated=false,
            detection_probability_calibrated=false,
            onset_distribution_verified=false,
            visit_independence_verified=false,
            monitoring_horizon_edges_modeled=false,
            trend_detection_power_calculated=false,
            ecological_failure_probability_estimated=false,
            external_action_performed=false
        }
    })
end

return M
