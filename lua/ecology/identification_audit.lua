-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, identity verification, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local audit arithmetic; no image recognition, I/O, or release.

local V = require("lua.ecology.validation")
local M = {VERSION = "1.0.0"}
local MAX_RECORDS = 100000

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "taxon_labels", "records"
    }, {}, "input")
    if not r.ok then return r end
    if x.schema_version ~= 1 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version",
            {expected=1, actual=V.describe(x.schema_version)})
    end

    r = V.sequence(x.taxon_labels, 100, "input.taxon_labels")
    if not r.ok then return r end
    local labels, allowed, seen = {}, {}, {}
    for i = 1, r.value do
        local label = x.taxon_labels[i]
        r = V.text(label, 200, "input.taxon_labels[" .. i .. "]")
        if not r.ok then return r end
        if seen[label] then
            return V.fail("E_DUPLICATE_LABEL", "input.taxon_labels[" .. i .. "]")
        end
        seen[label], allowed[label], labels[i] = true, true, label
    end
    if not allowed.unresolved then
        return V.fail("E_UNRESOLVED_REQUIRED", "input.taxon_labels")
    end

    r = V.sequence(x.records, MAX_RECORDS, "input.records")
    if not r.ok then return r end
    local counts, row_totals, total, exact = {}, {}, 0, 0
    for _, ref in ipairs(labels) do
        counts[ref], row_totals[ref] = {}, 0
        for _, obs in ipairs(labels) do counts[ref][obs] = 0 end
    end

    for i = 1, r.value do
        local row, path = x.records[i], "input.records[" .. i .. "]"
        local rr = V.record(row, {"reference", "observer"}, {}, path)
        if not rr.ok then return rr end
        for _, key in ipairs({"reference", "observer"}) do
            if type(row[key]) ~= "string" or not allowed[row[key]] then
                return V.fail("E_LABEL", path .. "." .. key)
            end
        end
        counts[row.reference][row.observer] =
            counts[row.reference][row.observer] + 1
        row_totals[row.reference] = row_totals[row.reference] + 1
        total = total + 1
        if row.reference == row.observer then exact = exact + 1 end
    end

    local normalized = {}
    for _, ref in ipairs(labels) do
        normalized[ref] = {}
        for _, obs in ipairs(labels) do
            normalized[ref][obs] = row_totals[ref] > 0
                and counts[ref][obs] / row_totals[ref] or false
        end
    end

    return V.ok({
        module_version=M.VERSION, schema_version=1,
        status="screen_blind_identification_agreement",
        labels=labels, record_count=total,
        confusion_counts=counts,
        row_totals=row_totals,
        row_normalized_confusion=normalized,
        overall_exact_agreement=total > 0 and exact / total or false,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            reference_identifications_verified=false,
            observer_blinding_verified=false,
            sampling_design_evaluated=false,
            class_prevalence_representative=false,
            ecological_outcome_estimated=false,
            publication_authorized=false,
            external_action_performed=false
        }
    })
end

return M
