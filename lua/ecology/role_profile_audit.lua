-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no identity verification, consent, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local categorical counts; no ranking, storage, logging, or sharing.

local V = require("lua.ecology.validation")
local M = {VERSION = "1.0.0"}
local ROLES = {
    "habitat_builder", "consumer_regulator", "pollinator",
    "seed_disperser", "nutrient_transporter",
    "primary_producer", "decomposer"
}
local STATES = {"documented", "proposed", "unassessed"}
local MAX_RECORDS = 1000

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "scope", "records"
    }, {}, "input")
    if not r.ok then return r end
    if x.schema_version ~= 1 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version", {
            expected = 1, actual = V.describe(x.schema_version)
        })
    end
    r = V.text(x.scope, 500, "input.scope")
    if not r.ok then return r end

    r = V.sequence(x.records, MAX_RECORDS, "input.records")
    if not r.ok then return r end
    local count = r.value
    local profile = {}
    for _, role in ipairs(ROLES) do
        profile[role] = {documented=0, proposed=0, unassessed=0}
    end

    for i = 1, count do
        local row = x.records[i]
        local path = "input.records[" .. i .. "]"
        r = V.record(row, {"assignments"}, {}, path)
        if not r.ok then return r end

        r = V.record(row.assignments, {}, ROLES, path .. ".assignments")
        if not r.ok then return r end

        for _, role in ipairs(ROLES) do
            local assignment = row.assignments[role]
            local state = "unassessed"
            if assignment ~= nil then
                local ap = path .. ".assignments." .. role
                r = V.record(assignment, {"state"}, {"evidence_reference"}, ap)
                if not r.ok then return r end
                r = V.enum(assignment.state, STATES, "E_ROLE_STATE", ap .. ".state")
                if not r.ok then return r end
                state = assignment.state

                if assignment.evidence_reference ~= nil then
                    r = V.text(assignment.evidence_reference, 500,
                        ap .. ".evidence_reference")
                    if not r.ok then return r end
                end
                if state == "documented"
                    and assignment.evidence_reference == nil then
                    return V.fail("E_EVIDENCE_REQUIRED",
                        ap .. ".evidence_reference")
                end
            end
            profile[role][state] = profile[role][state] + 1
        end
    end

    local order = {}
    for i, role in ipairs(ROLES) do order[i] = role end

    return V.ok({
        module_version = M.VERSION,
        schema_version = 1,
        validator_version = V.VERSION,
        vocabulary_version = 1,
        status = "screen_nonranking_role_profile",
        scope = x.scope,
        record_count = count,
        role_order = order,
        assignment_counts_by_role = profile,
        counting_rule = "one_state_per_role_per_input_record",
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            unique_taxa_verified = false,
            ecological_assignments_verified = false,
            evidence_references_verified = false,
            interaction_strength_estimated = false,
            species_value_ranked = false,
            conservation_priority_established = false,
            participant_consent_verified = false,
            anonymity_established = false,
            publication_authorized = false,
            persistence_performed = false,
            logging_performed = false,
            external_action_performed = false
        }
    })
end

return M
