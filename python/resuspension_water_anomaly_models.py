from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, sqrt
from statistics import NormalDist
from typing import Sequence


STANDARD_NORMAL = NormalDist()
SECONDS_PER_HOUR = 3_600.0


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _probability(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0 or value >= 1.0:
        raise ValueError(f"{name} must be strictly between zero and one.")


@dataclass(frozen=True)
class SurfaceResuspensionInputs:
    """
    Aggregate settled material and environmental inputs.

    surface_loading_organisms_per_m2:
        Measured or conservatively bounded viable/pathogenic loading after
        deposition. It must not be inferred from visual wetness.

    k_resusp_reference_per_s:
        Empirical reference coefficient for the stated material, smooth
        concrete condition, activity class, humidity, and reference shear.
        The model does not treat this value as universal.

    friction_velocity_m_per_s:
        Local u* derived from near-surface wind measurement or an accepted
        wind-profile model, not generic station wind speed.

    pedestrian_disturbance_multiplier:
        Equals one for wind-only conditions; use a validated activity-specific
        multiplier for walking, wheeled traffic, cleaning, or maintenance.

    roughness_multiplier:
        Represents the measured surface and deposited-film condition. Smooth
        concrete with no loose dust film should normally be near one.
    """

    surface_loading_organisms_per_m2: float
    k_resusp_reference_per_s: float
    reference_friction_velocity_m_per_s: float
    friction_velocity_m_per_s: float
    shear_exponent: float
    roughness_multiplier: float
    turbulence_multiplier: float
    pedestrian_disturbance_multiplier: float
    receptor_mixing_volume_m3: float
    breathing_rate_m3_per_hour: float
    exposure_duration_hours: float
    viable_fraction: float
    deposition_fraction: float

    def __post_init__(self) -> None:
        for name, value in (
            ("surface_loading_organisms_per_m2", self.surface_loading_organisms_per_m2),
            ("k_resusp_reference_per_s", self.k_resusp_reference_per_s),
            (
                "reference_friction_velocity_m_per_s",
                self.reference_friction_velocity_m_per_s,
            ),
            ("friction_velocity_m_per_s", self.friction_velocity_m_per_s),
            ("shear_exponent", self.shear_exponent),
            ("roughness_multiplier", self.roughness_multiplier),
            ("turbulence_multiplier", self.turbulence_multiplier),
            (
                "pedestrian_disturbance_multiplier",
                self.pedestrian_disturbance_multiplier,
            ),
            ("receptor_mixing_volume_m3", self.receptor_mixing_volume_m3),
            ("breathing_rate_m3_per_hour", self.breathing_rate_m3_per_hour),
            ("exposure_duration_hours", self.exposure_duration_hours),
        ):
            _nonnegative(name, value)

        _positive("k_resusp_reference_per_s", self.k_resusp_reference_per_s)
        _positive(
            "reference_friction_velocity_m_per_s",
            self.reference_friction_velocity_m_per_s,
        )
        _positive("receptor_mixing_volume_m3", self.receptor_mixing_volume_m3)
        _positive("breathing_rate_m3_per_hour", self.breathing_rate_m3_per_hour)
        _positive("exposure_duration_hours", self.exposure_duration_hours)

        for name, value in (
            ("viable_fraction", self.viable_fraction),
            ("deposition_fraction", self.deposition_fraction),
        ):
            if not 0.0 <= value <= 1.0:
                raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class ResuspensionDoseResult:
    effective_resuspension_coefficient_per_s: float
    resuspension_flux_organisms_per_m2_s: float
    airborne_concentration_organisms_per_m3: float
    inhaled_deposited_dose_organisms: float
    significance_ratio_to_direct_dose: float | None
    interpretation: str


def effective_resuspension_coefficient(
    inputs: SurfaceResuspensionInputs,
) -> float:
    """
    Compute an explicit resuspension coefficient:

      k_eff =
        k_ref
        (u*/u*_ref)^n
        f_roughness
        f_turbulence
        f_pedestrian

    This is a semi-empirical formulation. k_ref is material- and surface-
    specific and should be obtained through local tracer or microbiological
    resuspension experiments. Wind-driven dust flux commonly rises strongly
    with friction velocity; the exponent is therefore explicit rather than
    hidden in a fixed Phoenix coefficient.
    """
    shear_ratio = (
        inputs.friction_velocity_m_per_s
        / inputs.reference_friction_velocity_m_per_s
    )
    return (
        inputs.k_resusp_reference_per_s
        * (shear_ratio ** inputs.shear_exponent)
        * inputs.roughness_multiplier
        * inputs.turbulence_multiplier
        * inputs.pedestrian_disturbance_multiplier
    )


def calculate_resuspension_dose(
    inputs: SurfaceResuspensionInputs,
    direct_inhaled_deposited_dose_organisms: float | None = None,
) -> ResuspensionDoseResult:
    """
    Compute:

      J_resuspend = k_eff * C_surface

      C_air = J_resuspend / Q_mix

    Q_mix is represented by the specified local effective mixing volume per
    second. The implementation uses a one-second source basis; atmospheric
    dispersion, deposition, inactivation, and spatial plume structure should
    be included in a validated site model for operational assessment.
    """
    if direct_inhaled_deposited_dose_organisms is not None:
        _nonnegative(
            "direct_inhaled_deposited_dose_organisms",
            direct_inhaled_deposited_dose_organisms,
        )

    coefficient = effective_resuspension_coefficient(inputs)
    flux = coefficient * inputs.surface_loading_organisms_per_m2
    airborne_concentration = flux / inputs.receptor_mixing_volume_m3
    inhaled_air_volume = (
        inputs.breathing_rate_m3_per_hour * inputs.exposure_duration_hours
    )
    inhaled_deposited = (
        airborne_concentration
        * inhaled_air_volume
        * inputs.viable_fraction
        * inputs.deposition_fraction
    )
    ratio = (
        None
        if direct_inhaled_deposited_dose_organisms is None
        or direct_inhaled_deposited_dose_organisms == 0.0
        else inhaled_deposited / direct_inhaled_deposited_dose_organisms
    )

    interpretation = (
        "Resuspension is a material contribution when the modeled dose is "
        "comparable to or exceeds the direct-release dose. Its magnitude "
        "requires measured surface loading, local friction velocity, and "
        "surface-specific k_resusp calibration."
        if ratio is None or ratio >= 0.10
        else
        "The modeled resuspension contribution is below 10 percent of the "
        "specified direct-release dose, while remaining a monitoring and "
        "surface-cleaning consideration."
    )

    return ResuspensionDoseResult(
        effective_resuspension_coefficient_per_s=coefficient,
        resuspension_flux_organisms_per_m2_s=flux,
        airborne_concentration_organisms_per_m3=airborne_concentration,
        inhaled_deposited_dose_organisms=inhaled_deposited,
        significance_ratio_to_direct_dose=ratio,
        interpretation=interpretation,
    )


@dataclass(frozen=True)
class WaterQualityObservation:
    """
    Time-aligned water-quality observation.

    Parameter order:
      turbidity_ntu,
      conductivity_us_per_cm,
      ph,
      chlorine_residual_mg_per_l,
      temperature_c,
      flow_m3_per_s.

    This schema intentionally treats raw sensor fields as environmental process
    telemetry, not as a complete health or compliance conclusion.
    """

    turbidity_ntu: float
    conductivity_us_per_cm: float
    ph: float
    chlorine_residual_mg_per_l: float
    temperature_c: float
    flow_m3_per_s: float
    timestamp_label: str

    def __post_init__(self) -> None:
        for name, value in (
            ("turbidity_ntu", self.turbidity_ntu),
            ("conductivity_us_per_cm", self.conductivity_us_per_cm),
            ("chlorine_residual_mg_per_l", self.chlorine_residual_mg_per_l),
            ("flow_m3_per_s", self.flow_m3_per_s),
        ):
            _nonnegative(name, value)

        if not isfinite(self.ph) or not 0.0 <= self.ph <= 14.0:
            raise ValueError("ph must be finite and within [0, 14].")
        if not isfinite(self.temperature_c):
            raise ValueError("temperature_c must be finite.")
        if not self.timestamp_label.strip():
            raise ValueError("timestamp_label must not be empty.")

    def values(self) -> tuple[float, float, float, float, float, float]:
        return (
            self.turbidity_ntu,
            self.conductivity_us_per_cm,
            self.ph,
            self.chlorine_residual_mg_per_l,
            self.temperature_c,
            self.flow_m3_per_s,
        )


@dataclass(frozen=True)
class RobustControlChartModel:
    """
    Multivariate score model based on robust standardized residuals.

    median and robust_scale are trained only on quality-controlled baseline
    operation. A production deployment should version these arrays with the
    source period, calibration state, maintenance events, and treatment mode.

    correlation_matrix_inverse is the inverse covariance/correlation matrix of
    standardized baseline residuals. A diagonal matrix produces independent
    z-score control; a full matrix incorporates covariance between channels.
    """

    medians: tuple[float, float, float, float, float, float]
    robust_scales: tuple[float, float, float, float, float, float]
    inverse_correlation: tuple[
        tuple[float, float, float, float, float, float],
        tuple[float, float, float, float, float, float],
        tuple[float, float, float, float, float, float],
        tuple[float, float, float, float, float, float],
        tuple[float, float, float, float, float, float],
        tuple[float, float, float, float, float, float],
    ]

    def __post_init__(self) -> None:
        if len(self.medians) != 6 or len(self.robust_scales) != 6:
            raise ValueError("medians and robust_scales must contain six values.")
        for scale in self.robust_scales:
            _positive("robust_scale", scale)
        if len(self.inverse_correlation) != 6 or any(
            len(row) != 6 for row in self.inverse_correlation
        ):
            raise ValueError("inverse_correlation must be a 6 by 6 matrix.")


@dataclass(frozen=True)
class AnomalyPolicy:
    """
    alarm_threshold is a squared Mahalanobis / Hotelling T² score.

    persistence_samples limits nuisance alarms: a single outlier is recorded
    and available for review, while an operator-facing upset alert requires
    repeated threshold crossings or a separately configured hard-limit rule.
    """

    alarm_threshold: float
    persistence_samples: int
    maximum_false_alarm_rate_per_day: float

    def __post_init__(self) -> None:
        _positive("alarm_threshold", self.alarm_threshold)
        if self.persistence_samples < 1:
            raise ValueError("persistence_samples must be at least one.")
        _nonnegative(
            "maximum_false_alarm_rate_per_day",
            self.maximum_false_alarm_rate_per_day,
        )


@dataclass(frozen=True)
class AnomalyEvaluation:
    scores: tuple[float, ...]
    alerts: tuple[bool, ...]
    false_alarm_rate: float
    true_positive_rate: float
    detection_delay_samples: int | None
    detection_delay_minutes: float | None
    threshold: float
    operator_fatigue_status: str


def robust_mahalanobis_score(
    observation: WaterQualityObservation,
    model: RobustControlChartModel,
) -> float:
    """
    Compute robust standardized T² score:

      z_i = (x_i - median_i) / scale_i
      score = z^T Sigma^{-1} z
    """
    z = [
        (value - median) / scale
        for value, median, scale in zip(
            observation.values(),
            model.medians,
            model.robust_scales,
        )
    ]
    transformed = [
        sum(model.inverse_correlation[row][column] * z[column] for column in range(6))
        for row in range(6)
    ]
    return sum(z[index] * transformed[index] for index in range(6))


def evaluate_anomaly_policy(
    observations: Sequence[WaterQualityObservation],
    baseline_labels: Sequence[bool],
    upset_labels: Sequence[bool],
    model: RobustControlChartModel,
    policy: AnomalyPolicy,
    sample_interval_minutes: float,
) -> AnomalyEvaluation:
    """
    Evaluate an early-warning policy against labeled replay or injected-upset
    data. Labels are used only for offline validation, never as an online input.

    A detection is counted after `persistence_samples` consecutive scores exceed
    threshold. This avoids treating isolated sensor noise as a plant upset.
    """
    _positive("sample_interval_minutes", sample_interval_minutes)
    if not (
        len(observations) == len(baseline_labels) == len(upset_labels)
    ):
        raise ValueError("Observations and labels must have identical lengths.")
    if not observations:
        raise ValueError("At least one observation is required.")

    scores = [robust_mahalanobis_score(item, model) for item in observations]
    alerts: list[bool] = []
    consecutive = 0

    for score in scores:
        consecutive = consecutive + 1 if score >= policy.alarm_threshold else 0
        alerts.append(consecutive >= policy.persistence_samples)

    baseline_count = sum(baseline_labels)
    upset_count = sum(upset_labels)
    false_positive_count = sum(
        alerted and baseline
        for alerted, baseline in zip(alerts, baseline_labels)
    )
    true_positive_count = sum(
        alerted and upset
        for alerted, upset in zip(alerts, upset_labels)
    )

    first_upset = next(
        (index for index, value in enumerate(upset_labels) if value),
        None,
    )
    first_detection = (
        None
        if first_upset is None
        else next(
            (
                index
                for index in range(first_upset, len(alerts))
                if alerts[index]
            ),
            None,
        )
    )
    delay_samples = (
        None
        if first_upset is None or first_detection is None
        else first_detection - first_upset
    )
    delay_minutes = (
        None
        if delay_samples is None
        else delay_samples * sample_interval_minutes
    )

    false_alarm_rate = (
        false_positive_count / baseline_count if baseline_count > 0 else 0.0
    )
    true_positive_rate = (
        true_positive_count / upset_count if upset_count > 0 else 0.0
    )
    fatigue_status = (
        "within_declared_operator_fatigue_budget"
        if false_alarm_rate <= policy.maximum_false_alarm_rate_per_day
        else "exceeds_declared_operator_fatigue_budget"
    )

    return AnomalyEvaluation(
        scores=tuple(scores),
        alerts=tuple(alerts),
        false_alarm_rate=false_alarm_rate,
        true_positive_rate=true_positive_rate,
        detection_delay_samples=delay_samples,
        detection_delay_minutes=delay_minutes,
        threshold=policy.alarm_threshold,
        operator_fatigue_status=fatigue_status,
    )


def select_balanced_anomaly_threshold(
    observations: Sequence[WaterQualityObservation],
    baseline_labels: Sequence[bool],
    upset_labels: Sequence[bool],
    model: RobustControlChartModel,
    candidate_thresholds: Sequence[float],
    persistence_samples: int,
    maximum_false_alarm_rate: float,
    sample_interval_minutes: float,
) -> AnomalyEvaluation:
    """
    Choose a threshold that maximizes true-positive rate subject to a hard
    false-alarm constraint, then minimizes detection delay, then minimizes
    threshold severity.

    This supports operator workload as an explicit safety and accessibility
    requirement rather than an afterthought.
    """
    if not candidate_thresholds:
        raise ValueError("candidate_thresholds must not be empty.")

    evaluations = [
        evaluate_anomaly_policy(
            observations=observations,
            baseline_labels=baseline_labels,
            upset_labels=upset_labels,
            model=model,
            policy=AnomalyPolicy(
                alarm_threshold=threshold,
                persistence_samples=persistence_samples,
                maximum_false_alarm_rate_per_day=maximum_false_alarm_rate,
            ),
            sample_interval_minutes=sample_interval_minutes,
        )
        for threshold in candidate_thresholds
    ]

    eligible = [
        evaluation
        for evaluation in evaluations
        if evaluation.false_alarm_rate <= maximum_false_alarm_rate
    ]
    if not eligible:
        raise ValueError(
            "No candidate threshold meets the declared false-alarm budget."
        )

    return max(
        eligible,
        key=lambda result: (
            result.true_positive_rate,
            -(
                result.detection_delay_minutes
                if result.detection_delay_minutes is not None
                else float("inf")
            ),
            -result.threshold,
        ),
    )
