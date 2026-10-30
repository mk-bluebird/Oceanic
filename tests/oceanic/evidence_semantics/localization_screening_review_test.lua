-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Localization fixtures are synthetic English examples, not translations.
-- Screening fixtures reproduce supplied published confusion counts.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded_l, L = pcall(require,
    "lua.oceanic.language_semantics.localization_force_audit")
local loaded_s, S = pcall(require,
    "lua.oceanic.evidence_semantics.screening_miss_metrics")

if not loaded_l or not loaded_s then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local total, failures = 0, 0

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

local function fixture()
    return {
        registry_version = "1.0.0",
        base = {
            locale = "en",
            purpose = "clarification_request",
            roles = {"field"},
            template = "You may clarify %{field}."
        },
        target = {
            locale = "en",
            purpose = "clarification_request",
            roles = {"field"},
            template = "For %{field}, clarification of %{field} is optional."
        },
        semantic_review = {
            negation = "not_applicable",
            uncertainty = "not_reviewed",
            evidential_status = "not_applicable",
            agency = "not_reviewed",
            severity = "not_reviewed",
            request_force = "not_reviewed"
        },
        fallback_available = true
    }
end

test("repeated_role_does_not_require_equal_placeholder_count", function()
    local result = L.evaluate(fixture())
    assert(result.ok and result.value.mechanical_conformance)
    assert(not result.value.semantic_equivalence_verified)
end)

test("purpose_mismatch_is_visible", function()
    local input = fixture()
    input.target.purpose = "error_report"
    local result = L.evaluate(input)
    assert(result.ok)
    assert(not result.value.mechanical_conformance)
end)

test("human_concern_can_coexist_with_mechanical_match", function()
    local input = fixture()
    input.semantic_review.request_force = "concern"
    local result = L.evaluate(input)
    assert(result.ok and result.value.mechanical_conformance)
    assert(result.value.semantic_concerns[1] == "request_force")
end)

test("unregistered_template_role_is_rejected", function()
    local input = fixture()
    input.target.template = "Clarify %{private_detail}."
    local result = L.evaluate(input)
    assert(not result.ok and result.error.code == "E_TARGET_ENTRY")
end)

test("title_abstract_counts_reproduce_sensitivity", function()
    local result = S.evaluate({tp = 22, fp = 3, fn = 1, tn = 14})
    assert(result.ok)
    assert(result.value.evaluated_record_count == 40)
    assert(math.abs(result.value.sensitivity.value - 22 / 23) <= 1e-12)
end)

test("full_text_misses_remain_explicit", function()
    local result = S.evaluate({tp = 11, fp = 1, fn = 7, tn = 26})
    assert(result.ok)
    assert(result.value.evaluated_record_count == 45)
    assert(result.value.missed_eligible_count == 7)
    assert(math.abs(result.value.sensitivity.value - 11 / 18) <= 1e-12)
    assert(not result.value.safe_exclusion_established)
end)

test("zero_eligible_denominator_is_undefined", function()
    local result = S.evaluate({tp = 0, fp = 1, fn = 0, tn = 4})
    assert(result.ok)
    assert(result.value.sensitivity.status == "undefined")
    assert(result.value.sensitivity.value == nil)
end)

test("fractional_count_is_rejected", function()
    local result = S.evaluate({tp = 1.5, fp = 0, fn = 0, tn = 1})
    assert(not result.ok and result.error.code == "E_COUNT_VALUE")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
