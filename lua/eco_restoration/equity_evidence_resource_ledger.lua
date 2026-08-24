-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/equity_evidence_resource_ledger.lua
-- Destination: lua/eco_restoration/

local Ledger = {}

local INTERFACE_WEIGHTS = {
    biological_evidence = 0.24,
    mechanical_compatibility = 0.18,
    chemical_compatibility = 0.18,
    signal_performance = 0.16,
    verification_quality = 0.14,
    resource_feasibility = 0.10,
}

local INTERFACE_THRESHOLDS = {
    total = 0.80,
    biological_evidence = 0.85,
    mechanical_compatibility = 0.75,
    chemical_compatibility = 0.75,
    verification_quality = 0.80,
}

local REQUIRED_INTERFACE_FIELDS = {
    "biological_evidence",
    "mechanical_compatibility",
    "chemical_compatibility",
    "signal_performance",
    "verification_quality",
    "resource_feasibility",
}

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_unit_interval(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
    assert(value >= 0 and value <= 1, name .. " must be within [0, 1]")
end

local function require_nonnegative_finite(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
    assert(value >= 0, name .. " must be non-negative")
end

local function require_field(input, name, context)
    assert(input[name] ~= nil, context .. "." .. name .. " is required")
    return input[name]
end

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function normalized_decimal_observation(value, name)
    assert(type(value) == "string", name .. " must be a string")

    local normalized = trim(value)
    local decimal, unit = normalized:match("^([0-9]+%.?[0-9]*)%s+([^%s]+)$")

    assert(
        decimal ~= nil and unit ~= nil,
        name .. " must be a non-negative decimal string followed by a unit"
    )

    assert(
        decimal:match("^%d+%.?%d*$") ~= nil,
        name .. " must begin with a non-negative decimal"
    )

    return normalized
end

local function is_nonnegative_decimal_string(value)
    return type(value) == "string"
        and value:match("^%d+$") ~= nil
end

local function add_decimal_strings(left, right)
    assert(is_nonnegative_decimal_string(left), "left must be a non-negative integer string")
    assert(is_nonnegative_decimal_string(right), "right must be a non-negative integer string")

    local carry = 0
    local result = {}
    local left_index = #left
    local right_index = #right

    while left_index > 0 or right_index > 0 or carry > 0 do
        local left_digit = left_index > 0 and tonumber(left:sub(left_index, left_index)) or 0
        local right_digit = right_index > 0 and tonumber(right:sub(right_index, right_index)) or 0
        local sum = left_digit + right_digit + carry

        table.insert(result, 1, tostring(sum % 10))
        carry = math.floor(sum / 10)
        left_index = left_index - 1
        right_index = right_index - 1
    end

    return table.concat(result)
end

local function normalise_uint256_string(value, name)
    assert(type(value) == "string", name .. " must be a decimal integer string")
    assert(value:match("^%d+$") ~= nil, name .. " must contain only decimal digits")

    local normalized = value:gsub("^0+", "")

    if normalized == "" then
        normalized = "0"
    end

    assert(
        #normalized < 78
            or (#normalized == 78
                and normalized <= "115792089237316195423570985008687907853269984665640564039457584007913129639935"),
        name .. " exceeds uint256 range"
    )

    return normalized
end

local function copy_table(source)
    local copy = {}

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

--- SC-010: Calculates the supplied inverse-deprivation weighted ecological
--- benefit. This describes the existing distribution only. A separate
--- equity-gap metric identifies whether high-deprivation zones receive less
--- benefit, which is usually the actionable restoration concern.
---@param zones table[]
---@return table
function Ledger.equity_weighted_eco_benefit(zones)
    require_table(zones, "zones")
    assert(#zones > 0, "zones must contain at least one zone")

    local weighted_numerator = 0.0
    local inverse_deprivation_weight_total = 0.0
    local benefit_total = 0.0
    local high_deprivation_benefit_total = 0.0
    local high_deprivation_count = 0

    for index, zone in ipairs(zones) do
        require_table(zone, "zones[" .. index .. "]")

        local benefit = require_field(zone, "benefit", "zones[" .. index .. "]")
        local deprivation_index = require_field(
            zone,
            "deprivation_index",
            "zones[" .. index .. "]"
        )

        require_unit_interval(benefit, "zones[" .. index .. "].benefit")
        require_unit_interval(
            deprivation_index,
            "zones[" .. index .. "].deprivation_index"
        )

        local inverse_deprivation_weight = 1.0 - deprivation_index

        weighted_numerator =
            weighted_numerator + benefit * inverse_deprivation_weight
        inverse_deprivation_weight_total =
            inverse_deprivation_weight_total + inverse_deprivation_weight
        benefit_total = benefit_total + benefit

        if deprivation_index >= 0.50 then
            high_deprivation_benefit_total =
                high_deprivation_benefit_total + benefit
            high_deprivation_count = high_deprivation_count + 1
        end
    end

    local equity_benefit = 0.0

    if inverse_deprivation_weight_total > 0 then
        equity_benefit =
            weighted_numerator / inverse_deprivation_weight_total
    end

    local average_benefit = benefit_total / #zones
    local high_deprivation_average_benefit = 0.0

    if high_deprivation_count > 0 then
        high_deprivation_average_benefit =
            high_deprivation_benefit_total / high_deprivation_count
    end

    local equity_gap = clamp(
        average_benefit - high_deprivation_average_benefit,
        -1.0,
        1.0
    )

    return {
        object_id = "sc-010",
        name = "EquityWeightedEcoBenefit",
        inverse_deprivation_weighted_benefit = equity_benefit,
        overall_average_benefit = average_benefit,
        high_deprivation_average_benefit = high_deprivation_average_benefit,
        equity_gap = equity_gap,
        zone_count = #zones,
        high_deprivation_zone_count = high_deprivation_count,
        units = "normalized ecological benefit index, 0..1",
        knowledge_factor = math.min(#zones / 20.0, 1.0),
        eco_impact_value = average_benefit,
        harm_risk = clamp(math.max(0.0, equity_gap), 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "The supplied inverse-deprivation weighting emphasizes lower-deprivation zones. "
            .. "Use equity_gap to identify whether higher-deprivation zones receive less ecological benefit.",
    }
end

--- SC-011: Scores supplied interface evidence against bounded, auditable
--- criteria. This is research decision support only and cannot authorize,
--- deploy, operate, or clinically validate an interface.
---@param evidence table
---@return table
function Ledger.interface_evidence_scorer(evidence)
    require_table(evidence, "interface_evidence")

    for _, field in ipairs(REQUIRED_INTERFACE_FIELDS) do
        require_unit_interval(
            require_field(evidence, field, "interface_evidence"),
            "interface_evidence." .. field
        )
    end

    local score =
        INTERFACE_WEIGHTS.biological_evidence * evidence.biological_evidence
        + INTERFACE_WEIGHTS.mechanical_compatibility * evidence.mechanical_compatibility
        + INTERFACE_WEIGHTS.chemical_compatibility * evidence.chemical_compatibility
        + INTERFACE_WEIGHTS.signal_performance * evidence.signal_performance
        + INTERFACE_WEIGHTS.verification_quality * evidence.verification_quality
        + INTERFACE_WEIGHTS.resource_feasibility * evidence.resource_feasibility

    local meets_total = score >= INTERFACE_THRESHOLDS.total
    local meets_biological =
        evidence.biological_evidence >= INTERFACE_THRESHOLDS.biological_evidence
    local meets_mechanical =
        evidence.mechanical_compatibility >= INTERFACE_THRESHOLDS.mechanical_compatibility
    local meets_chemical =
        evidence.chemical_compatibility >= INTERFACE_THRESHOLDS.chemical_compatibility
    local meets_verification =
        evidence.verification_quality >= INTERFACE_THRESHOLDS.verification_quality

    local responsible_research_review =
        meets_total
        and meets_biological
        and meets_mechanical
        and meets_chemical
        and meets_verification

    local missing_criteria = {}

    if not meets_total then
        table.insert(missing_criteria, "total_score")
    end

    if not meets_biological then
        table.insert(missing_criteria, "biological_evidence")
    end

    if not meets_mechanical then
        table.insert(missing_criteria, "mechanical_compatibility")
    end

    if not meets_chemical then
        table.insert(missing_criteria, "chemical_compatibility")
    end

    if not meets_verification then
        table.insert(missing_criteria, "verification_quality")
    end

    local weakest_criterion = "biological_evidence"
    local weakest_value = evidence.biological_evidence

    for _, field in ipairs(REQUIRED_INTERFACE_FIELDS) do
        if evidence[field] < weakest_value then
            weakest_criterion = field
            weakest_value = evidence[field]
        end
    end

    return {
        object_id = "sc-011",
        name = "InterfaceEvidenceScorer",
        eligibility_score = score,
        responsible_research_review = responsible_research_review,
        thresholds = copy_table(INTERFACE_THRESHOLDS),
        weights = copy_table(INTERFACE_WEIGHTS),
        missing_criteria = missing_criteria,
        weakest_criterion = weakest_criterion,
        weakest_value = weakest_value,
        knowledge_factor = evidence.verification_quality,
        eco_impact_value = 0.0,
        harm_risk = clamp(1.0 - score, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "A passing result supports further evidence review only. It is not certification, "
            .. "clinical validation, authorization, or permission for real-world deployment.",
    }
end

--- SC-012: Validates non-convertible local ledger fields. Values are held as
--- decimal strings to preserve arbitrary-size unsigned counters without using
--- Lua floating-point arithmetic. No method converts biomarker observations
--- into compute gas, energy, privileges, or any other ledger category.
---@param record table
---@return table
function Ledger.validate_resource_accounting_ledger(record)
    require_table(record, "resource_accounting_record")

    local ota_compute_microgas = normalise_uint256_string(
        require_field(record, "ota_compute_microgas", "resource_accounting_record"),
        "resource_accounting_record.ota_compute_microgas"
    )
    local bench_energy_microjoules = normalise_uint256_string(
        require_field(record, "bench_energy_microjoules", "resource_accounting_record"),
        "resource_accounting_record.bench_energy_microjoules"
    )
    local glucose_observation = normalized_decimal_observation(
        require_field(record, "glucose_observation", "resource_accounting_record"),
        "resource_accounting_record.glucose_observation"
    )
    local protein_observation = normalized_decimal_observation(
        require_field(record, "protein_observation", "resource_accounting_record"),
        "resource_accounting_record.protein_observation"
    )

    return {
        object_id = "sc-012",
        name = "ResourceAccountingLedger",
        valid = true,
        ledgers = {
            ota_compute_microgas = ota_compute_microgas,
            bench_energy_microjoules = bench_energy_microjoules,
            glucose_observation = glucose_observation,
            protein_observation = protein_observation,
        },
        invariant =
            "Biomarker observations, laboratory energy, and OTA compute gas are separate non-convertible ledger classes.",
        prohibited_mappings = {
            "glucose_observation_to_ota_compute_microgas",
            "protein_observation_to_ota_compute_microgas",
            "ota_compute_microgas_to_glucose_observation",
            "ota_compute_microgas_to_protein_observation",
            "bench_energy_microjoules_to_biomarker_observation",
        },
        knowledge_factor = 0.65,
        eco_impact_value = 0.0,
        harm_risk = 0.10,
        authority_effect = "none",
        interpretation =
            "This validator checks data shape and ledger separation. It does not interpret "
            .. "health measurements, perform clinical assessment, or establish a resource exchange rate.",
    }
end

--- Adds two uint256-compatible decimal integer strings without converting them
--- to floating-point numbers. This is intentionally limited to the same ledger
--- class; callers must not use it across resource categories.
---@param left string
---@param right string
---@param ledger_class string
---@return string
function Ledger.add_same_class_uint256(left, right, ledger_class)
    assert(
        ledger_class == "ota_compute_microgas"
            or ledger_class == "bench_energy_microjoules",
        "ledger_class must be an approved non-convertible unsigned-counter class"
    )

    local normalized_left = normalise_uint256_string(left, "left")
    local normalized_right = normalise_uint256_string(right, "right")
    local result = add_decimal_strings(normalized_left, normalized_right)

    return normalise_uint256_string(result, "sum")
end

return Ledger
