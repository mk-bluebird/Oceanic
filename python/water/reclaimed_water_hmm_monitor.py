from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class MonitoringDesign:
    combined_log10_standard_deviation: float
    detection_assurance: float
    detection_window_hours: float
    sample_interval_hours: float


def required_post_change_observations(
    combined_log10_standard_deviation: float,
    detection_assurance: float = 0.90,
    target_log10_increase: float = 1.0,
) -> int:
    if combined_log10_standard_deviation <= 0.0:
        raise ValueError("combined_log10_standard_deviation must be positive.")
    if target_log10_increase <= 0.0:
        raise ValueError("target_log10_increase must be positive.")

    quantiles = {
        0.80: 0.8416212335729143,
        0.90: 1.2815515655446004,
        0.95: 1.6448536269514722,
    }
    if detection_assurance not in quantiles:
        raise ValueError("detection_assurance must be 0.80, 0.90, or 0.95.")

    one_sided_95 = 1.6448536269514722
    required = (
        (one_sided_95 + quantiles[detection_assurance])
        * combined_log10_standard_deviation
        / target_log10_increase
    ) ** 2
    return max(1, math.ceil(required))


def observations_available(design: MonitoringDesign) -> int:
    if design.detection_window_hours <= 0.0:
        raise ValueError("detection_window_hours must be positive.")
    if design.sample_interval_hours <= 0.0:
        raise ValueError("sample_interval_hours must be positive.")
    return math.floor(
        design.detection_window_hours / design.sample_interval_hours
    )


def design_meets_detection_target(design: MonitoringDesign) -> bool:
    return observations_available(design) >= required_post_change_observations(
        combined_log10_standard_deviation=design.combined_log10_standard_deviation,
        detection_assurance=design.detection_assurance,
    )


def recommended_sample_interval_hours(
    combined_log10_standard_deviation: float,
    detection_window_hours: float = 48.0,
    detection_assurance: float = 0.90,
) -> float:
    required = required_post_change_observations(
        combined_log10_standard_deviation,
        detection_assurance,
    )
    return detection_window_hours / required
