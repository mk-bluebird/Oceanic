-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.shortlist_coverage")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        local safe = tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500)
        io.write("DETAIL\t", name, "\t", safe, "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        protocol_version = "synthetic-test-protocol",
        target_count = 2,
        role_minimums = {habitat_builder = 1, seed_disperser = 1},
        habitat_minimums = {land = 1, marine = 1},
        species = {
            {
                name = "Synthetic marine taxon",
                roles = {"habitat_builder"}, habitats = {"marine"},
                evidence_reference = "Synthetic fixture only"
            },
            {
                name = "Synthetic terrestrial taxon",
                roles = {"seed_disperser"}, habitats = {"land"},
                evidence_reference = "Synthetic fixture only"
            }
        }
    }
end

test("coverage_is_not_life_ranking", function()
    local r = m.evaluate(fixture())
    assert(r.ok and r.value.status == "screen_coverage_requirements_met")
    assert(not r.value.interpretation_limits.life_value_ranked)
    assert(not r.value.interpretation_limits.evidence_references_verified)
end)

test("unmet_role_is_visible", function()
    local x = fixture()
    x.role_minimums.pollinator = 1
    local r = m.evaluate(x)
    assert(r.ok and r.value.status == "screen_coverage_requirements_unmet")
    assert(r.value.unmet_requirements[1] == "role:pollinator")
end)

test("input_order_does_not_change_counts", function()
    local x = fixture()
    x.species[1], x.species[2] = x.species[2], x.species[1]
    local a, b = m.evaluate(fixture()), m.evaluate(x)
    assert(a.ok and b.ok)
    assert(a.value.role_counts.habitat_builder == b.value.role_counts.habitat_builder)
    assert(a.value.names_alphabetical[1] == b.value.names_alphabetical[1])
end)

test("duplicate_roles_cannot_inflate_coverage", function()
    local x = fixture()
    x.species[1].roles = {"habitat_builder", "habitat_builder"}
    assert(m.evaluate(x).error.code == "E_DUPLICATE_CATEGORY")
end)

test("empty_shortlist_and_invalid_schema", function()
    local x = fixture()
    x.species = {}
    assert(m.evaluate(x).value.status == "screen_coverage_requirements_unmet")
    x.schema_version = 2
    assert(m.evaluate(x).error.code == "E_SCHEMA_VERSION")
end)

test("output_mutation_does_not_change_input", function()
    local x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.role_minimums.habitat_builder = 99
    r.value.names_alphabetical[1] = "Changed"
    assert(x.role_minimums.habitat_builder == 1)
    assert(x.species[1].name == "Synthetic marine taxon")
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
