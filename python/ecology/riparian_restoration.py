from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal, Sequence


class InputValidationError(ValueError):
    """Raised when riparian-restoration inputs are invalid."""


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
class RiparianReachInputs:
    """
    Aggregate riparian reach condition for a declared stream segment.

    No field may identify property owners, easement holders, water-right
    holders, or any person-level land-use history.
    """

    reach_id: str
    riparian_condition_gap: float
    water_quality_gap: float
    habitat_connectivity_gap: float
    thermal_load_gap: float
    restoration_benefit_score: float
    hydrological_feasibility_score: float
    maintenance_feasibility_score: float
    community_governance_readiness: float
    jurisdictional_conflict_score: float
    evidence_quality: float
    observation_coverage: float


@dataclass(frozen=True)
class RiparianRestorationResult:
    reach_id: str
    restoration_priority_score: float
    coverage_adjusted_score: float
    coverage_status: Literal["sufficient", "insufficient"]
    priority_band: Literal[
        "routine_monitoring",
        "study_and_engage",
        "priority_restoration_review",
        "insufficient_coverage",
    ]
    interpretation: str


def evaluate_riparian_reach(
    reach: RiparianReachInputs,
    *,
    minimum_coverage: float = 0.70,
) -> RiparianRestorationResult:
    """
    Evaluate one riparian reach for restoration-review prioritization.

    This is a public-infrastructure and ecological planning signal. It must
    not be used to rank landowners, compel access, or authorize restoration.
    """
    if not reach.reach_id.strip():
        raise InputValidationError("reach_id must not be blank")

    for name, value in (
        ("riparian_condition_gap", reach.riparian_condition_gap),
        ("water_quality_gap", reach.water_quality_gap),
        ("habitat_connectivity_gap", reach.habitat_connectivity_gap),
        ("thermal_load_gap", reach.thermal_load_gap),
        ("restoration_benefit_score", reach.restoration_benefit_score),
        ("hydrological_feasibility_score", reach.hydrological_feasibility_score),
        ("maintenance_feasibility_score", reach.maintenance_feasibility_score),
        ("community_governance_readiness", reach.community_governance_readiness),
        ("jurisdictional_conflict_score", reach.jurisdictional_conflict_score),
        ("evidence_quality", reach.evidence_quality),
        ("observation_coverage", reach.observation_coverage),
    ):
        _range(name, value, 0.0, 1.0)

    _range("minimum_coverage", minimum_coverage, 0.0, 1.0)

    gap = (
        0.35 * reach.riparian_condition_gap
        + 0.25 * reach.water_quality_gap
        + 0.20 * reach.habitat_connectivity_gap
        + 0.20 * reach.thermal_load_gap
    )

    feasibility = (
        0.50 * reach.hydrological_feasibility_score
        + 0.30 * reach.maintenance_feasibility_score
        + 0.20 * reach.community_governance_readiness
    )

    raw = _clamp(
        0.40 * gap
        + 0.30 * reach.restoration_benefit_score
        + 0.20 * feasibility
        - 0.20 * reach.jurisdictional_conflict_score
    )

    quality = reach.evidence_quality * reach.observation_coverage
    coverage_adjusted = raw * quality

    coverage_status: Literal["sufficient", "insufficient"] = (
        "sufficient" if quality >= minimum_coverage else "insufficient"
    )

    if coverage_status == "insufficient":
        band: Literal[
            "routine_monitoring",
            "study_and_engage",
            "priority_restoration_review",
            "insufficient_coverage",
        ] = "insufficient_coverage"
        interpretation = (
            "Riparian, water-quality, or hydrological evidence is insufficient. "
            "Do not use this result for investment, access, or disclosure."
        )
    elif raw >= 0.65 and reach.community_governance_readiness >= 0.50:
        band = "priority_restoration_review"
        interpretation = (
            "Aggregate condition gap, restoration benefit, and feasibility "
            "support priority public/community restoration review. Coordinate "
            "with watershed governance, habitat stewards, accessibility, and "
            "affected communities before any field activity."
        )
    elif reach.jurisdictional_conflict_score >= 0.60:
        band = "study_and_engage"
        interpretation = (
            "Aggregate conditions warrant additional study and community "
            "engagement before restoration review. Address jurisdictional "
            "questions through lawful, voluntary, and governance-respecting "
            "channels."
        )
    else:
        band = "routine_monitoring"
        interpretation = (
            "Aggregate conditions support routine monitoring and maintenance. "
            "Revisit after additional field observation, hydrological review, "
            "and community engagement."
        )

    return RiparianRestorationResult(
        reach_id=reach.reach_id,
        restoration_priority_score=raw,
        coverage_adjusted_score=coverage_adjusted,
        coverage_status=coverage_status,
        priority_band=band,
        interpretation=interpretation,
    )
