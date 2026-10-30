-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.restoration_semantics.endpoint_competency_gaps")

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

local function endpoint(verdict)
    return {
        verdict = verdict,
        response_definition = "Synthetic endpoint definition",
        observation_period = "Synthetic declared period",
        reason = "Synthetic supplied review"
    }
end

local function competency()
    return {
        protocol_version = "synthetic-1",
        split = "held_out",
        required_concepts = {"recruitment", "detection"},
        represented_concepts = {"recruitment", "detection"},
        model_applicability = "supported",
        evidence_sufficiency = "sufficient",
        acceptance_criteria = "pass",
        partial_answer_supported = false
    }
end

test("survival_does_not_substitute_for_recruitment", function()
    local result = M.restoration({
        intended_outcome = "Synthetic persistent population",
        endpoints = {
            survival = endpoint("met"),
            recruitment = endpoint("not_met")
        },
        continuing_pressure_review = "unreviewed"
    })
    assert(result.ok)
    assert(result.value.declared_unmet_endpoints[1] == "recruitment")
    assert(not result.value.bottleneck_identified)
    assert(not result.value.overall_success_score_computed)
end)

test("absent_endpoint_is_not_assessed_not_failed", function()
    local result = M.restoration({
        intended_outcome = "Synthetic restoration outcome",
        endpoints = {},
        continuing_pressure_review = "unreviewed"
    })
    assert(result.ok)
    assert(#result.value.declared_unmet_endpoints == 0)
    assert(#result.value.unresolved_endpoints == 7)
end)

test("missing_required_concept_is_representation_failure", function()
    local input = competency()
    input.represented_concepts = {"recruitment"}
    input.evidence_sufficiency = "insufficient"
    local result = M.competency(input)
    assert(result.ok)
    assert(result.value.outcome == "representation_failure")
    assert(result.value.supplied_evidence_sufficiency == "insufficient")
end)

test("represented_concepts_do_not_establish_answer_support", function()
    local input = competency()
    input.model_applicability = "concern"
    local result = M.competency(input)
    assert(result.ok and result.value.outcome == "insufficient_basis")
end)

test("partial_answer_has_distinct_category", function()
    local input = competency()
    input.evidence_sufficiency = "partial"
    input.acceptance_criteria = "fail"
    input.partial_answer_supported = true
    local result = M.competency(input)
    assert(result.ok)
    assert(result.value.outcome == "qualified_partial_answer")
end)

test("empty_checklist_gap_does_not_prove_completeness", function()
    local result = M.gap({
        checklist_version = "synthetic-1",
        required_concepts = {"life_stage", "observation_process"},
        represented_concepts = {"life_stage", "observation_process"}
    })
    assert(result.ok and result.value.checklist_gap_empty)
    assert(result.value.actual_relevant_vocabulary_complete
        == "not_established")
    assert(not result.value.omission_probability_computed)
end)

test("gap_order_is_deterministic", function()
    local result = M.gap({
        checklist_version = "synthetic-1",
        required_concepts = {"recruitment", "detection", "boundary"},
        represented_concepts = {"recruitment"}
    })
    assert(result.ok)
    assert(result.value.missing_concepts[1] == "boundary")
    assert(result.value.missing_concepts[2] == "detection")
end)

test("duplicate_concepts_are_rejected", function()
    local input = competency()
    input.required_concepts = {"recruitment", "recruitment"}
    local result = M.competency(input)
    assert(not result.ok and result.error.code == "E_CONCEPT_LIST")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
