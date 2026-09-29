from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal


class InputValidationError(ValueError):
    """Raised when urban food-system resilience inputs are invalid."""


def _finite(name: str, value: float) -> float:
    if not isfinite(value):
        raise InputValidationError(f"{name} must be finite")
    return value


def _range(name: str, value: float, minimum: float, maximum: float) -> float:
    _finite(name, value)
    if value < minimum or value > maximum:
        raise InputValidationError(
            f"{name} must be within [{minimum}, {maximum}], got {value}"
        )
    return value


def _clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(value, maximum))


@dataclass(frozen=True)
class UrbanFoodSystemInputs:
    """
    Aggregate service-zone food-system conditions.

    `zone_id` identifies a planning or service zone. No field may contain
    household consumption, benefits eligibility, immigration status, medical
    dietary information, or any person-level record.
    """

    zone_id: str
    regional_supply_days_estimate: float
    distribution_redundancy_score: float
    cold_chain_integrity_score: float
    market_and_pantry_coverage_score: float
    transit_access_to_food_score: float
    local_production_capacity_score: float
    emergency_food_infra_ready_score: float
    perishable_loss_reduction_score: float
    forecast_coverage: float
    evidence_quality: float


@dataclass(frozen=True)
class UrbanFoodResilienceResult:
    food_supply_score: float
    distribution_score: float
    cold_chain_score: float
    access_friction_score: float
    local_capacity_score: float
    food_system_resilience_index: float
    coverage_status: Literal["sufficient", "insufficient"]
    planning_band: Literal[
        "routine_monitoring",
        "prepare_redundancy",
        "priority_infrastructure_review",
        "insufficient_coverage",
    ]
    interpretation: str


def estimate_urban_food_system_resilience(
    inputs: UrbanFoodSystemInputs,
    *,
    minimum_coverage: float = 0.70,
) -> UrbanFoodResilienceResult:
    """
    Estimate aggregate public food-system resilience for a service zone.

    This is a public-infrastructure planning signal. It must not be used to
    score households, evaluate eligibility, restrict benefits, or classify
    any individual's food security.
    """
    if not inputs.zone_id.strip():
        raise InputValidationError("zone_id must not be blank")

    supply = _range(
        "regional_supply_days_estimate",
        inputs.regional_supply_days_estimate,
        0.0,
        365.0,
    ) / 30.0

    redundancy = _range(
        "distribution_redundancy_score",
        inputs.distribution_redundancy_score,
        0.0,
        1.0,
    )
    cold_chain = _range(
        "cold_chain_integrity_score",
        inputs.cold_chain_integrity_score,
        0.0,
        1.0,
    )
    market_coverage = _range(
        "market_and_pantry_coverage_score",
        inputs.market_and_pantry_coverage_score,
        0.0,
        1.0,
    )
    transit_access = _range(
        "transit_access_to_food_score",
        inputs.transit_access_to_food_score,
        0.0,
        1.0,
    )
    local_capacity = _range(
        "local_production_capacity_score",
        inputs.local_production_capacity_score,
        0.0,
        1.0,
    )
    emergency_ready = _range(
        "emergency_food_infra_ready_score",
        inputs.emergency_food_infra_ready_score,
        0.0,
        1.0,
    )
    loss_reduction = _range(
        "perishable_loss_reduction_score",
        inputs.perishable_loss_reduction_score,
        0.0,
        1.0,
    )
    forecast_coverage = _range(
        "forecast_coverage",
        inputs.forecast_coverage,
        0.0,
        1.0,
    )
    evidence = _range(
        "evidence_quality",
        inputs.evidence_quality,
        0.0,
        1.0,
    )
    _range("minimum_coverage", minimum_coverage, 0.0, 1.0)

    food_supply_score = _clamp(supply)
    distribution_score = _clamp(
        0.60 * redundancy + 0.40 * emergency_ready
    )
    cold_chain_score = _clamp(
        0.70 * cold_chain + 0.30 * loss_reduction
    )
    access_friction_score = _clamp(
        0.60 * market_coverage + 0.40 * transit_access
    )
    local_capacity_score = _clamp(local_capacity)

    resilience = _clamp(
        0.25 * food_supply_score
        + 0.20 * distribution_score
        + 0.20 * cold_chain_score
        + 0.20 * access_friction_score
        + 0.15 * local_capacity_score
    )

    coverage_status: Literal["sufficient", "insufficient"] = (
        "sufficient"
        if forecast_coverage * evidence >= minimum_coverage
        else "insufficient"
    )

    if coverage_status == "insufficient":
        band: Literal[
            "routine_monitoring",
            "prepare_redundancy",
            "priority_infrastructure_review",
            "insufficient_coverage",
        ] = "insufficient_coverage"
        interpretation = (
            "Food-system evidence is insufficient for a reliable planning "
            "signal. Do not use this result for resource-allocation, eligibility, "
            "or community ranking decisions."
        )
    elif resilience >= 0.70:
        band = "routine_monitoring"
        interpretation = (
            "Aggregate supply, distribution, cold-chain, access, and local "
            "capacity indicators are comparatively favorable. Maintain routine "
            "monitoring and infrastructure resilience."
        )
    elif resilience >= 0.45:
        band = "prepare_redundancy"
        interpretation = (
            "Aggregate conditions indicate developing food-system pressure. "
            "Review distribution redundancy, cold-chain readiness, food-loss "
            "reduction, market coverage, transit access, and emergency food "
            "infrastructure. This is infrastructure planning, not household scoring."
        )
    else:
        band = "priority_infrastructure_review"
        interpretation = (
            "Aggregate food-system indicators support a priority infrastructure "
            "review. Coordinate with public health, transit, markets, pantries, "
            "emergency management, and community organizations. Human review "
            "remains required before any service change."
        )

    return UrbanFoodResilienceResult(
        food_supply_score=food_supply_score,
        distribution_score=distribution_score,
        cold_chain_score=cold_chain_score,
        access_friction_score=access_friction_score,
        local_capacity_score=local_capacity_score,
        food_system_resilience_index=resilience,
        coverage_status=coverage_status,
        planning_band=band,
        interpretation=interpretation,
    )
