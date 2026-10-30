-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.connected_element_budget")
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
        schema_version=1,element="nitrogen",
        interval_basis="Synthetic common accounting interval",
        tolerance_kg=1e-9,
        compartments={
            {name="Freshwater",initial_kg=100,final_kg=95,
                external_in_kg=0,external_out_kg=0},
            {name="Riparian",initial_kg=20,final_kg=25,
                external_in_kg=0,external_out_kg=0}
        },
        transfers={{source="Freshwater",target="Riparian",mass_kg=5}}
    }
end

test("internal_transfer_conserves_system_mass",function()
    local r=M.evaluate(fixture())
    assert(r.ok)
    assert(r.value.system_residual_kg==0)
    assert(r.value.compartments[1].residual_kg==0)
    assert(r.value.compartments[2].residual_kg==0)
end)

test("system_cancellation_does_not_hide_local_residuals",function()
    local x=fixture()
    x.compartments[1].final_kg=96
    x.compartments[2].final_kg=24
    local r=M.evaluate(x)
    assert(r.ok and r.value.system_residual_kg==0)
    assert(r.value.status=="screen_compartment_residual_review_required")
end)

test("unknown_boundary_is_rejected",function()
    local x=fixture()
    x.transfers[1].target="Unlisted habitat"
    assert(M.evaluate(x).error.code=="E_UNKNOWN_COMPARTMENT")
end)

test("invalid_mass_and_output_independence",function()
    local x=fixture()
    x.transfers[1].mass_kg=-1
    assert(M.evaluate(x).error.code=="E_NONNEGATIVE_FINITE")
    x=fixture()
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.compartments[1].name="Changed"
    assert(x.compartments[1].name=="Freshwater")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
