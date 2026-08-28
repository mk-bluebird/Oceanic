from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, pi, sqrt
from typing import Sequence


VACUUM_PERMITTIVITY_F_PER_M = 8.8541878128e-12
AIR_DYNAMIC_VISCOSITY_PA_S = 1.90e-5
AIR_DENSITY_KG_PER_M3 = 1.15
WATER_DENSITY_KG_PER_M3 = 997.0
GRAVITY_M_PER_S2 = 9.80665


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
class ChargedDropletInputs:
    """
    Screening inputs for a spherical aqueous droplet near a grounded or
    effectively conducting collection surface.

    The image-force term is applicable only after confirming the surface's
    electrostatic boundary condition. Concrete, paint, vegetation, skin,
    fabric, and wet surfaces can behave as lossy dielectrics rather than ideal
    conductors, so laboratory validation remains required.

    distance_to_surface_m:
        Gap h from droplet center to a nearby receiving surface. It must exceed
        droplet radius.

    charge_to_mass_c_per_kg:
        Measured nozzle-exit q/m. This is preferred to deriving charge from a
        nominal voltage because charging depends on liquid conductivity,
        nozzle material, flow, pressure, grounding, and plume space charge.
    """

    droplet_diameter_um: float
    charge_to_mass_c_per_kg: float
    distance_to_surface_m: float
    air_dynamic_viscosity_pa_s: float = AIR_DYNAMIC_VISCOSITY_PA_S
    air_density_kg_per_m3: float = AIR_DENSITY_KG_PER_M3
    water_density_kg_per_m3: float = WATER_DENSITY_KG_PER_M3
    image_force_capture_distance_m: float = 0.05
    significant_removal_fraction: float = 0.10

    def __post_init__(self) -> None:
        for name, value in (
            ("droplet_diameter_um", self.droplet_diameter_um),
            ("charge_to_mass_c_per_kg", self.charge_to_mass_c_per_kg),
            ("distance_to_surface_m", self.distance_to_surface_m),
            ("air_dynamic_viscosity_pa_s", self.air_dynamic_viscosity_pa_s),
            ("air_density_kg_per_m3", self.air_density_kg_per_m3),
            ("water_density_kg_per_m3", self.water_density_kg_per_m3),
            (
                "image_force_capture_distance_m",
                self.image_force_capture_distance_m,
            ),
            ("significant_removal_fraction", self.significant_removal_fraction),
        ):
            _nonnegative(name, value)

        _positive("droplet_diameter_um", self.droplet_diameter_um)
        _positive("distance_to_surface_m", self.distance_to_surface_m)
        _positive("air_dynamic_viscosity_pa_s", self.air_dynamic_viscosity_pa_s)
        _positive("water_density_kg_per_m3", self.water_density_kg_per_m3)
        _positive("image_force_capture_distance_m", self.image_force_capture_distance_m)
        _bounded(
            "significant_removal_fraction",
            self.significant_removal_fraction,
            0.0,
            1.0,
        )

        if self.distance_to_surface_m <= self.radius_m:
            raise ValueError(
                "distance_to_surface_m must exceed the droplet radius."
            )

    @property
    def radius_m(self) -> float:
        return self.droplet_diameter_um * 1e-6 / 2.0

    @property
    def mass_kg(self) -> float:
        return (
            (4.0 / 3.0)
            * pi
            * self.radius_m**3
            * self.water_density_kg_per_m3
        )

    @property
    def charge_c(self) -> float:
        return self.charge_to_mass_c_per_kg * self.mass_kg


@dataclass(frozen=True)
class ElectrostaticDepositionResult:
    stokes_settling_velocity_m_per_s: float
    image_force_velocity_m_per_s: float
    effective_surface_directed_velocity_m_per_s: float
    charge_to_mass_significance_threshold_c_per_kg: float
    electrostatic_removal_significant: bool
    design_status: str
    interpretation: str


def stokes_settling_velocity(inputs: ChargedDropletInputs) -> float:
    """
    Low-Reynolds-number gravitational settling velocity.
    """
    diameter_m = inputs.droplet_diameter_um * 1e-6
    return (
        (inputs.water_density_kg_per_m3 - inputs.air_density_kg_per_m3)
        * GRAVITY_M_PER_S2
        * diameter_m**2
        / (18.0 * inputs.air_dynamic_viscosity_pa_s)
    )


