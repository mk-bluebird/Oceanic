from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log
from typing import Iterable, Sequence


WATER_DENSITY_KG_PER_M3 = 1_000.0
MICROMETRES_PER_METRE = 1_000_000.0
DEFAULT_EVAPORATION_FRACTION = 0.90


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


@dataclass(frozen=True)
class DropletEvaporationInputs:
    """
    SI-unit inputs for a single droplet class.

    The transfer relation follows the user's proposed mass-transfer form:

      dm/dt = 4*pi*r*D_v*(rho_sat-rho_infinity)*Sh /
              [1 + (D_v/r)*(1/alpha_m)]

    Values for vapour diffusivity, saturation vapour density, ambient vapour
    density, accommodation coefficient, and turbulence correction must come
    from local meteorological measurements and nozzle/plume calibration.
    """

    diameter_um: float
    vapour_diffusivity_m2_per_s: float
    saturated_vapour_density_kg_per_m3: float
    ambient_vapour_density_kg_per_m3: float
    mass_accommodation_coefficient_m_per_s: float
    molecular_schmidt_number: float
    relative_velocity_m_per_s: float
    nozzle_turbulence_intensity: float
    turbulence_gain: float
    nozzle_to_release_speed_m_per_s: float

    def __post_init__(self) -> None:
        for name, value in (
            ("diameter_um", self.diameter_um),
            ("vapour_diffusivity_m2_per_s", self.vapour_diffusivity_m2_per_s),
            (
                "saturated_vapour_density_kg_per_m3",
                self.saturated_vapour_density_kg_per_m3,
            ),
            ("mass_accommodation_coefficient_m_per_s",
             self.mass_accommodation_coefficient_m_per_s),
            ("molecular_schmidt_number", self.molecular_schmidt_number),
            ("relative_velocity_m_per_s", self.relative_velocity_m_per_s),
            ("nozzle_to_release_speed_m_per_s", self.nozzle_to_release_speed_m_per_s),
        ):
            _positive(name, value)

        for name, value in (
            ("ambient_vapour_density_kg_per_m3", self.ambient_vapour_density_kg_per_m3),
            ("nozzle_turbulence_intensity", self.nozzle_turbulence_intensity),
            ("turbulence_gain", self.turbulence_gain),
        ):
            _nonnegative(name, value)

        if self.ambient_vapour_density_kg_per_m3 >= self.saturated_vapour_density_kg_per_m3:
            raise ValueError(
                "Ambient vapour density must remain below saturation density "
                "for an evaporation-only model."
            )

    @property
    def radius_m(self) -> float:
        return self.diameter_um / (2.0 * MICROMETRES_PER_METRE)


@dataclass(frozen=True)
class DropletEvaporationResult:
    sherwood_number: float
    evaporation_rate_kg_per_s: float
    full_evaporation_time_s: float
    distance_to_full_evaporation_m: float
    required_turbulence_intensity: float | None
    meets_90_percent_target_at_10_m: bool
    receptor_separation_adequate: bool | None
    safety_status: str


def droplet_reynolds_number(inputs: DropletEvaporationInputs) -> float:
    """
    Reynolds number using water-density-free kinematic substitution:

       Re = U*d/D_v*Sc

    because nu = Sc*D_v. This form avoids requiring a separate viscosity input
    when Schmidt number and vapour diffusivity are already part of the model.
    """
    diameter_m = inputs.diameter_um / MICROMETRES_PER_METRE
    return (
        inputs.relative_velocity_m_per_s
        * diameter_m
        * inputs.molecular_schmidt_number
        / inputs.vapour_diffusivity_m2_per_s
    )


