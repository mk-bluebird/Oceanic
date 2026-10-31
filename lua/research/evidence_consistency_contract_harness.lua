-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4 standard library.
-- run(screen_function)
--
-- The injected function must implement the previously supplied
-- evidence_view_consistency_screen.screen contract.
--
-- All cases are synthetic.
-- No files, networking, persistence, publication, or actuation.
-- Only inject a trusted local implementation.

local M = {}
local VERSION = "0.1.0"

local function envelope(ok, value, code, path)
    return {
        ok = ok,
        schema_version = VERSION,
        module_version = VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            path = path or "",
            message_key = code or ""
        }
    }
end

local function fail(code, path)
    return envelope(false, false, code, path)
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for key, item in next, value do
        copied[key] = clone(item)
    end
    return copied
end

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in next, a do
        if not equal(value, b[key]) then return false end
    end
    for key in next, b do
        if a[key] == nil then return false end
    end
    return true
end

local function projection()
    return {
        card_version = "0.1.0",
        claim_text = "Synthetic tissue-level hazard estimate.",
        evidence_category = "statistical_estimate",
        analysis_unit = "tissue_region",
        effect_measure = "hazard_ratio",
        spatial_support = "synthetic_study_sites",
        temporal_support = "synthetic_event_window",
        limitation_codes = {"R_SITE_SCOPE", "R_NO_TRANSFER"}
    }
end

local function fixture()
    return {
        canonical = projection(),
        human_projection = projection(),
        machine_projection = projection(),
        evidence_projection = projection()
    }
end

local function cases()
    return {
        {
            name = "identical_projections",
            tier = "contract",
            mutate = function(_) end,
            findings = 0
        },
        {
            name = "effect_measure_changed",
            tier = "contract",
            mutate = function(c)
                c.human_projection.effect_measure = "risk_ratio"
            end,
            findings = 1
        },
        {
            name = "analysis_unit_changed",
            tier = "contract",
            mutate = function(c)
                c.machine_projection.analysis_unit = "colony"
            end,
            findings = 1
        },
        {
            name = "stale_card_version",
            tier = "contract",
            mutate = function(c)
                c.evidence_projection.card_version = "0.0.9"
            end,
            findings = 1
        },
        {
            name = "added_limitation",
            tier = "contract",
            mutate = function(c)
                c.human_projection.limitation_codes[3] = "R_NEW"
            end,
            findings = 1
        },
        {
            name = "limitation_order_only",
            tier = "contract",
            mutate = function(c)
                c.machine_projection.limitation_codes =
                    {"R_NO_TRANSFER", "R_SITE_SCOPE"}
            end,
            findings = 0
        },
        {
            name = "duplicate_limitation",
            tier = "contract",
            mutate = function(c)
                c.human_projection.limitation_codes =
                    {"R_SITE_SCOPE", "R_SITE_SCOPE"}
            end,
            error_code = "E_DUPLICATE"
        },
        {
            name = "missing_required_field",
            tier = "contract",
            mutate = function(c)
                c.machine_projection.effect_measure = nil
            end,
            error_code = "E_TEXT"
        },
        {
            name = "faithful_paraphrase_flags_exact_text",
            tier = "semantic_boundary",
            mutate = function(c)
                c.human_projection.claim_text =
                    "Synthetic hazard estimate at the tissue level."
            end,
            findings = 1
        },
        {
            name = "shared_incorrect_interpretation",
            tier = "semantic_boundary",
            mutate = function(c)
                local views = {
                    "canonical", "human_projection",
                    "machine_projection", "evidence_projection"
                }
                for _, view in ipairs(views) do
                    c[view].claim_text =
                        "Synthetic unsupported colony-level risk claim."
                    c[view].analysis_unit = "colony"
                    c[view].effect_measure = "risk_ratio"
                end
            end,
            findings = 0
        }
    }
end

local function run_impl(screen_function)
    if type(screen_function) ~= "function" then
        return fail("E_SCREEN_FUNCTION", "screen_function")
    end

    local results = {}
    local passed = 0
    local suite = cases()

    for _, test in ipairs(suite) do
        local input = fixture()
        test.mutate(input)
        local before = clone(input)

        local completed, output = pcall(screen_function, input)
        local success = false
        local reason = "malformed_or_raised_output"

        if completed and type(output) == "table"
            and type(output.ok) == "boolean" then

            if test.error_code then
                success = output.ok == false
                    and type(output.error) == "table"
                    and output.error.code == test.error_code
            else
                success = output.ok == true
                    and type(output.value) == "table"
                    and output.value.finding_count == test.findings
            end

            reason = success and "expected_behavior_observed"
                or "unexpected_behavior"
        end

        local unchanged = equal(input, before)
        if not unchanged then
            success = false
            reason = "input_mutated"
        end

        if success then passed = passed + 1 end
        results[#results + 1] = {
            case_name = test.name,
            tier = test.tier,
            passed = success,
            input_unchanged = unchanged,
            result_code = reason
        }
    end

    return envelope(true, {
        status = "contract_harness_completed",
        tests_passed = passed == #suite,
        passed_case_count = passed,
        total_case_count = #suite,
        cases = results,
        scientific_correctness_established = false,
        ecological_transfer_validated = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_EXECUTION_SCOPE",
                message = "Passing applies only to this synthetic suite."
            },
            {
                code = "R_SHARED_ERROR",
                message = "Shared incorrect claims are expected to evade drift detection."
            },
            {
                code = "R_PARAPHRASE",
                message = "Exact text differences are not semantic error judgments."
            },
            {
                code = "R_TRUSTED_CODE",
                message = "Injected functions execute locally and must be trusted."
            }
        }
    })
end

function M.run(screen_function)
    local ok, result = pcall(run_impl, screen_function)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end

return M
