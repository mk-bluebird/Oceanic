from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log
from random import Random
from typing import Mapping, Sequence


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class CorridorDesign:
    """
    Candidate multi-species corridor design.

    width_m:
        Total vegetated width. Each species applies its own effective core-width
        and edge-effect requirements.

    path_resistance_by_species:
        Total accumulated landscape resistance on the selected route for each
        focal species. It should be produced from a calibrated resistance
        surface, not inferred from vegetation cover alone.

    vegetation_quality_by_species:
        Fraction from zero to one describing the design's suitability for the
        species' required vegetation structure, phenology, refuge, forage,
        substrate, and water conditions.

    restoration_cost:
        A transparent cost or resource score for the candidate design. It can
        represent financial, water, land-access, or composite bounded budget
        consumption as declared by the project.
    """

    design_name: str
    position_id: str
    total_width_m: float
    path_resistance_by_species: Mapping[str, float]
    vegetation_quality_by_species: Mapping[str, float]
    restoration_cost: float

    def __post_init__(self) -> None:
        if not self.design_name.strip() or not self.position_id.strip():
            raise ValueError("design_name and position_id must not be empty.")
        _positive("total_width_m", self.total_width_m)
        _nonnegative("restoration_cost", self.restoration_cost)

        for species, resistance in self.path_resistance_by_species.items():
            if not species.strip():
                raise ValueError("Species names must not be empty.")
            _nonnegative("path resistance", resistance)

        for species, quality in self.vegetation_quality_by_species.items():
            if not species.strip():
                raise ValueError("Species names must not be empty.")
            _unit_interval("vegetation quality", quality)


@dataclass(frozen=True)
class SpeciesConnectivityRequirement:
    """
    Species-specific corridor requirements.

    connectivity is evaluated as:

      C_s(d) =
        M_s(d)
        * exp[-R_s(d) / R_scale,s]
        * V_s(d)

    where:
      M_s is width/mobility feasibility,
      R_s is resistance-weighted route cost,
      V_s is vegetation-composition suitability.

    The width feasibility term is:

      M_s(d) =
        min(1, W_core(d) / W_core_required,s)
        * min(1, mobility_range_s / maximum_gap_s)

    This makes a candidate fail visibly when it is too narrow or contains
    movement gaps beyond the focal species' range.
    """

    species_name: str
    weight: float
    minimum_core_width_m: float
    edge_effect_width_m: float
    mobility_range_m: float
    maximum_gap_m: float
    resistance_scale: float
    minimum_connectivity: float
    required_vegetation_quality: float

    def __post_init__(self) -> None:
        if not self.species_name.strip():
            raise ValueError("species_name must not be empty.")
        for name, value in (
            ("weight", self.weight),
            ("minimum_core_width_m", self.minimum_core_width_m),
            ("edge_effect_width_m", self.edge_effect_width_m),
            ("mobility_range_m", self.mobility_range_m),
            ("maximum_gap_m", self.maximum_gap_m),
            ("resistance_scale", self.resistance_scale),
            ("minimum_connectivity", self.minimum_connectivity),
            ("required_vegetation_quality", self.required_vegetation_quality),
        ):
            _nonnegative(name, value)

        _positive("weight", self.weight)
        _positive("minimum_core_width_m", self.minimum_core_width_m)
        _positive("mobility_range_m", self.mobility_range_m)
        _positive("maximum_gap_m", self.maximum_gap_m)
        _positive("resistance_scale", self.resistance_scale)
        _unit_interval("minimum_connectivity", self.minimum_connectivity)
        _unit_interval(
            "required_vegetation_quality",
            self.required_vegetation_quality,
        )


@dataclass(frozen=True)
class CorridorOptimizationResult:
    selected_design_name: str
    selected_position_id: str
    weighted_connectivity: float
    minimum_species_connectivity: float
    connectivity_by_species: dict[str, float]
    meets_all_species_minimums: bool
    total_width_m: float
    restoration_cost: float
    vegetation_composition_guidance: str
    explanation: str


