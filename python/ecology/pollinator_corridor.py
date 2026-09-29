from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal, Sequence


class InputValidationError(ValueError):
    """Raised when pollinator-corridor inputs are invalid."""


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
class PollinatorHabitatUnit:
    """
    Aggregate habitat patch or corridor segment.

    Units describe public, community, conservation, or habitat-scale conditions.
    They do not identify private property owners or pesticide applicators.
    """

    unit_id: str
    habitat_quality_score: float
    floral_resource_score: float
    nesting_opportunity_score: float
    connectivity_score: float
    pesticide_pressure_gap_score: float
    maintenance_feasibility_score: float
    area_hectares: float
    species_sensitivity_score: float
    evidence_quality: float
    measurement_coverage: float


@dataclass(frozen=True)
class PollinatorCorridorResult:
    unit_id: str
    pollinator_corridor_score: float
    coverage_adjusted_score: float
    coverage_status: Literal["sufficient", "insufficient"]
    planning_band: Literal[
        "routine_monitoring",
        "enhance_floral_resource",
        "priority_corridor_investment",
        "insufficient_coverage",
    ]
    interpretation: str


def evaluate_pollinator_corridor_unit(
    unit: PollinatorHabitatUnit,
    *,
    minimum_coverage: float = 0.70,
) -> PollinatorCorridorResult:
    """
    Evaluate one pollinator-corridor unit for public/community investment review.

    This is a habitat planning signal. It must not be used to target private
    property owners, pesticide enforcement, or land-use restrictions.
    """
    if not unit.unit_id.strip():
        raise InputValidationError("unit_id must not be blank")

    for name, value in (
        ("habitat_quality_score", unit.habitat_quality_score),
        ("floral_resource_score", unit.floral_resource_score),
        ("nesting_opportunity_score", unit.nesting_opportunity_score),
        ("connectivity_score", unit.connectivity_score),
        ("pesticide_pressure_gap_score", unit.pesticide_pressure_gap_score),
        ("maintenance_feasibility_score", unit.maintenance_feasibility_score),
        ("species_sensitivity_score", unit.species_sensitivity_score),
        ("evidence_quality", unit.evidence_quality),
        ("measurement_coverage", unit.measurement_coverage),
    ):
        _range(name, value, 0.0, 1.0)

    _range("area_hectares", unit.area_hectares, 0.0, 1e9)
    _range("minimum_coverage", minimum_coverage, 0.0, 1.0)

    score = _clamp(
        0.25 * unit.habitat_quality_score
        + 0.20 * unit.floral_resource_score
        + 0.15 * unit.nesting_opportunity_score
        + 0.20 * unit.connectivity_score
        + 0.10 * unit.pesticide_pressure_gap_score
        + 0.10 * unit.maintenance_feasibility_score
    )

    quality = unit.evidence_quality * unit.measurement_coverage
    coverage_adjusted = score * quality

    coverage_status: Literal["sufficient", "insufficient"] = (
        "sufficient" if quality >= minimum_coverage else "insufficient"
    )

    if coverage_status == "insufficient":
        band: Literal[
            "routine_monitoring",
            "enhance_floral_resource",
            "priority_corridor_investment",
            "insufficient_coverage",
        ] = "insufficient_coverage"
        interpretation = (
            "Habitat, floral, connectivity, or maintenance evidence is "
            "insufficient. Do not use this unit score for investment, "
            "protection, or disclosure decisions."
        )
    elif score >= 0.70 and unit.connectivity_score >= 0.60:
        band = "priority_corridor_investment"
        interpretation = (
            "Aggregate habitat, floral, connectivity, and maintenance "
            "conditions support priority public/community corridor investment. "
            "Coordinate with habitat stewards, accessibility review, and "
            "community governance."
        )
    elif unit.floral_resource_score < 0.50:
        band = "enhance_floral_resource"
        interpretation = (
            "Connectivity or habitat quality is present, but floral resources "
            "are limited. Prioritize native, locally appropriate, non-invasive "
            "planting and seasonal bloom continuity."
        )
    else:
        band = "routine_monitoring"
        interpretation = (
            "Aggregate habitat conditions support routine monitoring and "
            "maintenance. Continue floral continuity, nesting opportunity, and "
            "connectivity assessment."
        )

    return PollinatorCorridorResult(
        unit_id=unit.unit_id,
        pollinator_corridor_score=score,
        coverage_adjusted_score=coverage_adjusted,
        coverage_status=coverage_status,
        planning_band=band,
        interpretation=interpretation,
    )
