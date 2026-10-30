-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.krill_schedule_timeliness")
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
        assumption_profile =
            "uniform_onset_periodic_surveys_perfect_detection_fixed_delays",
        survey_interval_days = 5,
        actionable_horizon_days = 6,
        reporting_delay_days = 1,
        analysis_delay_days = 0.5,
        decision_delay_days = 0.5,
        implementation_delay_days = 1
    }
end

test("frozen_schedule_example", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    assert(math.abs(r.value.conditional_schedule_timeliness - 0.6) < 1e-12)
    assert(r.value.mean_total_delay_days == 5.5)
    assert(r.value.worst_case_total_delay_days == 8)
end)

test("piecewise_boundaries", function()
    local x = fixture()
    x.actionable_horizon_days = 3
    assert(m.evaluate(x).value.conditional_schedule_timeliness == 0)
    x.actionable_horizon_days = 8
    assert(m.evaluate(x).value.conditional_schedule_timeliness == 1)
end)

test("more_horizon_never_reduces_timeliness", function()
    local previous = -1
    for horizon = 0, 20 do
        local x = fixture()
        x.actionable_horizon_days = horizon
        local r = m.evaluate(x)
        assert(r.ok)
        local p = r.value.conditional_schedule_timeliness
        assert(p >= previous and p >= 0 and p <= 1)
        previous = p
    end
end)

test("longer_intervals_do_not_improve_timeliness", function()
    local previous = 1
    for interval = 1, 20 do
        local x = fixture()
        x.survey_interval_days = interval
        local p = m.evaluate(x).value.conditional_schedule_timeliness
        assert(p <= previous)
        previous = p
    end
end)

test("invalid_inputs_and_output_independence", function()
    local x = fixture()
    x.survey_interval_days = 0
    assert(m.evaluate(x).error.code == "E_POSITIVE_INTERVAL")
    x = fixture()
    x.analysis_delay_days = 0/0
    assert(m.evaluate(x).error.code == "E_NONNEGATIVE")
    x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.delays.reporting_delay_days = 99
    assert(x.reporting_delay_days == 1)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
