from __future__ import annotations

from dataclasses import dataclass
from math import ceil, isfinite, pi, sqrt
from typing import Sequence


GRAVITY_M_PER_S2 = 9.80665
WATER_DENSITY_KG_PER_M3 = 997.0
AIR_DENSITY_KG_PER_M3 = 1.15
AIR_DYNAMIC_VISCOSITY_PA_S = 1.90e-5
SECONDS_PER_HOUR = 3_600.0
KWH_PER_MWH = 1_000.0


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


@dataclass(frozen=True)
class TimeSlot:
    """
    One decision interval, commonly one hour.

    Irrigation legality is represented directly rather than inferred from clock
    time. This permits the scheduler to use the currently applicable municipal,
    district, or site-specific restriction set without hardcoding a legal rule.
    """

    label: str
    duration_hours: float
    energy_price_usd_per_kwh: float
    grid_carbon_kgco2e_per_kwh: float
    grid_peak_weight: float
    irrigation_allowed: bool
    irrigation_efficiency: float
    canopy_stress_reduction_per_m3: float
    soil_warming_benefit_per_kwh: float
    remote_sensing_deadline_priority: float

    def __post_init__(self) -> None:
        _positive("duration_hours", self.duration_hours)
        for name, value in (
            ("energy_price_usd_per_kwh", self.energy_price_usd_per_kwh),
            ("grid_carbon_kgco2e_per_kwh", self.grid_carbon_kgco2e_per_kwh),
            ("grid_peak_weight", self.grid_peak_weight),
            ("irrigation_efficiency", self.irrigation_efficiency),
            ("canopy_stress_reduction_per_m3", self.canopy_stress_reduction_per_m3),
            ("soil_warming_benefit_per_kwh", self.soil_warming_benefit_per_kwh),
            ("remote_sensing_deadline_priority", self.remote_sensing_deadline_priority),
        ):
            _nonnegative(name, value)

        if not self.label.strip():
            raise ValueError("label must not be empty.")
        if self.irrigation_efficiency > 1.0:
            raise ValueError("irrigation_efficiency must not exceed one.")


@dataclass(frozen=True)
class ComputeWorkload:
    """
    Non-divisible job block for a restoration workload.

    workload_type:
      irrigation_model,
      remote_sensing,
      soil_warming

    Soil warming uses recoverable waste heat. The model credits only the
    measured fraction of compute heat beneficially delivered to soil, not all
    electrical energy consumed by a processor.
    """

    workload_id: str
    workload_type: str
    energy_kwh: float
    deadline_slot_index: int
    required: bool = True
    recoverable_waste_heat_fraction: float = 0.0

    def __post_init__(self) -> None:
        if self.workload_type not in {
            "irrigation_model",
            "remote_sensing",
            "soil_warming",
        }:
            raise ValueError("workload_type is not supported.")
        _positive("energy_kwh", self.energy_kwh)
        if self.deadline_slot_index < 0:
            raise ValueError("deadline_slot_index must be non-negative.")
        _nonnegative(
            "recoverable_waste_heat_fraction",
            self.recoverable_waste_heat_fraction,
        )
        if self.recoverable_waste_heat_fraction > 1.0:
            raise ValueError("recoverable_waste_heat_fraction must not exceed one.")
        if not self.workload_id.strip():
            raise ValueError("workload_id must not be empty.")


@dataclass(frozen=True)
class IrrigationDemand:
    required_root_zone_water_m3: float
    daily_water_budget_m3: float

    def __post_init__(self) -> None:
        _nonnegative(
            "required_root_zone_water_m3",
            self.required_root_zone_water_m3,
        )
        _nonnegative("daily_water_budget_m3", self.daily_water_budget_m3)


@dataclass(frozen=True)
class ScheduledWorkload:
    workload_id: str
    workload_type: str
    slot_label: str
    energy_kwh: float
    cost_usd: float
    carbon_kgco2e: float
    grid_peak_score: float
    useful_soil_heat_benefit: float


