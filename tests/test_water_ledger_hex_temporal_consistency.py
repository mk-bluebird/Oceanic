import unittest

from python.water_ledger_hex_temporal_consistency import (
    PilotWaterLedgerEntry,
    ThermalAnomalyObservation,
    assess_hex_temporal_consistency,
    summarize_land_use_decorrelation,
    summarize_water_ledger,
)


class WaterLedgerHexTemporalConsistencyTests(unittest.TestCase):
    def test_water_ledger_separates_counterfactual_evaporation(self) -> None:
        summary = summarize_water_ledger(
            (
                PilotWaterLedgerEntry(
                    interval_label="hour-1",
                    extracted_m3=10.0,
                    treated_m3=8.0,
                    evaporated_total_m3=4.0,
                    counterfactual_atmospheric_vapor_m3=1.0,
                    discharged_m3=3.0,
                    recovered_m3=0.0,
                    storage_change_m3=3.0,
                    measurement_uncertainty_m3=0.1,
                ),
            )
        )

        self.assertEqual(summary.gross_evaporated_m3, 4.0)
        self.assertEqual(summary.attributable_evaporated_m3, 3.0)
        self.assertEqual(summary.mass_balance_residual_m3, 0.0)
        self.assertTrue(summary.mass_balance_within_uncertainty)

    def test_ledger_detects_unreconciled_mass_balance(self) -> None:
        summary = summarize_water_ledger(
            (
                PilotWaterLedgerEntry(
                    interval_label="hour-1",
                    extracted_m3=10.0,
                    treated_m3=10.0,
                    evaporated_total_m3=3.0,
                    counterfactual_atmospheric_vapor_m3=0.5,
                    discharged_m3=2.0,
                    recovered_m3=0.0,
                    storage_change_m3=1.0,
                    measurement_uncertainty_m3=0.1,
                ),
            )
        )

        self.assertFalse(summary.mass_balance_within_uncertainty)
        self.assertGreater(abs(summary.mass_balance_residual_m3), 0.1)

    def test_low_autocorrelation_requests_versioned_recalibration(self) -> None:
        observations = (
            ThermalAnomalyObservation(0, 0.0, "impervious_commercial", 0.9),
            ThermalAnomalyObservation(1, 3.0, "impervious_commercial", 0.9),
            ThermalAnomalyObservation(2, -3.0, "impervious_commercial", 0.9),
            ThermalAnomalyObservation(3, 3.0, "impervious_commercial", 0.9),
            ThermalAnomalyObservation(4, -3.0, "impervious_commercial", 0.9),
        )

        result = assess_hex_temporal_consistency(
            observations=observations,
            lag_steps=1,
            update_threshold=0.5,
        )

        self.assertTrue(result.calibration_update_required)
        self.assertLess(result.autocorrelation, 0.5)

    def test_land_use_summary_groups_series(self) -> None:
        observations = (
            ThermalAnomalyObservation(0, 0.0, "riparian_restoration", 0.95),
            ThermalAnomalyObservation(1, 1.0, "riparian_restoration", 0.95),
            ThermalAnomalyObservation(2, 0.1, "riparian_restoration", 0.95),
            ThermalAnomalyObservation(0, 0.0, "impervious_commercial", 0.90),
            ThermalAnomalyObservation(1, 3.0, "impervious_commercial", 0.90),
            ThermalAnomalyObservation(2, -3.0, "impervious_commercial", 0.90),
        )

        result = summarize_land_use_decorrelation(observations)

        self.assertIn("riparian_restoration", result)
        self.assertIn("impervious_commercial", result)


if __name__ == "__main__":
    unittest.main()
