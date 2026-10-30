-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M = require("lua.ecology.uncertainty_metadata")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1,500), "\n")
    end
end

local function interval(kind)
    return {
        schema_version=1, kind=kind,
        basis="Synthetic reporting fixture",
        estimate=12, lower=8, upper=16,
        units="synthetic_units", method="Synthetic method"
    }
end

test("confidence_interval_requires_level", function()
    local x=interval("confidence_interval")
    assert(M.evaluate(x).error.field_path=="input.level")
    x.level=0.95
    assert(M.evaluate(x).ok)
end)

test("sensitivity_range_is_not_confidence_interval", function()
    local x=interval("sensitivity_range")
    assert(M.evaluate(x).ok)
    x.level=0.95
    assert(M.evaluate(x).error.code=="E_UNUSED_FIELD")
end)

test("unquantified_has_no_hidden_interval", function()
    local x={
        schema_version=1,kind="not_quantified",
        basis="No uncertainty calculation supplied"
    }
    assert(M.evaluate(x).ok)
    x.lower=0
    assert(M.evaluate(x).error.code=="E_UNUSED_FIELD")
end)

test("qualitative_assessment_has_documented_method", function()
    local x={
        schema_version=1,kind="qualitative_assessment",
        basis="Synthetic assessment fixture",
        method="Synthetic rubric",assessment_label="Not assessed empirically"
    }
    assert(M.evaluate(x).ok)
end)

test("invalid_numbers_and_order", function()
    local x=interval("measurement_bound")
    x.upper=7
    assert(M.evaluate(x).error.code=="E_INTERVAL_ORDER")
    x=interval("measurement_bound")
    x.lower=0/0
    assert(M.evaluate(x).error.code=="E_FINITE")
end)

test("output_does_not_alias_input", function()
    local x=interval("sensitivity_range")
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.uncertainty.lower=999
    assert(x.lower==8)
    assert(not r.value.interpretation_limits.publication_authorized)
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