@dataclass(frozen=True)
class EnergyWaterSchedule:
    scheduled_workloads: tuple[ScheduledWorkload, ...]
    irrigation_slot_label: str | None
    applied_water_m3: float
    delivered_root_zone_water_m3: float
    total_energy_kwh: float
    total_cost_usd: float
    total_carbon_kgco2e: float
    total_peak_score: float
    total_soil_heat_benefit: float
    all_required_workloads_scheduled: bool


def _workload_slot_score(
    workload: ComputeWorkload,
    slot: TimeSlot,
    peak_penalty_weight: float,
    carbon_penalty_weight: float,
    deadline_bonus_weight: float,
) -> float:
    """
    Lower scores are preferred.

    The score coordinates:
      - TOU energy price,
      - peak-demand avoidance,
      - marginal/attributional carbon intensity,
      - deadline-sensitive remote-sensing value,
      - measured recoverable waste-heat benefit.
    """
    direct_cost = workload.energy_kwh * slot.energy_price_usd_per_kwh
    peak_cost = workload.energy_kwh * slot.grid_peak_weight * peak_penalty_weight
    carbon_cost = (
        workload.energy_kwh
        * slot.grid_carbon_kgco2e_per_kwh
        * carbon_penalty_weight
    )
    deadline_benefit = (
        slot.remote_sensing_deadline_priority
        * deadline_bonus_weight
        if workload.workload_type == "remote_sensing"
        else 0.0
    )
    soil_heat_benefit = (
        workload.energy_kwh
        * workload.recoverable_waste_heat_fraction
        * slot.soil_warming_benefit_per_kwh
        if workload.workload_type == "soil_warming"
        else 0.0
    )
    return direct_cost + peak_cost + carbon_cost - deadline_benefit - soil_heat_benefit


def optimize_energy_water_schedule(
    slots: Sequence[TimeSlot],
    workloads: Sequence[ComputeWorkload],
    irrigation: IrrigationDemand,
    peak_penalty_weight: float = 1.0,
    carbon_penalty_weight: float = 0.0,
    deadline_bonus_weight: float = 1.0,
) -> EnergyWaterSchedule:
    """
    Solve a transparent discrete scheduling problem.

    Objective:

      minimize sum_t [
          price_t * E_t
          + lambda_peak * peak_weight_t * E_t
          + lambda_carbon * CI_t * E_t
      ]
      - deadline_value(remote_sensing)
      - useful_waste_heat(soil_warming)

    subject to:
      each required workload is scheduled at most once before its deadline;
      irrigation occurs only in allowed time slots;
      applied water is within budget;
      delivered root-zone water is maximized using irrigation efficiency.

    A production fleet can replace the greedy placement with a MILP while
    retaining these explicit constraints and objective terms.
    """
    if not slots:
        raise ValueError("At least one time slot is required.")
    if peak_penalty_weight < 0.0 or carbon_penalty_weight < 0.0:
        raise ValueError("Penalty weights must be non-negative.")

    scheduled: list[ScheduledWorkload] = []
    all_required = True

    for workload in sorted(
        workloads,
        key=lambda item: (
            item.deadline_slot_index,
            item.workload_type != "irrigation_model",
        ),
    ):
        eligible_indices = range(min(workload.deadline_slot_index + 1, len(slots)))
        candidate_indices = list(eligible_indices)

        if not candidate_indices:
            if workload.required:
                all_required = False
            continue

        best_index = min(
            candidate_indices,
            key=lambda index: _workload_slot_score(
                workload,
                slots[index],
                peak_penalty_weight,
                carbon_penalty_weight,
                deadline_bonus_weight,
            ),
        )
        slot = slots[best_index]
        useful_soil_heat = (
            workload.energy_kwh
            * workload.recoverable_waste_heat_fraction
            * slot.soil_warming_benefit_per_kwh
            if workload.workload_type == "soil_warming"
            else 0.0
        )
        scheduled.append(
            ScheduledWorkload(
                workload_id=workload.workload_id,
                workload_type=workload.workload_type,
                slot_label=slot.label,
                energy_kwh=workload.energy_kwh,
                cost_usd=workload.energy_kwh * slot.energy_price_usd_per_kwh,
                carbon_kgco2e=(
                    workload.energy_kwh * slot.grid_carbon_kgco2e_per_kwh
                ),
                grid_peak_score=(
                    workload.energy_kwh * slot.grid_peak_weight
                ),
                useful_soil_heat_benefit=useful_soil_heat,
            )
        )

    irrigation_options = [
        (index, slot)
        for index, slot in enumerate(slots)
        if slot.irrigation_allowed and slot.irrigation_efficiency > 0.0
    ]

    irrigation_slot_label: str | None = None
    applied_water = 0.0
    delivered_water = 0.0
    if irrigation_options and irrigation.daily_water_budget_m3 > 0.0:
        _, best_irrigation_slot = max(
            irrigation_options,
            key=lambda item: (
                item[1].irrigation_efficiency
                * item[1].canopy_stress_reduction_per_m3
            ),
        )
        applied_water = min(
            irrigation.daily_water_budget_m3,
            irrigation.required_root_zone_water_m3
            / best_irrigation_slot.irrigation_efficiency,
        )
        delivered_water = applied_water * best_irrigation_slot.irrigation_efficiency
        irrigation_slot_label = best_irrigation_slot.label

    return EnergyWaterSchedule(
        scheduled_workloads=tuple(scheduled),
        irrigation_slot_label=irrigation_slot_label,
        applied_water_m3=applied_water,
        delivered_root_zone_water_m3=delivered_water,
        total_energy_kwh=sum(item.energy_kwh for item in scheduled),
        total_cost_usd=sum(item.cost_usd for item in scheduled),
        total_carbon_kgco2e=sum(item.carbon_kgco2e for item in scheduled),
        total_peak_score=sum(item.grid_peak_score for item in scheduled),
        total_soil_heat_benefit=sum(
            item.useful_soil_heat_benefit for item in scheduled
        ),
        all_required_workloads_scheduled=all_required,
    )


