-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.binary_forecast_audit")
local failures=0

local function test(name,fn)
    local ok,detail=pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures=failures+1
        io.write("DETAIL\t",name,"\t",
            tostring(detail):gsub("[%z\1-\31\127]"," "):sub(1,500),"\n")
    end
end

local function fixture()
    return {
        schema_version=1,scope="Synthetic forecast audit",
        evaluation_basis="synthetic",bin_count=2,
        records={
            {probability=0.2,baseline_probability=0.5,outcome=0},
            {probability=0.8,baseline_probability=0.5,outcome=1}
        }
    }
end

test("frozen_brier_and_skill",function()
    local r=M.evaluate(fixture())
    assert(r.ok)
    assert(math.abs(r.value.brier_score-0.04)<1e-12)
    assert(math.abs(r.value.brier_skill_score-0.84)<1e-12)
    assert(not r.value.interpretation_limits.decision_readiness_established)
end)

test("perfect_baseline_has_no_skill_ratio",function()
    local x=fixture()
    x.records[1].baseline_probability=0
    x.records[2].baseline_probability=1
    local r=M.evaluate(x)
    assert(r.ok and not r.value.brier_skill_available)
    assert(r.value.brier_skill_score==nil)
end)

test("probability_one_is_in_last_bin",function()
    local x=fixture()
    x.records[2].probability=1
    local r=M.evaluate(x)
    assert(r.ok and r.value.calibration_bins[2].count==1)
end)

test("invalid_outcome_and_probability",function()
    local x=fixture()
    x.records[1].outcome=2
    assert(M.evaluate(x).error.code=="E_BINARY")
    x=fixture()
    x.records[1].probability=0/0
    assert(M.evaluate(x).error.code=="E_PROBABILITY")
end)

test("output_does_not_modify_input",function()
    local x=fixture()
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.calibration_bins[1].count=99
    assert(x.records[1].probability==0.2)
    assert(#x.records==2)
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