def species_connectivity(
    design: CorridorDesign,
    requirement: SpeciesConnectivityRequirement,
) -> float:
    """
    Calculate a bounded species-specific connectivity score.
    """
    resistance = design.path_resistance_by_species.get(requirement.species_name)
    vegetation_quality = design.vegetation_quality_by_species.get(
        requirement.species_name
    )
    if resistance is None or vegetation_quality is None:
        raise ValueError(
            f"Design {design.design_name} lacks data for {requirement.species_name}."
        )

    effective_core_width = max(
        0.0,
        design.total_width_m - 2.0 * requirement.edge_effect_width_m,
    )
    width_feasibility = min(
        1.0,
        effective_core_width / requirement.minimum_core_width_m,
    )
    mobility_feasibility = min(
        1.0,
        requirement.mobility_range_m / requirement.maximum_gap_m,
    )
    vegetation_feasibility = min(
        1.0,
        vegetation_quality / max(requirement.required_vegetation_quality, 1e-12),
    )
    resistance_feasibility = exp(-resistance / requirement.resistance_scale)

    return (
        width_feasibility
        * mobility_feasibility
        * vegetation_feasibility
        * resistance_feasibility
    )


def optimize_multispecies_corridor(
    designs: Sequence[CorridorDesign],
    requirements: Sequence[SpeciesConnectivityRequirement],
    maximum_restoration_cost: float,
) -> CorridorOptimizationResult:
    """
    Solve a lexicographic maximin-plus-weighted-sum selection.

    Formal formulation:

      maximize z, sum_s w_s C_s(d)

      subject to:
        z <= C_s(d)                 for every species s
        C_s(d) >= C_s,min            for every species s
        cost(d) <= B
        d belongs to candidate designs

    Primary objective: maximize the least-served species connectivity z.
    Secondary objective: maximize weighted aggregate connectivity.
    Tertiary tie-break: minimize restoration cost.

    The solution avoids a weighted average that appears strong while leaving a
    low-mobility or specialist species disconnected.
    """
    _nonnegative("maximum_restoration_cost", maximum_restoration_cost)
    if not designs:
        raise ValueError("At least one corridor design is required.")
    if not requirements:
        raise ValueError("At least one species requirement is required.")

    candidates: list[
        tuple[CorridorDesign, dict[str, float], float, float, bool]
    ] = []

    for design in designs:
        if design.restoration_cost > maximum_restoration_cost:
            continue

        connectivity = {
            requirement.species_name: species_connectivity(design, requirement)
            for requirement in requirements
        }
        minimum = min(connectivity.values())
        weighted = sum(
            requirement.weight * connectivity[requirement.species_name]
            for requirement in requirements
        )
        feasible = all(
            connectivity[requirement.species_name]
            >= requirement.minimum_connectivity
            for requirement in requirements
        )
        candidates.append((design, connectivity, minimum, weighted, feasible))

    if not candidates:
        raise ValueError("No candidate corridor design fits the restoration budget.")

    feasible_candidates = [item for item in candidates if item[4]]
    selection_pool = feasible_candidates if feasible_candidates else candidates
    selected = max(
        selection_pool,
        key=lambda item: (
            item[2],
            item[3],
            -item[0].restoration_cost,
        ),
    )
    design, connectivity, minimum, weighted, feasible = selected

    limiting_species = min(connectivity, key=connectivity.get)
    vegetation_guidance = (
        "Use a layered native vegetation composition that preserves the "
        "lowest-connectivity focal species' required structural habitat, while "
        "retaining flowering, refuge, substrate, and seasonal resources for "
        "the other target species."
    )

    explanation = (
        "The selected design meets every declared species connectivity minimum "
        "and maximizes the least-served species score before optimizing the "
        "weighted multi-species total."
        if feasible
        else (
            "No candidate satisfies every declared species minimum within the "
            "budget. The selected design maximizes the least-served species "
            "connectivity and preserves the unmet requirement for transparent "
            "community and ecological review. The limiting species is "
            f"{limiting_species}."
        )
    )

    return CorridorOptimizationResult(
        selected_design_name=design.design_name,
        selected_position_id=design.position_id,
        weighted_connectivity=weighted,
        minimum_species_connectivity=minimum,
        connectivity_by_species=connectivity,
        meets_all_species_minimums=feasible,
        total_width_m=design.total_width_m,
        restoration_cost=design.restoration_cost,
        vegetation_composition_guidance=vegetation_guidance,
        explanation=explanation,
    )


