local M = {}

local max_risk_for_advisory = 0.35
local minimum_knowledge_for_advisory = 0.60
local minimum_readiness_for_advisory = 0.60

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_unit_interval(value)
    return is_finite_number(value) and value >= 0.0 and value <= 1.0
end

local function required_text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function require_valid_record(record)
    if type(record) ~= "table" then
        return nil, "record must be a table"
    end

    for _, field in ipairs({ "evidence_id", "hex_anchor", "observed_at_utc" }) do
        if not required_text(record[field]) then
            return nil, field .. " must be a non-empty string"
        end
    end

    for _, field in ipairs({ "readiness", "k_factor", "e_factor", "r_factor" }) do
        if not in_unit_interval(record[field]) then
            return nil, field .. " must be a finite number in [0, 1]"
        end
    end

    return true
end

function M.route(record)
    local valid, reason = require_valid_record(record)
    if not valid then
        return {
            queue = "operator_review_queue",
            fog_state = "unresolved",
            status = "withheld",
            reason = reason
        }
    end

    if record.source_valid ~= true
        or record.parameter_current ~= true
        or record.consent_scope_valid ~= true
        or record.retention_eligible ~= true then
        return {
            queue = "operator_review_queue",
            fog_state = "unresolved",
            status = "withheld",
            reason = "source, parameter, consent, or retention eligibility is not valid"
        }
    end

    if record.r_factor > max_risk_for_advisory then
        return {
            queue = "operator_review_queue",
            fog_state = "withhold_risk",
            status = "withheld",
            reason = "non-compensating risk exceeds threshold"
        }
    end

    if record.k_factor < minimum_knowledge_for_advisory then
        return {
            queue = "operator_review_queue",
            fog_state = "withhold_knowledge",
            status = "withheld",
            reason = "knowledge factor is below threshold"
        }
    end

    if record.readiness < minimum_readiness_for_advisory then
        return {
            queue = "reduced_resource_queue",
            fog_state = "partial",
            status = "informational",
            reason = "eligible evidence does not meet readiness threshold"
        }
    end

    return {
        queue = "low_impact_queue",
        fog_state = record.k_factor < 0.80 and "partial" or "resolved",
        status = "advisory",
        reason = "bounded advisory eligible for human review"
    }
end

return M
