-- Lua 5.4 local regression tests.
-- Preserve this attribution block in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit/workstream metadata only; not consent, biological binding, identity verification,
-- authority, execution evidence, or a public status designation.
-- No persistent-memory or cryptographic-attestation claim.

local script = arg and arg[0]
assert(type(script) == "string", "run this file as a Lua script")
local directory = script:match("^(.*[/\\])") or "./"
package.path = directory .. "?.lua;" .. package.path

local module = require("restartable_aac_route")

local function expect_error(call, message)
    local ok = pcall(call)
    assert(not ok, message)
end

local function fixture(limit)
    local time = 0.0
    local route = module.new({
        expected_configuration = "reviewed-local",
        allowed_destinations = { "local_preview" },
        readiness_lifetime = 10.0,
        candidate_lifetime = 2.0,
        max_text_bytes = 4096,
        generation_limit = limit or 1000,
        clock = function()
            return time
        end
    })
    return route, function(value)
        time = value
    end
end

local function ready(route)
    route.signal_restored()
    assert(route.revalidate("reviewed-local", true, true),
        "supplied valid readiness must be accepted")
    route.user_resume()
    assert(route.user_select_route("local_preview"),
        "an allowlisted route must be selectable after resume")
end

local route, set_time = fixture()
assert(route.prepare_candidate() == nil,
    "initially unavailable route must reject preparation")

expect_error(function()
    route.revalidate("reviewed-local", true, true)
end, "revalidation must require connection observation")

ready(route)

local handle = route.prepare_candidate()
assert(handle ~= nil, "ready route must prepare a candidate")
assert(route.prepare_candidate() == nil,
    "pending candidate storage must be bounded to one")

assert(not route.consume_candidate({}).model_eligible,
    "an unrelated reference must be denied")
assert(route.status().pending_count == 1,
    "wrong-reference attempts must not consume the valid candidate")

set_time(1.5)
local accepted = route.consume_candidate(handle)
assert(accepted.model_eligible, "candidate must be eligible before expiry")
assert(accepted.permitted_by_model, "compatibility result field must agree")
assert(not accepted.current_permission_checked,
    "model result must not claim current authorization")
assert(not route.commit_decision(handle).model_eligible,
    "consumed handles must not be reusable")

local expiring = route.prepare_candidate()
set_time(3.5)
local expiry = route.consume_candidate(expiring)
assert(not expiry.model_eligible, "expiry endpoint must be exclusive")
assert(expiry.reason == "candidate_expired",
    "candidate expiry must produce a specific denial")

local replaceable = route.prepare_candidate()
assert(replaceable ~= nil, "a new candidate must fit after consumption")
set_time(6.0)
assert(route.prepare_candidate() ~= nil,
    "expired pending storage must be reclaimable")

route.user_pause()
route.signal_lost()
route.signal_restored()
assert(route.revalidate("reviewed-local", true, true))
assert(route.status().paused, "reconnection must preserve pause")

route.user_resume()
assert(route.user_select_route("local_preview"))
local old = route.prepare_candidate()
route.permission_changed()
assert(not route.consume_candidate(old).model_eligible,
    "permission changes must invalidate pending candidates")

route.user_deselect_route()
assert(route.prepare_candidate() == nil,
    "deselection must prevent candidate preparation")

set_time(16.0)
assert(route.status().phase == "needs_revalidation",
    "route readiness must expire independently of candidate expiry")

local legacy = module.new("reviewed-local")
legacy.signal_restored()
assert(legacy.revalidate("reviewed-local", true, true))
legacy.user_resume()
assert(legacy.user_select_route("legacy-local-preview"))
local legacy_handle = legacy.prepare_candidate(100, 10)
local legacy_result = legacy.commit_decision(legacy_handle, 11)
assert(legacy_result.permitted_by_model,
    "original constructor and commit signature must remain supported")
assert(legacy.status().mode == "caller_timed_compatibility",
    "compatibility timing must be visible")

legacy.permission_changed()
assert(legacy.prepare_candidate(100, 12) == nil,
    "legacy permission changes must block new preparation")
assert(legacy.revalidate("reviewed-local", true, true),
    "permission renewal must not require a fictitious reconnect")

local rollback, rollback_time = fixture()
ready(rollback)
rollback_time(1.0)
rollback.status()
rollback_time(0.5)
expect_error(function()
    rollback.status()
end, "backward clock movement must be rejected")
assert(rollback.snapshot().pending_count == 0,
    "clock failure must discard pending work")
assert(rollback.snapshot().phase == "needs_revalidation",
    "clock failure must invalidate readiness")

local limited = fixture(2)
limited.signal_restored()
limited.signal_restored()
expect_error(function()
    limited.signal_restored()
end, "generation exhaustion must reject further transitions")
assert(limited.status().exhausted,
    "generation exhaustion must remain latched")

local independent = fixture()
ready(independent)
route.signal_lost()
assert(independent.status().phase == "ready",
    "one instance must not mutate another")

expect_error(function()
    module.new("")
end, "empty configuration must be rejected")

expect_error(function()
    module.new({
        expected_configuration = "reviewed-local",
        allowed_destinations = { [2] = "local_preview" },
        readiness_lifetime = 10,
        candidate_lifetime = 2,
        clock = function() return 0 end
    })
end, "sparse destination allowlists must be rejected")