@dataclass(frozen=True)
class DashboardOperationalSnapshot:
    """
    Environmental and operational metrics intended for exact public reporting.

    These values are system-level aggregates. They must not include exact
    complaint coordinates, staff identifiers, operator schedules, or other
    person-linked records.

    aerosol_risk_level is a categorical, reviewable state:
      low,
      elevated,
      hold_for_review,
      halted.
    """

    observed_at_utc: str
    water_use_rate_l_per_min: float
    treatment_status: str
    aerosol_risk_level: str
    thermal_benefit_wbgt_reduction_c: float
    operational_state: str
    data_quality_factor: float

    def __post_init__(self) -> None:
        if not self.observed_at_utc.strip():
            raise ValueError("observed_at_utc must not be empty.")
        _nonnegative("water_use_rate_l_per_min", self.water_use_rate_l_per_min)
        if not self.treatment_status.strip() or not self.operational_state.strip():
            raise ValueError("Status fields must not be empty.")
        if self.aerosol_risk_level not in {
            "low",
            "elevated",
            "hold_for_review",
            "halted",
        }:
            raise ValueError("aerosol_risk_level is not recognized.")
        _unit_interval("data_quality_factor", self.data_quality_factor)
        if not isfinite(self.thermal_benefit_wbgt_reduction_c):
            raise ValueError("thermal_benefit_wbgt_reduction_c must be finite.")


@dataclass(frozen=True)
class DifferentialPrivacyPolicy:
    """
    Epsilon-DP policy for person-linked dashboard aggregates.

    The exact dashboard operational snapshot is not noised because it contains
    no person-linked data. Differential privacy applies only to bounded,
    aggregate releases derived from individual complaint reports or maintenance
    personnel records.

    epsilon_per_release:
      Privacy loss budget per independently released statistic.

    total_epsilon_budget:
      Maximum cumulative basic-composition budget for a reporting period.

    The default 0.5 per release yields a maximum likelihood ratio e^0.5 of
    about 1.65 for a single pure-DP release. That is materially stronger than
    epsilon 1, whose factor is about 2.72, while generally retaining useful
    city- or district-level aggregate counts after appropriate batching.
    """

    epsilon_per_release: float = 0.5
    total_epsilon_budget: float = 2.0
    minimum_aggregation_count: int = 20

    def __post_init__(self) -> None:
        _positive("epsilon_per_release", self.epsilon_per_release)
        _positive("total_epsilon_budget", self.total_epsilon_budget)
        if self.epsilon_per_release > self.total_epsilon_budget:
            raise ValueError(
                "epsilon_per_release cannot exceed total_epsilon_budget."
            )
        if self.minimum_aggregation_count < 1:
            raise ValueError("minimum_aggregation_count must be at least one.")

    @property
    def maximum_likelihood_ratio(self) -> float:
        return exp(self.epsilon_per_release)


@dataclass(frozen=True)
class DifferentiallyPrivateAggregate:
    metric_name: str
    raw_count: int
    released_count: float | None
    epsilon: float
    sensitivity: float
    suppression_reason: str | None
    privacy_likelihood_ratio_bound: float
    remaining_epsilon_budget: float


def laplace_noise(scale: float, rng: Random) -> float:
    """
    Sample Laplace(0, scale) using inverse-CDF transformation.
    """
    _positive("scale", scale)
    uniform = rng.random() - 0.5
    sign = -1.0 if uniform < 0.0 else 1.0
    return -scale * sign * log(1.0 - 2.0 * abs(uniform))


