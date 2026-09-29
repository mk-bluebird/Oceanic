from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal


class InputValidationError(ValueError):
    """Raised when rainwater-harvesting inputs are invalid."""


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
class RainwaterHarvestingInputs:
    """
    Aggregate facility or district rainwater-harvesting planning inputs.

    The model does not adjudicate water rights, potability, or household-level
    allocation. All fields describe public, community, or facility
    infrastructure.
    """

    catchment_area_m2: float
    annual_precipitation_mm: float
    runoff_coefficient: float
    first_flush_loss_fraction: float
    storage_capacity_m3: float
    treatment_effectiveness_score: float
    non_potable_demand_m3_year: float
    potable_demand_m3_year: float
    drought_stress_factor: float
    observation_coverage: float
    evidence_quality: float


@dataclass(frozen=True)
class RainwaterHarvestingResult:
    gross_harvestable_m3_year: float
    net_harvestable_m3_year: float
    storage_limited_delivery_m3_year: float
    non_potable_substitution_fraction: float
    potable_substitution_fraction: float
    water_pressure_reduction_score: float
    coverage_status: Literal["sufficient", "insufficient"]
    planning_band: Literal[
        "routine_monitoring",
        "expand_harvesting",
        "priority_infrastructure_review",
        "insufficient_coverage",
    ]
    interpretation: str


def estimate_rainwater_harvesting(
    inputs: RainwaterHarvestingInputs,
    *,
    minimum_coverage: float = 0.70,
) -> RainwaterHarvestingResult:
    """
    Estimate aggregate rainwater-harvesting potential for a facility zone.

    This is a planning estimate. It does not establish water rights, potable
    suitability, treatment compliance, or household allocation.
    """
    catchment = _range(
        "catchment_area_m2",
        inputs.catchment_area_m2,
        0.0,
        1e9,
    )
    precipitation = _range(
        "annual_precipitation_mm",
        inputs.annual_precipitation_mm,
        0.0,
        10_000.0,
    )
    runoff = _range(
        "runoff_coefficient",
        inputs.runoff_coefficient,
        0.0,
        1.0,
    )
    first_flush = _range(
        "first_flush_loss_fraction",
        inputs.first_flush_loss_fraction,
        0.0,
        0.50,
    )
    storage = _range(
        "storage_capacity_m3",
        inputs.storage_capacity_m3,
        0.0,
        1e9,
    )
    treatment = _range(
        "treatment_effectiveness_score",
        inputs.treatment_effectiveness_score,
        0.0,
        1.0,
    )
    non_potable_demand = _range(
        "non_potable_demand_m3_year",
        inputs.non_potable_demand_m3_year,
        0.0,
        1e9,
    )
    potable_demand = _range(
        "potable_demand_m3_year",
        inputs.potable_demand_m3_year,
        0.0,
        1e9,
    )
    drought_stress = _range(
        "drought_stress_factor",
        inputs.drought_stress_factor,
        0.0,
        1.0,
    )
    coverage = _range(
        "observation_coverage",
        inputs.observation_coverage,
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

    gross = catchment * precipitation * 0.001 * runoff
    net = gross * (1.0 - first_flush)
    storage_limited = min(net, storage)

    non_potable_substitution = (
        min(non_potable_demand, storage_limited) / non_potable_demand
        if non_potable_demand > 0.0
        else 0.0
    )

    potable_eligible = storage_limited * treatment
    potable_substitution = (
        min(potable_demand, potable_eligible) / potable_demand
        if potable_demand > 0.0
        else 0.0
    )

    water_pressure_reduction = _clamp(
        0.55 * non_potable_substitution
        + 0.25 * potable_substitution
        + 0.20 * drought_stress
    )

    coverage_status: Literal["sufficient", "insufficient"] = (
        "sufficient"
        if coverage * evidence >= minimum_coverage
        else "insufficient"
    )

    if coverage_status == "insufficient":
        band: Literal[
            "routine_monitoring",
            "expand_harvesting",
            "priority_infrastructure_review",
            "insufficient_coverage",
        ] = "insufficient_coverage"
        interpretation = (
            "Precipitation, storage, treatment, or demand evidence is "
            "insufficient. Do not use this estimate for investment, water-right, "
            "or potable-water claims."
        )
    elif water_pressure_reduction >= 0.60 and drought_stress >= 0.50:
        band = "priority_infrastructure_review"
        interpretation = (
            "Aggregate drought stress and modeled substitution capacity support "
            "priority review of catchment expansion, storage, filtration, "
            "treatment, and non-potable dual-use plumbing. Potable use requires "
            "separate treatment, testing, and regulatory review."
        )
    elif net > storage_limited:
        band = "expand_harvesting"
        interpretation = (
            "Annual harvestable volume exceeds current storage capacity. "
            "Evaluate storage expansion, seasonal demand timing, filtration, "
            "and non-potable dual-use opportunities before adding catchment."
        )
    else:
        band = "routine_monitoring"
        interpretation = (
            "Aggregate harvestable volume and storage capacity are comparatively "
            "aligned. Continue routine inspection, first-flush management, "
            "filtration maintenance, and non-potable demand matching."
        )

    return RainwaterHarvestingResult(
        gross_harvestable_m3_year=gross,
        net_harvestable_m3_year=net,
        storage_limited_delivery_m3_year=storage_limited,
        non_potable_substitution_fraction=_clamp(non_potable_substitution),
        potable_substitution_fraction=_clamp(potable_substitution),
        water_pressure_reduction_score=water_pressure_reduction,
        coverage_status=coverage_status,
        planning_band=band,
        interpretation=interpretation,
    )
