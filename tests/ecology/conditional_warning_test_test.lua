-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.conditional_warning_test")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500), "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        protocol_frozen_before_outcome = true,
        assumption_checks = {"met", "met"},
        event_status = "confirmed",
        observation_adequacy = "adequate",
        precursor_status = "absent"
    }
end

test("eligible_absence_is_candidate_counterexample", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    assert(r.value.status == "screen_candidate_counterexample_to_strict_claim")
    assert(not r.value.interpretation_limits.universal_claim_confirmed)
end)

test("unknown_and_failed_gates_do_not_compensate", function()
    local x = fixture()
    x.assumption_checks = {"met", "unknown", "met"}
    assert(m.evaluate(x).value.status == "screen_eligibility_unresolved")
    x.assumption_checks = {"met", "not_met", "met"}
    assert(m.evaluate(x).value.status == "screen_ineligible_assumptions")
end)

test("inadequate_observation_is_inconclusive", function()
    local x = fixture()
    x.observation_adequacy = "inadequate"
    assert(m.evaluate(x).value.status == "screen_inconclusive_observation")
end)

test("present_precursor_is_consistency_not_proof", function()
    local x = fixture()
    x.precursor_status = "present"
    assert(m.evaluate(x).value.status == "screen_eligible_event_consistent_with_claim")
end)

test("post_outcome_protocol_is_exploratory", function()
    local x = fixture()
    x.protocol_frozen_before_outcome = false
    assert(m.evaluate(x).value.status == "screen_exploratory_protocol")
end)

test("invalid_states_are_errors", function()
    local x = fixture()
    x.assumption_checks[1] = true
    assert(m.evaluate(x).error.code == "E_ASSUMPTION_STATE")
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
