from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal


class InputValidationError(ValueError):
    """Raised when wildfire smoke intrusion inputs are invalid."""


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
class WildfireSmokeIntrusionInputs:
    """
    Aggregate building-zone smoke-infiltration and clean-air readiness inputs.

    No field may contain occupant, patient, resident, worker, visitor, or
    household information. The model is a facility-planning signal, not a
    medical or occupancy determination.
    """

    outdoor_pm25_ug_m3: float
    infiltration_factor_estimate: float
    filter_effectiveness_score: float
    ventilation_shutdown_readiness: float
    envelope_sealing_score: float
    clean_air_room_capacity_fraction: float
    outdoor_air_intake_controllable: bool
    mechanical_ventilation_present: bool
    forecast_coverage: float
    evidence_quality: float


@dataclass(frozen=True)
class WildfireSmokeIntrusionResult:
    indoor_pm25_estimate_ug_m3: float
    smoke_intrusion_score: float
    clean_air_readiness_score: float
    coverage_status: Literal["sufficient", "insufficient"]
    smoke_band: Literal[
        "routine_monitoring",
        "prepare_filtration",
        "activate_clean_air",
        "restrict_exposure",
        "insufficient_coverage",
    ]
    interpretation: str


def estimate_wildfire_smoke_intrusion(
    inputs: WildfireSmokeIntrusionInputs,
    *,
    minimum_coverage: float = 0.70,
) -> WildfireSmokeIntrusionResult:
    """
    Estimate aggregate smoke-infiltration pressure and clean-air readiness
    for a public or community-serving building zone.

    This is a facility-planning signal, not a medical assessment, occupancy
    determination, or instruction about any individual's behavior.
    """
    outdoor_pm25 = _range(
        "outdoor_pm25_ug_m3",
        inputs.outdoor_pm25_ug_m3,
        0.0,
        2_000.0,
    )
    infiltration = _range(
        "infiltration_factor_estimate",
        inputs.infiltration_factor_estimate,
        0.0,
        1.0,
    )
    filter_eff = _range(
        "filter_effectiveness_score",
        inputs.filter_effectiveness_score,
        0.0,
        1.0,
    )
    vent_shutdown = _range(
        "ventilation_shutdown_readiness",
        inputs.ventilation_shutdown_readiness,
        0.0,
        1.0,
    )
    envelope = _range(
        "envelope_sealing_score",
        inputs.envelope_sealing_score,
        0.0,
        1.0,
    )
    clean_air_capacity = _range(
        "clean_air_room_capacity_fraction",
        inputs.clean_air_room_capacity_fraction,
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

    base_infiltration = infiltration * (1.0 - 0.55 * envelope)
    vent_penalty = 0.0 if (
        inputs.outdoor_air_intake_controllable
        and inputs.mechanical_ventilation_present
    ) else 0.15

    indoor_pm25 = max(
        0.0,
        outdoor_pm25 * (base_infiltration + vent_penalty) * (1.0 - filter_eff),
    )

    smoke_intrusion_score = _clamp(
        outdoor_pm25 / 150.0 * (1.0 - 0.60 * filter_eff)
        + 0.20 * base_infiltration
        + vent_penalty,
    )

    clean_air_readiness = _clamp(
        0.30 * filter_eff
        + 0.20 * vent_shutdown
        + 0.20 * envelope
        + 0.30 * clean_air_capacity,
    )

    coverage_status: Literal["sufficient", "insufficient"] = (
        "sufficient"
        if forecast_coverage * evidence >= minimum_coverage
        else "insufficient"
    )

    if coverage_status == "insufficient":
        band: Literal[
            "routine_monitoring",
            "prepare_filtration",
            "activate_clean_air",
            "restrict_exposure",
            "insufficient_coverage",
        ] = "insufficient_coverage"
        interpretation = (
            "Outdoor smoke forecast or building readiness evidence is "
            "insufficient. Do not use this result for facility-closure or "
            "public-occupancy decisions without additional verification."
        )
    elif smoke_intrusion_score < 0.25 and clean_air_readiness >= 0.60:
        band = "routine_monitoring"
        interpretation = (
            "Aggregate smoke-intrusion pressure is low and clean-air readiness "
            "is comparatively high. Maintain filter, envelope, and ventilation "
            "readiness checks."
        )
    elif smoke_intrusion_score < 0.50:
        band = "prepare_filtration"
        interpretation = (
            "Aggregate smoke pressure is developing. Confirm filter stock, "
            "ventilation control, envelope sealing, and clean-air room readiness "
            "before the smoke episode intensifies."
        )
    elif smoke_intrusion_score < 0.75 and clean_air_readiness >= 0.50:
        band = "activate_clean_air"
        interpretation = (
            "Aggregate smoke-intrusion pressure is elevated. Activate clean-air "
            "readiness, keep windows closed, prioritize filtered or clean-air "
            "rooms, and continue monitoring. This is a facility plan, not an "
            "individual respiratory instruction."
        )
    else:
        band = "restrict_exposure"
        interpretation = (
            "Aggregate smoke pressure is high relative to declared clean-air "
            "readiness. Consider pausing non-essential outdoor operations, "
            "expanding filtered indoor space, distributing public guidance, "
            "and coordinating with public-health authorities. Human review "
            "remains required before any service or occupancy change."
        )

    return WildfireSmokeIntrusionResult(
        indoor_pm25_estimate_ug_m3=indoor_pm25,
        smoke_intrusion_score=smoke_intrusion_score,
        clean_air_readiness_score=clean_air_readiness,
        coverage_status=coverage_status,
        smoke_band=band,
        interpretation=interpretation,
    )
