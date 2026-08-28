from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Sequence


def _finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class WaterLedgerInterval:
    extracted_m3: float
    recovered_m3: float
    discharged_m3: float
    evaporated_gross_m3: float
    counterfactual_vapor_m3: float
    storage_change_m3: float
    uncertainty_m3: float

    def __post_init__(self) -> None:
        for name, value in (
            ("extracted_m3", self.extracted_m3),
            ("recovered_m3", self.recovered_m3),
            ("discharged_m3", self.discharged_m3),
            ("evaporated_gross_m3", self.evaporated_gross_m3),
            ("counterfactual_vapor_m3", self.counterfactual_vapor_m3),
            ("uncertainty_m3", self.uncertainty_m3),
        ):
            _finite_nonnegative(name, value)

        if not isfinite(self.storage_change_m3):
            raise ValueError("storage_change_m3 must be finite.")
        if self.counterfactual_vapor_m3 > self.evaporated_gross_m3:
            raise ValueError(
                "counterfactual_vapor_m3 cannot exceed evaporated_gross_m3."
            )

    @property
    def attributable_evaporation_m3(self) -> float:
        return self.evaporated_gross_m3 - self.counterfactual_vapor_m3

    @property
    def mass_balance_residual_m3(self) -> float:
        return (
            self.extracted_m3
            + self.recovered_m3
            - self.discharged_m3
            - self.evaporated_gross_m3
            - self.storage_change_m3
        )

    @property
    def closes_within_uncertainty(self) -> bool:
        return abs(self.mass_balance_residual_m3) <= self.uncertainty_m3


@dataclass(frozen=True)
class SafetyEvidence:
    water_margin: float
    aerosol_margin: float
    humidity_margin: float
    resource_margin: float
    data_quality_margin: float
    hard_safety_failure: bool
    required_evidence_complete: bool

    def __post_init__(self) -> None:
        for name, value in (
            ("water_margin", self.water_margin),
            ("aerosol_margin", self.aerosol_margin),
            ("humidity_margin", self.humidity_margin),
            ("resource_margin", self.resource_margin),
            ("data_quality_margin", self.data_quality_margin),
        ):
            _unit_interval(name, value)

    @property
    def overall_margin(self) -> float:
        return min(
            self.water_margin,
            self.aerosol_margin,
            self.humidity_margin,
            self.resource_margin,
            self.data_quality_margin,
        )

    def eligibility_state(
        self,
        review_threshold: float = 0.50,
        routine_threshold: float = 0.80,
    ) -> str:
        _unit_interval("review_threshold", review_threshold)
        _unit_interval("routine_threshold", routine_threshold)
        if review_threshold > routine_threshold:
            raise ValueError(
                "review_threshold cannot exceed routine_threshold."
            )
        if self.hard_safety_failure:
            return "halted"
        if not self.required_evidence_complete:
            return "hold_for_review"
        if self.overall_margin < review_threshold:
            return "hold_for_review"
        if self.overall_margin < routine_threshold:
            return "elevated"
        return "low"