def turbulent_sherwood_number(inputs: DropletEvaporationInputs) -> float:
    """
    Ranz-Marshall baseline plus explicit nozzle-turbulence gain:

      Sh_0 = 2 + 0.6 Re^(1/2) Sc^(1/3)
      Sh_T = Sh_0 [1 + gamma I]

    I is turbulence intensity u'_rms / U and gamma is calibration-specific.
    It must be derived from a validated nozzle/plume experiment or CFD model
    checked against physical measurements.
    """
    reynolds = droplet_reynolds_number(inputs)
    baseline = 2.0 + 0.6 * (reynolds ** 0.5) * (inputs.molecular_schmidt_number ** (1.0 / 3.0))
    return baseline * (
        1.0 + inputs.turbulence_gain * inputs.nozzle_turbulence_intensity
    )


def droplet_mass_kg(radius_m: float) -> float:
    _positive("radius_m", radius_m)
    return (4.0 / 3.0) * 3.141592653589793 * (radius_m ** 3) * WATER_DENSITY_KG_PER_M3


def evaporation_rate_kg_per_s(inputs: DropletEvaporationInputs) -> float:
    """
    Compute positive evaporation mass loss rate using the supplied equation.
    """
    radius = inputs.radius_m
    sherwood = turbulent_sherwood_number(inputs)
    density_deficit = (
        inputs.saturated_vapour_density_kg_per_m3
        - inputs.ambient_vapour_density_kg_per_m3
    )
    interface_resistance = (
        1.0
        + (inputs.vapour_diffusivity_m2_per_s / radius)
        * (1.0 / inputs.mass_accommodation_coefficient_m_per_s)
    )

    return (
        4.0
        * 3.141592653589793
        * radius
        * inputs.vapour_diffusivity_m2_per_s
        * density_deficit
        * sherwood
        / interface_resistance
    )


def full_evaporation_time_s(inputs: DropletEvaporationInputs) -> float:
    """
    A constant-rate screening estimate.

    This provides an auditable conservative first pass. Production use should
    use a shrinking-radius integration, a thermal energy balance, solute
    residue behavior, plume entrainment, and measured local humidity.
    """
    return droplet_mass_kg(inputs.radius_m) / evaporation_rate_kg_per_s(inputs)


def distance_to_full_evaporation_m(inputs: DropletEvaporationInputs) -> float:
    return full_evaporation_time_s(inputs) * inputs.nozzle_to_release_speed_m_per_s


def required_turbulence_intensity_for_distance(
    inputs: DropletEvaporationInputs,
    target_distance_m: float = 10.0,
) -> float | None:
    """
    Derive the intensity needed under the linear Sh_T = Sh_0(1+gamma I) model.

    Returns None if the target is already reached at I=0. A target that
    requires I > 1 represents a physically implausible nozzle specification
    under this simplified correlation and must not be treated as deployable.
    """
    _positive("target_distance_m", target_distance_m)
    _positive("turbulence_gain", inputs.turbulence_gain)

    zero_turbulence = DropletEvaporationInputs(
        diameter_um=inputs.diameter_um,
        vapour_diffusivity_m2_per_s=inputs.vapour_diffusivity_m2_per_s,
        saturated_vapour_density_kg_per_m3=inputs.saturated_vapour_density_kg_per_m3,
        ambient_vapour_density_kg_per_m3=inputs.ambient_vapour_density_kg_per_m3,
        mass_accommodation_coefficient_m_per_s=inputs.mass_accommodation_coefficient_m_per_s,
        molecular_schmidt_number=inputs.molecular_schmidt_number,
        relative_velocity_m_per_s=inputs.relative_velocity_m_per_s,
        nozzle_turbulence_intensity=0.0,
        turbulence_gain=inputs.turbulence_gain,
        nozzle_to_release_speed_m_per_s=inputs.nozzle_to_release_speed_m_per_s,
    )

    distance_at_zero = distance_to_full_evaporation_m(zero_turbulence)
    if distance_at_zero <= target_distance_m:
        return None

    required_enhancement = distance_at_zero / target_distance_m
    return (required_enhancement - 1.0) / inputs.turbulence_gain