@dataclass(frozen=True)
class BuoyantPlumeInputs:
    """
    Thermal plume screening inputs above a hot Phoenix surface.

    surface_temperature_c and air_temperature_c define excess temperature.
    plume_velocity_reference_m_per_s must come from sonic anemometry, validated
    CFD, or an accepted buoyant-plume relation; 65°C surface temperature alone
    cannot uniquely determine an updraft speed.

    The decay exponent supports a transparent fitted profile:

      v_plume(z) = v_ref * [(z + z0)/z_ref]^(-n)
    """

    surface_temperature_c: float
    air_temperature_c: float
    plume_velocity_reference_m_per_s: float
    reference_height_m: float
    roughness_length_m: float
    plume_decay_exponent: float
    measurement_height_m: float
    air_dynamic_viscosity_pa_s: float = AIR_DYNAMIC_VISCOSITY_PA_S
    air_density_kg_per_m3: float = AIR_DENSITY_KG_PER_M3
    water_density_kg_per_m3: float = WATER_DENSITY_KG_PER_M3

    def __post_init__(self) -> None:
        _positive(
            "plume_velocity_reference_m_per_s",
            self.plume_velocity_reference_m_per_s,
        )
        _positive("reference_height_m", self.reference_height_m)
        _nonnegative("roughness_length_m", self.roughness_length_m)
        _nonnegative("plume_decay_exponent", self.plume_decay_exponent)
        _nonnegative("measurement_height_m", self.measurement_height_m)
        _positive("air_dynamic_viscosity_pa_s", self.air_dynamic_viscosity_pa_s)
        _positive("air_density_kg_per_m3", self.air_density_kg_per_m3)
        _positive("water_density_kg_per_m3", self.water_density_kg_per_m3)
        if self.surface_temperature_c <= self.air_temperature_c:
            raise ValueError(
                "surface_temperature_c must exceed air_temperature_c for a buoyant plume."
            )


@dataclass(frozen=True)
class BuoyantSettlingResult:
    plume_updraft_m_per_s: float
    droplet_diameter_equilibrium_um: float
    stokes_velocity_at_equilibrium_m_per_s: float
    net_settling_velocity_m_per_s: float
    stokes_regime_warning: bool


