import unittest

from python.nocturnal_humidity_et_irrigation_models import (
    ETForecast,
    NocturnalCanyonInputs,
    SoilWaterState,
    assess_nocturnal_humidity,
    optimize_et_irrigation_horizon,
    select_optimal_et_horizon,
)


class NocturnalHumidityEtIrrigationModelsTests(unittest.TestCase):
    def test_higher_exchange_reduces_equilibrium_humidity(self) -> None:
        slow_exchange = NocturnalCanyonInputs(
            canyon_height_m=30.0,
            canyon_width_m=20.0,
            source_rate_kg_per_s=0.001,
            exchange_velocity_m_per_s=0.02,
            condensation_rate_per_s=0.00001,
            ambient_vapor_density_kg_per_m3=0.012,
            initial_vapor_density_kg_per_m3=0.012,
            nighttime_air_temperature_c=30.0,
        )
        fast_exchange = NocturnalCanyonInputs(
            **{
                **slow_exchange.__dict__,
                "exchange_velocity_m_per_s": 0.10,
            }
        )

        slow = assess_nocturnal_humidity(
            slow_exchange,
            night_duration_hours=8.0,
        )
        fast = assess_nocturnal_humidity(
            fast_exchange,
            night_duration_hours=8.0,
        )

        self.assertGreater(
            slow.equilibrium_relative_humidity_percent,
            fast.equilibrium_relative_humidity_percent,
        )

    def test_three_hour_limit_is_more_conservative_than_equilibrium_limit(self) -> None:
        inputs = NocturnalCanyonInputs(
            canyon_height_m=30.0,
            canyon_width_m=20.0,
            source_rate_kg_per_s=0.001,
            exchange_velocity_m_per_s=0.03,
            condensation_rate_per_s=0.00001,
            ambient_vapor_density_kg_per_m3=0.010,
            initial_vapor_density_kg_per_m3=0.010,
            nighttime_air_temperature_c=28.0,
        )

        result = assess_nocturnal_humidity(
            inputs=inputs,
            night_duration_hours=8.0,
            target_relative_humidity_percent=80.0,
            allowed_consecutive_hours_above_target=3.0,
        )

        self.assertGreaterEqual(
            result.source_rate_limit_for_80_percent_kg_per_s,
            result.source_rate_limit_for_three_hour_rule_kg_per_s,
        )

    def test_short_horizon_has_lower_uncertainty_when_errors_grow_with_lead(self) -> None:
        forecasts = (
            ETForecast(1, 5.0, 0.3),
            ETForecast(2, 5.0, 0.6),
            ETForecast(3, 5.0, 0.9),
            ETForecast(4, 5.0, 1.2),
            ETForecast(5, 5.0, 1.5),
            ETForecast(6, 5.0, 1.8),
            ETForecast(7, 5.0, 2.1),
        )
        soil = SoilWaterState(
            initial_deficit_mm=10.0,
            total_available_water_mm=80.0,
            readily_available_water_mm=40.0,
            maximum_daily_irrigation_mm=10.0,
            remaining_water_budget_mm=50.0,
            irrigation_efficiency=0.9,
        )

        one_day = optimize_et_irrigation_horizon(forecasts, soil, 1)
        seven_day = optimize_et_irrigation_horizon(forecasts, soil, 7)

        self.assertLess(
            one_day.forecast_uncertainty_penalty_mm,
            seven_day.forecast_uncertainty_penalty_mm,
        )

    def test_horizon_selection_returns_feasible_plan(self) -> None:
        forecasts = (
            ETForecast(1, 4.0, 0.2),
            ETForecast(2, 4.2, 0.3),
            ETForecast(3, 4.1, 0.4),
            ETForecast(4, 4.5, 0.7),
            ETForecast(5, 4.6, 0.9),
            ETForecast(6, 4.8, 1.1),
            ETForecast(7, 5.0, 1.3),
        )
        soil = SoilWaterState(
            initial_deficit_mm=15.0,
            total_available_water_mm=90.0,
            readily_available_water_mm=45.0,
            maximum_daily_irrigation_mm=12.0,
            remaining_water_budget_mm=60.0,
            irrigation_efficiency=0.9,
        )

        result = select_optimal_et_horizon(forecasts, soil)

        self.assertIn(result.horizon_days, (1, 3, 7))
        self.assertTrue(result.feasible)
        self.assertLessEqual(result.total_applied_irrigation_mm, 60.0)


if __name__ == "__main__":
    unittest.main()
