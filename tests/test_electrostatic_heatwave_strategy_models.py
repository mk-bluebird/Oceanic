import unittest

from python.electrostatic_heatwave_strategy_models import (
    ChargedDropletInputs,
    HeatStrategy,
    HeatWaveHour,
    assess_electrostatic_deposition,
    compare_heatwave_strategies,
)


class ElectrostaticHeatwaveStrategyModelsTests(unittest.TestCase):
    def test_charge_increases_image_force_surface_velocity(self) -> None:
        low_charge = ChargedDropletInputs(
            droplet_diameter_um=20.0,
            charge_to_mass_c_per_kg=1e-6,
            distance_to_surface_m=0.01,
        )
        higher_charge = ChargedDropletInputs(
            droplet_diameter_um=20.0,
            charge_to_mass_c_per_kg=1e-4,
            distance_to_surface_m=0.01,
        )

        low = assess_electrostatic_deposition(low_charge)
        high = assess_electrostatic_deposition(higher_charge)

        self.assertGreater(
            high.image_force_velocity_m_per_s,
            low.image_force_velocity_m_per_s,
        )
        self.assertGreater(
            high.charge_to_mass_significance_threshold_c_per_kg,
            0.0,
        )

    def test_heatwave_comparison_records_water_and_accessible_benefit(self) -> None:
        hours = (
            HeatWaveHour(
                hour_index=0,
                ambient_temperature_c=46.0,
                baseline_wbgt_c=39.0,
                solar_load_w_per_m2=850.0,
                relative_humidity_percent=20.0,
                wind_speed_m_per_s=2.0,
                vulnerable_population_weight=2.0,
            ),
            HeatWaveHour(
                hour_index=1,
                ambient_temperature_c=47.0,
                baseline_wbgt_c=40.0,
                solar_load_w_per_m2=900.0,
                relative_humidity_percent=45.0,
                wind_speed_m_per_s=2.0,
                vulnerable_population_weight=2.0,
            ),
        )
        strategies = (
            HeatStrategy(
                name="cyboquatic",
                static_wbgt_reduction_c=3.0,
                water_l_per_hour=100.0,
                base_failure_probability=0.05,
                heat_failure_sensitivity_per_c=0.02,
                humidity_performance_sensitivity=0.8,
                solar_performance_sensitivity_per_kw_m2=0.0,
                wind_performance_sensitivity_per_m_s=0.0,
                vulnerable_accessibility_fraction=0.8,
            ),
            HeatStrategy(
                name="shade",
                static_wbgt_reduction_c=4.0,
                water_l_per_hour=0.0,
                base_failure_probability=0.01,
                heat_failure_sensitivity_per_c=0.005,
                humidity_performance_sensitivity=0.0,
                solar_performance_sensitivity_per_kw_m2=0.2,
                wind_performance_sensitivity_per_m_s=0.0,
                vulnerable_accessibility_fraction=0.9,
            ),
        )

        result = compare_heatwave_strategies(hours, strategies)

        self.assertEqual(result.total_water_l_by_strategy["shade"], 0.0)
        self.assertGreater(result.total_water_l_by_strategy["cyboquatic"], 0.0)
        self.assertGreater(
            result.vulnerable_population_benefit_by_strategy["shade"],
            0.0,
        )
        self.assertLess(
            result.mean_wbgt_reduction_by_strategy["cyboquatic"],
            3.0,
        )


if __name__ == "__main__":
    unittest.main()
