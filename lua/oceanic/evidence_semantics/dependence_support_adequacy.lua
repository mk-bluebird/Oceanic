-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Local review ledger only; no I/O, storage, retrieval, or actuation.
-- Returned review text may be sensitive. Do not automatically log it.

local M = {VERSION = "1.0.0"}
local MAX = 16
local MAX_LINKS = 64

local RELATIONS = {
    supports = true,
    weakens = true,
    uninformative = true,
    not_assessed = true
}

local DEPENDENCE = {
    repeated_observations = true,
    shared_samples = true,
    shared_controls = true,
    shared_methods = true,
    possible_overlap = true
}

local STATUS = {pass = true, fail = true, undetermined = true}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "dependence_support_adequacy." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, required)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function length(value, maximum, allow_empty)
    if not plain(value) then return nil end
    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > maximum or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > maximum then
            return nil
        end
        if key > highest then highest = key end
    end
    if count ~= highest or (count == 0 and not allow_empty) then
        return nil
    end
    return count
end

local function text(value)
    return type(value) == "string"
        and #value > 0 and #value <= 2000
        and not value:match("^[ \t\r\n]*$")
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function position(value, maximum)
    return type(value) == "number"
        and value % 1 == 0
        and value >= 1 and value <= maximum
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in next, value do result[key] = copy(item) end
    return result
end

function M.evaluate(input)
    if not shape(input, {
        "claims", "evidence_rows", "dependence_links",
        "comparative_review", "adequacy"
    }) then
        return fail("E_INPUT_SHAPE", "input")
    end

    local claims = length(input.claims, MAX, false)
    local rows = length(input.evidence_rows, MAX, false)
    local links = length(input.dependence_links, MAX_LINKS, true)

    if not claims then return fail("E_CLAIMS", "input.claims") end
    if not rows then return fail("E_ROWS", "input.evidence_rows") end
    if not links then
        return fail("E_LINKS", "input.dependence_links")
    end

    for _, claim in ipairs(input.claims) do
        if not shape(claim, {"statement", "endpoint"})
            or not text(claim.statement) or not text(claim.endpoint) then
            return fail("E_CLAIM", "input.claims")
        end
    end

    for _, row in ipairs(input.evidence_rows) do
        if not shape(row, {"description", "cells"})
            or not text(row.description)
            or length(row.cells, MAX, false) ~= claims then
            return fail("E_EVIDENCE_ROW", "input.evidence_rows")
        end

        for _, cell in ipairs(row.cells) do
            if not shape(cell, {"relation", "reason"})
                or type(cell.relation) ~= "string"
                or not RELATIONS[cell.relation]
                or not text(cell.reason) then
                return fail("E_SUPPORT_CELL", "input.evidence_rows")
            end
        end
    end

    local canonical_links, seen = {}, {}
    for _, link in ipairs(input.dependence_links) do
        if not shape(link, {"left", "right", "kind"})
            or not position(link.left, rows)
            or not position(link.right, rows)
            or link.left == link.right
            or type(link.kind) ~= "string"
            or not DEPENDENCE[link.kind] then
            return fail("E_DEPENDENCE_LINK", "input.dependence_links")
        end

        local left = math.min(link.left, link.right)
        local right = math.max(link.left, link.right)
        local key = left .. ":" .. right .. ":" .. link.kind

        if seen[key] then
            return fail("E_DUPLICATE_LINK", "input.dependence_links")
        end
        seen[key] = true
        canonical_links[#canonical_links + 1] = {
            left = left, right = right, kind = link.kind
        }
    end

    table.sort(canonical_links, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        if a.right ~= b.right then return a.right < b.right end
        return a.kind < b.kind
    end)

    local comparative = input.comparative_review
    if not shape(comparative, {"status", "preferred_claims", "reason"})
        or (comparative.status ~= "preference_declared"
            and comparative.status ~= "undetermined")
        or not text(comparative.reason) then
        return fail("E_COMPARATIVE_REVIEW", "input.comparative_review")
    end

    local preferred_count = length(
        comparative.preferred_claims, MAX, true)
    if preferred_count == nil then
        return fail("E_PREFERENCE", "input.comparative_review")
    end
    if (comparative.status == "preference_declared" and preferred_count == 0)
        or (comparative.status == "undetermined" and preferred_count ~= 0) then
        return fail("E_PREFERENCE_STATUS", "input.comparative_review")
    end

    local preferred_seen = {}
    for _, p in ipairs(comparative.preferred_claims) do
        if not position(p, claims) or preferred_seen[p] then
            return fail("E_PREFERENCE", "input.comparative_review")
        end
        preferred_seen[p] = true
    end

    local adequacy = input.adequacy
    if not shape(adequacy, {
        "intended_use", "criteria_version", "criteria"
    }) or not text(adequacy.intended_use)
        or not text(adequacy.criteria_version) then
        return fail("E_ADEQUACY", "input.adequacy")
    end

    local criterion_count = length(adequacy.criteria, MAX, true)
    if criterion_count == nil then
        return fail("E_CRITERIA", "input.adequacy.criteria")
    end

    local overall = criterion_count == 0 and "undetermined" or "met"
    local failed, unresolved, names = {}, {}, {}

    for i, criterion in ipairs(adequacy.criteria) do
        if not shape(criterion, {"name", "status", "reason"})
            or not text(criterion.name)
            or type(criterion.status) ~= "string"
            or not STATUS[criterion.status]
            or not text(criterion.reason) then
            return fail("E_CRITERION", "input.adequacy.criteria")
        end
        if names[criterion.name] then
            return fail("E_DUPLICATE_CRITERION", "input.adequacy.criteria")
        end
        names[criterion.name] = true

        if criterion.status == "fail" then
            overall = "not_met"
            failed[#failed + 1] = i
        elseif criterion.status == "undetermined" then
            unresolved[#unresolved + 1] = i
            if overall ~= "not_met" then overall = "undetermined" end
        end
    end

    local adjacent = {}
    for i = 1, rows do adjacent[i] = {} end
    for i, link in ipairs(canonical_links) do
        adjacent[link.left][#adjacent[link.left] + 1] = i
        adjacent[link.right][#adjacent[link.right] + 1] = i
    end

    return ok({
        module_version = M.VERSION,
        claims = copy(input.claims),
        evidence_rows = copy(input.evidence_rows),
        dependence_links = canonical_links,
        row_link_positions = adjacent,
        comparative_review = copy(comparative),
        adequacy_review = copy(adequacy),
        adequacy_status = overall,
        failed_criterion_positions = failed,
        unresolved_criterion_positions = unresolved,
        criterion_set_completeness_verified = false,
        dependence_completeness_verified = false,
        undeclared_pairs_assumed_independent = false,
        numerical_evidence_score_computed = false,
        covariance_estimated = false,
        scientific_judgments_independently_verified = false,
        permission_assessed = false,
        assessment_scope = "supplied_review_organization"
    })
end

return M
