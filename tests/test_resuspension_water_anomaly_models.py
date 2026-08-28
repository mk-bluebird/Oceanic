import unittest

from python.resuspension_water_anomaly_models import (
    AnomalyPolicy,
    RobustControlChartModel,
    SurfaceResuspensionInputs,
    WaterQualityObservation,
    calculate_resuspension_dose,
    evaluate_anomaly_policy,
    select_balanced_anomaly_threshold,
)


IDENTITY_6 = (
    (1.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    (0.0, 1.0, 0.0, 0.0, 0.0, 0.0),
    (0.0, 0.0, 1.0, 0.0, 0.0, 0.0),
    (0.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    (0.0, 0.0, 0.0, 0.0, 1.0, 0.0),
    (0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
)


class ResuspensionWaterAnomalyModelsTests(unittest.TestCase):
    def test_resuspension_coefficient_increases_with_shear(self) -> None:
        base = SurfaceResuspensionInputs(
            surface_loading_organisms_per_m2=1_000.0,
            k_resusp_reference_per_s=1e-6,
            reference_friction_velocity_m_per_s=0.2,
            friction_velocity_m_per_s=0.2,
            shear_exponent=3.0,
            roughness_multiplier=1.0,
            turbulence_multiplier=1.0,
            pedestrian_disturbance_multiplier=1.0,
            receptor_mixing_volume_m3=10.0,
            breathing_rate_m3_per_hour=1.0,
            exposure_duration_hours=1.0,
            viable_fraction=0.5,
            deposition_fraction=0.5,
        )
        windy = SurfaceResuspensionInputs(
            **{
                **base.__dict__,
                "friction_velocity_m_per_s": 0.4,
            }
        )

        base_result = calculate_resuspension_dose(base)
        windy_result = calculate_resuspension_dose(windy)

        self.assertGreater(
            windy_result.effective_resuspension_coefficient_per_s,
            base_result.effective_resuspension_coefficient_per_s,
        )
        self.assertGreater(
            windy_result.inhaled_deposited_dose_organisms,
            base_result.inhaled_deposited_dose_organisms,
        )

    def test_control_chart_detects_persistent_treatment_upset(self) -> None:
        model = RobustControlChartModel(
            medians=(1.0, 500.0, 7.2, 1.0, 25.0, 1.0),
            robust_scales=(0.2, 30.0, 0.1, 0.1, 1.0, 0.1),
            inverse_correlation=IDENTITY_6,
        )
        observations = (
            WaterQualityObservation(1.0, 500.0, 7.2, 1.0, 25.0, 1.0, "t0"),
            WaterQualityObservation(1.1, 510.0, 7.25, 0.95, 25.2, 1.0, "t1"),
            WaterQualityObservation(5.0, 700.0, 6.7, 0.2, 30.0, 1.5, "t2"),
            WaterQualityObservation(5.2, 710.0, 6.6, 0.2, 30.5, 1.5, "t3"),
            WaterQualityObservation(5.1, 705.0, 6.7, 0.2, 30.2, 1.5, "t4"),
        )
        baseline = (True, True, False, False, False)
        upset = (False, False, True, True, True)

        result = evaluate_anomaly_policy(
            observations=observations,
            baseline_labels=baseline,
            upset_labels=upset,
            model=model,
            policy=AnomalyPolicy(
                alarm_threshold=20.0,
                persistence_samples=2,
                maximum_false_alarm_rate_per_day=0.05,
            ),
            sample_interval_minutes=5.0,
        )

        self.assertEqual(result.false_alarm_rate, 0.0)
        self.assertGreater(result.true_positive_rate, 0.0)
        self.assertEqual(result.detection_delay_minutes, 5.0)

    def test_threshold_selection_enforces_alarm_budget(self) -> None:
        model = RobustControlChartModel(
            medians=(1.0, 500.0, 7.2, 1.0, 25.0, 1.0),
            robust_scales=(0.2, 30.0, 0.1, 0.1, 1.0, 0.1),
            inverse_correlation=IDENTITY_6,
        )
        observations = (
            WaterQualityObservation(1.0, 500.0, 7.2, 1.0, 25.0, 1.0, "t0"),
            WaterQualityObservation(1.2, 520.0, 7.3, 0.9, 25.5, 1.1, "t1"),
            WaterQualityObservation(4.0, 680.0, 6.8, 0.2, 29.0, 1.4, "t2"),
            WaterQualityObservation(4.1, 690.0, 6.8, 0.2, 29.5, 1.4, "t3"),
        )
        baseline = (True, True, False, False)
        upset = (False, False, True, True)

        result = select_balanced_anomaly_threshold(
            observations=observations,
            baseline_labels=baseline,
            upset_labels=upset,
            model=model,
            candidate_thresholds=(10.0, 20.0, 50.0),
            persistence_samples=2,
            maximum_false_alarm_rate=0.10,
            sample_interval_minutes=5.0,
        )

        self.assertLessEqual(result.false_alarm_rate, 0.10)
        self.assertGreaterEqual(result.true_positive_rate, 0.0)


if __name__ == "__main__":
    unittest.main()
