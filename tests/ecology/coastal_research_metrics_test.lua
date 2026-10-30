-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Run: lua tests/ecology/coastal_research_metrics_test.lua
local m = require("lua.ecology.coastal_research_metrics")

local function close(actual, expected)
    assert(math.abs(actual - expected) < 1e-12)
end

local b = m.canopy_baci({
    impact_before = 0.40,
    impact_after = 0.60,
    reference_before = 0.50,
    reference_after = 0.45
})
close(b.contrast_fraction, 0.25)
close(b.contrast_percentage_points, 25)
assert(not b.causal_effect_established)

local observations = {
    {time_days = 10, event = true},
    {time_days = 15, event = false},
    {time_days = 20, event = true},
    {time_days = 30, event = false}
}
local s = m.kaplan_meier(observations, 20)
close(s.survival_at_horizon, 0.375)
assert(s.horizon_within_followup)
assert(observations[1].time_days == 10)

local beyond = m.kaplan_meier(observations, 40)
assert(not beyond.horizon_within_followup)
assert(beyond.survival_at_horizon == nil)

local tied = m.kaplan_meier({
    {time_days = 5, event = true},
    {time_days = 5, event = false}
}, 5)
close(tied.survival_at_horizon, 0.5)

local function equivalence(lower, estimate, upper)
    return m.equivalence_interval({
        metric = "Synthetic restored/reference metric ratio",
        estimate = estimate,
        interval_lower = lower,
        interval_upper = upper,
        acceptable_lower = 0.80,
        acceptable_upper = 1.25,
        interval_basis = "Synthetic test interval; not an inference",
        bounds_basis = "Synthetic test bounds; not ecological thresholds"
    })
end

assert(equivalence(0.90, 1.00, 1.10).status
    == "interval_within_selected_bounds")
assert(equivalence(0.60, 0.70, 0.75).status
    == "interval_wholly_outside_selected_bounds")
assert(equivalence(0.70, 0.90, 1.10).status
    == "unresolved_overlap")

assert(not pcall(m.kaplan_meier, {}, 10))
assert(not pcall(m.kaplan_meier, {
    {time_days = -1, event = true}
}, 10))
assert(not pcall(m.kaplan_meier, {
    {time_days = 1, event = "unknown"}
}, 10))
assert(not pcall(equivalence, 1.10, 1.00, 0.90))
assert(not pcall(m.canopy_baci, {
    impact_before = 1.1, impact_after = 0.5,
    reference_before = 0.5, reference_after = 0.5
}))

assert(not m.attribution.grants_authority)
assert(not m.attribution.persistent_storage_performed)
io.write("Coastal research metrics tests passed.\n")
