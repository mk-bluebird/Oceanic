from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Sequence


SECONDS_PER_HOUR = 3_600.0
WATER_VAPOR_GAS_CONSTANT_J_PER_KG_K = 461.5


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _bounded(name: str, value: float, lower: float, upper: float) -> None:
    if not isfinite(value) or not lower <= value <= upper:
        raise ValueError(f"{name} must be within [{lower}, {upper}].")


@dataclass(frozen=True)
class NocturnalCanyonInputs:
    """
    Per-metre street-length street-canyon control volume.

    Q_source_kg_per_s:
        Water-vapor mass source. This represents actual vapor transferred into
        canyon air, not liquid-water throughput.

    exchange_velocity_m_per_s:
        Effective roof-level exchange velocity. It must be calibrated from
        local anemometry, tracer tests, or a validated canyon model.

    condensation_rate_per_s:
        First-order net sink capturing surface condensation or retention. It is
        zero when no measurable condensation sink applies.

    ambient_vapor_density_kg_per_m3:
        Background vapor density entering through canyon exchange.

    canyon dimensions:
        H/W can be varied directly. Per metre street length:
          V = H*W
          A_roof = W
          source term = Q/V
          ventilation rate constant = u_e/H
    """

    canyon_height_m: float
    canyon_width_m: float
    source_rate_kg_per_s: float
    exchange_velocity_m_per_s: float
    condensation_rate_per_s: float
    ambient_vapor_density_kg_per_m3: float
    initial_vapor_density_kg_per_m3: float
    nighttime_air_temperature_c: float

    def __post_init__(self) -> None:
        for name, value in (
            ("canyon_height_m", self.canyon_height_m),
            ("canyon_width_m", self.canyon_width_m),
            ("source_rate_kg_per_s", self.source_rate_kg_per_s),
            ("exchange_velocity_m_per_s", self.exchange_velocity_m_per_s),
            ("condensation_rate_per_s", self.condensation_rate_per_s),
            (
                "ambient_vapor_density_kg_per_m3",
                self.ambient_vapor_density_kg_per_m3,
            ),
            (
                "initial_vapor_density_kg_per_m3",
                self.initial_vapor_density_kg_per_m3,
            ),
        ):
            _nonnegative(name, value)

        _positive("canyon_height_m", self.canyon_height_m)
        _positive("canyon_width_m", self.canyon_width_m)
        if not isfinite(self.nighttime_air_temperature_c):
            raise ValueError("nighttime_air_temperature_c must be finite.")

    @property
    def aspect_ratio(self) -> float:
        return self.canyon_height_m / self.canyon_width_m

    @property
    def canyon_volume_m3_per_m_street(self) -> float:
        return self.canyon_height_m * self.canyon_width_m

    @property
    def ventilation_rate_per_s(self) -> float:
        return self.exchange_velocity_m_per_s / self.canyon_height_m

    @property
    def total_removal_rate_per_s(self) -> float:
        return self.ventilation_rate_per_s + self.condensation_rate_per_s


@dataclass(frozen=True)
class NocturnalHumidityResult:
    aspect_ratio: float
    source_rate_kg_per_s: float
    equilibrium_vapor_density_kg_per_m3: float
    equilibrium_relative_humidity_percent: float
    time_to_80_percent_rh_hours: float | None
    duration_above_80_percent_hours: float
    exceeds_three_consecutive_hour_limit: bool
    source_rate_limit_for_80_percent_kg_per_s: float
    source_rate_limit_for_three_hour_rule_kg_per_s: float


def saturation_vapor_density_kg_per_m3(temperature_c: float) -> float:
    """
    Saturation vapor density from Tetens saturation-vapor-pressure relation.

      e_s [Pa] = 610.94 * exp(17.625*T/(T+243.04))
      rho_vs = e_s / (R_v * T_K)

    This is suitable for operational screening over ordinary outdoor
    temperature ranges. A production calibration can substitute a preferred
    psychrometric library while keeping the same units and interfaces.
    """
    if not isfinite(temperature_c):
        raise ValueError("temperature_c must be finite.")
    temperature_k = temperature_c + 273.15
    if temperature_k <= 0.0:
        raise ValueError("temperature_c is below physical absolute zero.")
    saturation_pressure_pa = 610.94 * exp(
        17.625 * temperature_c / (temperature_c + 243.04)
    )
    return saturation_pressure_pa / (WATER_VAPOR_GAS_CONSTANT_J_PER_KG_K * temperature_k)