@dataclass(frozen=True)
class CoolingObservation:
    strategy: str
    control_wbgt_c: float
    strategy_wbgt_c: float
    uptime: float
    public_availability: float
    accessible_route_availability: float
    information_accessibility: float
    vulnerability_weight: float
    attributable_water_m3: float
    energy_kwh: float
    lifecycle_carbon_kgco2e: float
    maintenance_burden: float
    failure_probability: float

    def __post_init__(self) -> None:
        if not self.strategy.strip():
            raise ValueError("strategy must not be empty.")
        if not isfinite(self.control_wbgt_c) or not isfinite(self.strategy_wbgt_c):
            raise ValueError("WBGT values must be finite.")
        for name, value in (
            ("uptime", self.uptime),
            ("public_availability", self.public_availability),
            ("accessible_route_availability", self.accessible_route_availability),
            ("information_accessibility", self.information_accessibility),
            ("vulnerability_weight", self.vulnerability_weight),
            ("attributable_water_m3", self.attributable_water_m3),
            ("energy_kwh", self.energy_kwh),
            ("lifecycle_carbon_kgco2e", self.lifecycle_carbon_kgco2e),
            ("maintenance_burden", self.maintenance_burden),
            ("failure_probability", self.failure_probability),
        ):
            _finite_nonnegative(name, value)

        for name, value in (
            ("uptime", self.uptime),
            ("public_availability", self.public_availability),
            ("accessible_route_availability", self.accessible_route_availability),
            ("information_accessibility", self.information_accessibility),
            ("failure_probability", self.failure_probability),
        ):
            _unit_interval(name, value)

    @property
    def wbgt_reduction_c(self) -> float:
        return self.control_wbgt_c - self.strategy_wbgt_c

    @property
    def accessible_availability(self) -> float:
        return (
            self.uptime
            * self.public_availability
            * self.accessible_route_availability
            * self.information_accessibility
        )

    @property
    def equity_weighted_benefit(self) -> float:
        return max(0.0, self.wbgt_reduction_c) * (
            self.accessible_availability
        ) * self.vulnerability_weight

    def resource_normalized_value(
        self,
        water_weight: float,
        energy_weight: float,
        carbon_weight: float,
        maintenance_weight: float,
    ) -> float:
        for name, value in (
            ("water_weight", water_weight),
            ("energy_weight", energy_weight),
            ("carbon_weight", carbon_weight),
            ("maintenance_weight", maintenance_weight),
        ):
            _finite_nonnegative(name, value)

        denominator = (
            water_weight * self.attributable_water_m3
            + energy_weight * self.energy_kwh
            + carbon_weight * self.lifecycle_carbon_kgco2e
            + maintenance_weight * self.maintenance_burden
        )
        if denominator <= 0.0:
            return 0.0
        return (
            self.equity_weighted_benefit
            * (1.0 - self.failure_probability)
            / denominator
        )


@dataclass(frozen=True)
class CanyonTransportInputs:
    source_strength_per_m_s: float
    along_canyon_speed_m_s: float
    canyon_height_m: float
    exchange_velocity_m_s: float
    settling_velocity_m_s: float
    background_concentration: float

    def __post_init__(self) -> None:
        for name, value in (
            ("source_strength_per_m_s", self.source_strength_per_m_s),
            ("along_canyon_speed_m_s", self.along_canyon_speed_m_s),
            ("canyon_height_m", self.canyon_height_m),
            ("exchange_velocity_m_s", self.exchange_velocity_m_s),
            ("settling_velocity_m_s", self.settling_velocity_m_s),
            ("background_concentration", self.background_concentration),
        ):
            _finite_nonnegative(name, value)

        if self.along_canyon_speed_m_s <= 0.0:
            raise ValueError("along_canyon_speed_m_s must be greater than zero.")
        if self.canyon_height_m <= 0.0:
            raise ValueError("canyon_height_m must be greater than zero.")
        if self.exchange_velocity_m_s + self.settling_velocity_m_s <= 0.0:
            raise ValueError(
                "exchange plus settling velocity must be greater than zero."
            )

    @property
    def e_folding_distance_m(self) -> float:
        return (
            self.along_canyon_speed_m_s
            * self.canyon_height_m
            / (self.exchange_velocity_m_s + self.settling_velocity_m_s)
        )

    def concentration(self, distance_m: float) -> float:
        _finite_nonnegative("distance_m", distance_m)
        source_excess = (
            self.source_strength_per_m_s
            / (self.along_canyon_speed_m_s * self.canyon_height_m)
        )
        return self.background_concentration + source_excess * exp(
            -distance_m / self.e_folding_distance_m
        )


def summarize_strategy_values(
    observations: Sequence[CoolingObservation],
    water_weight: float,
    energy_weight: float,
    carbon_weight: float,
    maintenance_weight: float,
) -> dict[str, float]:
    if not observations:
        raise ValueError("At least one cooling observation is required.")

    totals: dict[str, float] = {}
    counts: dict[str, int] = {}
    for observation in observations:
        totals[observation.strategy] = totals.get(observation.strategy, 0.0) + (
            observation.resource_normalized_value(
                water_weight,
                energy_weight,
                carbon_weight,
                maintenance_weight,
            )
        )
        counts[observation.strategy] = counts.get(observation.strategy, 0) + 1

    return {
        strategy: totals[strategy] / counts[strategy]
        for strategy in totals
    }
