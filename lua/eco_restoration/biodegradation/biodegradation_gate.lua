local M = {}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function probability(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function valid_text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function withhold(fog_state, reason)
    return {
        queue = "human_review_queue",
        status = "withheld",
        fog_state = fog_state,
        reason = reason
    }
end

function M.evaluate(record)
    if type(record) ~= "table" then
        return withhold("withhold", "evidence record must be a table")
    end

    for _, field in ipairs({
        "evidence_id",
        "observed_at_utc",
        "method_version",
        "calibration_version"
    }) do
        if not valid_text(record[field]) then
            return withhold("withhold", field .. " must be a non-empty string")
        end
    end

    for _, field in ipairs({
        "readiness",
        "knowledge_factor",
        "eco_impact_value",
        "harm_risk",
        "test_inoculum_viability",
        "reference_inoculum_viability"
    }) do
        if not probability(record[field]) then
            return withhold("withhold", field .. " must be a finite value in [0, 1]")
        end
    end

    if record.source_valid ~= true
        or record.parameter_current ~= true
        or record.consent_scope_valid ~= true
        or record.retention_eligible ~= true then
        return withhold(
            "withhold",
            "source, parameter, consent, or retention provenance is not eligible"
        )
    end

    if record.matrix == nil or record.matrix == "unknown" then
        return withhold(
            "human_review_pending",
            "material matrix is unknown and requires medium-specific review"
        )
    end

    if record.transformation_product_flag == true
        and record.transformation_product_scope_complete ~= true then
        return withhold(
            "unmodeled_transformation_product",
            "transformation-product scope is incomplete"
        )
    end

    if record.test_inoculum_viability < 0.60
        or record.reference_inoculum_viability < 0.60 then
        return withhold(
            "withhold",
            "test or reference inoculum viability is below the configured evidence floor"
        )
    end

    if not finite_number(record.corrected_reference_signal)
        or record.corrected_reference_signal <= 1e-12 then
        return withhold(
            "withhold",
            "reference blank-corrected signal is insufficient for a stable ratio"
        )
    end

    if record.harm_risk > 0.35 then
        return withhold(
            "withhold",
            "a non-compensating risk boundary was crossed"
        )
    end

    if record.knowledge_factor < 0.60 then
        return withhold(
            "withhold",
            "knowledge factor is below the advisory threshold"
        )
    end

    return {
        queue = "human_review_queue",
        status = "advisory_candidate",
        fog_state = "clear",
        reason = "bounded evidence is eligible for human review"
    }
end

return M