def assess_droplet_evaporation(
    inputs: DropletEvaporationInputs,
    pedestrian_receptor_distance_m: float | None,
    target_distance_m: float = 10.0,
) -> DropletEvaporationResult:
    """
    Evaluate the 30 µm screening class.

    A public-facing deployment is not authorized by this model. The result
    marks a plume as unsuitable for pedestrian-proximate release whenever
    evaporation distance meets or exceeds the closest receptor separation,
    because partially evaporated droplets and solute residues require
    site-specific exposure assessment.
    """
    if pedestrian_receptor_distance_m is not None:
        _positive("pedestrian_receptor_distance_m", pedestrian_receptor_distance_m)

    sherwood = turbulent_sherwood_number(inputs)
    rate = evaporation_rate_kg_per_s(inputs)
    evaporation_time = full_evaporation_time_s(inputs)
    distance = distance_to_full_evaporation_m(inputs)
    required_intensity = required_turbulence_intensity_for_distance(
        inputs, target_distance_m
    )

    target_met = distance <= target_distance_m
    receptor_adequate = (
        None
        if pedestrian_receptor_distance_m is None
        else distance < pedestrian_receptor_distance_m
    )

    if not target_met:
        status = "hold_for_nozzle_or_containment_design"
    elif receptor_adequate is False:
        status = "hold_for_receptor_separation_or_containment"
    else:
        status = "requires_field_validation_before_public_operation"

    return DropletEvaporationResult(
        sherwood_number=sherwood,
        evaporation_rate_kg_per_s=rate,
        full_evaporation_time_s=evaporation_time,
        distance_to_full_evaporation_m=distance,
        required_turbulence_intensity=required_intensity,
        meets_90_percent_target_at_10_m=target_met,
        receptor_separation_adequate=receptor_adequate,
        safety_status=status,
    )


@dataclass(frozen=True)
class HeatZone:
    """
    Aggregated zone-level planning input only.

    vulnerability_index must be derived from openly documented, non-identifying
    variables. It must not be used to deny heat relief, restrict movement, or
    determine an individual's access to services.
    """

    zone_name: str
    vulnerability_index: float
    predicted_wbgt_reduction_c: float
    node_cost_usd: float
    candidate_nodes: int

    def __post_init__(self) -> None:
        _positive("vulnerability_index", self.vulnerability_index)
        _nonnegative("predicted_wbgt_reduction_c", self.predicted_wbgt_reduction_c)
        _nonnegative("node_cost_usd", self.node_cost_usd)
        if self.candidate_nodes < 0:
            raise ValueError("candidate_nodes must be non-negative.")


@dataclass(frozen=True)
class EquityHeatBenefitResult:
    p_value: float
    normalized_weights: dict[str, float]
    weighted_heat_benefit_c: float
    allocated_nodes: dict[str, int]
    allocation_explanation: str


def normalized_vulnerability_weights(
    zones: Sequence[HeatZone],
    p_value: float,
) -> dict[str, float]:
    """
    For p=0, all zones receive equal positive weight. For p>0:

      w_i = VI_i^p / sum_j VI_j^p

    Direct exponentiation is deliberately visible to support civic review of
    distributive consequences.
    """
    if not zones:
        raise ValueError("At least one heat zone is required.")
    _nonnegative("p_value", p_value)

    if p_value == 0.0:
        equal_weight = 1.0 / len(zones)
        return {zone.zone_name: equal_weight for zone in zones}

    raw = {zone.zone_name: zone.vulnerability_index ** p_value for zone in zones}
    denominator = sum(raw.values())
    return {name: value / denominator for name, value in raw.items()}


