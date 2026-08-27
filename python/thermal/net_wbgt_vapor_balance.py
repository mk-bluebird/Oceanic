from __future__ import annotations

import math


def saturation_vapor_pressure_kpa(temperature_c: float) -> float:
    return 0.61094 * math.exp(
        17.625 * temperature_c / (temperature_c + 243.04)
    )


def vapor_pressure_kpa(temperature_c: float, relative_humidity_percent: float) -> float:
    if not 0.0 <= relative_humidity_percent <= 100.0:
        raise ValueError("relative_humidity_percent must be within [0, 100].")
    return (
        relative_humidity_percent / 100.0
        * saturation_vapor_pressure_kpa(temperature_c)
    )


def relative_humidity_percent(
    temperature_c: float,
    vapor_pressure_kpa_value: float,
) -> float:
    if vapor_pressure_kpa_value < 0.0:
        raise ValueError("vapor_pressure_kpa_value must be nonnegative.")
    return 100.0 * vapor_pressure_kpa_value / saturation_vapor_pressure_kpa(
        temperature_c
    )


def psychrometric_wet_bulb_c(
    dry_bulb_c: float,
    vapor_pressure_kpa_value: float,
) -> float:
    low = -40.0
    high = dry_bulb_c

    for _ in range(80):
        wet_bulb_c = 0.5 * (low + high)
        saturation_at_wet_bulb = saturation_vapor_pressure_kpa(wet_bulb_c)
        psychrometric_term = 0.000067 * 101.325 * (dry_bulb_c - wet_bulb_c)
        estimated_vapor_pressure = saturation_at_wet_bulb - psychrometric_term

        if estimated_vapor_pressure > vapor_pressure_kpa_value:
            high = wet_bulb_c
        else:
            low = wet_bulb_c

    return 0.5 * (low + high)


def simplified_outdoor_wbgt_c(
    dry_bulb_c: float,
    wet_bulb_c: float,
    globe_c: float,
) -> float:
    return 0.7 * wet_bulb_c + 0.2 * globe_c + 0.1 * dry_bulb_c


def neutral_added_vapor_pressure_kpa(
    baseline_dry_bulb_c: float,
    baseline_relative_humidity_percent: float,
    cooled_dry_bulb_c: float,
) -> float:
    baseline_vapor_pressure = vapor_pressure_kpa(
        baseline_dry_bulb_c,
        baseline_relative_humidity_percent,
    )
    baseline_wet_bulb = psychrometric_wet_bulb_c(
        baseline_dry_bulb_c,
        baseline_vapor_pressure,
    )

    low = baseline_vapor_pressure
    high = saturation_vapor_pressure_kpa(cooled_dry_bulb_c) * 0.999

    for _ in range(80):
        candidate = 0.5 * (low + high)
        cooled_wet_bulb = psychrometric_wet_bulb_c(
            cooled_dry_bulb_c,
            candidate,
        )
        if cooled_wet_bulb > baseline_wet_bulb:
            high = candidate
        else:
            low = candidate

    return 0.5 * (low + high) - baseline_vapor_pressure
