-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.restoration_contrast")
local failures = 0
local ABS_TOL = 1e-12
local REL_TOL = 1e-10

local function close(a, b)
    assert(math.abs(a - b) <= ABS_TOL
        + REL_TOL * math.max(math.abs(a), math.abs(b)))
end

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        local safe = tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500)
        io.write("DETAIL\t", name, "\t", safe, "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic matched before-after example",
        metric = "Synthetic response",
        units = "synthetic_units",
        endpoint_class = "structure",
        mode = "additive",
        measurements = {
            impact_before = 40, impact_after = 60,
            reference_before = 50, reference_after = 45
        }
    }
end

test("frozen_additive_contrast", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    close(r.value.contrast, 25)
    assert(not r.value.interpretation_limits.causal_effect_established)
end)

test("common_translation_invariance", function()
    local x = fixture()
    for key, value in pairs(x.measurements) do
        x.measurements[key] = value + 100
    end
    close(m.evaluate(x).value.contrast, 25)
end)

test("log_ratio_and_scale_invariance", function()
    local x = fixture()
    x.mode = "log_ratio_of_ratios"
    local first = m.evaluate(x)
    assert(first.ok)
    close(first.value.contrast, math.log(5 / 3))
    for key, value in pairs(x.measurements) do
        x.measurements[key] = value * 10
    end
    close(m.evaluate(x).value.contrast, first.value.contrast)
end)

test("identical_changes_yield_zero", function()
    local x = fixture()
    x.measurements.reference_after = 70
    close(m.evaluate(x).value.contrast, 0)
end)

test("domain_and_structure_errors", function()
    local x = fixture()
    x.mode = "log_ratio_of_ratios"
    x.measurements.impact_before = 0
    assert(m.evaluate(x).error.code == "E_POSITIVE_REQUIRED")
    x = fixture()
    x.measurements.impact_after = 0 / 0
    assert(m.evaluate(x).error.code == "E_FINITE")
    x = fixture()
    x.measurements.reference_after = nil
    assert(m.evaluate(x).error.code == "E_MISSING")
end)

test("copied_measurements_do_not_alias_input", function()
    local x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.measurements.impact_before = 999
    assert(x.measurements.impact_before == 40)
end)

io.write("SUMMARY\tfailures\t", tostring(failures),
    "\tabs_tol\t", tostring(ABS_TOL),
    "\trel_tol\t", tostring(REL_TOL), "\n")
os.exit(failures == 0 and 0 or 1)
