-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4 standard library. No I/O, networking, storage, or actuation.
--
-- Required fields:
-- relationship_type: feeding, habitat, pollination, dispersal,
--                    nutrient_transfer, or unresolved
-- source_role, target_role: exact documented role labels
-- evidence_basis: observation, source_report, model, or hypothesis
-- claim_level: event or functional_effect
-- endpoint_support: documented, not_established, or unknown
-- evidence_locator: bounded descriptive source location
-- scope: bounded spatial/temporal support description
--
-- For unresolved type, roles must both equal "unresolved".
-- This screen does not parse sources or authenticate evidence.

local M = {}
local VERSION = "0.1.0"

local fields = {
    "relationship_type", "source_role", "target_role",
    "evidence_basis", "claim_level", "endpoint_support",
    "evidence_locator", "scope"
}

local allowed = {}
for _, name in ipairs(fields) do allowed[name] = true end

local roles = {
    feeding = {"food_resource", "consumer"},
    habitat = {"habitat_provider", "habitat_user"},
    pollination = {"pollen_transfer_agent", "recipient_plant"},
    dispersal = {"transport_agent", "transported_organism_or_propagule"},
    nutrient_transfer = {"nutrient_donor", "nutrient_recipient"},
    unresolved = {"unresolved", "unresolved"}
}

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

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value, maximum)
    return type(value) == "string"
        and #value > 0 and #value <= maximum
        and value:find("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function member(value, choices)
    for _, choice in ipairs(choices) do
        if value == choice then return true end
    end
    return false
end

local function screen_impl(record)
    if not plain(record) then
        return fail("E_RECORD", "record")
    end

    for key in next, record do
        if not allowed[key] then
            return fail("E_FIELD", "record")
        end
    end

    for _, name in ipairs(fields) do
        if not text(rawget(record, name), 2048) then
            return fail("E_TEXT", name)
        end
    end

    local expected = roles[record.relationship_type]
    if not expected then
        return fail("E_TYPE", "relationship_type")
    end

    if record.source_role ~= expected[1] then
        return fail("E_DIRECTION_ROLE", "source_role")
    end
    if record.target_role ~= expected[2] then
        return fail("E_DIRECTION_ROLE", "target_role")
    end

    if not member(record.evidence_basis,
        {"observation", "source_report", "model", "hypothesis"}) then
        return fail("E_BASIS", "evidence_basis")
    end
    if not member(record.claim_level, {"event", "functional_effect"}) then
        return fail("E_LEVEL", "claim_level")
    end
    if not member(record.endpoint_support,
        {"documented", "not_established", "unknown"}) then
        return fail("E_ENDPOINT", "endpoint_support")
    end

    local routing = "source_and_scope_review_required"

    if record.relationship_type == "unresolved" then
        routing = "relationship_disambiguation_required"
    elseif record.evidence_basis == "model" then
        routing = "model_relationship_view_only_pending_review"
    elseif record.evidence_basis == "hypothesis" then
        routing = "hypothesis_view_only_pending_review"
    elseif record.claim_level == "functional_effect"
        and record.endpoint_support ~= "documented" then
        routing = "functional_effect_support_missing"
    end

    return envelope(true, {
        status = "declaration_screen_only",
        relationship_type = record.relationship_type,
        direction_convention = {
            source_role = expected[1],
            target_role = expected[2]
        },
        evidence_basis_declared = record.evidence_basis,
        claim_level_declared = record.claim_level,
        endpoint_support_declared = record.endpoint_support,
        review_routing = routing,
        source_verified = false,
        causal_effect_established = false,
        graph_admission_approved = false,
        release_authorized = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_DECLARED_TYPE",
                message = "A valid type declaration does not establish the process."
            },
            {
                code = "R_EVENT_EFFECT",
                message = "An event does not automatically establish benefit or dependence."
            },
            {
                code = "R_SOURCE",
                message = "Evidence locators and support declarations are not verified."
            },
            {
                code = "R_DIRECTION",
                message = "Arrow conventions are proposed project conventions."
            },
            {
                code = "R_NO_INFLUENCE",
                message = "No ecological influence or species worth is assessed."
            }
        }
    })
end

function M.screen(record)
    local ok, result = pcall(screen_impl, record)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end

function M.self_test()
    local function fixture()
        return {
            relationship_type = "feeding",
            source_role = "food_resource",
            target_role = "consumer",
            evidence_basis = "observation",
            claim_level = "event",
            endpoint_support = "unknown",
            evidence_locator = "Synthetic study, observation section",
            scope = "Synthetic site and observation period"
        }
    end

    local a = fixture()
    local first = M.screen(a)
    if not first.ok or first.value.graph_admission_approved then
        return fail("E_SELF_TEST", "baseline")
    end

    local reversed = fixture()
    reversed.source_role = "consumer"
    local r = M.screen(reversed)
    if r.ok or r.error.code ~= "E_DIRECTION_ROLE" then
        return fail("E_SELF_TEST", "reversed_direction")
    end

    local effect = fixture()
    effect.claim_level = "functional_effect"
    r = M.screen(effect)
    if not r.ok
        or r.value.review_routing ~= "functional_effect_support_missing" then
        return fail("E_SELF_TEST", "unsupported_effect")
    end

    local ambiguous = fixture()
    ambiguous.relationship_type = "unresolved"
    ambiguous.source_role = "unresolved"
    ambiguous.target_role = "unresolved"
    r = M.screen(ambiguous)
    if not r.ok
        or r.value.review_routing ~= "relationship_disambiguation_required" then
        return fail("E_SELF_TEST", "ambiguity_preserved")
    end

    local again = M.screen(a)
    if not again.ok
        or again.value.review_routing ~= first.value.review_routing
        or a.source_role ~= "food_resource" then
        return fail("E_SELF_TEST", "determinism_nonmutation")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        field_validation = "not_performed",
        ecological_relationships_verified = false
    })
end

return M
