-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.governance_semantics.scoped_permission_limitation")

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

local function use()
    return {
        operation = "analysis",
        purpose = "Synthetic recruitment comparison",
        audience = "restricted_review",
        scope = "Synthetic coarse habitat description",
        start_second = 10,
        end_second = 20,
        derivative = "none"
    }
end

local function request(records)
    return M.match_permission({
        policy_version = "1.0.0",
        request = use(),
        records = records
    })
end

test("matching_record_is_not_authorization", function()
    local result = request({
        {use = use(), determination = "permitted"}
    })
    assert(result.ok)
    assert(result.value.recorded_permission_status == "permitted")
    assert(not result.value.authority_verified)
    assert(not result.value.action_authorized_here)
end)

test("audience_change_does_not_inherit_permission", function()
    local record = use()
    record.audience = "public"
    local result = request({
        {use = record, determination = "permitted"}
    })
    assert(result.ok)
    assert(result.value.recorded_permission_status == "undetermined")
end)

test("derivative_change_does_not_inherit_permission", function()
    local record = use()
    record.derivative = "summary"
    local result = request({
        {use = record, determination = "permitted"}
    })
    assert(result.ok)
    assert(result.value.matching_record_count == 0)
end)

test("use_interval_must_be_contained", function()
    local record = use()
    record.start_second = 11
    local result = request({
        {use = record, determination = "permitted"}
    })
    assert(result.ok)
    assert(result.value.recorded_permission_status == "undetermined")
end)

test("conflicting_records_do_not_grant_permission", function()
    local result = request({
        {use = use(), determination = "permitted"},
        {use = use(), determination = "not_permitted"}
    })
    assert(result.ok)
    assert(result.value.recorded_permission_status == "undetermined")
end)

test("narrower_inference_can_avoid_withheld_requirement", function()
    local result = M.trace_limitations({
        withheld = {"exact_location"},
        steps = {
            {requirements = {"exact_location", "response_measurements"}},
            {requirements = {"coarse_location", "response_measurements"}}
        }
    })
    assert(result.ok)
    assert(result.value.step_results[1].status == "potentially_limited")
    assert(result.value.step_results[2].status
        == "not_blocked_by_declared_withholding")
    assert(not result.value.disclosure_requested)
end)

test("public_notice_does_not_consume_trace", function()
    local first = M.public_notice()
    local second = M.public_notice()
    assert(first.ok and second.ok)
    assert(first.value.text == second.value.text)
    assert(not first.value.trace_consumed)
    assert(not first.value.text:find("withheld", 1, true))
    assert(not first.value.text:find("exact_location", 1, true))
end)

test("summary_label_does_not_verify_release", function()
    local result = M.summary_notice("scope_limited")
    assert(result.ok)
    assert(not result.value.release_approval_verified)
    assert(not result.value.publication_authorized)
end)

test("unregistered_requirement_is_rejected", function()
    local result = M.trace_limitations({
        withheld = {"SYNTHETIC_PRIVATE_REQUIREMENT"},
        steps = {}
    })
    assert(not result.ok)
    assert(result.error.code == "E_REQUIREMENTS")
    assert(next(result.error.args) == nil)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
