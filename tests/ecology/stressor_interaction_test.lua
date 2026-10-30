-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.stressor_interaction")
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
        schema_version=1,scope="Synthetic factorial comparison",
        response="Synthetic survival response",units="synthetic_units",
        preferred_direction="higher",
        cells={neither=100,climate_only=80,local_only=70,both=56}
    }
end

test("response_scales_can_disagree",function()
    local r=M.evaluate(fixture())
    assert(r.ok)
    assert(r.value.additive_interaction==6)
    assert(math.abs(r.value.log_multiplicative_interaction)<1e-12)
    assert(not r.value.interpretation_limits.causal_interaction_established)
end)

test("additive_translation_invariance",function()
    local x=fixture()
    for key,value in pairs(x.cells) do x.cells[key]=value+100 end
    assert(M.evaluate(x).value.additive_interaction==6)
end)

test("multiplicative_scale_invariance",function()
    local x=fixture()
    x.cells.both=40
    local a=M.evaluate(x).value.log_multiplicative_interaction
    for key,value in pairs(x.cells) do x.cells[key]=value*10 end
    local b=M.evaluate(x).value.log_multiplicative_interaction
    assert(math.abs(a-b)<1e-12)
end)

test("zero_does_not_receive_pseudocount",function()
    local x=fixture()
    x.cells.both=0
    local r=M.evaluate(x)
    assert(r.ok)
    assert(r.value.log_multiplicative_interaction==nil)
    assert(r.value.log_interaction_status=="not_applicable_nonpositive_response")
end)

test("nonfinite_and_output_independence",function()
    local x=fixture()
    x.cells.both=0/0
    assert(M.evaluate(x).error.code=="E_FINITE")
    x=fixture()
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.cells.both=999
    assert(x.cells.both==56)
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