def image_force_velocity(inputs: ChargedDropletInputs) -> float:
    """
    Surface-directed image-force drift velocity.

    Starting with the user's expression:

      v_image =
        q^2 /
        [16*pi*epsilon_0*h^2*6*pi*eta*r]

    This is added as a surface-normal removal velocity magnitude. In a full
    trajectory model it must be projected onto local surface normal and coupled
    with aerodynamic drag, turbulent diffusion, charge decay, and electric
    field geometry.
    """
    return (
        inputs.charge_c**2
        / (
            16.0
            * pi
            * VACUUM_PERMITTIVITY_F_PER_M
            * inputs.distance_to_surface_m**2
            * 6.0
            * pi
            * inputs.air_dynamic_viscosity_pa_s
            * inputs.radius_m
        )
    )


def charge_to_mass_for_significant_capture(
    inputs: ChargedDropletInputs,
) -> float:
    """
    Solve q/m such that image-force transit speed through the capture distance
    equals the required surface-directed velocity.

    Required velocity is defined as a significant fraction of gravitational
    Stokes settling velocity:

      v_image,target = f_significant * v_stokes

    Since q = (q/m)*m and v_image proportional to q²:

      (q/m)_threshold =
        sqrt[
          v_target*16*pi*epsilon_0*h²*6*pi*eta*r
          / m²
        ].
    """
    target_velocity = (
        inputs.significant_removal_fraction * stokes_settling_velocity(inputs)
    )
    numerator = (
        target_velocity
        * 16.0
        * pi
        * VACUUM_PERMITTIVITY_F_PER_M
        * inputs.distance_to_surface_m**2
        * 6.0
        * pi
        * inputs.air_dynamic_viscosity_pa_s
        * inputs.radius_m
    )
    return sqrt(numerator / inputs.mass_kg**2)


def assess_electrostatic_deposition(
    inputs: ChargedDropletInputs,
) -> ElectrostaticDepositionResult:
    """
    Apply a non-deployment screening decision.

    Deliberate charge is marked as research-only because a charge that increases
    external surface deposition can also alter respiratory-tract deposition,
    nozzle plume behavior, and deposition on people, assistive devices, and
    public infrastructure. Any public-facing aerosol release remains outside
    this artifact's authorization scope.
    """
    stokes = stokes_settling_velocity(inputs)
    image_velocity = image_force_velocity(inputs)
    threshold = charge_to_mass_for_significant_capture(inputs)
    significant = inputs.charge_to_mass_c_per_kg >= threshold

    if significant:
        status = "research_validation_required_before_any_public_use"
        explanation = (
            "The modeled image-force contribution reaches the declared "
            "significance threshold. It may improve capture onto intentionally "
            "grounded collector surfaces, but it may also increase deposition "
            "onto unintended surfaces and alter inhalation deposition."
        )
    else:
        status = "electrostatic_effect_below_declared_screening_threshold"
        explanation = (
            "The modeled image-force contribution is below the declared "
            "surface-removal threshold under the stated ideal-conductor "
            "assumption. It does not establish low aerosol risk."
        )

    return ElectrostaticDepositionResult(
        stokes_settling_velocity_m_per_s=stokes,
        image_force_velocity_m_per_s=image_velocity,
        effective_surface_directed_velocity_m_per_s=stokes + image_velocity,
        charge_to_mass_significance_threshold_c_per_kg=threshold,
        electrostatic_removal_significant=significant,
        design_status=status,
        interpretation=explanation,
    )


