-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.evidence_state_screen")
local failures = 0
local required = {
    "question", "observed_time", "subject",
    "result", "method", "effort", "uncertainty"
}

local function sanitize(value)
    return tostring(value):gsub("[%z\1-\31\127]", " "):sub(1, 500)
end

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t", sanitize(detail), "\n")
    end
end

local function fixture()
    return {
        schema_version = 2,
        entry_states = {},
        sensitivity_declaration = "unknown",
        consent_to_review = "granted"
    }
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = clone(item) end
    return copy
end

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function checked(input)
    local r = m.evaluate(input)
    assert(r.ok, r.error and r.error.code)
    return r.value
end

test("empty_entry_is_explicit_draft", function()
    local out = checked(fixture())
    assert(out.status == "screen_incomplete_draft")
    assert(out.review_projection.supplied_completeness == 0)
    assert(out.review_projection.accounted_completeness == 0)
end)

test("all_128_required_subsets", function()
    for mask = 0, 127 do
        local x, supplied = fixture(), 0
        for i, key in ipairs(required) do
            if math.floor(mask / 2^(i-1)) % 2 == 1 then
                x.entry_states[key] = "supplied"
                supplied = supplied + 1
            end
        end
        local p = checked(x).review_projection
        assert(p.supplied_required_count == supplied)
        assert(#p.not_supplied_required_fields == 7 - supplied)
        assert(p.supplied_completeness == supplied / 7)
        local seen = {}
        for _, key in ipairs(p.not_supplied_required_fields) do
            assert(not seen[key])
            assert(p.required_field_states[key] ~= "supplied")
            seen[key] = true
        end
        for _, key in ipairs(required) do
            assert((p.required_field_states[key] == "supplied")
                ~= (seen[key] == true))
        end
    end
end)

test("unknown_and_withheld_are_not_supplied", function()
    local x = fixture()
    for _, key in ipairs(required) do x.entry_states[key] = "supplied" end
    x.entry_states.effort = "unknown"
    x.entry_states.uncertainty = "withheld"
    local p = checked(x).review_projection
    assert(p.supplied_required_count == 5)
    assert(p.accounted_completeness == 1)
    assert(p.required_state_counts.withheld == 1)
end)

test("projection_exact_whitelist", function()
    local expected = {
        required_set_version = true, required_field_names = true,
        completeness_scope = true, required_field_count = true,
        supplied_required_count = true, required_state_counts = true,
        required_field_states = true, not_supplied_required_fields = true,
        supplied_completeness = true, accounted_completeness = true,
        optional_supplied_count = true, optional_accounted_count = true
    }
    local p = checked(fixture()).review_projection
    for key in pairs(p) do assert(expected[key], key) end
    for key in pairs(expected) do assert(p[key] ~= nil, key) end
end)

test("permission_gate_returns_no_projection", function()
    for _, permission in ipairs({"declined", "unknown"}) do
        local x = fixture()
        x.consent_to_review = permission
        x.entry_states = "not processed"
        local out = checked(x)
        assert(out.review_projection == nil)
        assert(out.status == "screen_review_permission_not_granted")
    end
end)

test("schema_states_and_extensions", function()
    local x = fixture()
    x.schema_version = 1
    local r = m.evaluate(x)
    assert(r.error.code == "E_SCHEMA_VERSION")
    assert(r.error.args.expected == 2 and r.error.args.actual == "1")

    x = fixture()
    x.entry_states.result = false
    assert(m.evaluate(x).error.code == "E_FIELD_STATE")

    x = fixture()
    x.sensitivity_declaration = "reviewed_low"
    assert(m.evaluate(x).error.code == "E_SENSITIVITY")

    x = fixture()
    x.extensions = {source_kind = "synthetic", entry_channel = "assisted"}
    assert(m.evaluate(x).ok)
    x.extensions.note = "not accepted raw text"
    assert(m.evaluate(x).error.code == "E_UNKNOWN_FIELD")

    assert(m.evaluate(nil).error.code == "E_RECORD")
end)

test("deep_nonmutation_and_output_independence", function()
    local x = fixture()
    x.entry_states.question = "supplied"
    x.extensions = {source_kind = "synthetic"}
    local before = clone(x)
    local out = checked(x)
    assert(equal(x, before))
    out.review_projection.required_field_states.question = "withheld"
    out.review_projection.required_field_names[1] = "changed"
    assert(equal(x, before))
    assert(checked(x).review_projection.required_field_names[1] == "question")
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
