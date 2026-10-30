-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.seasonal_flower_gaps")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function close(a, b)
    assert(math.abs(a - b) < 1e-12)
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic contiguous assessment window",
        units = "synthetic_resource_units",
        reference_basis = "Synthetic test assumption",
        availability_basis = "Synthetic test bounds",
        bin_capacity = 20,
        bins = {
            {start_day = 0, end_day = 9, reference = 100,
                known = true, lower = 60, upper = 80},
            {start_day = 10, end_day = 19, reference = 100, known = false}
        }
    }
end

local function rejects(change, code, path)
    local x = fixture()
    change(x)
    local r = m.evaluate(x)
    assert(not r.ok and r.error.code == code)
    assert(r.error.field_path == path)
end

test("shortfall and unknown time stay separate", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    close(r.value.bins[1].shortfall_lower, 0.2)
    close(r.value.bins[1].shortfall_upper, 0.4)
    close(r.value.time_coverage_fraction, 0.5)
    assert(r.value.unknown_days == 10)
    assert(r.value.certain_gap_days_among_known == 10)
end)

test("boundary and crossing intervals", function()
    local x = fixture()
    x.bins[1].lower, x.bins[1].upper = 100, 100
    assert(m.evaluate(x).value.bins[1].status == "screen_reference_met")
    x.bins[1].lower, x.bins[1].upper = 80, 120
    assert(m.evaluate(x).value.bins[1].status == "screen_reference_crossing")
end)

test("structured rejections", function()
    rejects(function(x) x.scope = nil end, "E_MISSING", "input.scope")
    rejects(function(x) x.bins[1].lower = 0 / 0 end,
        "E_AVAILABILITY", "input.bins[1].lower")
    rejects(function(x) x.bins[1].upper = math.huge end,
        "E_AVAILABILITY", "input.bins[1].upper")
    rejects(function(x) x.bins[2].start_day = 11 end,
        "E_TIME_CONTIGUITY", "input.bins[2].start_day")
    rejects(function(x) x.bins[2].lower = 0 end,
        "E_UNKNOWN_WITH_VALUES", "input.bins[2]")
    rejects(function(x) x.bins[3] = x.bins[2]; x.bins[2] = nil end,
        "E_SEQUENCE_GAP", "input.bins")
end)

test("input unchanged and output independent", function()
    local x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.bins[1].availability_lower = 999
    assert(x.bins[1].lower == 60)
    assert(x.bins[1].status == nil)
end)

test("more resources cannot increase screened shortfall", function()
    local previous = 1
    for value = 0, 150 do
        local x = fixture()
        x.bins[1].lower, x.bins[1].upper = value, value
        local r = m.evaluate(x)
        assert(r.ok)
        local shortfall = r.value.bins[1].shortfall_upper
        assert(shortfall <= previous)
        assert(shortfall >= 0 and shortfall <= 1)
        previous = shortfall
    end
end)

os.exit(failures == 0 and 0 or 1)