def relative_humidity_percent(
    vapor_density_kg_per_m3: float,
    temperature_c: float,
) -> float:
    _nonnegative("vapor_density_kg_per_m3", vapor_density_kg_per_m3)
    return min(
        100.0,
        100.0
        * vapor_density_kg_per_m3
        / saturation_vapor_density_kg_per_m3(temperature_c),
    )


def vapor_density_at_time(
    inputs: NocturnalCanyonInputs,
    elapsed_seconds: float,
) -> float:
    """
    Solve the specified mass-balance ODE:

      dC/dt = Q/V - (u_e/H)(C-C_ambient) - k_cond*C

    Define:
      lambda = u_e/H + k_cond
      C_inf = [Q/V + (u_e/H)C_ambient] / lambda

    Then:
      C(t) = C_inf + [C(0)-C_inf]exp(-lambda*t)
    """
    _nonnegative("elapsed_seconds", elapsed_seconds)
    removal = inputs.total_removal_rate_per_s

    if removal == 0.0:
        return (
            inputs.initial_vapor_density_kg_per_m3
            + inputs.source_rate_kg_per_s
            / inputs.canyon_volume_m3_per_m_street
            * elapsed_seconds
        )

    equilibrium = (
        inputs.source_rate_kg_per_s / inputs.canyon_volume_m3_per_m_street
        + inputs.ventilation_rate_per_s * inputs.ambient_vapor_density_kg_per_m3
    ) / removal

    return equilibrium + (
        inputs.initial_vapor_density_kg_per_m3 - equilibrium
    ) * exp(-removal * elapsed_seconds)


def source_rate_for_target_rh(
    inputs: NocturnalCanyonInputs,
    target_relative_humidity_percent: float = 80.0,
) -> float:
    """
    Find the source rate at which equilibrium RH equals the target.

      C_target = RH_target * rho_sat / 100

      Q_limit = V[
          lambda*C_target - (u_e/H)*C_ambient
      ]

    A non-positive result means ambient/initial conditions already place the
    canyon at or above the requested equilibrium target under the stated sink
    configuration.
    """
    _bounded(
        "target_relative_humidity_percent",
        target_relative_humidity_percent,
        0.0,
        100.0,
    )
    target_density = (
        target_relative_humidity_percent
        / 100.0
        * saturation_vapor_density_kg_per_m3(inputs.nighttime_air_temperature_c)
    )
    rate = inputs.canyon_volume_m3_per_m_street * (
        inputs.total_removal_rate_per_s * target_density
        - inputs.ventilation_rate_per_s * inputs.ambient_vapor_density_kg_per_m3
    )
    return max(0.0, rate)


def source_rate_for_duration_limit(
    inputs: NocturnalCanyonInputs,
    night_duration_hours: float,
    allowed_consecutive_hours_above_target: float = 3.0,
    target_relative_humidity_percent: float = 80.0,
) -> float:
    """
    Solve the maximum source that keeps time above target RH at or below the
    allowed duration, assuming monotonically increasing C(t).

    The target crossing is set at:
      t_cross = night_duration - allowed_duration

    Required target state:
      C_target =
        C_inf + (C_0-C_inf) exp(-lambda*t_cross)

    Solving for C_inf:
      C_inf =
        [C_target - C_0 exp(-lambda*t_cross)]
        / [1-exp(-lambda*t_cross)]

    Then solve C_inf for Q. If the initial condition is already at/above the
    target, the permissible source rate is zero.
    """
    _positive("night_duration_hours", night_duration_hours)
    _nonnegative(
        "allowed_consecutive_hours_above_target",
        allowed_consecutive_hours_above_target,
    )
    if allowed_consecutive_hours_above_target >= night_duration_hours:
        return source_rate_for_target_rh(inputs, target_relative_humidity_percent)

    target_density = (
        target_relative_humidity_percent
        / 100.0
        * saturation_vapor_density_kg_per_m3(inputs.nighttime_air_temperature_c)
    )
    if inputs.initial_vapor_density_kg_per_m3 >= target_density:
        return 0.0

    removal = inputs.total_removal_rate_per_s
    if removal == 0.0:
        time_to_target_seconds = (
            night_duration_hours - allowed_consecutive_hours_above_target
        ) * SECONDS_PER_HOUR
        return (
            (target_density - inputs.initial_vapor_density_kg_per_m3)
            * inputs.canyon_volume_m3_per_m_street
            / time_to_target_seconds
        )

    crossing_time_seconds = (
        night_duration_hours - allowed_consecutive_hours_above_target
    ) * SECONDS_PER_HOUR
    decay = exp(-removal * crossing_time_seconds)
    equilibrium_required = (
        target_density
        - inputs.initial_vapor_density_kg_per_m3 * decay
    ) / (1.0 - decay)

    source_rate = inputs.canyon_volume_m3_per_m_street * (
        removal * equilibrium_required
        - inputs.ventilation_rate_per_s * inputs.ambient_vapor_density_kg_per_m3
    )
    return max(0.0, source_rate)