@dataclass(frozen=True)
class HeatWaveHour:
    """
    One hour in an extreme-heat event.

    vulnerable_population_weight is an aggregate equity weight for accessible,
    high-need service areas. It does not identify or score individual people.
    """

    hour_index: int
    ambient_temperature_c: float
    baseline_wbgt_c: float
    solar_load_w_per_m2: float
    relative_humidity_percent: float
    wind_speed_m_per_s: float
    vulnerable_population_weight: float

    def __post_init__(self) -> None:
        if self.hour_index < 0:
            raise ValueError("hour_index must be non-negative.")
        for name, value in (
            ("solar_load_w_per_m2", self.solar_load_w_per_m2),
            ("relative_humidity_percent", self.relative_humidity_percent),
            ("wind_speed_m_per_s", self.wind_speed_m_per_s),
            (
                "vulnerable_population_weight",
                self.vulnerable_population_weight,
            ),
        ):
            _nonnegative(name, value)
        if self.relative_humidity_percent > 100.0:
            raise ValueError("relative_humidity_percent must not exceed 100.")
        if not isfinite(self.ambient_temperature_c) or not isfinite(self.baseline_wbgt_c):
            raise ValueError("temperature and WBGT values must be finite.")


@dataclass(frozen=True)
class HeatStrategy:
    """
    Performance coefficients must be calibrated from field measurements.

    wbgt_reduction:
      static reduction potential before hourly environmental adjustment.

    water_l_per_hour:
      direct operational water consumption. Tree canopy is modeled through
      maintenance/irrigation water, while shade and cool pavement can be zero
      during operation.

    base_failure_probability:
      probability of unavailability before environmental stress adjustment.
      This is a planning reliability input, not a prediction of component
      failure for any particular installation.

    accessibility_fraction:
      proportion of the strategy's nominal spatial benefit accessible through
      a usable public route and service condition.
    """

    name: str
    static_wbgt_reduction_c: float
    water_l_per_hour: float
    base_failure_probability: float
    heat_failure_sensitivity_per_c: float
    humidity_performance_sensitivity: float
    solar_performance_sensitivity_per_kw_m2: float
    wind_performance_sensitivity_per_m_s: float
    vulnerable_accessibility_fraction: float

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("name must not be empty.")
        for name, value in (
            ("static_wbgt_reduction_c", self.static_wbgt_reduction_c),
            ("water_l_per_hour", self.water_l_per_hour),
            ("base_failure_probability", self.base_failure_probability),
            (
                "heat_failure_sensitivity_per_c",
                self.heat_failure_sensitivity_per_c,
            ),
            (
                "humidity_performance_sensitivity",
                self.humidity_performance_sensitivity,
            ),
            (
                "solar_performance_sensitivity_per_kw_m2",
                self.solar_performance_sensitivity_per_kw_m2,
            ),
            (
                "wind_performance_sensitivity_per_m_s",
                self.wind_performance_sensitivity_per_m_s,
            ),
            (
                "vulnerable_accessibility_fraction",
                self.vulnerable_accessibility_fraction,
            ),
        ):
            _nonnegative(name, value)

        _bounded("base_failure_probability", self.base_failure_probability, 0.0, 1.0)
        _bounded(
            "vulnerable_accessibility_fraction",
            self.vulnerable_accessibility_fraction,
            0.0,
            1.0,
        )


@dataclass(frozen=True)
class StrategyHourResult:
    strategy_name: str
    hour_index: int
    wbgt_reduction_c: float
    water_l_per_hour: float
    failure_probability: float
    vulnerable_population_benefit: float


@dataclass(frozen=True)
class HeatWaveComparisonResult:
    hourly_results: tuple[StrategyHourResult, ...]
    mean_wbgt_reduction_by_strategy: dict[str, float]
    total_water_l_by_strategy: dict[str, float]
    mean_failure_probability_by_strategy: dict[str, float]
    vulnerable_population_benefit_by_strategy: dict[str, float]
    crossover_hours: dict[str, tuple[int, ...]]


