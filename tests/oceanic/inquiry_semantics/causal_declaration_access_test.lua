-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.inquiry_semantics.causal_declaration_access")

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

test("confounded_association_is_not_intervention_effect", function()
    local result = M.binary_causal_comparison({
        p_z1 = 0.5,
        p_x1_given_z = {0.1, 0.9},
        p_y1_given_xz = {{0, 1}, {0, 1}}
    })
    assert(result.ok)
    local value = result.value
    assert(math.abs(value.observational_p_y1_given_x[1].value - 0.1) <= 1e-12)
    assert(math.abs(value.observational_p_y1_given_x[2].value - 0.9) <= 1e-12)
    assert(value.interventional_risk_difference == 0)
    assert(not value.intervention_authorized)
end)

test("undefined_observational_conditional_is_retained", function()
    local result = M.binary_causal_comparison({
        p_z1 = 0.5,
        p_x1_given_z = {1, 1},
        p_y1_given_xz = {{0.2, 0.2}, {0.8, 0.8}}
    })
    assert(result.ok)
    assert(result.value.observational_p_y1_given_x[1].status == "undefined")
end)

test("predictive_improvement_has_no_causal_status", function()
    local result = M.prediction_comparison({
        outcomes = {0, 1},
        baseline = {0.5, 0.5},
        augmented = {0.1, 0.9}
    })
    assert(result.ok)
    assert(math.abs(result.value.loss_reduction - 0.24) <= 1e-12)
    assert(not result.value.causal_effect_established)
end)

test("knowledge_claim_is_not_factive_knowledge", function()
    local result = M.record_declaration({
        speech_act = "knowledge_claim",
        proposition = "Synthetic recruitment increased.",
        scope = "Synthetic period and reach."
    })
    assert(result.ok)
    assert(result.value.speech_act == "knowledge_claim")
    assert(not result.value.factive_knowledge_asserted)
    assert(not result.value.actual_belief_inferred)
end)

test("completion_does_not_erase_unwanted_disclosure", function()
    local result = M.access_summary({
        protocol_version = "synthetic-1",
        tasks = {
            {
                completion = "completed",
                interpretation_error = "no",
                unwanted_disclosure = "yes",
                correction = "unavailable",
                voluntary_burden = "not_provided"
            }
        }
    })
    assert(result.ok)
    assert(result.value.completion_fraction.value == 1)
    assert(result.value.unwanted_disclosure_counts.yes == 1)
    assert(result.value.voluntary_burden_report_count == 0)
    assert(not result.value.competence_rank_computed)
end)

test("empty_task_set_has_undefined_completion_fraction", function()
    local result = M.access_summary({
        protocol_version = "synthetic-1",
        tasks = {}
    })
    assert(result.ok)
    assert(result.value.completion_fraction.status == "undefined")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
