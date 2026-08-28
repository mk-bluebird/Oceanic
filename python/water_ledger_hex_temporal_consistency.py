from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from statistics import mean
from typing import Sequence


SECONDS_PER_HOUR = 3_600.0
LITRES_PER_CUBIC_METRE = 1_000.0


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
class PilotWaterLedgerEntry:
    """
    One accounting interval for a Cyboquatic pilot.

    All water quantities are cubic metres per interval.

    extracted_m3:
        Withdrawn from the authorized source.

    treated_m3:
        Water processed by the treatment train. It is tracked separately from
        extraction because recirculated or previously stored water can be treated
        without a new extraction during the current interval.

    evaporated_total_m3:
        Gross water transfer from the pilot liquid domain to atmosphere.

    counterfactual_atmospheric_vapor_m3:
        Vapor transfer that would have occurred without system operation from
        the matched reference surface, baseline evapotranspiration, or an
        independently validated counterfactual model. This is never a claim
        that atmospheric background water belongs to the pilot.

    discharged_m3:
        Released through a measured, permitted, and quality-assured liquid path.

    recovered_m3:
        Condensed, captured, recirculated, or otherwise returned as usable
        measured water. It cannot exceed physical water available for recovery.

    storage_change_m3:
        Change in liquid on-site storage, defined as final minus initial volume.
        Positive means storage increased, negative means storage was drawn down.

    measurement_uncertainty_m3:
        Combined interval uncertainty bound from flow metering, tank gauging,
        treatment accounting, and recovery measurement.
    """

    interval_label: str
    extracted_m3: float
    treated_m3: float
    evaporated_total_m3: float
    counterfactual_atmospheric_vapor_m3: float
    discharged_m3: float
    recovered_m3: float
    storage_change_m3: float
    measurement_uncertainty_m3: float

    def __post_init__(self) -> None:
        if not self.interval_label.strip():
            raise ValueError("interval_label must not be empty.")

        for name, value in (
            ("extracted_m3", self.extracted_m3),
            ("treated_m3", self.treated_m3),
            ("evaporated_total_m3", self.evaporated_total_m3),
            (
                "counterfactual_atmospheric_vapor_m3",
                self.counterfactual_atmospheric_vapor_m3,
            ),
            ("discharged_m3", self.discharged_m3),
            ("recovered_m3", self.recovered_m3),
            ("measurement_uncertainty_m3", self.measurement_uncertainty_m3),
        ):
            _nonnegative(name, value)

        if not isfinite(self.storage_change_m3):
            raise ValueError("storage_change_m3 must be finite.")

        if self.counterfactual_atmospheric_vapor_m3 > self.evaporated_total_m3:
            raise ValueError(
                "counterfactual_atmospheric_vapor_m3 cannot exceed gross "
                "evaporated_total_m3 within the same accounting boundary."
            )


@dataclass(frozen=True)
class WaterLedgerSummary:
    gross_extracted_m3: float
    gross_treated_m3: float
    gross_evaporated_m3: float
    counterfactual_atmospheric_vapor_m3: float
    attributable_evaporated_m3: float
    discharged_m3: float
    recovered_m3: float
    storage_change_m3: float
    net_consumptive_water_use_m3: float
    gross_misting_style_consumption_m3: float
    mass_balance_residual_m3: float
    combined_measurement_uncertainty_m3: float
    mass_balance_within_uncertainty: bool
    interpretation: str


