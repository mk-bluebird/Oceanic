-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/building_energy_accessibility_maintenance.lua
-- Destination: lua/tools/

local Tools = {}

local DOOR_ACCESSIBILITY_CONSTRAINTS = {
    min_opening_delay_for_mobility_s = 2.0,
    max_energy_loss_per_cycle = 0.05,
    must_detect_mobility_aids = true,
    must_not_use_protected_attributes_for_optimization = true,
}

local ANOMALY_WEIGHTS = {
    vibration = 0.50,
    roughness = 0.30,
    temperature = 0.20,
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

local function require_finite(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
end

local function require_nonnegative(value, name)
    require_finite(value, name)
    assert(value >= 0, name .. " must be non-negative")
end

local function require_positive(value, name)
    require_finite(value, name)
    assert(value > 0, name .. " must be greater than zero")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function require_field(input, name, context)
    assert(input[name] ~= nil, context .. "." .. name .. " is required")
    return input[name]
end

local function shallow_copy(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

--- SC-016: Computes conversion efficiency, thermal loss, and junction
--- temperature from supplied steady-state electrical and thermal inputs.
--- THD is accepted only as a measured input; this model does not infer it.
---@param input table
---@return table
function Tools.electronic_conversion_efficiency(input)
    require_table(input, "electronic_conversion_input")

    local p_out_w = require_field(input, "p_out_w", "electronic_conversion_input")
    local p_in_w = require_field(input, "p_in_w", "electronic_conversion_input")
    local ambient_temperature_c = require_field(
        input,
        "ambient_temperature_c",
        "electronic_conversion_input"
    )
    local thermal_resistance_c_per_w = require_field(
        input,
        "thermal_resistance_c_per_w",
        "electronic_conversion_input"
    )
    local thd_fraction = input.thd_fraction

    require_nonnegative(p_out_w, "electronic_conversion_input.p_out_w")
    require_positive(p_in_w, "electronic_conversion_input.p_in_w")
    require_finite(
        ambient_temperature_c,
        "electronic_conversion_input.ambient_temperature_c"
    )
    require_nonnegative(
        thermal_resistance_c_per_w,
        "electronic_conversion_input.thermal_resistance_c_per_w"
    )
    assert(
        p_out_w <= p_in_w,
        "p_out_w cannot exceed p_in_w in this steady-state loss model"
    )

    if thd_fraction ~= nil then
        require_nonnegative(thd_fraction, "electronic_conversion_input.thd_fraction")
    end

    local efficiency = p_out_w / p_in_w
    local power_loss_w = p_in_w - p_out_w
    local junction_temperature_c =
        ambient_temperature_c + power_loss_w * thermal_resistance_c_per_w

    local thermal_risk = clamp(
        (junction_temperature_c - 85.0) / 65.0,
        0.0,
        1.0
    )

    return {
        object_id = "sc-016",
        name = "ElectronicConversionEfficiency",
        efficiency = efficiency,
        power_loss_w = power_loss_w,
        junction_temperature_c = junction_temperature_c,
        thd_fraction = thd_fraction,
        inputs = {
            p_out_w = p_out_w,
            p_in_w = p_in_w,
            ambient_temperature_c = ambient_temperature_c,
            thermal_resistance_c_per_w = thermal_resistance_c_per_w,
        },
        units = {
            power = "W",
            temperature = "degrees C",
            thermal_resistance = "degrees C/W",
            thd_fraction = "dimensionless measured fraction",
        },
        knowledge_factor = thd_fraction == nil and 0.65 or 0.75,
        eco_impact_value = efficiency,
        harm_risk = thermal_risk,
        authority_effect = "none",
        interpretation =
            "Steady-state conversion and thermal screening result. It does not replace "
            .. "component derating, transient thermal analysis, electromagnetic compatibility testing, "
            .. "or a certified electrical-safety review.",
    }
end

--- SC-017: Evaluates an already proposed automatic-door configuration against
--- inclusive-access and energy constraints. It is non-actuating and does not
--- infer mobility or use protected attributes for optimization.
---@param input table
---@return table
function Tools.automatic_door_accessibility_policy(input)
    require_table(input, "automatic_door_policy_input")

    local proposed_opening_delay_s = require_field(
        input,
        "proposed_opening_delay_s",
        "automatic_door_policy_input"
    )
    local estimated_energy_loss_per_cycle = require_field(
        input,
        "estimated_energy_loss_per_cycle",
        "automatic_door_policy_input"
    )
    local mobility_aid_detection_available = require_field(
        input,
        "mobility_aid_detection_available",
        "automatic_door_policy_input"
    )
    local protected_attributes_used = require_field(
        input,
        "protected_attributes_used",
        "automatic_door_policy_input"
    )

    require_nonnegative(
        proposed_opening_delay_s,
        "automatic_door_policy_input.proposed_opening_delay_s"
    )
    require_nonnegative(
        estimated_energy_loss_per_cycle,
        "automatic_door_policy_input.estimated_energy_loss_per_cycle"
    )
    require_boolean(
        mobility_aid_detection_available,
        "automatic_door_policy_input.mobility_aid_detection_available"
    )
    require_boolean(
        protected_attributes_used,
        "automatic_door_policy_input.protected_attributes_used"
    )

    local delay_compliant =
        proposed_opening_delay_s
        >= DOOR_ACCESSIBILITY_CONSTRAINTS.min_opening_delay_for_mobility_s

    local energy_compliant =
        estimated_energy_loss_per_cycle
        <= DOOR_ACCESSIBILITY_CONSTRAINTS.max_energy_loss_per_cycle

    local detection_compliant =
        mobility_aid_detection_available
        == DOOR_ACCESSIBILITY_CONSTRAINTS.must_detect_mobility_aids

    local non_discrimination_compliant =
        protected_attributes_used
        ~= DOOR_ACCESSIBILITY_CONSTRAINTS.must_not_use_protected_attributes_for_optimization

    local eligible_for_human_review =
        delay_compliant
        and energy_compliant
        and detection_compliant
        and non_discrimination_compliant

    local failed_constraints = {}

    if not delay_compliant then
        table.insert(failed_constraints, "minimum_opening_delay_for_mobility")
    end

    if not energy_compliant then
        table.insert(failed_constraints, "maximum_energy_loss_per_cycle")
    end

    if not detection_compliant then
        table.insert(failed_constraints, "mobility_aid_detection_required")
    end

    if not non_discrimination_compliant then
        table.insert(failed_constraints, "protected_attributes_must_not_be_used")
    end

    return {
        object_id = "sc-017",
        name = "AutomaticDoorAccessibilityPolicy",
        eligible_for_human_review = eligible_for_human_review,
        failed_constraints = failed_constraints,
        proposed_opening_delay_s = proposed_opening_delay_s,
        estimated_energy_loss_per_cycle = estimated_energy_loss_per_cycle,
        constraints = shallow_copy(DOOR_ACCESSIBILITY_CONSTRAINTS),
        knowledge_factor = 0.70,
        eco_impact_value = clamp(
            1.0 - estimated_energy_loss_per_cycle
                / DOOR_ACCESSIBILITY_CONSTRAINTS.max_energy_loss_per_cycle,
            0.0,
            1.0
        ),
        harm_risk = eligible_for_human_review and 0.05 or 0.75,
        authority_effect = "none",
        interpretation =
            "Read-only policy evaluation. A passing result supports human accessibility and "
            .. "facilities review; it cannot open, close, configure, or control a physical door.",
    }
end

--- SC-018: Calculates an interpretable anomaly index from deviations relative
--- to supplied maintenance baselines. Measurements and baselines must share
--- compatible units per channel.
---@param input table
---@param baseline table|nil
---@param weights table|nil
---@return table
function Tools.maintenance_bot_surface_anomaly(input, baseline, weights)
    require_table(input, "maintenance_anomaly_input")

    local vibration = require_field(input, "vibration", "maintenance_anomaly_input")
    local roughness = require_field(input, "roughness", "maintenance_anomaly_input")
    local temperature = require_field(input, "temperature", "maintenance_anomaly_input")

    require_finite(vibration, "maintenance_anomaly_input.vibration")
    require_finite(roughness, "maintenance_anomaly_input.roughness")
    require_finite(temperature, "maintenance_anomaly_input.temperature")

    baseline = baseline or {
        vibration = 0.0,
        roughness = 0.0,
        temperature = 20.0,
    }
    weights = weights or ANOMALY_WEIGHTS

    require_table(baseline, "maintenance_anomaly_baseline")
    require_table(weights, "maintenance_anomaly_weights")

    for _, channel in ipairs({ "vibration", "roughness", "temperature" }) do
        require_finite(
            require_field(baseline, channel, "maintenance_anomaly_baseline"),
            "maintenance_anomaly_baseline." .. channel
        )
        require_nonnegative(
            require_field(weights, channel, "maintenance_anomaly_weights"),
            "maintenance_anomaly_weights." .. channel
        )
    end

    local weight_total =
        weights.vibration + weights.roughness + weights.temperature

    assert(weight_total > 0, "maintenance anomaly weights must have positive total")

    local normalized_weights = {
        vibration = weights.vibration / weight_total,
        roughness = weights.roughness / weight_total,
        temperature = weights.temperature / weight_total,
    }

    local deviations = {
        vibration = math.abs(vibration - baseline.vibration),
        roughness = math.abs(roughness - baseline.roughness),
        temperature = math.abs(temperature - baseline.temperature),
    }

    local weighted_components = {
        vibration = normalized_weights.vibration * deviations.vibration,
        roughness = normalized_weights.roughness * deviations.roughness,
        temperature = normalized_weights.temperature * deviations.temperature,
    }

    local anomaly_score =
        weighted_components.vibration
        + weighted_components.roughness
        + weighted_components.temperature

    local dominant_channel = "vibration"
    local dominant_component = weighted_components.vibration

    for _, channel in ipairs({ "roughness", "temperature" }) do
        if weighted_components[channel] > dominant_component then
            dominant_channel = channel
            dominant_component = weighted_components[channel]
        end
    end

    return {
        object_id = "sc-018",
        name = "MaintenanceBotSurfaceAnomaly",
        anomaly_score = anomaly_score,
        dominant_channel = dominant_channel,
        deviations = deviations,
        weighted_components = weighted_components,
        normalized_weights = normalized_weights,
        knowledge_factor = 0.60,
        eco_impact_value = 0.0,
        harm_risk = clamp(anomaly_score, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Maintenance triage evidence only. The score should create an inspection record; "
            .. "it cannot autonomously dispatch equipment, alter infrastructure, or make a safety determination.",
    }
end

return Tools