def assess_nocturnal_humidity(
    inputs: NocturnalCanyonInputs,
    night_duration_hours: float,
    target_relative_humidity_percent: float = 80.0,
    allowed_consecutive_hours_above_target: float = 3.0,
) -> NocturnalHumidityResult:
    """
    Assess threshold crossing and duration using the analytical solution.
    """
    _positive("night_duration_hours", night_duration_hours)
    _nonnegative(
        "allowed_consecutive_hours_above_target",
        allowed_consecutive_hours_above_target,
    )
    target_density = (
        target_relative_humidity_percent
        / 100.0
        * saturation_vapor_density_kg_per_m3(inputs.nighttime_air_temperature_c)
    )
    end_density = vapor_density_at_time(
        inputs,
        night_duration_hours * SECONDS_PER_HOUR,
    )

    equilibrium_density = (
        vapor_density_at_time(inputs, 365.0 * 24.0 * SECONDS_PER_HOUR)
        if inputs.total_removal_rate_per_s > 0.0
        else float("inf")
    )
    equilibrium_rh = relative_humidity_percent(
        equilibrium_density,
        inputs.nighttime_air_temperature_c,
    )

    time_to_target_hours: float | None = None
    duration_above_target = 0.0

    if inputs.initial_vapor_density_kg_per_m3 >= target_density:
        time_to_target_hours = 0.0
        duration_above_target = night_duration_hours
    elif end_density >= target_density:
        removal = inputs.total_removal_rate_per_s
        if removal == 0.0:
            time_seconds = (
                (target_density - inputs.initial_vapor_density_kg_per_m3)
                * inputs.canyon_volume_m3_per_m_street
                / inputs.source_rate_kg_per_s
            )
        else:
            equilibrium = (
                inputs.source_rate_kg_per_s / inputs.canyon_volume_m3_per_m_street
                + inputs.ventilation_rate_per_s
                * inputs.ambient_vapor_density_kg_per_m3
            ) / removal
            ratio = (
                (target_density - equilibrium)
                / (
                    inputs.initial_vapor_density_kg_per_m3
                    - equilibrium
                )
            )
            time_seconds = -log_safe(ratio) / removal

        time_to_target_hours = max(0.0, time_seconds / SECONDS_PER_HOUR)
        duration_above_target = max(0.0, night_duration_hours - time_to_target_hours)

    return NocturnalHumidityResult(
        aspect_ratio=inputs.aspect_ratio,
        source_rate_kg_per_s=inputs.source_rate_kg_per_s,
        equilibrium_vapor_density_kg_per_m3=equilibrium_density,
        equilibrium_relative_humidity_percent=equilibrium_rh,
        time_to_80_percent_rh_hours=time_to_target_hours,
        duration_above_80_percent_hours=duration_above_target,
        exceeds_three_consecutive_hour_limit=(
            duration_above_target > allowed_consecutive_hours_above_target
        ),
        source_rate_limit_for_80_percent_kg_per_s=source_rate_for_target_rh(
            inputs,
            target_relative_humidity_percent,
        ),
        source_rate_limit_for_three_hour_rule_kg_per_s=source_rate_for_duration_limit(
            inputs,
            night_duration_hours,
            allowed_consecutive_hours_above_target,
            target_relative_humidity_percent,
        ),
    )


def log_safe(value: float) -> float:
    if value <= 0.0:
        raise ValueError(
            "No finite positive threshold crossing exists under the stated inputs."
        )
    return __import__("math").log(value)


