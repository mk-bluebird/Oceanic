-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Local interval screening; no network, storage, or actuation.
-- Research proposal, not a validated ecological prediction model.

local M = {}

M.attribution = {
    sovereign_anchor =
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
    purpose = "document_credit_and_configured_workstream_metadata_only",
    grants_authority = false,
    establishes_consent = false,
    establishes_verified_identity = false,
    persistent_storage_performed = false
}

local function require_text(value, name)
    assert(
        type(value) == "string" and value:match("%S"),
        name .. " must contain text"
    )
end

local function require_number(value, name, strictly_positive)
    assert(
        type(value) == "number"
            and value == value
            and value > -math.huge
            and value < math.huge,
        name .. " must be finite"
    )
    if strictly_positive then
        assert(value > 0, name .. " must be positive")
    else
        assert(value >= 0, name .. " must be nonnegative")
    end
end

local function require_record(value, allowed, name)
    assert(
        type(value) == "table" and getmetatable(value) == nil,
        name .. " must be a plain table"
    )
    for key in pairs(value) do
        assert(allowed[key], name .. " contains an unsupported field")
    end
end

local function sequence_length(values)
    assert(
        type(values) == "table" and getmetatable(values) == nil,
        "conditions must be a plain sequence"
    )
    local count = 0
    for key in pairs(values) do
        assert(
            type(key) == "number"
                and key % 1 == 0
                and key >= 1
                and key <= 1000,
            "conditions must use integer positions from 1 through 1000"
        )
        count = count + 1
    end
    assert(count > 0, "at least one condition is required")
    for index = 1, count do
        assert(rawget(values, index) ~= nil, "conditions must be contiguous")
    end
    return count
end

local function shortfall(availability, reference)
    if availability >= reference then
        return 0
    end
    return 1 - availability / reference
end

function M.screen(input)
    require_record(input, {
        species = true,
        scope = true,
        conditions = true
    }, "input")

    require_text(input.species, "species")
    require_text(input.scope, "scope")

    local count = sequence_length(input.conditions)
    local result = {
        species = input.species,
        scope = input.scope,
        model = "proposed_reference_relative_interval_screen",
        conditions = {},
        known_count = 0,
        unknown_count = 0,
        screened_shortfall_present = false,
        reference_crossing_present = false,
        external_actions_performed = false,
        intervention_authorized = false,
        extinction_probability_estimated = false
    }

    local maximum_lower = 0
    local maximum_upper = 0

    for index = 1, count do
        local condition = input.conditions[index]
        require_record(condition, {
            name = true,
            unit = true,
            reference = true,
            reference_basis = true,
            lower = true,
            upper = true,
            availability_basis = true
        }, "condition")

        require_text(condition.name, "condition.name")
        require_text(condition.unit, "condition.unit")
        require_text(condition.reference_basis, "condition.reference_basis")
        require_number(condition.reference, "condition.reference", true)

        local item = {
            name = condition.name,
            unit = condition.unit,
            reference = condition.reference,
            reference_basis = condition.reference_basis
        }

        local missing_lower = condition.lower == nil
        local missing_upper = condition.upper == nil

        assert(
            missing_lower == missing_upper,
            "provide both availability bounds or neither"
        )

        if missing_lower then
            item.status = "unknown"
            result.unknown_count = result.unknown_count + 1
        else
            require_number(condition.lower, "condition.lower", false)
            require_number(condition.upper, "condition.upper", false)
            require_text(
                condition.availability_basis,
                "condition.availability_basis"
            )
            assert(
                condition.lower <= condition.upper,
                "lower availability must not exceed upper availability"
            )

            local lower = shortfall(condition.upper, condition.reference)
            local upper = shortfall(condition.lower, condition.reference)

            item.availability_lower = condition.lower
            item.availability_upper = condition.upper
            item.availability_basis = condition.availability_basis
            item.shortfall_lower = lower
            item.shortfall_upper = upper

            if condition.upper < condition.reference then
                item.status = "shortfall_across_interval"
                result.screened_shortfall_present = true
            elseif condition.lower < condition.reference then
                item.status = "reference_crossing_uncertainty"
                result.reference_crossing_present = true
            else
                item.status = "meets_reference_across_interval"
            end

            maximum_lower = math.max(maximum_lower, lower)
            maximum_upper = math.max(maximum_upper, upper)
            result.known_count = result.known_count + 1
        end

        result.conditions[index] = item
    end

    result.coverage_fraction = result.known_count / count

    if result.known_count > 0 then
        result.known_conditions_shortfall = {
            lower = maximum_lower,
            upper = maximum_upper
        }
    end

    if result.unknown_count == 0 then
        result.complete_conditions_shortfall = {
            lower = maximum_lower,
            upper = maximum_upper
        }
    end

    if result.screened_shortfall_present then
        result.review_status = "review_screened_shortfall"
    elseif result.unknown_count > 0 then
        result.review_status = "incomplete_evidence"
    elseif result.reference_crossing_present then
        result.review_status = "resolve_reference_crossing_uncertainty"
    else
        result.review_status = "listed_references_met_not_species_clearance"
    end

    return result
end

return M
