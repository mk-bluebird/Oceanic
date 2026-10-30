-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Supplied-record processing only.
-- No correction, deletion, messaging, storage, or publication is performed.
-- This module does not authenticate supporting records.

local M = {
    VERSION = "1.0.0",
    REMEDY_POLICY_VERSION = "1.0.0",
    CONTRIBUTION_TAXONOMY_VERSION = "1.0.0"
}

local AREAS = {
    "active_record",
    "known_derivatives",
    "future_use",
    "retained_copies",
    "external_copies"
}

local AREA_SET = {}
for _, area in ipairs(AREAS) do AREA_SET[area] = true end

local PROGRESS = {
    not_started = true,
    requested = true,
    acknowledged = true,
    check_recorded = true,
    external_confirmation_reported = true,
    unresolved = true
}

local BASIS = {
    none = true,
    request_record_declared = true,
    acknowledgment_declared = true,
    local_check_record_declared = true,
    external_confirmation_declared = true
}

local KINDS = {
    source_report = true,
    observation = true,
    assumption = true,
    definition = true,
    derivation = true,
    tested_counterexample = true,
    proposed_method = true,
    hypothesis = true,
    recommendation = true,
    synthesis = true
}

local CONTRIBUTION_BASES = {
    not_reviewed = true,
    source_record_declared = true,
    observation_record_declared = true,
    assumptions_declared = true,
    execution_record_declared = true,
    review_record_declared = true
}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "remedy_contribution_records." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, keys)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(keys) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function text(value, maximum)
    return type(value) == "string"
        and #value > 0 and #value <= maximum
        and not value:match("^[ \t\r\n]*$")
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function choice(value, values)
    return type(value) == "string" and values[value] == true
end

local function valid_status(area, progress, basis)
    if not choice(progress, PROGRESS) or not choice(basis, BASIS) then
        return false
    end

    if progress == "not_started" then
        return basis == "none"
    elseif progress == "requested" then
        return basis == "request_record_declared"
    elseif progress == "acknowledged" then
        return basis == "acknowledgment_declared"
    elseif progress == "check_recorded" then
        return area ~= "external_copies"
            and basis == "local_check_record_declared"
    elseif progress == "external_confirmation_reported" then
        return area == "external_copies"
            and basis == "external_confirmation_declared"
    end

    return progress == "unresolved"
end

function M.transition(input)
    if not shape(input, {
        "policy_version", "area",
        "from_progress", "to_progress", "basis"
    }) then
        return fail("E_TRANSITION_SHAPE", "input")
    end

    if input.policy_version ~= M.REMEDY_POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end

    if not choice(input.area, AREA_SET)
        or not choice(input.from_progress, PROGRESS)
        or not valid_status(input.area, input.to_progress, input.basis) then
        return fail("E_TRANSITION_VALUE", "input")
    end

    local from, target = input.from_progress, input.to_progress
    local allowed =
        target == "unresolved"
        or (from == "not_started" and target == "requested")
        or (from == "requested" and target == "acknowledged")
        or (from == "acknowledged" and target == "check_recorded")
        or (from == "acknowledged"
            and target == "external_confirmation_reported")
        or (from == "unresolved" and target == "requested")

    if not allowed then
        return fail("E_TRANSITION_NOT_ALLOWED", "input")
    end

    return ok({
        policy_version = M.REMEDY_POLICY_VERSION,
        area = input.area,
        recorded_progress = target,
        supporting_basis = input.basis,
        previous_record_authenticated = false,
        supporting_record_verified = false,
        remedy_executed_here = false,
        all_copies_addressed = false
    })
end

function M.remedy_report(input)
    if not shape(input, {"policy_version", "areas"}) then
        return fail("E_REPORT_SHAPE", "input")
    end
    if input.policy_version ~= M.REMEDY_POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end
    if not plain(input.areas) then
        return fail("E_AREA_RECORDS", "input.areas")
    end

    for area in next, input.areas do
        if type(area) ~= "string" or not AREA_SET[area] then
            return fail("E_UNKNOWN_AREA", "input.areas")
        end
    end

    local records = {}
    local unreviewed_inventory, unresolved_progress = 0, 0

    for _, area in ipairs(AREAS) do
        local record = rawget(input.areas, area)

        if record == nil then
            unreviewed_inventory = unreviewed_inventory + 1
            unresolved_progress = unresolved_progress + 1
            records[#records + 1] = {
                area = area,
                progress = "unresolved",
                inventory_status = "unreviewed",
                basis = "none"
            }
        else
            if not shape(record, {
                "progress", "inventory_status", "basis"
            }) or not valid_status(area, record.progress, record.basis)
                or (record.inventory_status ~= "reviewed"
                    and record.inventory_status ~= "unreviewed") then
                return fail("E_AREA_RECORD", "input.areas")
            end

            if record.inventory_status == "unreviewed" then
                unreviewed_inventory = unreviewed_inventory + 1
            end
            if record.progress == "unresolved"
                or record.progress == "not_started" then
                unresolved_progress = unresolved_progress + 1
            end

            records[#records + 1] = {
                area = area,
                progress = record.progress,
                inventory_status = record.inventory_status,
                basis = record.basis
            }
        end
    end

    return ok({
        policy_version = M.REMEDY_POLICY_VERSION,
        area_records = records,
        unreviewed_inventory_area_count = unreviewed_inventory,
        unresolved_or_unstarted_area_count = unresolved_progress,
        inventory_exhaustiveness_verified = false,
        correction_propagation_verified = false,
        universal_deletion_verified = false,
        complete_recall_verified = false,
        future_use_restriction_enforced_here = false,
        assessment_scope = "supplied_remedy_progress_only"
    })
end

function M.contribution(input)
    if not shape(input, {
        "taxonomy_version", "kind", "content",
        "scope", "basis", "limitations"
    }) then
        return fail("E_CONTRIBUTION_SHAPE", "input")
    end

    if input.taxonomy_version ~= M.CONTRIBUTION_TAXONOMY_VERSION then
        return fail("E_TAXONOMY_VERSION", "input.taxonomy_version")
    end

    if not choice(input.kind, KINDS)
        or not choice(input.basis, CONTRIBUTION_BASES)
        or not text(input.content, 4000)
        or not text(input.scope, 1000)
        or not text(input.limitations, 2000) then
        return fail("E_CONTRIBUTION_VALUE", "input")
    end

    local expected = {
        observation = "observation_record_declared",
        derivation = "assumptions_declared",
        tested_counterexample = "execution_record_declared",
        source_report = "source_record_declared"
    }

    local required_basis = expected[input.kind]
    local basis_matches =
        required_basis == nil or input.basis == required_basis

    return ok({
        taxonomy_version = M.CONTRIBUTION_TAXONOMY_VERSION,
        kind = input.kind,
        content = input.content,
        scope = input.scope,
        basis = input.basis,
        limitations = input.limitations,
        expected_basis_declared = basis_matches,
        basis_review_required = not basis_matches,
        contribution_label_verified = false,
        supporting_record_verified = false,
        empirical_finding_established = false,
        novelty_verified = false,
        authority_established = false,
        assessment_scope = "supplied_contribution_label"
    })
end

return M
