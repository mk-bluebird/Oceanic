-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures and in-memory callbacks only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded_m, Migration = pcall(require,
    "lua.oceanic.epistemic_semantics.loss_reporting_migration")
local loaded_s, Storage = pcall(require,
    "lua.oceanic.governance_semantics.approved_storage_boundary")

if not loaded_m or not loaded_s then
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

local function migration_input()
    return {
        source_schema_version = 1,
        target_schema_version = 2,
        policy_version = "research-migration-policy-1",
        frame = {
            subject = {tag = "supplied", text = "Synthetic habitat"},
            spatial_scope = {tag = "withheld"}
        },
        extensions = {}
    }
end

test("preserved_declarations_and_new_gaps_are_separate", function()
    local result = Migration.plan(migration_input())
    assert(result.ok)
    assert(result.value.outcome == "declaration_preserving_candidate")
    local candidate = result.value.candidates[1]
    assert(candidate.frame.spatial_scope.tag == "withheld")
    assert(candidate.frame.evidence_basis == nil)
    assert(not result.value.semantic_equivalence_established)
end)

test("ambiguous_legacy_tag_produces_no_complete_candidate", function()
    local input = migration_input()
    input.frame.spatial_scope.tag = "unavailable"
    local result = Migration.plan(input)
    assert(result.ok)
    assert(result.value.outcome == "review_required")
    assert(#result.value.candidates == 0)
    assert(#result.value.ambiguities == 1)
end)

test("ignored_extension_is_reported_as_loss", function()
    local input = migration_input()
    input.extensions.display_hint = "Synthetic display instruction"
    local result = Migration.plan(input)
    assert(result.ok and result.value.outcome == "lossy_candidate")
    assert(#result.value.losses == 1)
end)

test("quarantine_does_not_retain_extension_content", function()
    local input = migration_input()
    input.extensions.provenance_note = "SYNTHETIC_PRIVATE_NOTE_7392"
    local result = Migration.plan(input)
    assert(result.ok and #result.value.candidates == 0)
    assert(not result.value.quarantine_notices[1].content_retained_here)
end)

test("unknown_extension_is_rejected", function()
    local input = migration_input()
    input.extensions.synthetic_unknown = "Synthetic value"
    local result = Migration.plan(input)
    assert(not result.ok)
    assert(result.error.code == "E_EXTENSION_REJECTED")
end)

test("migration_output_does_not_alias_input", function()
    local input = migration_input()
    local result = Migration.plan(input)
    assert(result.ok)
    result.value.candidates[1].frame.subject.text = "Changed"
    assert(input.frame.subject.text == "Synthetic habitat")
end)

test("storage_defaults_to_disabled", function()
    local result = Storage.create()
    assert(result.ok and not result.value.enabled)
    local written = result.value.write("synthetic", {})
    assert(not written.ok and written.error.code == "E_STORAGE_DISABLED")
end)

test("write_requires_separate_approval", function()
    local calls = 0
    local configured = Storage.create({
        purpose = "Synthetic review",
        retention_policy = "Synthetic short retention",
        retention_seconds = 60,
        approval_declared = true
    }, {
        access_check = function() return true end,
        write = function() calls = calls + 1; return true end,
        delete = function() return true end
    })
    assert(configured.ok)
    local result = configured.value.write("synthetic", {
        purpose = "Synthetic review",
        write_approved = false
    })
    assert(not result.ok and calls == 0)
end)

test("acknowledgement_is_not_retention_or_deletion_proof", function()
    local configured = Storage.create({
        purpose = "Synthetic review",
        retention_policy = "Synthetic short retention",
        retention_seconds = 60,
        approval_declared = true
    }, {
        access_check = function() return true end,
        write = function() return true end,
        delete = function() return true end
    })
    assert(configured.ok)

    local written = configured.value.write("synthetic", {
        purpose = "Synthetic review", write_approved = true
    })
    assert(written.ok)
    assert(not written.value.retention_enforcement_verified)

    local deleted = configured.value.delete({
        purpose = "Synthetic review", delete_approved = true
    })
    assert(deleted.ok)
    assert(not deleted.value.all_copies_deleted_verified)
end)

test("backend_exception_is_not_echoed", function()
    local configured = Storage.create({
        purpose = "Synthetic review",
        retention_policy = "Synthetic short retention",
        retention_seconds = 60,
        approval_declared = true
    }, {
        access_check = function() return true end,
        write = function() error("SYNTHETIC_PRIVATE_BACKEND_DETAIL") end,
        delete = function() return true end
    })
    assert(configured.ok)
    local result = configured.value.write("synthetic", {
        purpose = "Synthetic review", write_approved = true
    })
    assert(not result.ok)
    assert(result.error.code == "E_BACKEND_WRITE")
    assert(next(result.error.args) == nil)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