def plume_updraft_velocity(
    height_m: float,
    inputs: BuoyantPlumeInputs,
) -> float:
    _nonnegative("height_m", height_m)
    numerator = height_m + inputs.roughness_length_m
    denominator = inputs.reference_height_m + inputs.roughness_length_m
    return inputs.plume_velocity_reference_m_per_s * (
        numerator / denominator
    ) ** (-inputs.plume_decay_exponent)


def stokes_terminal_velocity_m_per_s(
    droplet_diameter_m: float,
    air_dynamic_viscosity_pa_s: float = AIR_DYNAMIC_VISCOSITY_PA_S,
    air_density_kg_per_m3: float = AIR_DENSITY_KG_PER_M3,
    droplet_density_kg_per_m3: float = WATER_DENSITY_KG_PER_M3,
) -> float:
    """
    Stokes settling velocity, valid only at low droplet Reynolds number:

      v_Stokes = (rho_w - rho_air) g d^2 / (18 mu_air)
    """
    _positive("droplet_diameter_m", droplet_diameter_m)
    _positive("air_dynamic_viscosity_pa_s", air_dynamic_viscosity_pa_s)
    _positive("air_density_kg_per_m3", air_density_kg_per_m3)
    _positive("droplet_density_kg_per_m3", droplet_density_kg_per_m3)

    return (
        (droplet_density_kg_per_m3 - air_density_kg_per_m3)
        * GRAVITY_M_PER_S2
        * droplet_diameter_m**2
        / (18.0 * air_dynamic_viscosity_pa_s)
    )


def droplet_diameter_at_plume_equilibrium(
    inputs: BuoyantPlumeInputs,
) -> BuoyantSettlingResult:
    """
    Solve v_Stokes = v_plume(z):

      d_eq = sqrt(18 mu_air v_plume /
                  [(rho_w-rho_air) g])

    The result identifies the screening diameter at which gravitational settling
    and vertical thermal updraft balance at the stated height.
    """
    updraft = plume_updraft_velocity(inputs.measurement_height_m, inputs)
    diameter_m = sqrt(
        18.0
        * inputs.air_dynamic_viscosity_pa_s
        * updraft
        / (
            (inputs.water_density_kg_per_m3 - inputs.air_density_kg_per_m3)
            * GRAVITY_M_PER_S2
        )
    )
    stokes_velocity = stokes_terminal_velocity_m_per_s(
        droplet_diameter_m=diameter_m,
        air_dynamic_viscosity_pa_s=inputs.air_dynamic_viscosity_pa_s,
        air_density_kg_per_m3=inputs.air_density_kg_per_m3,
        droplet_density_kg_per_m3=inputs.water_density_kg_per_m3,
    )
    droplet_reynolds = (
        inputs.air_density_kg_per_m3
        * stokes_velocity
        * diameter_m
        / inputs.air_dynamic_viscosity_pa_s
    )

    return BuoyantSettlingResult(
        plume_updraft_m_per_s=updraft,
        droplet_diameter_equilibrium_um=diameter_m * 1_000_000.0,
        stokes_velocity_at_equilibrium_m_per_s=stokes_velocity,
        net_settling_velocity_m_per_s=stokes_velocity - updraft,
        stokes_regime_warning=droplet_reynolds >= 1.0,
    )