def summarize_water_ledger(
    entries: Sequence[PilotWaterLedgerEntry],
) -> WaterLedgerSummary:
    """
    Aggregate a transparent water-accounting boundary.

    Gross misting-style consumption typically reports:

      W_gross = extracted water supplied to misting or evaporated water

    The pilot ledger instead reports attributable consumptive depletion:

      E_attr = E_total - E_counterfactual

      W_net = E_attr + discharge_unrecovered + storage_drawdown
              - recovered_return

    The conservation audit residual is:

      residual =
        extracted + recovered - discharged - evaporated_total - storage_change

    A residual near zero within independent meter uncertainty indicates a
    physically coherent interval ledger. Treatment volume is intentionally
    reported as a process-throughput metric and is not inserted into the source
    mass balance because it can include recirculation.
    """
    if not entries:
        raise ValueError("At least one ledger entry is required.")

    extracted = sum(item.extracted_m3 for item in entries)
    treated = sum(item.treated_m3 for item in entries)
    evaporated = sum(item.evaporated_total_m3 for item in entries)
    counterfactual_vapor = sum(
        item.counterfactual_atmospheric_vapor_m3 for item in entries
    )
    attributable_evaporated = evaporated - counterfactual_vapor
    discharged = sum(item.discharged_m3 for item in entries)
    recovered = sum(item.recovered_m3 for item in entries)
    storage_change = sum(item.storage_change_m3 for item in entries)
    uncertainty = sum(item.measurement_uncertainty_m3 for item in entries)

    residual = extracted + recovered - discharged - evaporated - storage_change
    net_consumptive = (
        attributable_evaporated
        + discharged
        - recovered
        - storage_change
    )
    gross_misting = extracted

    return WaterLedgerSummary(
        gross_extracted_m3=extracted,
        gross_treated_m3=treated,
        gross_evaporated_m3=evaporated,
        counterfactual_atmospheric_vapor_m3=counterfactual_vapor,
        attributable_evaporated_m3=attributable_evaporated,
        discharged_m3=discharged,
        recovered_m3=recovered,
        storage_change_m3=storage_change,
        net_consumptive_water_use_m3=net_consumptive,
        gross_misting_style_consumption_m3=gross_misting,
        mass_balance_residual_m3=residual,
        combined_measurement_uncertainty_m3=uncertainty,
        mass_balance_within_uncertainty=abs(residual) <= uncertainty,
        interpretation=(
            "The interval ledger closes within its stated measurement "
            "uncertainty and distinguishes attributable evaporative depletion "
            "from vapor that would have occurred without the pilot."
            if abs(residual) <= uncertainty
            else (
                "The interval ledger does not close within its stated "
                "measurement uncertainty. The result remains an auditable "
                "reconciliation signal requiring flow-meter, tank-level, "
                "recovery, discharge, and timing review."
            )
        ),
    )


@dataclass(frozen=True)
class ThermalAnomalyObservation:
    """
    Quality-controlled LST anomaly for one hex anchor at one observation time.

    temperature_anomaly_c:
        LST minus a documented matched reference: for example, a seasonal,
        diurnal, weather-conditioned, or nearby-background estimate.

    Land-surface temperature is retained as an environmental planning metric. It
    must not be represented as a direct measurement of person-level heat
    exposure, which separately depends on air temperature, radiation, wind,
    humidity, clothing, activity, shade, and access to relief.
    """

    time_index: int
    temperature_anomaly_c: float
    land_use_class: str
    calibration_quality: float

    def __post_init__(self) -> None:
        if self.time_index < 0:
            raise ValueError("time_index must be non-negative.")
        if not isfinite(self.temperature_anomaly_c):
            raise ValueError("temperature_anomaly_c must be finite.")
        if not self.land_use_class.strip():
            raise ValueError("land_use_class must not be empty.")
        _unit_interval("calibration_quality", self.calibration_quality)


@dataclass(frozen=True)
class HexTemporalConsistencyResult:
    lag_steps: int
    autocorrelation: float
    decorrelation_time_steps: int | None
    calibration_update_required: bool
    calibration_action: str
    knowledge_factor: float


def autocorrelation_at_lag(
    observations: Sequence[ThermalAnomalyObservation],
    lag_steps: int,
) -> float:
    """
    Compute sample autocorrelation of a regularly sampled anomaly series:

      rho(tau) =
        Cov[T'(t), T'(t+tau)] / Var[T'(t)]

    Missing observations should be excluded or handled through a documented
    state-space imputation model before calling this calculation. The function
    deliberately rejects irregular or duplicate time indices rather than
    silently treating them as evenly spaced.
    """
    if lag_steps < 1:
        raise ValueError("lag_steps must be at least one.")
    if len(observations) <= lag_steps:
        raise ValueError("observations length must exceed lag_steps.")

    ordered = sorted(observations, key=lambda item: item.time_index)
    expected = list(range(ordered[0].time_index, ordered[0].time_index + len(ordered)))
    actual = [item.time_index for item in ordered]
    if actual != expected:
        raise ValueError(
            "Observations must have contiguous regular time_index values."
        )

    values = [item.temperature_anomaly_c for item in ordered]
    series_mean = mean(values)
    variance = sum((value - series_mean) ** 2 for value in values) / len(values)
    if variance <= 0.0:
        raise ValueError("Temperature anomaly variance must be greater than zero.")

    covariance = sum(
        (values[index] - series_mean)
        * (values[index + lag_steps] - series_mean)
        for index in range(len(values) - lag_steps)
    ) / (len(values) - lag_steps)

    return covariance / variance


