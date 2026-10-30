-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.pollinator_gap_audit")
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
        intervals = {
            {start_day=0, end_day=2, observed=true,
                bee_activity_index=3, floral_resource=5, floral_reference=10},
            {start_day=2, end_day=5, observed=true,
                bee_activity_index=2, floral_resource=10, floral_reference=10},
            {start_day=5, end_day=6, observed=false}
        }
    }
end

test("frozen_time_weighted_gap", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    assert(math.abs(r.value.observed_active_gap_fraction - 0.4) < 1e-12)
    assert(r.value.recorded_gap_days == 2)
    assert(r.value.unknown_days == 1)
end)

test("unknown_does_not_become_zero_resource", function()
    local x = fixture()
    x.intervals = {{start_day=0, end_day=6, observed=false}}
    local r = m.evaluate(x)
    assert(r.ok and r.value.observed_active_gap_fraction == nil)
    assert(r.value.recorded_gap_days == 0)
    assert(r.value.observation_time_coverage == 0)
end)

test("no_activity_has_no_gap_fraction", function()
    local x = fixture()
    x.intervals[1].bee_activity_index = 0
    x.intervals[2].bee_activity_index = 0
    assert(m.evaluate(x).value.observed_active_gap_fraction == nil)
end)

test("unknown_intervals_break_recorded_continuity", function()
    local x = fixture()
    x.intervals = {
        {start_day=0,end_day=2,observed=true,
            bee_activity_index=1,floral_resource=0,floral_reference=10},
        {start_day=2,end_day=3,observed=false},
        {start_day=3,end_day=5,observed=true,
            bee_activity_index=1,floral_resource=0,floral_reference=10}
    }
    local r = m.evaluate(x)
    assert(r.ok)
    assert(r.value.recorded_gap_days == 4)
    assert(r.value.longest_contiguous_recorded_gap_days == 2)
end)

test("invalid_values_and_input_preservation", function()
    local x = fixture()
    x.intervals[1].floral_resource = 0/0
    assert(m.evaluate(x).error.code == "E_NONNEGATIVE")
    x = fixture()
    assert(m.evaluate(x).ok)
    assert(x.intervals[1].floral_resource == 5)
    assert(x.intervals[3].observed == false)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