@dataclass(frozen=True)
class AnnualLifecycleRecord:
    """
    One-year signed carbon record in kgCO2e.

    Positive values:
      - embodied or replacement carbon,
      - operational electricity carbon,
      - water-treatment/delivery carbon,
      - maintenance and end-of-life carbon.

    Positive sequestration and avoided-emissions fields represent climate
    benefits. The net annual carbon outcome is burdens minus benefits.
    """

    embodied_kgco2e: float
    operations_kgco2e: float
    water_kgco2e: float
    maintenance_kgco2e: float
    end_of_life_kgco2e: float
    sequestration_kgco2e: float
    avoided_cooling_emissions_kgco2e: float

    def __post_init__(self) -> None:
        for name, value in (
            ("embodied_kgco2e", self.embodied_kgco2e),
            ("operations_kgco2e", self.operations_kgco2e),
            ("water_kgco2e", self.water_kgco2e),
            ("maintenance_kgco2e", self.maintenance_kgco2e),
            ("end_of_life_kgco2e", self.end_of_life_kgco2e),
            ("sequestration_kgco2e", self.sequestration_kgco2e),
            (
                "avoided_cooling_emissions_kgco2e",
                self.avoided_cooling_emissions_kgco2e,
            ),
        ):
            _nonnegative(name, value)

    @property
    def burdens_kgco2e(self) -> float:
        return (
            self.embodied_kgco2e
            + self.operations_kgco2e
            + self.water_kgco2e
            + self.maintenance_kgco2e
            + self.end_of_life_kgco2e
        )

    @property
    def benefits_kgco2e(self) -> float:
        return self.sequestration_kgco2e + self.avoided_cooling_emissions_kgco2e

    @property
    def net_carbon_kgco2e(self) -> float:
        return self.burdens_kgco2e - self.benefits_kgco2e


@dataclass(frozen=True)
class LifecycleComparisonResult:
    analysis_years: int
    misting_cumulative_net_kgco2e: tuple[float, ...]
    tree_cumulative_net_kgco2e: tuple[float, ...]
    misting_cumulative_benefit_kgco2e: tuple[float, ...]
    tree_cumulative_sequestration_kgco2e: tuple[float, ...]
    tree_sequestration_exceeds_misting_avoided_benefit_year: int | None
    tree_net_outperforms_misting_year: int | None


def compare_misting_and_tree_lifecycle(
    misting_records: Sequence[AnnualLifecycleRecord],
    tree_records: Sequence[AnnualLifecycleRecord],
) -> LifecycleComparisonResult:
    """
    Compare systems over an aligned analysis horizon.

    For a 15-year misting system versus a 30-year canopy, misting records must
    include replacement or explicit zero-operation entries for years 16–30.
    This prevents a service-life mismatch from being hidden in the analysis.
    """
    if not misting_records or not tree_records:
        raise ValueError("Both lifecycle record series must be non-empty.")
    if len(misting_records) != len(tree_records):
        raise ValueError("Lifecycle series must have the same analysis length.")

    misting_net: list[float] = []
    tree_net: list[float] = []
    misting_benefit: list[float] = []
    tree_sequestration: list[float] = []

    running_misting_net = 0.0
    running_tree_net = 0.0
    running_misting_benefit = 0.0
    running_tree_sequestration = 0.0
    sequestration_crossover: int | None = None
    net_crossover: int | None = None

    for index, (misting, tree) in enumerate(
        zip(misting_records, tree_records),
        start=1,
    ):
        running_misting_net += misting.net_carbon_kgco2e
        running_tree_net += tree.net_carbon_kgco2e
        running_misting_benefit += misting.avoided_cooling_emissions_kgco2e
        running_tree_sequestration += tree.sequestration_kgco2e

        misting_net.append(running_misting_net)
        tree_net.append(running_tree_net)
        misting_benefit.append(running_misting_benefit)
        tree_sequestration.append(running_tree_sequestration)

        if (
            sequestration_crossover is None
            and running_tree_sequestration > running_misting_benefit
        ):
            sequestration_crossover = index

        if net_crossover is None and running_tree_net < running_misting_net:
            net_crossover = index

    return LifecycleComparisonResult(
        analysis_years=len(misting_records),
        misting_cumulative_net_kgco2e=tuple(misting_net),
        tree_cumulative_net_kgco2e=tuple(tree_net),
        misting_cumulative_benefit_kgco2e=tuple(misting_benefit),
        tree_cumulative_sequestration_kgco2e=tuple(tree_sequestration),
        tree_sequestration_exceeds_misting_avoided_benefit_year=sequestration_crossover,
        tree_net_outperforms_misting_year=net_crossover,
    )
