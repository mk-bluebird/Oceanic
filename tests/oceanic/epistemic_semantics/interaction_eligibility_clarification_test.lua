-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.epistemic_semantics.interaction_eligibility_clarification")

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

local function eligibility(assessments)
    return M.eligibility({
        policy_version = "1.0.0",
        decision = "proceed_to_comparative_forecast_evaluation",
        assessments = assessments
    })
end

local function request()
    return {
        policy_version = "1.0.0",
        participant_preference = "continue",
        asked_count = 0,
        maximum_questions = 2,
        burden_used = 0,
        burden_limit = 2,
        candidates = {
            {
                code = "clarify_alignment",
                request_permission = "allowed",
                burden_cost = 1
            }
        }
    }
end

test("interaction_record_has_version_and_no_satisfaction_claim", function()
    local result = M.interactions({
        registry_version = "1.0.0",
        intents = {"forecast", "compare"}
    })
    assert(result.ok)
    local record = result.value.interaction_records[1]
    assert(record.rule_version == "1.0.0")
    assert(record.assessment_status == "not_assessed")
    assert(record.triggering_intents[1] == "compare")
end)

test("unsupported_registry_version_is_rejected", function()
    local result = M.interactions({
        registry_version = "future",
        intents = {"compare", "forecast"}
    })
    assert(not result.ok)
    assert(result.error.code == "E_REGISTRY_VERSION")
end)

test("missing_assessments_are_undetermined", function()
    local result = eligibility({})
    assert(result.ok)
    assert(result.value.analytical_eligibility == "undetermined")
    assert(#result.value.missing_assessments == 3)
    assert(not result.value.participation_assessed)
end)

test("three_valued_conjunction_all_combinations", function()
    local values = {"pass", "fail", "undetermined"}
    local cases = 0

    for _, a in ipairs(values) do
        for _, b in ipairs(values) do
            for _, c in ipairs(values) do
                local expected = "pass"
                if a == "fail" or b == "fail" or c == "fail" then
                    expected = "fail"
                elseif a == "undetermined" or b == "undetermined"
                    or c == "undetermined" then
                    expected = "undetermined"
                end

                local result = eligibility({
                    comparison_prerequisites = a,
                    forecast_prerequisites = b,
                    alignment_prerequisites = c
                })

                assert(result.ok)
                assert(result.value.analytical_eligibility == expected)
                assert(not result.value.action_authorized)
                cases = cases + 1
            end
        end
    end

    assert(cases == 27)
end)

test("explicit_stop_has_priority", function()
    local input = request()
    input.participant_preference = "stop"
    local result = M.next_clarification(input)
    assert(result.ok)
    assert(result.value.action == "stop")
    assert(result.value.reason == "participant_requested_stop")
end)

test("explicit_pause_is_not_rejection", function()
    local input = request()
    input.participant_preference = "pause"
    local result = M.next_clarification(input)
    assert(result.ok and result.value.action == "pause")
end)

test("unknown_permission_does_not_become_pass", function()
    local input = request()
    input.candidates[1].request_permission = "undetermined"
    local result = M.next_clarification(input)
    assert(result.ok and result.value.action == "defer")
end)

test("question_limit_stops_requests", function()
    local input = request()
    input.asked_count = 2
    local result = M.next_clarification(input)
    assert(result.ok)
    assert(result.value.reason == "question_limit_reached")
end)

test("burden_limit_stops_requests", function()
    local input = request()
    input.burden_used = 1.5
    local result = M.next_clarification(input)
    assert(result.ok)
    assert(result.value.reason == "burden_limit_reached")
end)

test("candidate_is_proposed_not_executed", function()
    local result = M.next_clarification(request())
    assert(result.ok)
    assert(result.value.action == "propose_question")
    assert(result.value.candidate_code == "clarify_alignment")
    assert(not result.value.request_executed)
    assert(not result.value.optimality_claimed)
end)

test("negative_burden_is_rejected", function()
    local input = request()
    input.burden_used = -1
    local result = M.next_clarification(input)
    assert(not result.ok)
    assert(result.error.code == "E_BURDEN_VALUE")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
