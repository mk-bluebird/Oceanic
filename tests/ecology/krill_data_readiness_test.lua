-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.krill_data_readiness")
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
    local streams = {}
    for _, name in ipairs({"krill_acoustics", "predator_use", "fishery_activity"}) do
        streams[name] = {
            window_start_s = 900, window_end_s = 950, available_at_s = 970,
            cell_width_m = 1000, coverage_fraction = 0.9
        }
    end
    return {
        schema_version = 1, decision_time_s = 1000,
        requirements = {
            maximum_oldest_age_s = 100,
            maximum_delivery_lag_s = 20,
            maximum_window_s = 50,
            maximum_cell_width_m = 1000,
            minimum_coverage_fraction = 0.9
        },
        streams = streams
    }
end

test("inclusive_requirement_boundaries", function()
    local r = m.evaluate(fixture())
    assert(r.ok and r.value.status == "screen_all_stream_requirements_met")
    assert(not r.value.interpretation_limits.ecological_requirements_validated)
end)

test("oldest_and_newest_are_distinct", function()
    local r = m.evaluate(fixture())
    local s = r.value.streams.krill_acoustics
    assert(s.oldest_age_s == 100 and s.newest_age_s == 50)
    assert(s.delivery_lag_s == 20)
end)

test("stale_or_incomplete_stream_blocks_joint_screen", function()
    local x = fixture()
    x.streams.predator_use.coverage_fraction = 0.5
    local r = m.evaluate(x)
    assert(r.ok and r.value.status == "screen_data_requirements_unmet")
    assert(r.value.streams.predator_use.unmet_requirements[1] == "coverage")
end)

test("future_and_nonfinite_data_rejected", function()
    local x = fixture()
    x.streams.krill_acoustics.available_at_s = 1001
    assert(m.evaluate(x).error.code == "E_TIME_ORDER")
    x = fixture()
    x.streams.krill_acoustics.cell_width_m = 0/0
    assert(m.evaluate(x).error.code == "E_FINITE")
end)

test("copied_policy_does_not_alias_input", function()
    local x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.requirements.maximum_window_s = 999
    assert(x.requirements.maximum_window_s == 50)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
