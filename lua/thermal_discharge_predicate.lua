local M = {}

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function valid_temperature(value)
    return is_finite_number(value)
        and value >= -10.0
        and value <= 100.0
end

local function result(outcome, explanation_code, details)
    return {
        outcome = outcome,
        explanation_code = explanation_code,
        details = details or {},
    }
end

function M.thermalDischargePredicate(input)
    assert(type(input) == "table", "input must be a table")

    local discharge_temperature_c = input.discharge_temperature_c
    local human_max = input.human_max_discharge_temperature_c
    local aquatic_max = input.aquatic_max_discharge_temperature_c
    local riparian_max = input.riparian_max_discharge_temperature_c
    local avian_max = input.avian_max_discharge_temperature_c

    if not valid_temperature(discharge_temperature_c) then
        return result(
            "denied",
            "DISCHARGE_TEMPERATURE_INVALID_OR_MISSING",
            { metric = "discharge_temperature_c" }
        )
    end

    if not valid_temperature(human_max)
        or not valid_temperature(aquatic_max)
        or not valid_temperature(riparian_max)
        or not valid_temperature(avian_max) then
        return result(
            "denied",
            "CANAL_SPECIES_THERMAL_DATA_UNAVAILABLE",
            {
                required = {
                    "human_max_discharge_temperature_c",
                    "aquatic_max_discharge_temperature_c",
                    "riparian_max_discharge_temperature_c",
                    "avian_max_discharge_temperature_c",
                }
            }
        )
    end

    if input.threshold_source_status ~= "approved" then
        return result(
            "denied",
            "CANAL_SPECIES_THRESHOLD_SOURCE_NOT_APPROVED",
            { threshold_source_status = input.threshold_source_status }
        )
    end

    local threshold = math.min(
        human_max,
        aquatic_max,
        riparian_max,
        avian_max
    )

    if discharge_temperature_c > threshold then
        return result(
            "denied",
            "CANAL_DISCHARGE_EXCEEDS_MOST_SENSITIVE_SPECIES_THRESHOLD",
            {
                discharge_temperature_c = discharge_temperature_c,
                most_sensitive_threshold_c = threshold,
            }
        )
    end

    return result(
        "permitted",
        "CANAL_THERMAL_DISCHARGE_WITHIN_ALL_HARD_CONSTRAINTS",
        {
            discharge_temperature_c = discharge_temperature_c,
            most_sensitive_threshold_c = threshold,
        }
    )
end

return M
