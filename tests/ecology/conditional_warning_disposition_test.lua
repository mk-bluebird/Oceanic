-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local M = require("lua.ecology.conditional_warning_disposition")
local V = require("lua.ecology.validation")
local failures = 0

local function eq(actual, expected)
    assert(actual == expected,
        "expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500), "\n")
    end
end

local function fixture()
    return {
        schema_version = 2,
        scope = "Synthetic strict-warning protocol fixture",
        protocol_frozen_before_outcome = true,
        protocol_reference = {
            repository = "mk-bluebird/Augmented-Hub",
            path = "docs/research/synthetic-warning-protocol.md",
            version = "synthetic-1",
            declared_check_count = 2,
            freeze_time_s = 100,
            outcome_inspection_time_s = 200
        },
        assumption_checks = {"met", "met"},
        event_status = "confirmed",
        observation_adequacy = "adequate",
        precursor_status = "absent"
    }
end

local function rejects(change, code, path)
    local x = fixture()
    change(x)
    local r = M.evaluate(x)
    eq(r.ok, false)
    eq(r.value, nil)
    assert(type(r.error) == "table")
    eq(r.error.code, code)
    eq(r.error.field_path, path)
end

test("rejection_paths", function()
    rejects(function(x) x.schema_version=1 end, "E_SCHEMA_VERSION", "input.schema_version")
    rejects(function(x) x.scope=nil end, "E_MISSING", "input.scope")
    rejects(function(x) x.extra=true end, "E_UNKNOWN_FIELD", "input[extra]")
    rejects(function(x) x.protocol_frozen_before_outcome=1 end,
        "E_BOOLEAN", "input.protocol_frozen_before_outcome")
    rejects(function(x) x.assumption_checks=1 end, "E_SEQUENCE", "input.assumption_checks")
    rejects(function(x) x.assumption_checks={} end, "E_EMPTY", "input.assumption_checks")
    rejects(function(x) x.assumption_checks={[1]="met",[3]="met"} end,
        "E_SEQUENCE_GAP", "input.assumption_checks")
    rejects(function(x) x.assumption_checks[0.5]="met" end,
        "E_INDEX_INTEGER", "input.assumption_checks")
    rejects(function(x) x.assumption_checks[-1]="met" end,
        "E_INDEX_POSITIVE", "input.assumption_checks")
    rejects(function(x) x.assumption_checks.extra="met" end,
        "E_INDEX_TYPE", "input.assumption_checks")
    rejects(function(x) x.assumption_checks[101]="met" end,
        "E_CAPACITY", "input.assumption_checks")
    rejects(function(x) x.event_status=42 end, "E_EVENT_STATUS_TYPE", "input.event_status")
    rejects(function(x) x.event_status="bad" end, "E_EVENT_STATUS_VALUE", "input.event_status")
    rejects(function(x) x.observation_adequacy="bad" end,
        "E_OBSERVATION_STATUS_VALUE", "input.observation_adequacy")
    rejects(function(x) x.precursor_status="bad" end,
        "E_PRECURSOR_STATUS_VALUE", "input.precursor_status")
    rejects(function(x) x.protocol_reference.declared_check_count=3 end,
        "E_CHECK_COUNT_MISMATCH", "input.assumption_checks")
    rejects(function(x) x.protocol_reference.freeze_time_s=false end,
        "E_FREEZE_TIME_REQUIRED", "input.protocol_reference.freeze_time_s")
    rejects(function(x) x.protocol_reference.freeze_time_s=201 end,
        "E_FREEZE_CHRONOLOGY", "input.protocol_reference.freeze_time_s")
end)

test("validator_schema_is_checked", function()
    eq(V.record({}, 42, {}, "x").error.code, "E_VALIDATOR_SCHEMA")
end)

test("nonevent_requires_adequate_observation", function()
    local x = fixture()
    x.event_status = "absent"
    x.observation_adequacy = "inadequate"
    local r = M.evaluate(x)
    assert(r.ok)
    eq(r.value.status, "screen_inconclusive_observation")
    eq(r.value.usable_for_separate_false_alarm_analysis, false)
    x.observation_adequacy = "adequate"
    eq(M.evaluate(x).value.usable_for_separate_false_alarm_analysis, true)
end)

test("paired_gate_priority_matrix", function()
    local mutations = {
        function(x) x.protocol_frozen_before_outcome=false end,
        function(x) x.assumption_checks[1]="not_met" end,
        function(x) x.assumption_checks[2]="unknown" end,
        function(x) x.event_status="uncertain" end,
        function(x) x.observation_adequacy="inadequate" end,
        function(x) x.precursor_status="not_assessable" end
    }
    local winners = {
        "protocol_freeze", "failed_assumptions", "unknown_assumptions",
        "event_uncertain", "observation_adequacy", "precursor_assessability"
    }
    for i = 1, #mutations do
        for j = i + 1, #mutations do
            local x = fixture()
            mutations[i](x)
            mutations[j](x)
            local r = M.evaluate(x)
            assert(r.ok)
            eq(r.value.selected_gate, winners[i])
            eq(r.value.applied_gates[i].selected, true)
        end
    end
end)

test("eligible_event_precursor_property", function()
    for _, precursor in ipairs({"present", "absent"}) do
        local x = fixture()
        x.precursor_status = precursor
        local r = M.evaluate(x)
        assert(r.ok and r.error == nil)
        eq(r.value.selected_gate,
            precursor == "present" and "precursor_present" or "precursor_absent")
    end
end)

test("protocol_and_gate_output_do_not_alias_inputs", function()
    local x = fixture()
    local r = M.evaluate(x)
    assert(r.ok)
    r.value.protocol_reference.version = "changed"
    r.value.assumption_checks[1] = "unknown"
    eq(x.protocol_reference.version, "synthetic-1")
    eq(x.assumption_checks[1], "met")
    eq(M.evaluate(fixture()).value.gate_order_version, 2)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
