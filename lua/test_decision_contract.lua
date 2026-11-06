-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local engine = require("decision_contract")
local passed = 0

local function check(condition, name)
    assert(condition, name)
    passed = passed + 1
end

local function fixture(a, b, c, score)
    local input = {
        policy_version = "synthetic-policy/1.0.0",
        findings = {
            {
                name = "method evidence",
                stage = "evidence",
                status = a,
                code = "METHOD_REVIEW",
                rationale = "Synthetic test fixture."
            },
            {
                name = "material constraint",
                stage = "hard",
                status = b,
                code = "MATERIAL_REVIEW",
                rationale = "Synthetic test fixture."
            },
            {
                name = "scope uncertainty",
                stage = "uncertainty_qualified",
                status = c,
                code = "SCOPE_REVIEW",
                rationale = "Synthetic test fixture."
            }
        }
    }
    if score ~= nil then
        input.comparative_score = {
            value = score,
            rubric_version = "synthetic-rubric/1.0.0"
        }
    end
    return input
end

local states = { "pass", "fail", "unknown" }

for _, a in ipairs(states) do
    for _, b in ipairs(states) do
        for _, c in ipairs(states) do
            local input = fixture(a, b, c, 1)
            local result = engine.evaluate(input)
            check(result.ok, "truth_table_valid_input")

            local expected = "eligible_for_comparison"
            if a == "fail" or b == "fail" or c == "fail" then
                expected = "blocked"
            elseif a == "unknown" or b == "unknown" or c == "unknown" then
                expected = "unresolved"
            end

            check(result.value.disposition == expected,
                "truth_table_disposition")
            check(#result.value.findings == 3, "all_findings_preserved")

            for index, status in ipairs({ a, b, c }) do
                check(result.value.findings[index].status == status,
                    "individual_status_preserved")
            end

            local without_score = fixture(a, b, c)
            local plain = engine.evaluate(without_score)
            check(plain.value.disposition == result.value.disposition,
                "score_cannot_change_disposition")
        end
    end
end

local mixed = engine.evaluate(fixture("unknown", "fail", "pass", 1))
check(mixed.value.counts.fail == 1
    and mixed.value.counts.unknown == 1,
    "failure_and_unknown_coexist")
check(mixed.value.comparative_score.state == "withheld_from_comparison",
    "perfect_score_cannot_rescue_failure")

local input = fixture("pass", "pass", "pass")
local output = engine.evaluate(input)
output.value.findings[1].status = "fail"
check(input.findings[1].status == "pass", "output_does_not_alias_input")

input = fixture("pass", "pass", "pass")
input.findings[2].name = input.findings[1].name
check(engine.evaluate(input).error.code == "DUPLICATE_FINDING_NAME",
    "duplicate_names_rejected")

input = fixture("pass", "pass", "pass")
input.findings[2] = nil
check(engine.evaluate(input).error.code == "EXPECTED_DENSE_ARRAY",
    "sparse_findings_rejected")

input = fixture("pass", "pass", "pass")
input.findings[3].stage = "hard"
check(engine.evaluate(input).error.code == "MISSING_REQUIRED_STAGE",
    "missing_stage_rejected")

input = fixture("pass", "pass", "pass")
input.findings[1].status = "not_applicable"
check(engine.evaluate(input).error.code == "INVALID_STATUS",
    "unreviewed_exemption_rejected")

for _, value in ipairs({ math.huge, -math.huge, 0 / 0, -0.1, 1.1 }) do
    check(engine.evaluate(fixture("pass", "pass", "pass", value))
        .error.code == "INVALID_SCORE", "invalid_score_rejected")
end

input = fixture("pass", "pass", "pass")
input.override = true
check(engine.evaluate(input).error.code == "UNEXPECTED_FIELD",
    "undeclared_override_rejected")

io.write("Assertions passed: ", passed, "\n")
