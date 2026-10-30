-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.alert_lead_audit")
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
        schema_version=1,required_lead_hours=12,
        latest_observation_hour=7,data_available_hour=8,
        alert_issued_hour=9,alert_received_hour=10,
        onset_earliest_hour=20,onset_latest_hour=24
    }
end

test("onset_uncertainty_is_preserved",function()
    local r=M.evaluate(fixture())
    assert(r.ok)
    assert(r.value.delivered_lead_lower_hours==10)
    assert(r.value.delivered_lead_upper_hours==14)
    assert(r.value.status==
        "screen_lead_target_unresolved_with_onset_uncertainty")
end)

test("met_and_missed_targets",function()
    local x=fixture()
    x.onset_earliest_hour=22
    assert(M.evaluate(x).value.status==
        "screen_lead_target_met_across_onset_interval")
    x=fixture()
    x.onset_latest_hour=21
    assert(M.evaluate(x).value.status==
        "screen_lead_target_missed_across_onset_interval")
end)

test("post_onset_alert_has_negative_lead",function()
    local x=fixture()
    x.onset_earliest_hour=5
    x.onset_latest_hour=6
    local r=M.evaluate(x)
    assert(r.ok and r.value.delivered_lead_upper_hours==-4)
end)

test("invalid_chronology_and_input_independence",function()
    local x=fixture()
    x.alert_received_hour=8
    assert(M.evaluate(x).error.code=="E_ALERT_CHRONOLOGY")
    x=fixture()
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.timing_inputs.alert_received_hour=999
    assert(x.alert_received_hour==10)
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
