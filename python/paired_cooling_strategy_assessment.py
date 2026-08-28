from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from statistics import mean, median
from typing import Iterable, Sequence


SECONDS_PER_HOUR = 3_600.0
LITRES_PER_CUBIC_METRE = 1_000.0


def _finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class MatchedFieldObservation:
    """
    A synchronized paired-site observation.

    Each record compares one intervention site and one matched control during
    the same observation interval. This differential structure removes much of
    the shared solar, synoptic, and seasonal signal before strategy comparison.

    All quantities are site-aggregate physical measurements. No individual
    movement, identity, health, biometric, or behavioral data is used.
    """

    strategy_name: str
    site_pair_name: str
    observed_at_utc: str
    interval_minutes: float

    intervention_wbgt_c: float
    control_wbgt_c: float

    intervention_air_temperature_c: float
    control_air_temperature_c: float

    intervention_relative_humidity_percent: float
    control_relative_humidity_percent: float

    intervention_dew_point_c: float
    control_dew_point_c: float

    intervention_mean_radiant_temperature_c: float
    control_mean_radiant_temperature_c: float

    intervention_surface_temperature_c: float
    control_surface_temperature_c: float

    intervention_wind_speed_m_per_s: float
    control_wind_speed_m_per_s: float

    intervention_solar_radiation_w_per_m2: float
    control_solar_radiation_w_per_m2: float

    intervention_water_l: float
    intervention_electricity_kwh: float
    intervention_lifecycle_kgco2e: float

    availability_fraction: float
    accessible_service_fraction: float
    vulnerability_weight: float
    data_quality_factor: float
    aerosol_eligibility_state: str
    humidity_corridor_satisfied: bool
    treatment_status: str

    def __post_init__(self) -> None:
        if not self.strategy_name.strip():
            raise ValueError("strategy_name must not be empty.")
        if not self.site_pair_name.strip():
            raise ValueError("site_pair_name must not be empty.")
        if not self.observed_at_utc.strip():
            raise ValueError("observed_at_utc must not be empty.")

        _nonnegative("interval_minutes", self.interval_minutes)
        if self.interval_minutes <= 0.0:
            raise ValueError("interval_minutes must be greater than zero.")

        for name, value in (
            ("intervention_wbgt_c", self.intervention_wbgt_c),
            ("control_wbgt_c", self.control_wbgt_c),
            ("intervention_air_temperature_c", self.intervention_air_temperature_c),
            ("control_air_temperature_c", self.control_air_temperature_c),
            (
                "intervention_relative_humidity_percent",
                self.intervention_relative_humidity_percent,
            ),
            (
                "control_relative_humidity_percent",
                self.control_relative_humidity_percent,
            ),
            ("intervention_dew_point_c", self.intervention_dew_point_c),
            ("control_dew_point_c", self.control_dew_point_c),
            (
                "intervention_mean_radiant_temperature_c",
                self.intervention_mean_radiant_temperature_c,
            ),
            (
                "control_mean_radiant_temperature_c",
                self.control_mean_radiant_temperature_c,
            ),
            (
                "intervention_surface_temperature_c",
                self.intervention_surface_temperature_c,
            ),
            (
                "control_surface_temperature_c",
                self.control_surface_temperature_c,
            ),
            (
                "intervention_wind_speed_m_per_s",
                self.intervention_wind_speed_m_per_s,
            ),
            ("control_wind_speed_m_per_s", self.control_wind_speed_m_per_s),
            (
                "intervention_solar_radiation_w_per_m2",
                self.intervention_solar_radiation_w_per_m2,
            ),
            (
                "control_solar_radiation_w_per_m2",
                self.control_solar_radiation_w_per_m2,
            ),
            ("intervention_water_l", self.intervention_water_l),
            ("intervention_electricity_kwh", self.intervention_electricity_kwh),
            (
                "intervention_lifecycle_kgco2e",
                self.intervention_lifecycle_kgco2e,
            ),
            ("vulnerability_weight", self.vulnerability_weight),
        ):
            _finite(name, value)

        for name, value in (
            (
                "intervention_relative_humidity_percent",
                self.intervention_relative_humidity_percent,
            ),
            (
                "control_relative_humidity_percent",
                self.control_relative_humidity_percent,
            ),
        ):
            if value < 0.0 or value > 100.0:
                raise ValueError(f"{name} must be within [0, 100].")

        for name, value in (
            ("intervention_wind_speed_m_per_s", self.intervention_wind_speed_m_per_s),
            ("control_wind_speed_m_per_s", self.control_wind_speed_m_per_s),
            (
                "intervention_solar_radiation_w_per_m2",
                self.intervention_solar_radiation_w_per_m2,
            ),
            (
                "control_solar_radiation_w_per_m2",
                self.control_solar_radiation_w_per_m2,
            ),
            ("intervention_water_l", self.intervention_water_l),
            ("intervention_electricity_kwh", self.intervention_electricity_kwh),
            (
                "intervention_lifecycle_kgco2e",
                self.intervention_lifecycle_kgco2e,
            ),
            ("vulnerability_weight", self.vulnerability_weight),
        ):
            _nonnegative(name, value)

        for name, value in (
            ("availability_fraction", self.availability_fraction),
            (
                "accessible_service_fraction",
                self.accessible_service_fraction,
            ),
            ("data_quality_factor", self.data_quality_factor),
        ):
            _unit_interval(name, value)

        if self.aerosol_eligibility_state not in {
            "not_applicable",
            "low",
            "elevated",
            "hold_for_review",
            "halted",
        }:
            raise ValueError("aerosol_eligibility_state is not recognized.")

        if not self.treatment_status.strip():
            raise ValueError("treatment_status must not be empty.")


