-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M = require("lua.ecology.role_profile_audit")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1,500), "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic communication profile",
        records = {
            {assignments = {
                habitat_builder = {
                    state="documented",
                    evidence_reference="Synthetic fixture; not field evidence"
                },
                nutrient_transporter = {state="proposed"}
            }},
            {assignments = {
                pollinator = {
                    state="documented",
                    evidence_reference="Synthetic fixture; not field evidence"
                }
            }}
        }
    }
end

test("documented_and_proposed_are_separate", function()
    local r = M.evaluate(fixture())
    assert(r.ok)
    local p = r.value.assignment_counts_by_role
    assert(p.habitat_builder.documented == 1)
    assert(p.nutrient_transporter.proposed == 1)
    assert(p.decomposer.unassessed == 2)
    assert(not r.value.interpretation_limits.species_value_ranked)
end)

test("every_role_partitions_records", function()
    local r = M.evaluate(fixture())
    assert(r.ok)
    for _, role in ipairs(r.value.role_order) do
        local c = r.value.assignment_counts_by_role[role]
        assert(c.documented + c.proposed + c.unassessed == r.value.record_count)
    end
end)

test("documented_requires_reference", function()
    local x = fixture()
    x.records[1].assignments.habitat_builder.evidence_reference = nil
    local r = M.evaluate(x)
    assert(not r.ok and r.error.code == "E_EVIDENCE_REQUIRED")
end)

test("input_order_does_not_change_profile", function()
    local x = fixture()
    x.records[1], x.records[2] = x.records[2], x.records[1]
    local a, b = M.evaluate(fixture()), M.evaluate(x)
    assert(a.ok and b.ok)
    for _, role in ipairs(a.value.role_order) do
        for _, state in ipairs({"documented","proposed","unassessed"}) do
            assert(a.value.assignment_counts_by_role[role][state]
                == b.value.assignment_counts_by_role[role][state])
        end
    end
end)

test("output_does_not_alias_input", function()
    local x = fixture()
    local r = M.evaluate(x)
    assert(r.ok)
    r.value.assignment_counts_by_role.habitat_builder.documented = 99
    assert(x.records[1].assignments.habitat_builder.state == "documented")
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
