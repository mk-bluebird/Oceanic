-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Local research calculations; no I/O or external actions.

local M = {
    attribution = {
        sovereign_anchor =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        purpose = "document_credit_and_configured_workstream_metadata_only",
        establishes_consent = false,
        grants_authority = false,
        persistent_storage_performed = false
    }
}

local function finite(x, name)
    assert(type(x) == "number" and x == x
        and x > -math.huge and x < math.huge,
        name .. " must be a finite number")
    return x
end

local function text(x, name)
    assert(type(x) == "string" and x:match("%S"),
        name .. " must contain text")
end

local function record(x, fields, name)
    assert(type(x) == "table" and getmetatable(x) == nil,
        name .. " must be a plain table")
    for key in pairs(x) do
        assert(fields[key], name .. " contains an unsupported field")
    end
end

local function sequence(x)
    assert(type(x) == "table" and getmetatable(x) == nil,
        "observations must be a plain sequence")
    local n = 0
    for key in pairs(x) do
        assert(type(key) == "number" and key % 1 == 0
            and key >= 1 and key <= 100000,
            "invalid observation position")
        n = n + 1
    end
    assert(n > 0, "observations must not be empty")
    for i = 1, n do
        assert(rawget(x, i) ~= nil, "observations must be contiguous")
    end
    return n
end

function M.canopy_baci(x)
    record(x, {
        impact_before = true, impact_after = true,
        reference_before = true, reference_after = true
    }, "BACI input")

    for _, key in ipairs({
        "impact_before", "impact_after",
        "reference_before", "reference_after"
    }) do
        finite(x[key], key)
        assert(x[key] >= 0 and x[key] <= 1,
            key .. " must be a canopy fraction from zero to one")
    end

    local impact_change = x.impact_after - x.impact_before
    local reference_change = x.reference_after - x.reference_before
    local contrast = impact_change - reference_change

    return {
        impact_change_fraction = impact_change,
        reference_change_fraction = reference_change,
        contrast_fraction = contrast,
        contrast_percentage_points = 100 * contrast,
        uncertainty_estimated = false,
        causal_effect_established = false
    }
end

function M.kaplan_meier(observations, horizon)
    finite(horizon, "horizon")
    assert(horizon >= 0, "horizon must be nonnegative")
    local n = sequence(observations)
    local rows = {}

    for i = 1, n do
        local row = observations[i]
        record(row, {time_days = true, event = true}, "observation")
        finite(row.time_days, "time_days")
        assert(row.time_days >= 0, "time_days must be nonnegative")
        assert(type(row.event) == "boolean",
            "event must be true for failure or false for censoring")
        rows[i] = {time_days = row.time_days, event = row.event}
    end

    table.sort(rows, function(a, b)
        return a.time_days < b.time_days
    end)

    local at_risk, survival, i = n, 1, 1
    local curve = {}

    while i <= n and rows[i].time_days <= horizon do
        local time = rows[i].time_days
        local failures, censored = 0, 0

        repeat
            if rows[i].event then
                failures = failures + 1
            else
                censored = censored + 1
            end
            i = i + 1
        until i > n or rows[i].time_days ~= time

        -- Tied failures precede tied censoring in the risk-set convention.
        survival = survival * (1 - failures / at_risk)
        curve[#curve + 1] = {
            time_days = time,
            at_risk_before = at_risk,
            failures = failures,
            censored = censored,
            survival = survival
        }
        at_risk = at_risk - failures - censored
    end

    local supported = horizon <= rows[n].time_days
    local result = {
        horizon_days = horizon,
        horizon_within_followup = supported,
        last_observed_day = rows[n].time_days,
        curve = curve,
        uncertainty_estimated = false,
        clustering_adjusted = false,
        natural_recovery_estimated = false
    }
    if supported then
        result.survival_at_horizon = survival
    end
    return result
end

function M.equivalence_interval(x)
    record(x, {
        metric = true, estimate = true,
        interval_lower = true, interval_upper = true,
        acceptable_lower = true, acceptable_upper = true,
        interval_basis = true, bounds_basis = true
    }, "equivalence input")

    text(x.metric, "metric")
    text(x.interval_basis, "interval_basis")
    text(x.bounds_basis, "bounds_basis")

    for _, key in ipairs({
        "estimate", "interval_lower", "interval_upper",
        "acceptable_lower", "acceptable_upper"
    }) do
        finite(x[key], key)
    end

    assert(x.interval_lower <= x.estimate
        and x.estimate <= x.interval_upper,
        "estimate must lie within the supplied interval")
    assert(x.acceptable_lower < x.acceptable_upper,
        "acceptable bounds must be strictly ordered")

    local status
    if x.interval_lower >= x.acceptable_lower
        and x.interval_upper <= x.acceptable_upper then
        status = "interval_within_selected_bounds"
    elseif x.interval_upper < x.acceptable_lower
        or x.interval_lower > x.acceptable_upper then
        status = "interval_wholly_outside_selected_bounds"
    else
        status = "unresolved_overlap"
    end

    return {
        metric = x.metric,
        status = status,
        interval_basis = x.interval_basis,
        bounds_basis = x.bounds_basis,
        statistical_equivalence_certified = false,
        habitat_function_certified = false,
        external_action_authorized = false
    }
end

return M