@dataclass(frozen=True)
class ResourceWeights:
    """
    Conversion weights for a transparent multi-resource denominator.

    These weights must be approved through a documented public and technical
    governance process. They retain water, energy, and lifecycle burden as
    explicit separate quantities while allowing a declared normalized ranking.

    water_weight_per_l:
        Water opportunity-cost weight per litre.

    electricity_weight_per_kwh:
        Resource burden weight per kilowatt-hour.

    lifecycle_carbon_weight_per_kgco2e:
        Resource burden weight per kgCO2e of allocated lifecycle emissions.
    """

    water_weight_per_l: float
    electricity_weight_per_kwh: float
    lifecycle_carbon_weight_per_kgco2e: float

    def __post_init__(self) -> None:
        _nonnegative("water_weight_per_l", self.water_weight_per_l)
        _nonnegative(
            "electricity_weight_per_kwh",
            self.electricity_weight_per_kwh,
        )
        _nonnegative(
            "lifecycle_carbon_weight_per_kgco2e",
            self.lifecycle_carbon_weight_per_kgco2e,
        )


@dataclass(frozen=True)
class PairedStrategyRecord:
    strategy_name: str
    site_pair_name: str
    observed_at_utc: str
    wbgt_reduction_c: float
    air_temperature_reduction_c: float
    mean_radiant_temperature_reduction_c: float
    surface_temperature_reduction_c: float
    relative_humidity_change_percentage_points: float
    delivered_benefit_c_minutes: float
    resource_burden: float
    resource_accountability_score: float
    approved_for_comparison: bool
    exclusion_reason: str | None


@dataclass(frozen=True)
class CoolingStrategySummary:
    strategy_name: str
    paired_observation_count: int
    approved_observation_count: int
    mean_wbgt_reduction_c: float
    median_wbgt_reduction_c: float
    mean_air_temperature_reduction_c: float
    mean_mean_radiant_temperature_reduction_c: float
    mean_surface_temperature_reduction_c: float
    mean_relative_humidity_change_percentage_points: float
    cumulative_delivered_benefit_c_minutes: float
    total_water_l: float
    total_electricity_kwh: float
    allocated_lifecycle_kgco2e: float
    total_resource_burden: float
    integrated_accountability_score: float
    mean_availability_fraction: float
    mean_accessible_service_fraction: float
    mean_data_quality_factor: float
    recommended_use_case: str


