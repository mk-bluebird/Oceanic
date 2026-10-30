-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.typed_relationship_graph")
local failed = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failed = failed + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function fixture()
    return {
        schema_version = 1,
        scope = "Synthetic structural fixture; no field evidence",
        nodes = {
            {name = "Clark's nutcracker", class = "taxon"},
            {name = "Whitebark pine", class = "taxon"}
        },
        edges = {
            {
                source = "Clark's nutcracker", target = "Whitebark pine",
                relation = "consumes", evidence_kind = "hypothesis",
                evidence_reference = "Synthetic test fixture",
                review_status = "unreviewed"
            },
            {
                source = "Clark's nutcracker", target = "Whitebark pine",
                relation = "disperses_seeds", evidence_kind = "hypothesis",
                evidence_reference = "Synthetic test fixture",
                review_status = "unreviewed"
            }
        }
    }
end

local function rejects(change, code)
    local x = fixture()
    change(x)
    local r = m.evaluate(x)
    assert(not r.ok and r.error.code == code)
end

test("layers remain separate", function()
    local r = m.evaluate(fixture())
    assert(r.ok)
    local d = r.value.degree_by_layer
    assert(d.consumes["Clark's nutcracker"].outgoing == 1)
    assert(d.disperses_seeds["Clark's nutcracker"].outgoing == 1)
    assert(d.pollinates["Clark's nutcracker"].outgoing == 0)
    assert(not r.value.interpretation_limits.keystone_status_established)
end)

test("endpoint class restrictions", function()
    rejects(function(x) x.nodes[2].class = "compartment" end,
        "E_ENDPOINT_CLASS")
end)

test("duplicate edge and absent endpoint", function()
    rejects(function(x) x.edges[2].relation = "consumes" end,
        "E_DUPLICATE_EDGE")
    rejects(function(x) x.edges[1].target = "Absent taxon" end,
        "E_UNKNOWN_TARGET")
end)

test("missing fields and schema mismatch", function()
    rejects(function(x) x.scope = nil end, "E_MISSING")
    rejects(function(x) x.schema_version = 2 end, "E_SCHEMA_VERSION")
end)

test("empty edge layer is valid", function()
    local x = fixture()
    x.edges = {}
    local r = m.evaluate(x)
    assert(r.ok)
    assert(r.value.degree_by_layer.consumes["Whitebark pine"].incoming == 0)
end)

test("edge order does not change degree", function()
    local x = fixture()
    x.edges[1], x.edges[2] = x.edges[2], x.edges[1]
    local r = m.evaluate(x)
    assert(r.ok)
    assert(r.value.degree_by_layer.consumes["Whitebark pine"].incoming == 1)
end)

test("input and output are independent", function()
    local x = fixture()
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.edges[1].relation = "pollinates"
    r.value.nodes[1].name = "Changed"
    r.value.relation_order[1] = "Changed"
    assert(x.edges[1].relation == "consumes")
    assert(x.nodes[1].name == "Clark's nutcracker")
    assert(m.evaluate(fixture()).value.relation_order[1] == "consumes")
end)

os.exit(failed == 0 and 0 or 1)
