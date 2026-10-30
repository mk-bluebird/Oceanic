-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Run from repository root:
-- lua tests/ecology/habitat_support_screen_test.lua

local screen = require("lua.ecology.habitat_support_screen")

local function approximately(actual, expected)
    assert(math.abs(actual - expected) <= 1e-12)
end

local function fixture(lower, upper)
    return {
        species = "Synthetic test only; no biological species asserted",
        scope = "One synthetic site and assessment period",
        conditions = {
            {
                name = "Synthetic resource availability",
                unit = "resource_units_per_assessment_period",
                reference = 100,
                reference_basis = "Synthetic software-test assumption",
                lower = lower,
                upper = upper,
                availability_basis = "Synthetic software-test interval"
            }
        }
    }
end

local result = screen.screen(fixture(60, 80))
assert(result.review_status == "review_screened_shortfall")
approximately(result.complete_conditions_shortfall.lower, 0.20)
approximately(result.complete_conditions_shortfall.upper, 0.40)
approximately(result.coverage_fraction, 1)

result = screen.screen(fixture(80, 120))
assert(result.review_status == "resolve_reference_crossing_uncertainty")
approximately(result.complete_conditions_shortfall.lower, 0)
approximately(result.complete_conditions_shortfall.upper, 0.20)

result = screen.screen(fixture(100, 140))
assert(result.review_status == "listed_references_met_not_species_clearance")
approximately(result.complete_conditions_shortfall.upper, 0)

result = screen.screen(fixture(nil, nil))
assert(result.review_status == "incomplete_evidence")
assert(result.complete_conditions_shortfall == nil)
assert(result.known_conditions_shortfall == nil)
approximately(result.coverage_fraction, 0)

local mixed = fixture(60, 80)
mixed.conditions[2] = {
    name = "Unmeasured synthetic shelter condition",
    unit = "shelter_units",
    reference = 10,
    reference_basis = "Synthetic software-test assumption"
}
result = screen.screen(mixed)
assert(result.screened_shortfall_present)
assert(result.unknown_count == 1)
assert(result.complete_conditions_shortfall == nil)
approximately(result.coverage_fraction, 0.5)

assert(not pcall(screen.screen, fixture(90, 80)))
assert(not pcall(screen.screen, fixture(-1, 80)))
assert(not pcall(screen.screen, fixture(0 / 0, 80)))
assert(not pcall(screen.screen, fixture(60, math.huge)))
assert(not pcall(screen.screen, fixture(60, nil)))

local invalid_reference = fixture(60, 80)
invalid_reference.conditions[1].reference = 0
assert(not pcall(screen.screen, invalid_reference))

local sparse = fixture(60, 80)
sparse.conditions[3] = sparse.conditions[1]
assert(not pcall(screen.screen, sparse))

local unsupported = fixture(60, 80)
unsupported.authorize_intervention = true
assert(not pcall(screen.screen, unsupported))

assert(result.external_actions_performed == false)
assert(result.intervention_authorized == false)
assert(result.extinction_probability_estimated == false)
assert(screen.attribution.persistent_storage_performed == false)

io.write("Habitat-support screening tests passed.\n")