@dataclass(frozen=True)
class PortfolioRecommendation:
    ranked_strategies: tuple[CoolingStrategySummary, ...]
    recommended_portfolio: tuple[str, ...]
    evidence_status: str
    rationale: str


def _approved_for_comparison(
    observation: MatchedFieldObservation,
) -> tuple[bool, str | None]:
    """
    Water-based pathways remain outside comparative ranking when a safety
    corridor is not satisfied. Passive strategies use `not_applicable` for
    aerosol eligibility and are not penalized by a water-to-air safety state.
    """
    water_based = observation.aerosol_eligibility_state != "not_applicable"

    if water_based and observation.aerosol_eligibility_state in {
        "hold_for_review",
        "halted",
    }:
        return False, "aerosol_safety_envelope_not_satisfied"

    if water_based and not observation.humidity_corridor_satisfied:
        return False, "humidity_corridor_not_satisfied"

    if water_based and observation.treatment_status not in {
        "verified_operational",
        "verified_reference",
    }:
        return False, "treatment_status_not_verified"

    if observation.data_quality_factor < 0.75:
        return False, "measurement_quality_below_comparison_threshold"

    return True, None


def paired_strategy_record(
    observation: MatchedFieldObservation,
    weights: ResourceWeights,
) -> PairedStrategyRecord:
    """
    Compute the matched-pair treatment effect and equity-weighted benefit.

    Paired physical effects:

      DeltaWBGT = WBGT_control - WBGT_intervention
      DeltaT_air = T_air,control - T_air,intervention
      DeltaMRT = MRT_control - MRT_intervention
      DeltaT_surface = T_surface,control - T_surface,intervention

    Delivered equity-weighted benefit:

      B_s(t) =
        DeltaWBGT_s(t)
        * A_operational_s(t)
        * A_accessible_s(t)
        * V(t)
        * Delta_t

    Resource denominator:

      R_s(t) =
        w_water W_s(t)
        + w_electric E_s(t)
        + w_carbon C_lifecycle,s(t)

    Accountability score:

      E_s =
        sum_t B_s(t) / sum_t R_s(t)

    The physical and resource terms remain available individually; the
    normalized score never replaces raw public accounting.
    """
    approved, exclusion = _approved_for_comparison(observation)

    wbgt_reduction = observation.control_wbgt_c - observation.intervention_wbgt_c
    air_reduction = (
        observation.control_air_temperature_c
        - observation.intervention_air_temperature_c
    )
    mrt_reduction = (
        observation.control_mean_radiant_temperature_c
        - observation.intervention_mean_radiant_temperature_c
    )
    surface_reduction = (
        observation.control_surface_temperature_c
        - observation.intervention_surface_temperature_c
    )
    humidity_change = (
        observation.intervention_relative_humidity_percent
        - observation.control_relative_humidity_percent
    )

    delivered_benefit = (
        max(0.0, wbgt_reduction)
        * observation.availability_fraction
        * observation.accessible_service_fraction
        * observation.vulnerability_weight
        * observation.interval_minutes
        * observation.data_quality_factor
    )

    resource_burden = (
        weights.water_weight_per_l * observation.intervention_water_l
        + weights.electricity_weight_per_kwh
        * observation.intervention_electricity_kwh
        + weights.lifecycle_carbon_weight_per_kgco2e
        * observation.intervention_lifecycle_kgco2e
    )
    accountability = (
        delivered_benefit / resource_burden
        if resource_burden > 0.0 and approved
        else 0.0
    )

    return PairedStrategyRecord(
        strategy_name=observation.strategy_name,
        site_pair_name=observation.site_pair_name,
        observed_at_utc=observation.observed_at_utc,
        wbgt_reduction_c=wbgt_reduction,
        air_temperature_reduction_c=air_reduction,
        mean_radiant_temperature_reduction_c=mrt_reduction,
        surface_temperature_reduction_c=surface_reduction,
        relative_humidity_change_percentage_points=humidity_change,
        delivered_benefit_c_minutes=delivered_benefit,
        resource_burden=resource_burden,
        resource_accountability_score=accountability,
        approved_for_comparison=approved,
        exclusion_reason=exclusion,
    )