def strategy_hour_performance(
    strategy: HeatStrategy,
    hour: HeatWaveHour,
    reference_temperature_c: float = 46.0,
) -> StrategyHourResult:
    """
    Compute time-varying strategy performance.

      DeltaWBGT_s(t) =
        DeltaWBGT_static,s
        * A_humidity,s(t)
        * A_solar,s(t)
        * A_wind,s(t)
        * [1-P_failure,s(t)]

    Each adjustment is clipped at zero. This makes humidity-sensitive
    Cyboquatic evaporation decline as RH rises, while shade, tree canopy, and
    cool pavement receive their own measured coefficients rather than a
    fabricated universal ranking.
    """
    humidity_adjustment = max(
        0.0,
        1.0
        - strategy.humidity_performance_sensitivity
        * (hour.relative_humidity_percent / 100.0),
    )
    solar_adjustment = max(
        0.0,
        1.0
        + strategy.solar_performance_sensitivity_per_kw_m2
        * (hour.solar_load_w_per_m2 / 1_000.0),
    )
    wind_adjustment = max(
        0.0,
        1.0
        + strategy.wind_performance_sensitivity_per_m_s
        * hour.wind_speed_m_per_s,
    )
    failure_probability = min(
        1.0,
        strategy.base_failure_probability
        + strategy.heat_failure_sensitivity_per_c
        * max(0.0, hour.ambient_temperature_c - reference_temperature_c),
    )
    wbgt_reduction = (
        strategy.static_wbgt_reduction_c
        * humidity_adjustment
        * solar_adjustment
        * wind_adjustment
        * (1.0 - failure_probability)
    )
    vulnerable_benefit = (
        wbgt_reduction
        * hour.vulnerable_population_weight
        * strategy.vulnerable_accessibility_fraction
    )

    return StrategyHourResult(
        strategy_name=strategy.name,
        hour_index=hour.hour_index,
        wbgt_reduction_c=wbgt_reduction,
        water_l_per_hour=strategy.water_l_per_hour,
        failure_probability=failure_probability,
        vulnerable_population_benefit=vulnerable_benefit,
    )


def compare_heatwave_strategies(
    hours: Sequence[HeatWaveHour],
    strategies: Sequence[HeatStrategy],
) -> HeatWaveComparisonResult:
    """
    Evaluate strategy time series and pairwise-crossover hours.

    A crossover hour is reported for a strategy pair when their time-varying
    WBGT-reduction ordering changes between consecutive time steps. It signals
    an empirical operating condition where the relative benefit changes, not a
    universal strategy ranking.
    """
    if not hours:
        raise ValueError("At least one heat-wave hour is required.")
    if not strategies:
        raise ValueError("At least one strategy is required.")

    hourly = tuple(
        strategy_hour_performance(strategy, hour)
        for strategy in strategies
        for hour in hours
    )

    grouped: dict[str, list[StrategyHourResult]] = {
        strategy.name: [] for strategy in strategies
    }
    for result in hourly:
        grouped[result.strategy_name].append(result)

    mean_wbgt = {
        name: sum(item.wbgt_reduction_c for item in values) / len(values)
        for name, values in grouped.items()
    }
    total_water = {
        name: sum(item.water_l_per_hour for item in values)
        for name, values in grouped.items()
    }
    mean_failure = {
        name: sum(item.failure_probability for item in values) / len(values)
        for name, values in grouped.items()
    }
    vulnerable_benefit = {
        name: sum(item.vulnerable_population_benefit for item in values)
        for name, values in grouped.items()
    }

    crossovers: dict[str, tuple[int, ...]] = {}
    names = [strategy.name for strategy in strategies]
    for left_index in range(len(names)):
        for right_index in range(left_index + 1, len(names)):
            left = grouped[names[left_index]]
            right = grouped[names[right_index]]
            pair_key = f"{names[left_index]}__vs__{names[right_index]}"
            change_points: list[int] = []
            prior_difference = left[0].wbgt_reduction_c - right[0].wbgt_reduction_c

            for index in range(1, len(left)):
                current_difference = (
                    left[index].wbgt_reduction_c
                    - right[index].wbgt_reduction_c
                )
                if (
                    prior_difference != 0.0
                    and current_difference != 0.0
                    and prior_difference * current_difference < 0.0
                ):
                    change_points.append(left[index].hour_index)
                prior_difference = current_difference
            crossovers[pair_key] = tuple(change_points)

    return HeatWaveComparisonResult(
        hourly_results=hourly,
        mean_wbgt_reduction_by_strategy=mean_wbgt,
        total_water_l_by_strategy=total_water,
        mean_failure_probability_by_strategy=mean_failure,
        vulnerable_population_benefit_by_strategy=vulnerable_benefit,
        crossover_hours=crossovers,
    )
