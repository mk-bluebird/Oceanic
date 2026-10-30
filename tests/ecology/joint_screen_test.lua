-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Run from repository root with Lua 5.4.
local m = require("lua.ecology.joint_screen")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic regression fixture; not field observations",
        max_metrics = 100,
        required_domains = {"structure"},
        allow_synthetic = true,
        metrics = {{
            schema_version = 1,
            domain_name = "structure",
            metric_domain = "positive",
            units = "restored_to_reference_ratio",
            estimate = 1,
            interval_lower = 0.9,
            interval_upper = 1.1,
            interval_basis = "Synthetic interval",
            bounds_mode = "two_sided",
            bounds_provenance = "synthetic",
            bounds_basis = "Synthetic bounds; not ecological requirements",
            acceptable_lower = 0.8,
            acceptable_upper = 1.25
        }}
    }
end

local function rejects(change, expected)
    local x = fixture()
    change(x)
    local result, e = m.evaluate(x)
    assert(result == nil and e.code == expected)
end

test("inclusive boundaries and point intervals", function()
    local x = fixture()
    x.metrics[1].interval_lower = 0.8
    x.metrics[1].interval_upper = 1.25
    local r = assert(m.evaluate(x))
    assert(r.all_required_screens_within)
    x.metrics[1].estimate = 0.8
    x.metrics[1].interval_upper = 0.8
    r = assert(m.evaluate(x))
    assert(r.all_required_screens_within)
end)

test("one-sided lower acceptance", function()
    local x = fixture()
    x.metrics[1].bounds_mode = "lower_only"
    x.metrics[1].acceptable_upper = nil
    assert(m.evaluate(x).all_required_screens_within)
end)

test("synthetic bounds excluded", function()
    local x = fixture()
    x.allow_synthetic = false
    local r = assert(m.evaluate(x))
    assert(not r.all_required_screens_within)
    assert(r.screens[1].status == "screen_excluded_synthetic_bounds")
end)

test("missing required domain cannot pass", function()
    local x = fixture()
    x.required_domains[2] = "faunal_use"
    local r = assert(m.evaluate(x))
    assert(not r.all_required_screens_within)
    assert(r.unresolved_domains[1] == "faunal_use")
end)

test("required presence precedes type diagnostics", function()
    rejects(function(x) x.metrics[1].estimate = nil end, "E_MISSING")
end)

test("NaN and infinity rejected", function()
    rejects(function(x) x.metrics[1].estimate = 0 / 0 end, "E_FINITE")
    rejects(function(x) x.metrics[1].interval_upper = math.huge end,
        "E_FINITE")
end)

test("sequence rejection diagnostics", function()
    rejects(function(x) x.metrics.extra = true end, "E_INDEX_TYPE")
    rejects(function(x) x.metrics[1.5] = true end, "E_INDEX_INTEGER")
    rejects(function(x) x.metrics[0] = true end, "E_INDEX_POSITIVE")
    rejects(function(x) x.metrics[101] = true end, "E_SIZE_LIMIT")
    rejects(function(x) x.metrics[3] = x.metrics[1] end, "E_SEQUENCE_GAP")
end)

test("unknown fields and metric domains", function()
    rejects(function(x) x.metrics[1].unexpected = true end,
        "E_UNKNOWN_FIELD")
    rejects(function(x) x.metrics[1].acceptable_lower = -1 end,
        "E_DOMAIN")
end)

test("input unchanged and copied output independent", function()
    local x = fixture()
    local r = assert(m.evaluate(x))
    assert(x.metrics[1].estimate == 1)
    assert(x.metrics[1].interval_lower == 0.9)
    assert(x.metrics[1].status == nil)
    r.input.metrics[1].estimate = 999
    assert(x.metrics[1].estimate == 1)
end)

test("generated nested intervals preserve within status", function()
    for k = 0, 100 do
        local x = fixture()
        local width = k / 1000
        x.metrics[1].interval_lower = 1 - width
        x.metrics[1].interval_upper = 1 + width
        local r = assert(m.evaluate(x))
        assert(r.all_required_screens_within)
        assert(not r.interpretation_limits.habitat_function_certified)
    end
end)

os.exit(failures == 0 and 0 or 1)
