-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.provenance_semantics.remedy_contribution_records")

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

test("request_does_not_skip_to_local_check", function()
    local result = M.transition({
        policy_version = "1.0.0",
        area = "retained_copies",
        from_progress = "not_started",
        to_progress = "check_recorded",
        basis = "local_check_record_declared"
    })
    assert(not result.ok)
    assert(result.error.code == "E_TRANSITION_NOT_ALLOWED")
end)

test("external_confirmation_is_not_local_verification", function()
    local result = M.transition({
        policy_version = "1.0.0",
        area = "external_copies",
        from_progress = "acknowledged",
        to_progress = "external_confirmation_reported",
        basis = "external_confirmation_declared"
    })
    assert(result.ok)
    assert(not result.value.supporting_record_verified)
    assert(not result.value.all_copies_addressed)
end)

test("external_copies_cannot_use_local_check_status", function()
    local result = M.transition({
        policy_version = "1.0.0",
        area = "external_copies",
        from_progress = "acknowledged",
        to_progress = "check_recorded",
        basis = "local_check_record_declared"
    })
    assert(not result.ok)
    assert(result.error.code == "E_TRANSITION_VALUE")
end)

test("missing_remedy_areas_remain_unresolved", function()
    local result = M.remedy_report({
        policy_version = "1.0.0",
        areas = {
            active_record = {
                progress = "check_recorded",
                inventory_status = "reviewed",
                basis = "local_check_record_declared"
            }
        }
    })
    assert(result.ok)
    assert(result.value.unreviewed_inventory_area_count == 4)
    assert(not result.value.complete_recall_verified)
    assert(not result.value.universal_deletion_verified)
end)

test("tested_counterexample_requires_basis_review_if_unreviewed", function()
    local result = M.contribution({
        taxonomy_version = "1.0.0",
        kind = "tested_counterexample",
        content = "Synthetic counterexample description.",
        scope = "Synthetic finite model.",
        basis = "not_reviewed",
        limitations = "Execution has not been checked."
    })
    assert(result.ok)
    assert(result.value.basis_review_required)
    assert(not result.value.supporting_record_verified)
end)

test("synthesis_does_not_become_empirical_finding", function()
    local result = M.contribution({
        taxonomy_version = "1.0.0",
        kind = "synthesis",
        content = "Synthetic connection between existing distinctions.",
        scope = "Research agenda only.",
        basis = "source_record_declared",
        limitations = "No new observations are supplied."
    })
    assert(result.ok)
    assert(not result.value.empirical_finding_established)
    assert(not result.value.novelty_verified)
end)

test("unknown_area_is_not_echoed", function()
    local result = M.remedy_report({
        policy_version = "1.0.0",
        areas = {
            SYNTHETIC_PRIVATE_LOCATION = {
                progress = "requested",
                inventory_status = "reviewed",
                basis = "request_record_declared"
            }
        }
    })
    assert(not result.ok)
    assert(result.error.code == "E_UNKNOWN_AREA")
    assert(result.error.path == "input.areas")
    assert(next(result.error.args) == nil)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
