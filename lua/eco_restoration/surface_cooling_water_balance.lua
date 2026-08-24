-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/surface_cooling_water_balance.lua
-- Destination: lua/eco_restoration/

local SurfaceCoolingWaterBalance = {}

local DEFAULT_RHO_WATER_KG_PER_M3 = 1000.0
local DEFAULT_LATENT_HEAT_J_PER_KG = 2.26e6

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

local function require_finite_nonnegative(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
    assert(value >= 0, name .. " must be non-negative")
end

local function require_unit_interval(value, name)
    require_finite_nonnegative(value, name)
    assert(value <= 1, name .. " must be within [0, 1]")
end

local function require_field(input, name, context)
    assert(
        input[name] ~= nil,
        context .. "." .. name .. " is required"
    )

    return input[name]
end

local function finite_ratio(numerator, denominator)
    if denominator <= 0 then
        return 0.0
    end

    return clamp(numerator / denominator, 0.0, 1.0)
end

--- SC-007: Calculates avoided shortwave heat absorption from a surface-albedo
--- increase. The result is instantaneous radiative cooling power in watts.
---@param input table
---@return table
function SurfaceCoolingWaterBalance.albedo_radiative_cooling(input)
    require_table(input, "albedo_radiative_cooling_input")

    local delta_albedo = require_field(
        input,
        "delta_albedo",
        "albedo_radiative_cooling_input"
    )
    local solar_irradiance_w_m2 = require_field(
        input,
        "solar_irradiance_w_m2",
        "albedo_radiative_cooling_input"
    )
    local area_m2 = require_field(
        input,
        "area_m2",
        "albedo_radiative_cooling_input"
    )

    require_unit_interval(
        delta_albedo,
        "albedo_radiative_cooling_input.delta_albedo"
    )
    require_finite_nonnegative(
        solar_irradiance_w_m2,
        "albedo_radiative_cooling_input.solar_irradiance_w_m2"
    )
    require_finite_nonnegative(
        area_m2,
        "albedo_radiative_cooling_input.area_m2"
    )

    local avoided_heat_absorption_w =
        delta_albedo * solar_irradiance_w_m2 * area_m2

    return {
        object_id = "sc-007",
        name = "AlbedoRadiativeCooling",
        avoided_heat_absorption_w = avoided_heat_absorption_w,
        delta_albedo = delta_albedo,
        solar_irradiance_w_m2 = solar_irradiance_w_m2,
        area_m2 = area_m2,
        units = "W; instantaneous avoided absorbed shortwave power",
        knowledge_factor = 0.75,
        eco_impact_value = finite_ratio(delta_albedo * area_m2, 100000.0),
        harm_risk = 0.05,
        authority_effect = "none",
        interpretation =
            "A scenario estimate of shortwave energy not absorbed after an albedo increase. "
            .. "It does not estimate surface temperature, indoor comfort, glare, or lifecycle impacts.",
    }
end

--- SC-008: Calculates latent cooling power from evapotranspiration.
--- ET must be in m/s, so results are watts: kg/m^3 * J/kg * m/s * m^2.
---@param input table
---@param coefficients table|nil
---@return table
function SurfaceCoolingWaterBalance.evapotranspiration_cooling(input, coefficients)
    require_table(input, "evapotranspiration_cooling_input")

    local evapotranspiration_m_s = require_field(
        input,
        "evapotranspiration_m_s",
        "evapotranspiration_cooling_input"
    )
    local area_m2 = require_field(
        input,
        "area_m2",
        "evapotranspiration_cooling_input"
    )

    require_finite_nonnegative(
        evapotranspiration_m_s,
        "evapotranspiration_cooling_input.evapotranspiration_m_s"
    )
    require_finite_nonnegative(
        area_m2,
        "evapotranspiration_cooling_input.area_m2"
    )

    coefficients = coefficients or {}
    require_table(coefficients, "evapotranspiration_cooling_coefficients")

    local rho_water_kg_m3 =
        coefficients.rho_water_kg_m3 or DEFAULT_RHO_WATER_KG_PER_M3
    local latent_heat_j_kg =
        coefficients.latent_heat_j_kg or DEFAULT_LATENT_HEAT_J_PER_KG

    require_finite_nonnegative(
        rho_water_kg_m3,
        "evapotranspiration_cooling_coefficients.rho_water_kg_m3"
    )
    require_finite_nonnegative(
        latent_heat_j_kg,
        "evapotranspiration_cooling_coefficients.latent_heat_j_kg"
    )

    local cooling_power_w =
        rho_water_kg_m3
        * latent_heat_j_kg
        * evapotranspiration_m_s
        * area_m2

    local water_use_m3_s = evapotranspiration_m_s * area_m2
    local use_default_coefficients =
        coefficients.rho_water_kg_m3 == nil
        and coefficients.latent_heat_j_kg == nil

    return {
        object_id = "sc-008",
        name = "EvapotranspirationCooling",
        cooling_power_w = cooling_power_w,
        water_use_m3_s = water_use_m3_s,
        evapotranspiration_m_s = evapotranspiration_m_s,
        area_m2 = area_m2,
        rho_water_kg_m3 = rho_water_kg_m3,
        latent_heat_j_kg = latent_heat_j_kg,
        units = {
            cooling_power_w = "W; latent heat flux",
            water_use_m3_s = "m^3/s",
        },
        knowledge_factor = use_default_coefficients and 0.60 or 0.75,
        eco_impact_value = finite_ratio(cooling_power_w, 1.0e7),
        harm_risk = finite_ratio(water_use_m3_s, 0.01),
        authority_effect = "none",
        interpretation =
            "A latent-cooling scenario estimate. Water-demand, drought, irrigation source, "
            .. "plant health, humidity, and local microclimate effects require site-specific review.",
    }
end

--- SC-009: Computes water retained after event-depth losses.
--- All precipitation, abstraction, evapotranspiration, and runoff inputs are
--- event depths in metres over the same area and time window.
---@param input table
---@return table
function SurfaceCoolingWaterBalance.stormwater_retention(input)
    require_table(input, "stormwater_retention_input")

    local area_m2 = require_field(input, "area_m2", "stormwater_retention_input")
    local precipitation_m = require_field(
        input,
        "precipitation_m",
        "stormwater_retention_input"
    )
    local initial_abstraction_m = require_field(
        input,
        "initial_abstraction_m",
        "stormwater_retention_input"
    )
    local evapotranspiration_m = require_field(
        input,
        "evapotranspiration_m",
        "stormwater_retention_input"
    )
    local runoff_m = require_field(input, "runoff_m", "stormwater_retention_input")

    require_finite_nonnegative(area_m2, "stormwater_retention_input.area_m2")
    require_finite_nonnegative(
        precipitation_m,
        "stormwater_retention_input.precipitation_m"
    )
    require_finite_nonnegative(
        initial_abstraction_m,
        "stormwater_retention_input.initial_abstraction_m"
    )
    require_finite_nonnegative(
        evapotranspiration_m,
        "stormwater_retention_input.evapotranspiration_m"
    )
    require_finite_nonnegative(runoff_m, "stormwater_retention_input.runoff_m")

    local gross_precipitation_volume_m3 = area_m2 * precipitation_m
    local net_retention_depth_m =
        precipitation_m
        - initial_abstraction_m
        - evapotranspiration_m
        - runoff_m

    local retained_volume_m3 = math.max(
        0.0,
        area_m2 * net_retention_depth_m
    )

    local balance_deficit_m3 = math.max(
        0.0,
        -area_m2 * net_retention_depth_m
    )

    local retention_fraction = finite_ratio(
        retained_volume_m3,
        gross_precipitation_volume_m3
    )

    return {
        object_id = "sc-009",
        name = "StormwaterRetention",
        retained_volume_m3 = retained_volume_m3,
        gross_precipitation_volume_m3 = gross_precipitation_volume_m3,
        retention_fraction = retention_fraction,
        balance_deficit_m3 = balance_deficit_m3,
        event_depths_m = {
            precipitation = precipitation_m,
            initial_abstraction = initial_abstraction_m,
            evapotranspiration = evapotranspiration_m,
            runoff = runoff_m,
        },
        area_m2 = area_m2,
        units = {
            retained_volume_m3 = "m^3 per precipitation event",
            gross_precipitation_volume_m3 = "m^3 per precipitation event",
            event_depths_m = "m per precipitation event",
        },
        knowledge_factor = 0.70,
        eco_impact_value = retention_fraction,
        harm_risk = balance_deficit_m3 > 0 and 0.35 or 0.05,
        authority_effect = "none",
        interpretation =
            "A mass-balance scenario calculation. A positive deficit flags incompatible "
            .. "inputs or unmodeled inflows; it is not treated as negative retained water.",
    }
end

return SurfaceCoolingWaterBalance
