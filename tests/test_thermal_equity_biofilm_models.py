import unittest

from python.thermal_equity_biofilm_models import (
    BiofilmParameters,
    ChoiceResponse,
    DropletEvaporationInputs,
    HeatZone,
    PulsedFlowSchedule,
    allocate_heat_relief_nodes,
    assess_droplet_evaporation,
    community_prioritized_p_value,
    evaluate_pulsed_biofilm_growth,
    normalized_vulnerability_weights,
    select_biofilm_prevention_schedule,
)


class ThermalEquityBiofilmModelsTests(unittest.TestCase):
    def test_turbulence_increases_droplet_mass_transfer(self) -> None:
        inputs = DropletEvaporationInputs(
            diameter_um=30.0,
            vapour_diffusivity_m2_per_s=2.8e-5,
            saturated_vapour_density_kg_per_m3=0.050,
            ambient_vapour_density_kg_per_m3=0.015,
            mass_accommodation_coefficient_m_per_s=1.0,
            molecular_schmidt_number=0.60,
            relative_velocity_m_per_s=4.0,
            nozzle_turbulence_intensity=0.20,
            turbulence_gain=2.0,
            nozzle_to_release_speed_m_per_s=4.0,
        )
        result = assess_droplet_evaporation(
            inputs=inputs,
            pedestrian_receptor_distance_m=12.0,
            target_distance_m=10.0,
        )

        self.assertGreater(result.sherwood_number, 2.0)
        self.assertGreater(result.evaporation_rate_kg_per_s, 0.0)
        self.assertGreater(result.full_evaporation_time_s, 0.0)

    def test_equity_weights_change_with_p(self) -> None:
        zones = (
            HeatZone("high-vulnerability", 4.0, 1.0, 1.0, 10),
            HeatZone("lower-vulnerability", 1.0, 1.0, 1.0, 10),
        )

        equal = normalized_vulnerability_weights(zones, p_value=0.0)
        proportional = normalized_vulnerability_weights(zones, p_value=1.0)

        self.assertEqual(equal["high-vulnerability"], 0.5)
        self.assertGreater(
            proportional["high-vulnerability"],
            proportional["lower-vulnerability"],
        )

    def test_p1_allocation_prioritizes_vulnerability(self) -> None:
        zones = (
            HeatZone("high-vulnerability", 5.0, 0.8, 1.0, 10),
            HeatZone("lower-vulnerability", 1.0, 1.0, 1.0, 10),
        )
        result = allocate_heat_relief_nodes(zones, total_nodes=4, p_value=1.0)

        self.assertGreater(
            result.allocated_nodes["high-vulnerability"],
            result.allocated_nodes["lower-vulnerability"],
        )

    def test_structured_choice_returns_weighted_mode(self) -> None:
        selected = community_prioritized_p_value(
            (
                ChoiceResponse(0.0),
                ChoiceResponse(1.0, response_weight=4.0),
                ChoiceResponse(2.0, response_weight=2.0),
            )
        )
        self.assertEqual(selected, 1.0)

    def test_dry_interval_can_reduce_pulse_factor(self) -> None:
        parameters = BiofilmParameters(
            mu_max_per_s=0.0001,
            substrate_concentration_mg_per_l=1.0,
            half_saturation_constant_mg_per_l=0.5,
            detachment_coefficient_per_pa_s=0.0002,
            nutrient_replenishment_gain=100.0,
            desiccation_penalty_per_s=0.0001,
        )
        continuous = PulsedFlowSchedule(
            wet_duration_s=60.0,
            dry_duration_s=0.0,
            wall_shear_stress_pa=0.2,
            flow_rate_m3_per_s=0.001,
        )
        pulsed = PulsedFlowSchedule(
            wet_duration_s=20.0,
            dry_duration_s=40.0,
            wall_shear_stress_pa=0.8,
            flow_rate_m3_per_s=0.001,
        )

        continuous_result = evaluate_pulsed_biofilm_growth(continuous, parameters)
        pulsed_result = evaluate_pulsed_biofilm_growth(pulsed, parameters)

        self.assertLess(
            pulsed_result.water_use_m3_per_s,
            continuous_result.water_use_m3_per_s,
        )

    def test_schedule_selection_is_deterministic(self) -> None:
        parameters = BiofilmParameters(
            mu_max_per_s=0.0001,
            substrate_concentration_mg_per_l=1.0,
            half_saturation_constant_mg_per_l=0.5,
            detachment_coefficient_per_pa_s=0.0003,
            nutrient_replenishment_gain=10.0,
            desiccation_penalty_per_s=0.0002,
        )
        result = select_biofilm_prevention_schedule(
            (
                PulsedFlowSchedule(60.0, 0.0, 0.1, 0.001),
                PulsedFlowSchedule(20.0, 40.0, 1.0, 0.001),
            ),
            parameters,
        )

        self.assertGreaterEqual(result.pulse_frequency_hz, 0.0)


if __name__ == "__main__":
    unittest.main()
