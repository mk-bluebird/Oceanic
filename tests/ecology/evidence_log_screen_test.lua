-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.evidence_log_screen")
local failures = 0

local function test(name, fn)
    local ok = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then failures = failures + 1 end
end

local function fixture()
    return {
        schema_version = 1,
        sensitivity = "unknown",
        extensions = {source_kind = "synthetic"},
        entry = {
            question = "Synthetic question",
            observed_time = "Synthetic time",
            subject = "Synthetic subject",
            result = "Synthetic observation",
            method = "Synthetic protocol",
            effort = "Synthetic effort",
            uncertainty = "Unknown"
        }
    }
end

test("complete_form_is_not_scientific_verification", function()
    local r = m.evaluate(fixture())
    assert(r.ok and r.value.completeness == 1)
    assert(not r.value.interpretation_limits.scientific_accuracy_verified)
    assert(not r.value.interpretation_limits.publication_authorized)
end)

test("missing_fields_are_evidence_gaps", function()
    local x = fixture()
    x.entry.effort = nil
    x.entry.uncertainty = false
    local r = m.evaluate(x)
    assert(r.ok and r.value.supplied_required_count == 5)
    assert(r.value.missing_required_fields[1] == "effort")
    assert(r.value.missing_required_fields[2] == "uncertainty")
end)

test("projection_excludes_free_text", function()
    local x = fixture()
    x.entry.result = "SENSITIVE_SYNTHETIC_MARKER"
    x.extensions.note = "SENSITIVE_SYNTHETIC_MARKER"
    local r = m.evaluate(x)
    assert(r.ok)
    local p = r.value.review_projection
    assert(p.result == nil and p.extensions == nil)
    assert(p.observed_time == nil and p.subject == nil)
end)

test("unknown_fields_and_schema_mismatch", function()
    local x = fixture()
    x.entry.coordinates = "Synthetic"
    assert(m.evaluate(x).error.code == "E_UNKNOWN_FIELD")
    x = fixture()
    x.schema_version = 2
    assert(m.evaluate(x).error.code == "E_SCHEMA_VERSION")
end)

test("utf8_and_control_validation", function()
    local x = fixture()
    x.entry.question = "Observación comunitaria"
    assert(m.evaluate(x).ok)
    x.entry.question = "line\nbreak"
    assert(m.evaluate(x).error.code == "E_TEXT")
    x.entry.question = string.char(255)
    assert(m.evaluate(x).error.code == "E_TEXT")
end)

test("nonmutation_and_projection_independence", function()
    local x = fixture()
    x.entry.effort = nil
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.review_projection.missing_required_fields[1] = "changed"
    assert(r.value.missing_required_fields[1] == "effort")
    assert(x.entry.effort == nil)
    assert(x.entry.status == nil)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
