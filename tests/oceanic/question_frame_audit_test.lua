-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.oceanic.question_frame_audit")
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

test("empty_draft_generates_six_clarifications",function()
    local r=M.evaluate({
        schema_version=1,question_type="describe",frame={}
    })
    assert(r.ok)
    assert(#r.value.missing_fields==6)
    assert(#r.value.suggested_clarifications==6)
end)

test("forecast_receives_validation_check",function()
    local r=M.evaluate({
        schema_version=1,question_type="forecast",
        frame={subject="Synthetic lake",response="Defined oxygen event"}
    })
    assert(r.ok)
    assert(#r.value.supplied_fields==2)
    assert(#r.value.missing_fields==4)
    assert(#r.value.further_checks==4)
    assert(not r.value.interpretation_limits.question_answered)
end)

test("unknown_field_and_invalid_type",function()
    local r=M.evaluate({
        schema_version=1,question_type="describe",
        frame={undeclared="value"}
    })
    assert(r.error.code=="E_UNKNOWN_FIELD")
    r=M.evaluate({
        schema_version=1,question_type="describe",frame={subject=42}
    })
    assert(r.error.code=="E_TEXT_TYPE")
end)

test("supplied_fields_are_not_scientific_verification",function()
    local frame={}
    for _,key in ipairs({
        "subject","response","spatial_scope","temporal_scope",
        "measurement_basis","evidence_basis"
    }) do frame[key]="Synthetic declared content" end
    local r=M.evaluate({
        schema_version=1,question_type="compare",frame=frame
    })
    assert(r.ok and #r.value.missing_fields==0)
    assert(not r.value.interpretation_limits.scientific_content_verified)
    assert(frame.subject=="Synthetic declared content")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
