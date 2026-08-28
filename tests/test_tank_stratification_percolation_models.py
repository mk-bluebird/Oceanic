import unittest

from python.tank_stratification_percolation_models import (
    HexCell,
    StorageTankThermalInputs,
    assess_percolation_corridor,
    assess_tank_amplification_window,
    static_tank_temperature_c,
    tank_temperature_after_fill_c,
)


class TankStratificationPercolationModelsTests(unittest.TestCase):
    def test_solar_warming_decays_with_depth(self) -> None:
        inputs = StorageTankThermalInputs(
            total_water_depth_m=4.0,
            ambient_air_temperature_c=28.0,
            radiative_surface_warming_c=10.0,
            radiative_penetration_depth_m=0.5,
            evaporative_surface_cooling_c=1.0,
            evaporative_depth_m=0.2,
            tank_surface_area_m2=100.0,
            tank_volume_m3=400.0,
            fill_flow_m3_per_s=0.01,
            fill_mixing_efficiency=0.7,
            incoming_water_temperature_c=22.0,
        )

        surface = static_tank_temperature_c(0.0, inputs)
        deep = static_tank_temperature_c(3.0, inputs)

        self.assertGreater(surface, deep)

    def test_filling_cools_and_mixes_warm_surface_layer(self) -> None:
        inputs = StorageTankThermalInputs(
            total_water_depth_m=4.0,
            ambient_air_temperature_c=30.0,
            radiative_surface_warming_c=12.0,
            radiative_penetration_depth_m=0.5,
            evaporative_surface_cooling_c=1.0,
            evaporative_depth_m=0.2,
            tank_surface_area_m2=100.0,
            tank_volume_m3=50.0,
            fill_flow_m3_per_s=0.02,
            fill_mixing_efficiency=0.9,
            incoming_water_temperature_c=20.0,
        )

        result = tank_temperature_after_fill_c(
            depth_m=0.0,
            inputs=inputs,
            fill_duration_hours=2.0,
        )

        self.assertLess(result.mixed_temperature_c, result.static_temperature_c)

    def test_twelve_hour_temperature_window_is_detected(self) -> None:
        hourly_inputs = tuple(
            StorageTankThermalInputs(
                total_water_depth_m=2.0,
                ambient_air_temperature_c=30.0,
                radiative_surface_warming_c=5.0,
                radiative_penetration_depth_m=0.8,
                evaporative_surface_cooling_c=0.0,
                evaporative_depth_m=0.2,
                tank_surface_area_m2=20.0,
                tank_volume_m3=40.0,
                fill_flow_m3_per_s=0.0,
                fill_mixing_efficiency=0.0,
                incoming_water_temperature_c=20.0,
            )
            for _ in range(13)
        )

        assessment = assess_tank_amplification_window(
            inputs_by_hour=hourly_inputs,
            fill_duration_hours_by_hour=(0.0,) * 13,
            depth_increment_m=0.5,
        )

        self.assertTrue(assessment.exceeds_twelve_hour_persistence_limit)
        self.assertIsNotNone(assessment.shallowest_depth_above_threshold_m)

    def test_finite_hex_lattice_finds_minimum_restoration_path(self) -> None:
        cells = (
            HexCell(0, 0, resistance=0.1, resistance_threshold=0.5, role="salt_river"),
            HexCell(1, 0, resistance=0.8, resistance_threshold=0.5, role="intermediate"),
            HexCell(2, 0, resistance=0.2, resistance_threshold=0.5, role="mountains_preserve"),
            HexCell(1, -1, resistance=0.9, resistance_threshold=0.5, role="intermediate"),
        )

        result = assess_percolation_corridor(
            cells=cells,
            restoration_cost_per_cell=10_000.0,
        )

        self.assertFalse(result.salt_river_to_mountains_connected)
        self.assertEqual(result.minimum_additional_cells_for_connection, 1)
        self.assertEqual(result.minimum_restoration_investment, 10_000.0)

    def test_connected_lattice_requires_no_additional_cells(self) -> None:
        cells = (
            HexCell(0, 0, resistance=0.1, resistance_threshold=0.5, role="salt_river"),
            HexCell(1, 0, resistance=0.2, resistance_threshold=0.5, role="intermediate"),
            HexCell(2, 0, resistance=0.2, resistance_threshold=0.5, role="mountains_preserve"),
        )

        result = assess_percolation_corridor(
            cells=cells,
            restoration_cost_per_cell=10_000.0,
        )

        self.assertTrue(result.salt_river_to_mountains_connected)
        self.assertEqual(result.minimum_additional_cells_for_connection, 0)


if __name__ == "__main__":
    unittest.main()
