-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8kn6xaead9ye7
-- Attribution correction:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.evidence_semantics.dependence_support_adequacy")

if not loaded then
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
        claims = {
            {
                statement = "Synthetic intervention improved recruitment.",
                endpoint = "Recruitment in a declared reach and season."
            },
            {
                statement = "Synthetic background change explains recruitment.",
                endpoint = "The same declared recruitment endpoint."
            }
        },
        evidence_rows = {
            {
                description = "Synthetic primary observation report.",
                cells = {
                    {relation = "supports", reason = "Supplied review judgment."},
                    {relation = "weakens", reason = "Supplied alternative judgment."}
                }
            },
            {
                description = "Synthetic secondary report of shared observations.",
                cells = {
                    {relation = "supports", reason = "Reuses primary observations."},
                    {relation = "not_assessed", reason = "Alternative not reviewed."}
                }
            }
        },
        dependence_links = {
            {left = 2, right = 1, kind = "repeated_observations"}
        },
        comparative_review = {
            status = "preference_declared",
            preferred_claims = {1},
            reason = "Preferred among these alternatives only."
        },
        adequacy = {
            intended_use = "Synthetic causal attribution review.",
            criteria_version = "synthetic-1",
            criteria = {
                {
                    name = "Counterfactual comparison",
                    status = "fail",
                    reason = "No adequate comparison has been established."
                }
            }
        }
    }
end

test("preference_and_inadequacy_can_coexist", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    assert(result.value.comparative_review.preferred_claims[1] == 1)
    assert(result.value.adequacy_status == "not_met")
    assert(not result.value.numerical_evidence_score_computed)
end)

test("dependence_links_propagate_to_both_rows", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    assert(result.value.dependence_links[1].left == 1)
    assert(result.value.dependence_links[1].right == 2)
    assert(result.value.row_link_positions[1][1] == 1)
    assert(result.value.row_link_positions[2][1] == 1)
    assert(not result.value.undeclared_pairs_assumed_independent)
end)

test("shared_method_does_not_create_covariance_estimate", function()
    local input = fixture()
    input.dependence_links[1].kind = "shared_methods"
    local result = M.evaluate(input)
    assert(result.ok)
    assert(not result.value.covariance_estimated)
end)

test("empty_adequacy_criteria_are_undetermined", function()
    local input = fixture()
    input.adequacy.criteria = {}
    local result = M.evaluate(input)
    assert(result.ok)
    assert(result.value.adequacy_status == "undetermined")
end)

test("numeric_support_code_is_rejected", function()
    local input = fixture()
    input.evidence_rows[1].cells[1].relation = 1
    local result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_SUPPORT_CELL")
end)

test("reversed_duplicate_link_is_rejected", function()
    local input = fixture()
    input.dependence_links[2] = {
        left = 1, right = 2, kind = "repeated_observations"
    }
    local result = M.evaluate(input)
    assert(not result.ok and result.error.code == "E_DUPLICATE_LINK")
end)

test("output_does_not_alias_input", function()
    local input = fixture()
    local result = M.evaluate(input)
    assert(result.ok)
    result.value.evidence_rows[1].description = "Changed output."
    assert(input.evidence_rows[1].description
        == "Synthetic primary observation report.")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
