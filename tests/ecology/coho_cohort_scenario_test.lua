-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.coho_cohort_scenario")
local failed = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failed = failed + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function close(a, b)
    assert(math.abs(a - b) <= 1e-10)
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic cohort; three nonoverlapping transitions",
        cohort_count = 10000,
        max_stages = 10,
        stages = {
            {name = "first", survival = 0.20, evidence_basis = "Synthetic"},
            {name = "second", survival = 0.50, evidence_basis = "Synthetic"},
            {name = "third", survival = 0.05, evidence_basis = "Synthetic"}
        },
        scenario_stage = "first",
        survival_increment = 0.05,
        scenario_basis = "Synthetic arithmetic example",
        provenance_kind = "synthetic"
    }
end

local function rejects(change, code)
    local x = fixture()
    change(x)
    local result, e = m.evaluate(x)
    assert(result == nil and e.code == code)
end

test("frozen arithmetic and no input mutation", function()
    local x = fixture()
    local r = assert(m.evaluate(x))
    close(r.baseline_expected, 50)
    close(r.scenario_expected, 62.5)
    close(r.incremental_expected, 12.5)
    r.stages[1].survival = 0.99
    close(x.stages[1].survival, 0.20)
    assert(r.incremental_per_cost == false)
end)

test("alternative stage scenario", function()
    local x = fixture()
    x.scenario_stage = "third"
    x.survival_increment = 0.005
    close(assert(m.evaluate(x)).incremental_expected, 5)
end)

test("zero survival does not cause division by zero", function()
    local x = fixture()
    x.stages[1].survival = 0
    local r = assert(m.evaluate(x))
    close(r.baseline_expected, 0)
    close(r.incremental_expected, 12.5)
end)

test("generated increments are monotone and bounded", function()
    local previous = -1
    for k = 0, 80 do
        local x = fixture()
        x.survival_increment = k / 100
        local r = assert(m.evaluate(x))
        assert(r.scenario_expected >= previous)
        assert(r.scenario_expected <= x.cohort_count)
        previous = r.scenario_expected
    end
end)

test("structured validation failures", function()
    rejects(function(x) x.scope = nil end, "E_MISSING")
    rejects(function(x) x.stages[1].survival = 0 / 0 end, "E_PROBABILITY")
    rejects(function(x) x.stages[1].survival = math.huge end, "E_PROBABILITY")
    rejects(function(x) x.stages[2] = nil end, "E_SEQUENCE_GAP")
    rejects(function(x) x.stages[1.5] = true end, "E_INDEX_INTEGER")
    rejects(function(x) x.stages.extra = true end, "E_INDEX_TYPE")
    rejects(function(x) x.unknown = true end, "E_UNKNOWN_FIELD")
    rejects(function(x) x.survival_increment = 0.81 end,
        "E_SCENARIO_PROBABILITY")
    rejects(function(x) x.cost = 0 end, "E_MISSING")
end)

os.exit(failed == 0 and 0 or 1)