@dataclass(frozen=True)
class ETForecast:
    """
    Daily AI-predicted ET and forecast uncertainty for a receding-horizon plan.

    et_pred_mm_per_day is plot-scale modeled ET demand. It must be reconciled
    against soil-moisture observations and any quality-screened satellite ET
    inputs; it is not treated as a direct ground measurement.

    forecast_standard_error_mm increases with forecast lead time according to
    measured held-out forecast performance.
    """

    day_index: int
    et_pred_mm_per_day: float
    forecast_standard_error_mm: float
    effective_rainfall_mm: float = 0.0

    def __post_init__(self) -> None:
        if self.day_index < 1:
            raise ValueError("day_index must begin at one.")
        for name, value in (
            ("et_pred_mm_per_day", self.et_pred_mm_per_day),
            ("forecast_standard_error_mm", self.forecast_standard_error_mm),
            ("effective_rainfall_mm", self.effective_rainfall_mm),
        ):
            _nonnegative(name, value)


@dataclass(frozen=True)
class SoilWaterState:
    """
    Root-zone soil-water accounting in millimetres of water depth.

    deficit_mm rises as ET removes soil water and falls as infiltrated
    irrigation or effective rainfall replenishes it.

    Constraint:
      0 <= deficit_t <= total_available_water_mm

    The readily-available depletion boundary triggers stress prevention:
      deficit_t <= readily_available_water_mm.
    """

    initial_deficit_mm: float
    total_available_water_mm: float
    readily_available_water_mm: float
    maximum_daily_irrigation_mm: float
    remaining_water_budget_mm: float
    irrigation_efficiency: float

    def __post_init__(self) -> None:
        for name, value in (
            ("initial_deficit_mm", self.initial_deficit_mm),
            ("total_available_water_mm", self.total_available_water_mm),
            (
                "readily_available_water_mm",
                self.readily_available_water_mm,
            ),
            (
                "maximum_daily_irrigation_mm",
                self.maximum_daily_irrigation_mm,
            ),
            ("remaining_water_budget_mm", self.remaining_water_budget_mm),
            ("irrigation_efficiency", self.irrigation_efficiency),
        ):
            _nonnegative(name, value)

        _positive("total_available_water_mm", self.total_available_water_mm)
        if self.readily_available_water_mm > self.total_available_water_mm:
            raise ValueError(
                "readily_available_water_mm cannot exceed total_available_water_mm."
            )
        if self.initial_deficit_mm > self.total_available_water_mm:
            raise ValueError(
                "initial_deficit_mm cannot exceed total_available_water_mm."
            )
        if self.irrigation_efficiency > 1.0:
            raise ValueError("irrigation_efficiency cannot exceed one.")


@dataclass(frozen=True)
class IrrigationPlanDay:
    day_index: int
    predicted_et_mm: float
    forecast_error_mm: float
    irrigation_applied_mm: float
    expected_infiltrated_irrigation_mm: float
    effective_rainfall_mm: float
    predicted_end_deficit_mm: float
    stress_constraint_satisfied: bool


@dataclass(frozen=True)
class HorizonEvaluation:
    horizon_days: int
    plan: tuple[IrrigationPlanDay, ...]
    total_applied_irrigation_mm: float
    expected_water_use_efficiency: float
    expected_stress_penalty_mm: float
    forecast_uncertainty_penalty_mm: float
    objective_value: float
    feasible: bool
    recommendation: str


