-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.oxygen_box_crossing")
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
        schema_version = 1, volume_m3 = 1000, exchange_m3_s = 1,
        gas_exchange_s_inv = 0,
        initial_oxygen_g_m3 = 8, critical_oxygen_g_m3 = 4,
        saturation_oxygen_g_m3 = 8, inflow_oxygen_g_m3 = 2,
        production_g_m3_s = 0, respiration_g_m3_s = 0
    }
end

test("constant_rate_threshold_crossing", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    assert(math.abs(r.value.crossing_time_s - math.log(3)/0.001) < 1e-9)
    assert(r.value.relaxation_time_s == 1000)
    assert(not r.value.interpretation_limits.critical_slowing_down_established)
end)

test("asymptotic_and_no_crossing", function()
    local x = fixture()
    x.inflow_oxygen_g_m3 = 4
    assert(m.evaluate(x).value.status ==
        "screen_asymptotic_approach_no_finite_crossing")
    x.inflow_oxygen_g_m3 = 6
    assert(m.evaluate(x).value.status == "screen_no_downward_crossing")
end)

test("linear_closed_box", function()
    local x = fixture()
    x.exchange_m3_s = 0
    x.respiration_g_m3_s = 0.01
    local r = m.evaluate(x)
    assert(r.ok and math.abs(r.value.crossing_time_s - 400) < 1e-12)
end)

test("already_reached_and_invalid_volume", function()
    local x = fixture()
    x.initial_oxygen_g_m3 = 3
    assert(m.evaluate(x).value.crossing_time_s == 0)
    x.volume_m3 = 0
    assert(m.evaluate(x).error.code == "E_POSITIVE_VOLUME")
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
