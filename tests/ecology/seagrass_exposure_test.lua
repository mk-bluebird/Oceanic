-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.seagrass_exposure")
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
        temperature_reference_c = 20,
        oxygen_reference_mg_l = 4,
        intervals = {{
            start_hour = 0, end_hour = 2, measured = true,
            temperature_start_c = 18, temperature_end_c = 22,
            oxygen_start_mg_l = 6, oxygen_end_mg_l = 2
        }}
    }
end

test("linear_threshold_crossings", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    assert(math.abs(r.value.measured_heat_degree_hours - 1) < 1e-12)
    assert(math.abs(r.value.measured_oxygen_deficit_mg_l_hours - 1) < 1e-12)
end)

test("unknown_window_is_not_zero_exposure", function()
    local x = fixture()
    x.intervals = {{start_hour = 0, end_hour = 2, measured = false}}
    local r = m.evaluate(x)
    assert(r.ok and not r.value.exposure_available)
    assert(r.value.measured_heat_degree_hours == nil)
    assert(r.value.unknown_hours == 2)
end)

test("gaps_require_explicit_unknown_intervals", function()
    local x = fixture()
    x.intervals[2] = {start_hour = 3, end_hour = 4, measured = false}
    assert(m.evaluate(x).error.code == "E_TIME_CONTIGUITY")
end)

test("invalid_oxygen_and_nonfinite_inputs", function()
    local x = fixture()
    x.intervals[1].oxygen_end_mg_l = -1
    assert(m.evaluate(x).error.code == "E_OXYGEN")
    x = fixture()
    x.intervals[1].temperature_end_c = 0/0
    assert(m.evaluate(x).error.code == "E_FINITE")
end)

test("input_is_not_modified", function()
    local x = fixture()
    assert(m.evaluate(x).ok)
    assert(x.intervals[1].temperature_start_c == 18)
    assert(x.intervals[1].status == nil)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
