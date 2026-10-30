-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.periodic_event_detection")
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

local function run(interval,duration,p)
    return M.evaluate({
        schema_version=1,
        assumption_profile=
            "periodic_visits_uniform_onset_independent_detection_full_window",
        visit_interval_days=interval,
        event_duration_days=duration,
        per_visit_detection=p
    })
end

test("short_event_example",function()
    local r=run(7,2,0.8)
    assert(r.ok)
    assert(math.abs(r.value.conditional_detection_probability-1.6/7)<1e-12)
end)

test("two_visits_and_boundary_probabilities",function()
    assert(math.abs(run(7,14,0.5).value.conditional_detection_probability-0.75)<1e-12)
    assert(run(7,14,0).value.conditional_detection_probability==0)
    assert(run(7,7,1).value.conditional_detection_probability==1)
    assert(run(7,0,1).value.conditional_detection_probability==0)
end)

test("longer_events_do_not_reduce_detection",function()
    local previous=-1
    for duration=0,100 do
        local r=run(7,duration,0.6)
        assert(r.ok)
        local p=r.value.conditional_detection_probability
        assert(p>=previous and p>=0 and p<=1)
        previous=p
    end
end)

test("finer_schedule_does_not_reduce_detection",function()
    local previous=1
    for interval=1,30 do
        local p=run(interval,5,0.7).value.conditional_detection_probability
        assert(p<=previous+1e-12)
        previous=p
    end
end)

test("invalid_inputs_and_capacity",function()
    assert(run(0,2,0.8).error.code=="E_POSITIVE_INTERVAL")
    assert(run(7,-1,0.8).error.code=="E_NONNEGATIVE_DURATION")
    assert(run(7,2,1.1).error.code=="E_PROBABILITY")
    assert(run(1,10001,0.8).error.code=="E_COMPUTATION_CAPACITY")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