def allocate_heat_relief_nodes(
    zones: Sequence[HeatZone],
    total_nodes: int,
    p_value: float,
) -> EquityHeatBenefitResult:
    """
    Allocate scarce nodes using transparent proportional priorities:

      priority_i = w_i * DeltaWBGT_i / node_cost_i

    One allocation pass represents one planning cycle. In operational planning,
    mandatory service floors and accessible community review remain applicable
    regardless of an area's calculated priority.
    """
    if total_nodes < 0:
        raise ValueError("total_nodes must be non-negative.")
    weights = normalized_vulnerability_weights(zones, p_value)
    allocations = {zone.zone_name: 0 for zone in zones}

    for _ in range(total_nodes):
        eligible = [
            zone for zone in zones if allocations[zone.zone_name] < zone.candidate_nodes
        ]
        if not eligible:
            break

        def priority(zone: HeatZone) -> float:
            if zone.node_cost_usd == 0.0:
                return weights[zone.zone_name] * zone.predicted_wbgt_reduction_c
            return (
                weights[zone.zone_name]
                * zone.predicted_wbgt_reduction_c
                / zone.node_cost_usd
            )

        winner = max(eligible, key=priority)
        allocations[winner.zone_name] += 1

    total_benefit = sum(
        weights[zone.zone_name]
        * zone.predicted_wbgt_reduction_c
        * allocations[zone.zone_name]
        for zone in zones
    )

    model = (
        "Equal zone weights; allocation favors the greatest estimated "
        "unweighted WBGT reduction per dollar."
        if p_value == 0.0
        else
        "Vulnerability-weighted allocation; higher vulnerability indices "
        "increase the priority assigned to each unit of predicted WBGT relief."
    )

    return EquityHeatBenefitResult(
        p_value=p_value,
        normalized_weights=weights,
        weighted_heat_benefit_c=total_benefit,
        allocated_nodes=allocations,
        allocation_explanation=model,
    )


@dataclass(frozen=True)
class ChoiceResponse:
    """
    Community-choice-task response.

    Each response compares two named policy alternatives with pre-declared
    p-values. No demographic or individual identity attributes are needed.
    """

    chosen_p_value: float
    response_weight: float = 1.0

    def __post_init__(self) -> None:
        _nonnegative("chosen_p_value", self.chosen_p_value)
        _positive("response_weight", self.response_weight)


def community_prioritized_p_value(
    responses: Iterable[ChoiceResponse],
) -> float:
    """
    Return the weighted modal p-value selected in a structured choice task.

    A production consultation should publish recruitment method, accessible
    participation channels, language access, choice framing, response counts,
    missing-data treatment, and uncertainty intervals alongside the result.
    """
    totals: dict[float, float] = {}
    for response in responses:
        totals[response.chosen_p_value] = (
            totals.get(response.chosen_p_value, 0.0) + response.response_weight
        )
    if not totals:
        raise ValueError("At least one structured-choice response is required.")
    return max(totals, key=totals.get)


@dataclass(frozen=True)
class PulsedFlowSchedule:
    wet_duration_s: float
    dry_duration_s: float
    wall_shear_stress_pa: float
    flow_rate_m3_per_s: float

    def __post_init__(self) -> None:
        _positive("wet_duration_s", self.wet_duration_s)
        _nonnegative("dry_duration_s", self.dry_duration_s)
        _nonnegative("wall_shear_stress_pa", self.wall_shear_stress_pa)
        _nonnegative("flow_rate_m3_per_s", self.flow_rate_m3_per_s)

    @property
    def cycle_duration_s(self) -> float:
        return self.wet_duration_s + self.dry_duration_s

    @property
    def pulse_frequency_hz(self) -> float:
        return 1.0 / self.cycle_duration_s

    @property
    def duty_cycle(self) -> float:
        return self.wet_duration_s / self.cycle_duration_s

    @property
    def water_use_m3_per_s(self) -> float:
        return self.flow_rate_m3_per_s * self.duty_cycle