def release_dp_count(
    metric_name: str,
    raw_count: int,
    contribution_limit: int,
    policy: DifferentialPrivacyPolicy,
    cumulative_epsilon_spent: float,
    seed: int,
) -> DifferentiallyPrivateAggregate:
    """
    Release a bounded count with the Laplace mechanism.

      M(D) = count(D) + Laplace(Delta_f / epsilon)

    With per-person contribution clipping, Delta_f equals contribution_limit.

    Small groups are suppressed before adding noise. This supplements DP with
    a practical anti-singling-out control and avoids presenting noisy values as
    meaningful individual-level oversight data.
    """
    if not metric_name.strip():
        raise ValueError("metric_name must not be empty.")
    if raw_count < 0:
        raise ValueError("raw_count must be non-negative.")
    if contribution_limit < 1:
        raise ValueError("contribution_limit must be at least one.")
    _nonnegative("cumulative_epsilon_spent", cumulative_epsilon_spent)

    next_spend = cumulative_epsilon_spent + policy.epsilon_per_release
    remaining = policy.total_epsilon_budget - next_spend
    if remaining < -1e-12:
        raise ValueError("Differential privacy budget exhausted.")

    if raw_count < policy.minimum_aggregation_count:
        return DifferentiallyPrivateAggregate(
            metric_name=metric_name,
            raw_count=raw_count,
            released_count=None,
            epsilon=policy.epsilon_per_release,
            sensitivity=float(contribution_limit),
            suppression_reason="below_minimum_aggregation_count",
            privacy_likelihood_ratio_bound=policy.maximum_likelihood_ratio,
            remaining_epsilon_budget=max(0.0, remaining),
        )

    rng = Random(seed)
    noise = laplace_noise(
        scale=contribution_limit / policy.epsilon_per_release,
        rng=rng,
    )
    released = max(0.0, raw_count + noise)

    return DifferentiallyPrivateAggregate(
        metric_name=metric_name,
        raw_count=raw_count,
        released_count=released,
        epsilon=policy.epsilon_per_release,
        sensitivity=float(contribution_limit),
        suppression_reason=None,
        privacy_likelihood_ratio_bound=policy.maximum_likelihood_ratio,
        remaining_epsilon_budget=max(0.0, remaining),
    )


@dataclass(frozen=True)
class GovernanceDashboardView:
    """
    Accessible dashboard payload.

    The public view includes:
      - exact system-wide environmental operations,
      - DP-protected people-linked aggregates,
      - data quality and privacy-budget transparency,
      - a human review and grievance state.

    It intentionally excludes direct identifiers, exact complaint coordinates,
    source IPs, biometric signals, and individualized staff activity.
    """

    operational: DashboardOperationalSnapshot
    private_aggregates: tuple[DifferentiallyPrivateAggregate, ...]
    privacy_policy: DifferentialPrivacyPolicy
    grievance_status: str
    review_status: str

    def __post_init__(self) -> None:
        if not self.grievance_status.strip() or not self.review_status.strip():
            raise ValueError("grievance_status and review_status must not be empty.")


def build_governance_dashboard(
    operational: DashboardOperationalSnapshot,
    private_aggregates: Sequence[DifferentiallyPrivateAggregate],
    privacy_policy: DifferentialPrivacyPolicy,
    grievance_status: str,
    review_status: str,
) -> GovernanceDashboardView:
    """
    Build an immutable, accessibility-ready data view for rendering by an
    HTML/TypeScript front end. Rendering can provide text equivalents, high
    contrast, keyboard navigation, downloadable tables, and offline print view.
    """
    return GovernanceDashboardView(
        operational=operational,
        private_aggregates=tuple(private_aggregates),
        privacy_policy=privacy_policy,
        grievance_status=grievance_status,
        review_status=review_status,
    )