def summarize_cooling_strategies(
    observations: Sequence[MatchedFieldObservation],
    weights: ResourceWeights,
) -> tuple[CoolingStrategySummary, ...]:
    """
    Build per-strategy summaries while retaining exclusions from causal ranking.

    Excluded water-based records are still counted in the observation total but
    cannot raise performance or accountability rankings. This preserves safety
    evidence without concealing measurement outcomes.
    """
    if not observations:
        raise ValueError("At least one matched field observation is required.")

    paired_records = [
        paired_strategy_record(observation, weights)
        for observation in observations
    ]
    source_by_record = {
        (
            observation.strategy_name,
            observation.site_pair_name,
            observation.observed_at_utc,
        ): observation
        for observation in observations
    }

    grouped: dict[str, list[PairedStrategyRecord]] = {}
    for record in paired_records:
        grouped.setdefault(record.strategy_name, []).append(record)

    summaries: list[CoolingStrategySummary] = []
    for strategy_name, records in grouped.items():
        approved_records = [
            record for record in records if record.approved_for_comparison
        ]
        source_records = [
            source_by_record[
                (
                    record.strategy_name,
                    record.site_pair_name,
                    record.observed_at_utc,
                )
            ]
            for record in records
        ]
        approved_sources = [
            source_by_record[
                (
                    record.strategy_name,
                    record.site_pair_name,
                    record.observed_at_utc,
                )
            ]
            for record in approved_records
        ]

        evaluation_records = approved_records if approved_records else records
        score_numerator = sum(
            record.delivered_benefit_c_minutes
            for record in approved_records
        )
        score_denominator = sum(
            record.resource_burden
            for record in approved_records
        )

        summaries.append(
            CoolingStrategySummary(
                strategy_name=strategy_name,
                paired_observation_count=len(records),
                approved_observation_count=len(approved_records),
                mean_wbgt_reduction_c=mean(
                    record.wbgt_reduction_c for record in evaluation_records
                ),
                median_wbgt_reduction_c=median(
                    record.wbgt_reduction_c for record in evaluation_records
                ),
                mean_air_temperature_reduction_c=mean(
                    record.air_temperature_reduction_c
                    for record in evaluation_records
                ),
                mean_mean_radiant_temperature_reduction_c=mean(
                    record.mean_radiant_temperature_reduction_c
                    for record in evaluation_records
                ),
                mean_surface_temperature_reduction_c=mean(
                    record.surface_temperature_reduction_c
                    for record in evaluation_records
                ),
                mean_relative_humidity_change_percentage_points=mean(
                    record.relative_humidity_change_percentage_points
                    for record in evaluation_records
                ),
                cumulative_delivered_benefit_c_minutes=score_numerator,
                total_water_l=sum(
                    item.intervention_water_l for item in source_records
                ),
                total_electricity_kwh=sum(
                    item.intervention_electricity_kwh for item in source_records
                ),
                allocated_lifecycle_kgco2e=sum(
                    item.intervention_lifecycle_kgco2e for item in source_records
                ),
                total_resource_burden=score_denominator,
                integrated_accountability_score=(
                    score_numerator / score_denominator
                    if score_denominator > 0.0
                    else 0.0
                ),
                mean_availability_fraction=mean(
                    item.availability_fraction
                    for item in approved_sources or source_records
                ),
                mean_accessible_service_fraction=mean(
                    item.accessible_service_fraction
                    for item in approved_sources or source_records
                ),
                mean_data_quality_factor=mean(
                    item.data_quality_factor
                    for item in approved_sources or source_records
                ),
                recommended_use_case=_recommended_use_case(
                    strategy_name,
                    approved_records,
                    source_records,
                ),
            )
        )

    return tuple(
        sorted(
            summaries,
            key=lambda item: (
                item.approved_observation_count > 0,
                item.integrated_accountability_score,
                item.cumulative_delivered_benefit_c_minutes,
                item.mean_accessible_service_fraction,
            ),
            reverse=True,
        )
    )