@dataclass(frozen=True)
class BiofilmParameters:
    mu_max_per_s: float
    substrate_concentration_mg_per_l: float
    half_saturation_constant_mg_per_l: float
    detachment_coefficient_per_pa_s: float
    nutrient_replenishment_gain: float
    desiccation_penalty_per_s: float

    def __post_init__(self) -> None:
        for name, value in (
            ("mu_max_per_s", self.mu_max_per_s),
            ("substrate_concentration_mg_per_l", self.substrate_concentration_mg_per_l),
            ("half_saturation_constant_mg_per_l", self.half_saturation_constant_mg_per_l),
            ("detachment_coefficient_per_pa_s", self.detachment_coefficient_per_pa_s),
            ("nutrient_replenishment_gain", self.nutrient_replenishment_gain),
            ("desiccation_penalty_per_s", self.desiccation_penalty_per_s),
        ):
            _nonnegative(name, value)


@dataclass(frozen=True)
class BiofilmGrowthResult:
    pulse_frequency_hz: float
    duty_cycle: float
    pulse_factor: float
    net_specific_growth_rate_per_s: float
    water_use_m3_per_s: float
    prevention_score: float


def pulsed_flow_factor(
    schedule: PulsedFlowSchedule,
    parameters: BiofilmParameters,
) -> float:
    """
    Dimensionless wet/dry factor:

      f = [duty_cycle * (1 + a*f_pulse)] * exp(-k_dry*t_dry)

    Wet cycles replenish nutrients; dry cycles impose an explicit desiccation
    penalty. The factor is not a claim that drying safely eliminates biofilm:
    it is a calibration target for measured system response.
    """
    replenishment = schedule.duty_cycle * (
        1.0 + parameters.nutrient_replenishment_gain * schedule.pulse_frequency_hz
    )
    desiccation_multiplier = exp(
        -parameters.desiccation_penalty_per_s * schedule.dry_duration_s
    )
    return replenishment * desiccation_multiplier


def evaluate_pulsed_biofilm_growth(
    schedule: PulsedFlowSchedule,
    parameters: BiofilmParameters,
) -> BiofilmGrowthResult:
    """
    Evaluate:

      dB/dt = [mu_max*S/(K_s+S)*f - k_detach*tau_wall] B

    Prevention score is the negative of the net specific growth rate divided by
    water use, with a small positive floor to keep the ratio defined.
    """
    substrate_term = (
        parameters.substrate_concentration_mg_per_l
        / (
            parameters.half_saturation_constant_mg_per_l
            + parameters.substrate_concentration_mg_per_l
        )
        if (
            parameters.half_saturation_constant_mg_per_l
            + parameters.substrate_concentration_mg_per_l
        ) > 0.0
        else 0.0
    )

    factor = pulsed_flow_factor(schedule, parameters)
    growth = parameters.mu_max_per_s * substrate_term * factor
    detachment = parameters.detachment_coefficient_per_pa_s * schedule.wall_shear_stress_pa
    net_rate = growth - detachment
    water_use = schedule.water_use_m3_per_s
    prevention_score = -net_rate / max(water_use, 1e-12)

    return BiofilmGrowthResult(
        pulse_frequency_hz=schedule.pulse_frequency_hz,
        duty_cycle=schedule.duty_cycle,
        pulse_factor=factor,
        net_specific_growth_rate_per_s=net_rate,
        water_use_m3_per_s=water_use,
        prevention_score=prevention_score,
    )


def select_biofilm_prevention_schedule(
    candidates: Sequence[PulsedFlowSchedule],
    parameters: BiofilmParameters,
) -> BiofilmGrowthResult:
    """
    Select the schedule with the strongest modeled prevention score.

    Candidate schedules must comply with hydraulic, water-quality, materials,
    drainage, and maintenance requirements. The resulting choice is a
    testable starting condition for pilot validation, not an automatic
    operational command.
    """
    if not candidates:
        raise ValueError("At least one pulsed-flow schedule is required.")
    results = [evaluate_pulsed_biofilm_growth(schedule, parameters) for schedule in candidates]
    return max(results, key=lambda result: result.prevention_score)