def optimize_et_irrigation_horizon(
    forecasts: Sequence[ETForecast],
    soil: SoilWaterState,
    horizon_days: int,
    stress_penalty_weight: float = 10.0,
    uncertainty_penalty_weight: float = 1.0,
) -> HorizonEvaluation:
    """
    Receding-horizon irrigation scheduling with direct soil-water constraints.

    Forecast objective:

      minimize sum_t [
          (ET_pred(t) - I_eff(t))^2
          + lambda_stress * max(0, D_t - RAW)^2
          + lambda_uncertainty * sigma_ET(t)^2
      ]

    subject to:
      0 <= I(t) <= I_max
      sum I(t) <= water_budget
      D(t+1) = D(t) + ET_pred(t) - P_eff(t) - eta*I(t)
      0 <= D(t+1) <= TAW

    The applied irrigation rule maintains a conservative buffer proportional to
    forecast uncertainty while never silently exceeding the water budget.
    """
    if horizon_days not in {1, 3, 7}:
        raise ValueError("horizon_days must be one of 1, 3, or 7.")
    if len(forecasts) < horizon_days:
        raise ValueError("Not enough ET forecasts for requested horizon.")
    _nonnegative("stress_penalty_weight", stress_penalty_weight)
    _nonnegative("uncertainty_penalty_weight", uncertainty_penalty_weight)

    selected = sorted(forecasts[:horizon_days], key=lambda item: item.day_index)
    deficit = soil.initial_deficit_mm
    remaining_budget = soil.remaining_water_budget_mm
    days: list[IrrigationPlanDay] = []
    total_applied = 0.0
    total_stress_penalty = 0.0
    total_uncertainty_penalty = 0.0
    matching_loss = 0.0
    feasible = True

    for forecast in selected:
        projected_without_irrigation = (
            deficit
            + forecast.et_pred_mm_per_day
            - forecast.effective_rainfall_mm
        )
        uncertainty_buffer = forecast.forecast_standard_error_mm
        target_deficit = max(
            0.0,
            soil.readily_available_water_mm - uncertainty_buffer,
        )
        required_infiltrated = max(
            0.0,
            projected_without_irrigation - target_deficit,
        )
        requested_applied = required_infiltrated / max(soil.irrigation_efficiency, 1e-12)
        applied = min(
            requested_applied,
            soil.maximum_daily_irrigation_mm,
            remaining_budget,
        )
        infiltrated = applied * soil.irrigation_efficiency
        next_deficit = max(
            0.0,
            projected_without_irrigation - infiltrated,
        )
        stress_excess = max(
            0.0,
            next_deficit - soil.readily_available_water_mm,
        )
        physical_excess = max(
            0.0,
            next_deficit - soil.total_available_water_mm,
        )
        if physical_excess > 0.0:
            feasible = False

        matching_loss += (
            forecast.et_pred_mm_per_day - infiltrated
        ) ** 2
        total_stress_penalty += stress_excess**2
        total_uncertainty_penalty += forecast.forecast_standard_error_mm**2
        days.append(
            IrrigationPlanDay(
                day_index=forecast.day_index,
                predicted_et_mm=forecast.et_pred_mm_per_day,
                forecast_error_mm=forecast.forecast_standard_error_mm,
                irrigation_applied_mm=applied,
                expected_infiltrated_irrigation_mm=infiltrated,
                effective_rainfall_mm=forecast.effective_rainfall_mm,
                predicted_end_deficit_mm=next_deficit,
                stress_constraint_satisfied=(
                    next_deficit <= soil.readily_available_water_mm
                ),
            )
        )
        deficit = next_deficit
        remaining_budget -= applied
        total_applied += applied

    expected_useful_delivery = sum(
        item.expected_infiltrated_irrigation_mm for item in days
    )
    water_use_efficiency = (
        expected_useful_delivery / total_applied
        if total_applied > 0.0
        else 0.0
    )
    objective = (
        matching_loss
        + stress_penalty_weight * total_stress_penalty
        + uncertainty_penalty_weight * total_uncertainty_penalty
    )
    recommendation = (
        "Horizon remains within soil-water and budget corridors."
        if feasible
        else (
            "Forecast demand exceeds the modeled soil-water capacity under the "
            "available budget; retain operator review and restoration-stress "
            "mitigation pathways."
        )
    )

    return HorizonEvaluation(
        horizon_days=horizon_days,
        plan=tuple(days),
        total_applied_irrigation_mm=total_applied,
        expected_water_use_efficiency=water_use_efficiency,
        expected_stress_penalty_mm=total_stress_penalty,
        forecast_uncertainty_penalty_mm=total_uncertainty_penalty,
        objective_value=objective,
        feasible=feasible,
        recommendation=recommendation,
    )


def select_optimal_et_horizon(
    forecasts: Sequence[ETForecast],
    soil: SoilWaterState,
    horizons: Sequence[int] = (1, 3, 7),
    stress_penalty_weight: float = 10.0,
    uncertainty_penalty_weight: float = 1.0,
) -> HorizonEvaluation:
    """
    Select the horizon with minimum objective among feasible horizons.

    This determines the planning horizon; operational use remains receding
    horizon: re-observe soil moisture and update forecasts each day before
    applying the next allocation.
    """
    evaluations = [
        optimize_et_irrigation_horizon(
            forecasts=forecasts,
            soil=soil,
            horizon_days=horizon,
            stress_penalty_weight=stress_penalty_weight,
            uncertainty_penalty_weight=uncertainty_penalty_weight,
        )
        for horizon in horizons
    ]
    feasible = [item for item in evaluations if item.feasible]
    if not feasible:
        raise ValueError(
            "No requested forecast horizon remains feasible under current soil and water constraints."
        )

    return min(
        feasible,
        key=lambda item: (
            item.objective_value,
            -item.expected_water_use_efficiency,
            item.horizon_days,
        ),
    )