def _recommended_use_case(
    strategy_name: str,
    approved_records: Sequence[PairedStrategyRecord],
    source_records: Sequence[MatchedFieldObservation],
) -> str:
    """
    Produce a non-prescriptive evidence description suitable for a public
    decision memorandum. The final use case remains conditional on matched
    measurements, water safety, accessibility, and local governance.
    """
    normalized_name = strategy_name.lower()
    water_total = sum(item.intervention_water_l for item in source_records)
    mean_humidity_change = mean(
        item.intervention_relative_humidity_percent
        - item.control_relative_humidity_percent
        for item in source_records
    )

    if "shade" in normalized_name:
        return (
            "Accessible pedestrian corridors, transit waiting areas, outdoor "
            "rest zones, and locations requiring immediate zero-operational-water "
            "radiant-load reduction."
        )
    if "tree" in normalized_name or "canopy" in normalized_name:
        return (
            "Long-lived public routes and restoration areas with adequate root "
            "volume, establishment-water stewardship, and species-appropriate "
            "maintenance capacity."
        )
    if "pavement" in normalized_name:
        return (
            "Street and hardscape renewal projects where measured radiant-comfort, "
            "glare, durability, and nighttime performance remain acceptable."
        )
    if water_total > 0.0:
        if not approved_records:
            return (
                "Evidence-collection only; current safety, humidity, treatment, "
                "or data-quality conditions do not support comparative deployment "
                "ranking."
            )
        if mean_humidity_change > 0.0:
            return (
                "Contained or tightly controlled settings where verified cooling "
                "benefit remains within aerosol, water-quality, and humidity "
                "corridors and no accessible receptor burden is created."
            )
        return (
            "Verified controlled settings with monitored water accounting, "
            "treatment evidence, and accessible benefit."
        )
    return (
        "Use according to matched-site evidence, accessible coverage, lifecycle "
        "resource burden, and local maintenance capacity."
    )


def recommend_cooling_portfolio(
    summaries: Sequence[CoolingStrategySummary],
    minimum_approved_observations: int = 12,
    minimum_accessible_service_fraction: float = 0.70,
) -> PortfolioRecommendation:
    """
    Recommend a portfolio rather than a forced winner-take-all intervention.

    A strategy is portfolio-eligible when:
      - sufficient matched observations have passed its safety/data gates;
      - its accessible service fraction meets the declared public-service floor;
      - it produces non-negative delivered benefit under measured conditions.

    Ranking remains based on the accountable benefit score, while the result
    retains a diversified portfolio whenever multiple strategies satisfy the
    evidence threshold.
    """
    if not summaries:
        raise ValueError("At least one cooling strategy summary is required.")
    if minimum_approved_observations < 1:
        raise ValueError("minimum_approved_observations must be at least one.")
    _unit_interval(
        "minimum_accessible_service_fraction",
        minimum_accessible_service_fraction,
    )

    eligible = [
        summary
        for summary in summaries
        if summary.approved_observation_count >= minimum_approved_observations
        and summary.mean_accessible_service_fraction
        >= minimum_accessible_service_fraction
        and summary.cumulative_delivered_benefit_c_minutes > 0.0
    ]

    if not eligible:
        return PortfolioRecommendation(
            ranked_strategies=tuple(summaries),
            recommended_portfolio=(),
            evidence_status="insufficient_approved_matched_evidence",
            rationale=(
                "No strategy yet meets the declared matched-observation and "
                "accessible-service thresholds. Continue field evaluation and "
                "publish safety, humidity, treatment, and data-quality findings."
            ),
        )

    top_score = max(item.integrated_accountability_score for item in eligible)
    portfolio = tuple(
        item.strategy_name
        for item in eligible
        if item.integrated_accountability_score >= 0.75 * top_score
    )

    return PortfolioRecommendation(
        ranked_strategies=tuple(summaries),
        recommended_portfolio=portfolio,
        evidence_status="portfolio_candidates_supported_by_matched_evidence",
        rationale=(
            "The recommended portfolio contains strategies whose measured "
            "equity-weighted, accessible cooling benefit is within 75 percent "
            "of the leading accountable-benefit score and that satisfy the "
            "declared observation and accessibility evidence floors."
        ),
    )
