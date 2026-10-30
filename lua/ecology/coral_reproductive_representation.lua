-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, identity verification, or authority.
-- Input counts refer to assessed mature colonies grouped by genotype.
-- No public genotype labels, I/O, prediction, or intervention.

local M = {VERSION = "1.0.0"}
local MAX_GROUPS, MAX_TOTAL = 10000, 1000000

local function bad(code, path)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "coral_representation." .. code,
        args = {}, category = "validation"
    }}
end

local function integer(v, minimum, maximum)
    return type(v) == "number" and v == v
        and v >= minimum and v <= maximum and v % 1 == 0
end

function M.evaluate(x)
    if type(x) ~= "table" or getmetatable(x) ~= nil then
        return bad("E_RECORD", "input")
    end
    for _, key in ipairs({"schema_version", "mature_colony_counts"}) do
        if rawget(x, key) == nil then return bad("E_MISSING", "input." .. key) end
    end
    for key in pairs(x) do
        if key ~= "schema_version" and key ~= "mature_colony_counts" then
            return bad("E_UNKNOWN_FIELD", "input")
        end
    end
    if x.schema_version ~= 1 then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end

    local counts = x.mature_colony_counts
    if type(counts) ~= "table" or getmetatable(counts) ~= nil then
        return bad("E_SEQUENCE", "input.mature_colony_counts")
    end
    local groups, highest = 0, 0
    for key in pairs(counts) do
        if not integer(key, 1, MAX_GROUPS) then
            return bad("E_SEQUENCE_INDEX", "input.mature_colony_counts")
        end
        groups, highest = groups + 1, math.max(highest, key)
    end
    if groups ~= highest then
        return bad("E_SEQUENCE_GAP", "input.mature_colony_counts")
    end

    local total, same_pairs, sum_squares = 0, 0, 0
    local copied = {}
    for i = 1, groups do
        local n = counts[i]
        if not integer(n, 1, MAX_TOTAL) then
            return bad("E_COUNT", "input.mature_colony_counts[" .. i .. "]")
        end
        total = total + n
        if total > MAX_TOTAL then
            return bad("E_TOTAL_LIMIT", "input.mature_colony_counts")
        end
        same_pairs = same_pairs + n * (n - 1) / 2
        sum_squares = sum_squares + n * n
        copied[i] = n
    end

    local status = "screen_assessed_representation"
    if total == 0 then status = "screen_no_assessed_mature_colonies"
    elseif total == 1 then status = "screen_single_assessed_mature_colony" end

    local out = {
        module_version = M.VERSION, schema_version = 1,
        status = status,
        denominator = "assessed_mature_colonies",
        assessed_mature_count = total,
        observed_genotype_count = groups,
        mature_colony_counts = copied,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            retention = "copy_in_derivatives",
            establishes_consent = false, grants_authority = false
        },
        interpretation_limits = {
            maturity_assessment_verified = false,
            genotyping_verified = false,
            sample_completeness_verified = false,
            spatial_configuration_evaluated = false,
            spawning_synchrony_evaluated = false,
            compatibility_evaluated = false,
            fertilization_probability_estimated = false,
            reproductive_failure_established = false,
            population_recovery_established = false,
            external_action_performed = false
        }
    }

    if total > 0 then
        out.genotype_to_colony_ratio = groups / total
        out.effective_sampled_genotypes = total * total / sum_squares
    end
    if total >= 2 then
        local total_pairs = total * (total - 1) / 2
        out.unordered_colony_pairs = total_pairs
        out.different_genotype_pairs = total_pairs - same_pairs
        out.different_genotype_pair_fraction =
            (total_pairs - same_pairs) / total_pairs
    end
    return {ok = true, value = out}
end

return M
