-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.citation_audit_summary")
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

local function run(records)
    return M.evaluate({
        schema_version=1,scope="Synthetic citation audit",records=records
    })
end

test("broken_link_does_not_mean_contradicted_claim",function()
    local r=run({{
        access="not_found",content="not_compared",claim_support="supports"
    }})
    assert(r.ok)
    assert(r.value.technical_follow_up_count==1)
    assert(r.value.claim_support_counts.contradicts==0)
end)

test("reachable_changed_content_can_need_review",function()
    local r=run({{
        access="reachable",content="changed",claim_support="unreviewed"
    }})
    assert(r.ok)
    assert(r.value.semantic_review_count==1)
    assert(r.value.record_dispositions[1].support_assessment_outstanding)
end)

test("reviewed_change_is_not_automatically_invalid",function()
    local r=run({{
        access="reachable",content="changed",claim_support="supports"
    }})
    assert(r.ok and r.value.semantic_review_count==0)
end)

test("blocked_is_not_counted_as_confirmed_disappearance",function()
    local r=run({{
        access="blocked",content="not_compared",claim_support="unreviewed"
    }})
    assert(r.ok)
    assert(r.value.interpretable_access_count==0)
    assert(r.value.reachable_fraction_among_interpretable_access==nil)
end)

test("invalid_enum_and_output_independence",function()
    assert(run({{
        access="dead",content="not_compared",claim_support="unreviewed"
    }}).error.code=="E_ACCESS_VALUE")
    local records={{
        access="reachable",content="unchanged",claim_support="supports"
    }}
    local r=run(records)
    assert(r.ok)
    r.value.record_dispositions[1].access="gone"
    assert(records[1].access=="reachable")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