def characteristic_decorrelation_time(
    observations: Sequence[ThermalAnomalyObservation],
    threshold: float = 1.0 / 2.718281828459045,
) -> int | None:
    """
    Return the earliest lag with rho(lag) <= 1/e by default.

    The 1/e crossing is a common characteristic-time convention. A separate
    0.5 threshold is retained for the operational calibration update gate in
    accordance with the object definition.
    """
    _unit_interval("threshold", threshold)
    if threshold == 0.0:
        raise ValueError("threshold must be greater than zero.")
    if len(observations) < 3:
        raise ValueError("At least three observations are required.")

    for lag in range(1, len(observations)):
        if autocorrelation_at_lag(observations, lag) <= threshold:
            return lag
    return None


def assess_hex_temporal_consistency(
    observations: Sequence[ThermalAnomalyObservation],
    lag_steps: int,
    update_threshold: float = 0.5,
) -> HexTemporalConsistencyResult:
    """
    Apply the temporal consistency gate:

      update calibration when rho(tau) < 0.5

    The update action is a controlled calibration workflow:
      1. retain prior anchor records and model version;
      2. verify satellite/ground sensor calibration and cloud/quality flags;
      3. recompute the land-use-conditioned anomaly baseline;
      4. refresh seasonal and diurnal covariance parameters;
      5. validate against held-out observations;
      6. publish a new calibration version with uncertainty metadata.

    The method does not silently move or reassign spatial anchors.
    """
    _unit_interval("update_threshold", update_threshold)
    if update_threshold == 0.0:
        raise ValueError("update_threshold must be greater than zero.")

    correlation = autocorrelation_at_lag(observations, lag_steps)
    decorrelation = characteristic_decorrelation_time(observations)
    quality = mean(item.calibration_quality for item in observations)
    requires_update = correlation < update_threshold
    knowledge_factor = max(
        0.0,
        min(
            1.0,
            quality * max(0.0, min(1.0, correlation / update_threshold)),
        ),
    )

    return HexTemporalConsistencyResult(
        lag_steps=lag_steps,
        autocorrelation=correlation,
        decorrelation_time_steps=decorrelation,
        calibration_update_required=requires_update,
        calibration_action=(
            "retain_anchor_geometry_and_start_versioned_land_surface_temperature "
            "baseline_recalibration_with_sensor_quality_review"
            if requires_update
            else "retain_current_calibration_with_continued_quality_monitoring"
        ),
        knowledge_factor=knowledge_factor,
    )


def summarize_land_use_decorrelation(
    observations: Sequence[ThermalAnomalyObservation],
) -> dict[str, int | None]:
    """
    Estimate a characteristic decorrelation time separately by land-use class.

    Suitable classes include:
      impervious_commercial,
      impervious_residential,
      irrigated_vegetation,
      desert_preserve,
      riparian_restoration,
      cool_pavement,
      mixed_use.

    Each class needs sufficiently long, regularly sampled quality-controlled
    anomaly series. The output is intentionally data-derived rather than a
    fabricated universal Phoenix table.
    """
    grouped: dict[str, list[ThermalAnomalyObservation]] = {}
    for observation in observations:
        grouped.setdefault(observation.land_use_class, []).append(observation)

    result: dict[str, int | None] = {}
    for land_use, values in grouped.items():
        result[land_use] = (
            characteristic_decorrelation_time(values)
            if len(values) >= 3
            else None
        )
    return result
