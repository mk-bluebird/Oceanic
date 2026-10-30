-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Run from repository root:
-- lua tests/ecology/evidence_state_full_audit.lua
-- stdout: tab-separated CONFIG/PASS/FAIL/DETAIL/SUMMARY records.
-- Exit 0: all checks passed. Exit 1: at least one failed.
-- Synthetic state-space audit; not field data or a consent service.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no identity, consent, or operational authority.

local screen = require("lua.ecology.evidence_state_screen")
local REQUIRED = {
    "question", "observed_time", "subject",
    "result", "method", "effort", "uncertainty"
}
local OPTIONAL = {"units", "interpretation", "follow_up"}
local STATES = {"supplied", "unknown", "not_collected", "withheld"}
local EXPECTED_KEYS = {
    required_set_version = true,
    required_field_names = true,
    completeness_scope = true,
    required_field_count = true,
    supplied_required_count = true,
    required_state_counts = true,
    required_field_states = true,
    not_supplied_required_fields = true,
    supplied_completeness = true,
    accounted_completeness = true,
    optional_supplied_count = true,
    optional_accounted_count = true
}
local TOLERANCE = 1e-12
local failures, vectors_checked, optional_checked, transitions_checked = 0, 0, 0, 0

local function close(a, b)
    assert(type(a) == "number" and type(b) == "number")
    assert(math.abs(a - b) <= TOLERANCE)
end

local function sanitize(x)
    return tostring(x):gsub("[%z\1-\31\127]", " "):sub(1, 500)
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

local function clone(x)
    if type(x) ~= "table" then return x end
    local out = {}
    for key, value in pairs(x) do out[key] = clone(value) end
    return out
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

local function evaluate(x)
    local r = screen.evaluate(x)
    assert(type(r) == "table" and type(r.ok) == "boolean")
    if r.ok then
        assert(r.error == nil and type(r.value) == "table")
    else
        assert(r.value == nil and type(r.error) == "table")
        assert(type(r.error.code) == "string")
    end
    return r
end

local function check_projection(x)
    local before = clone(x)
    local r = evaluate(x)
    assert(r.ok, r.error and r.error.code)
    assert(equal(x, before), "input modified")
    local p = r.value.review_projection
    assert(type(p) == "table")

    for key in pairs(p) do
        assert(EXPECTED_KEYS[key], "unexpected projection key")
    end
    for key in pairs(EXPECTED_KEYS) do
        assert(p[key] ~= nil, "missing projection key")
    end

    local counts = {supplied = 0, unknown = 0, not_collected = 0, withheld = 0}
    local supplied, nonsupplied = {}, {}
    for i, key in ipairs(REQUIRED) do
        local state = x.entry_states[key] or "not_collected"
        counts[state] = counts[state] + 1
        assert(p.required_field_names[i] == key)
        assert(p.required_field_states[key] == state)
        if state == "supplied" then supplied[key] = true end
    end
    for _, key in ipairs(p.not_supplied_required_fields) do
        assert(not nonsupplied[key], "duplicate nonsupplied field")
        assert(not supplied[key], "field in both partitions")
        nonsupplied[key] = true
    end

    local total = 0
    for _, state in ipairs(STATES) do
        assert(p.required_state_counts[state] == counts[state])
        total = total + counts[state]
    end
    assert(total == 7)
    for _, key in ipairs(REQUIRED) do
        assert(supplied[key] or nonsupplied[key], "uncovered field")
    end
    assert(#p.not_supplied_required_fields == 7 - counts.supplied)
    assert(p.supplied_required_count == counts.supplied)
    assert(p.required_field_count == 7)
    assert(p.required_set_version == 1)
    assert(p.completeness_scope == "required_fields_only")
    close(p.supplied_completeness, counts.supplied / 7)
    close(p.accounted_completeness, 1 - counts.not_collected / 7)
    assert(p.supplied_completeness <= p.accounted_completeness + TOLERANCE)

    local optional_supplied, optional_accounted = 0, 0
    for _, key in ipairs(OPTIONAL) do
        local state = x.entry_states[key] or "not_collected"
        if state == "supplied" then optional_supplied = optional_supplied + 1 end
        if state ~= "not_collected" then
            optional_accounted = optional_accounted + 1
        end
    end
    assert(p.optional_supplied_count == optional_supplied)
    assert(p.optional_accounted_count == optional_accounted)
    return p
end

io.write("CONFIG\trequired_vectors\t16384\toptional_vectors\t64",
    "\ttolerance\t", tostring(TOLERANCE), "\n")

test("all_required_state_vectors", function()
    local pairs_seen, pair_count = {}, 0
    for encoding = 0, 4^7 - 1 do
        local x, value = fixture(), encoding
        for _, key in ipairs(REQUIRED) do
            x.entry_states[key] = STATES[value % 4 + 1]
            value = math.floor(value / 4)
        end
        local p = check_projection(x)
        local pair_key = p.supplied_required_count .. ":" ..
            p.required_state_counts.not_collected
        if not pairs_seen[pair_key] then
            pairs_seen[pair_key] = true
            pair_count = pair_count + 1
        end
        vectors_checked = vectors_checked + 1
    end
    assert(vectors_checked == 16384)
    assert(pair_count == 36)
end)

test("all_optional_state_vectors", function()
    for encoding = 0, 4^3 - 1 do
        local x, value = fixture(), encoding
        for _, key in ipairs(OPTIONAL) do
            x.entry_states[key] = STATES[value % 4 + 1]
            value = math.floor(value / 4)
        end
        check_projection(x)
        optional_checked = optional_checked + 1
    end
    assert(optional_checked == 64)
end)

test("all_single_field_ordered_transitions", function()
    for _, field in ipairs(REQUIRED) do
        for _, from in ipairs(STATES) do
            for _, to in ipairs(STATES) do
                if from ~= to then
                    local x = fixture()
                    x.entry_states[field] = from
                    check_projection(x)
                    x.entry_states[field] = to
                    check_projection(x)
                    transitions_checked = transitions_checked + 1
                end
            end
        end
    end
    assert(transitions_checked == 84)
end)

test("valid_denial_returns_no_projection", function()
    for _, permission in ipairs({"declined", "unknown"}) do
        local x = fixture()
        x.consent_to_review = permission
        local r = evaluate(x)
        assert(r.ok)
        assert(r.value.review_projection == nil)
    end
end)

test("new_requirement_invalid_states_rejected_under_denial", function()
    local x = fixture()
    x.consent_to_review = "declined"
    x.entry_states.result = false
    local r = evaluate(x)
    assert(not r.ok, "current module bypasses payload validation")
    assert(r.error.code == "E_FIELD_STATE")
    assert(r.error.field_path == "input.entry_states.result")
end)

test("empty_and_explicit_not_collected_are_equivalent", function()
    local x, y = fixture(), fixture()
    for _, key in ipairs(REQUIRED) do y.entry_states[key] = "not_collected" end
    assert(equal(check_projection(x), check_projection(y)))
end)

io.write("SUMMARY\tfailures\t", tostring(failures),
    "\trequired_checked\t", tostring(vectors_checked),
    "\toptional_checked\t", tostring(optional_checked),
    "\ttransitions_checked\t", tostring(transitions_checked), "\n")
os.exit(failures == 0 and 0 or 1)
