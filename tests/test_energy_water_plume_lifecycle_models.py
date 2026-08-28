import unittest

from python.energy_water_plume_lifecycle_models import (
    AnnualLifecycleRecord,
    BuoyantPlumeInputs,
    ComputeWorkload,
    IrrigationDemand,
    TimeSlot,
    compare_misting_and_tree_lifecycle,
    droplet_diameter_at_plume_equilibrium,
    optimize_energy_water_schedule,
)


class EnergyWaterPlumeLifecycleModelsTests(unittest.TestCase):
    def test_scheduler_avoids_peak_when_deadline_allows(self) -> None:
        slots = (
            TimeSlot(
                label="pre-dawn",
                duration_hours=1.0,
                energy_price_usd_per_kwh=0.09,
                grid_carbon_kgco2e_per_kwh=0.30,
                grid_peak_weight=0.2,
                irrigation_allowed=True,
                irrigation_efficiency=0.92,
                canopy_stress_reduction_per_m3=1.0,
                soil_warming_benefit_per_kwh=0.1,
                remote_sensing_deadline_priority=0.5,
            ),
            TimeSlot(
                label="afternoon-peak",
                duration_hours=1.0,
                energy_price_usd_per_kwh=0.26,
                grid_carbon_kgco2e_per_kwh=0.55,
                grid_peak_weight=1.0,
                irrigation_allowed=False,
                irrigation_efficiency=0.0,
                canopy_stress_reduction_per_m3=0.0,
                soil_warming_benefit_per_kwh=0.0,
                remote_sensing_deadline_priority=1.0,
            ),
        )
        workloads = (
            ComputeWorkload(
                workload_id="irrigation-forecast",
                workload_type="irrigation_model",
                energy_kwh=1.0,
                deadline_slot_index=1,
            ),
            ComputeWorkload(
                workload_id="canopy-imagery",
                workload_type="remote_sensing",
                energy_kwh=2.0,
                deadline_slot_index=1,
            ),
        )
        irrigation = IrrigationDemand(
            required_root_zone_water_m3=5.0,
            daily_water_budget_m3=6.0,
        )

        result = optimize_energy_water_schedule(
            slots=slots,
            workloads=workloads,
            irrigation=irrigation,
            peak_penalty_weight=2.0,
            carbon_penalty_weight=1.0,
        )

        self.assertEqual(result.irrigation_slot_label, "pre-dawn")
        self.assertTrue(result.all_required_workloads_scheduled)
        self.assertTrue(
            all(item.slot_label == "pre-dawn" for item in result.scheduled_workloads)
        )

    def test_droplet_equilibrium_balances_updraft(self) -> None:
        inputs = BuoyantPlumeInputs(
            surface_temperature_c=65.0,
            air_temperature_c=42.0,
            plume_velocity_reference_m_per_s=0.25,
            reference_height_m=1.0,
            roughness_length_m=0.05,
            plume_decay_exponent=0.35,
            measurement_height_m=1.5,
        )

        result = droplet_diameter_at_plume_equilibrium(inputs)

        self.assertGreater(result.plume_updraft_m_per_s, 0.0)
        self.assertGreater(result.droplet_diameter_equilibrium_um, 0.0)
        self.assertAlmostEqual(result.net_settling_velocity_m_per_s, 0.0, places=9)

    def test_lifecycle_crossover_detected(self) -> None:
        misting = []
        tree = []
        for year in range(1, 31):
            misting.append(
                AnnualLifecycleRecord(
                    embodied_kgco2e=1_000.0 if year in (1, 16) else 0.0,
                    operations_kgco2e=250.0 if year <= 30 else 0.0,
                    water_kgco2e=50.0 if year <= 30 else 0.0,
                    maintenance_kgco2e=25.0 if year <= 30 else 0.0,
                    end_of_life_kgco2e=200.0 if year == 30 else 0.0,
                    sequestration_kgco2e=0.0,
                    avoided_cooling_emissions_kgco2e=400.0 if year <= 30 else 0.0,
                )
            )
            tree.append(
                AnnualLifecycleRecord(
                    embodied_kgco2e=500.0 if year == 1 else 0.0,
                    operations_kgco2e=0.0,
                    water_kgco2e=30.0 if year <= 5 else 10.0,
                    maintenance_kgco2e=20.0,
                    end_of_life_kgco2e=0.0,
                    sequestration_kgco2e=50.0 * year,
                    avoided_cooling_emissions_kgco2e=20.0 * year,
                )
            )

        result = compare_misting_and_tree_lifecycle(misting, tree)

        self.assertIsNotNone(
            result.tree_sequestration_exceeds_misting_avoided_benefit_year
        )
        self.assertIsNotNone(result.tree_net_outperforms_misting_year)


if __name__ == "__main__":
    unittest.main()
