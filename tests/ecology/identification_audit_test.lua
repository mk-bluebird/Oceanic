-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M=require("lua.ecology.identification_audit")
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

test("confusion_counts_and_unknown_class",function()
    local r=M.evaluate({
        schema_version=1,
        taxon_labels={"native_target","lookalike","unresolved"},
        records={
            {reference="native_target",observer="native_target"},
            {reference="native_target",observer="unresolved"},
            {reference="lookalike",observer="native_target"}
        }
    })
    assert(r.ok)
    assert(r.value.confusion_counts.native_target.native_target==1)
    assert(r.value.confusion_counts.native_target.unresolved==1)
    assert(r.value.row_totals.lookalike==1)
    assert(r.value.overall_exact_agreement==1/3)
end)

test("zero_reference_class_is_not_divided_by_zero",function()
    local r=M.evaluate({
        schema_version=1,taxon_labels={"target","unresolved"},
        records={{reference="target",observer="target"}}
    })
    assert(r.ok)
    assert(r.value.row_normalized_confusion.unresolved.target==false)
end)

test("invalid_labels_and_records",function()
    local r=M.evaluate({
        schema_version=1,taxon_labels={"target"},
        records={{reference="target",observer="target"}}
    })
    assert(r.error.code=="E_UNRESOLVED_REQUIRED")
    r=M.evaluate({
        schema_version=1,taxon_labels={"target","unresolved"},
        records={{reference="other",observer="target"}}
    })
    assert(r.error.code=="E_LABEL")
end)

test("input_and_result_are_independent",function()
    local x={
        schema_version=1,taxon_labels={"target","unresolved"},
        records={{reference="target",observer="target"}}
    }
    local r=M.evaluate(x)
    assert(r.ok)
    r.value.confusion_counts.target.target=99
    assert(x.records[1].reference=="target")
end)

io.write("SUMMARY\tfailures\t",tostring(failures),"\n")
os.exit(failures==0 and 0 or 1)
