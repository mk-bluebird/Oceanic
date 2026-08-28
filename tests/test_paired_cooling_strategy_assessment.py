import unittest

from python.paired_cooling_strategy_assessment import (
    MatchedFieldObservation,
    ResourceWeights,
    recommend_cooling_portfolio,
    summarize_cooling_strategies,
)


class PairedCoolingStrategyAssessmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.weights = ResourceWeights(
            water_weight_per_l=0.01,
            electricity_weight_per_kwh=1.0,
            lifecycle_carbon_weight_per_kgco2e=0.5,
        )

    def observation(
        self,
        strategy_name: str,
        observed_at_utc: str,
        intervention_wbgt_c: float,
        control_wbgt_c: float,
        water_l: float,
        aerosol_state: str = "not_applicable",
        humidity_ok: bool = True,
        treatment_status: str = "verified_reference",
    ) -> MatchedFieldObservation:
        return MatchedFieldObservation(
            strategy_name=strategy_name,
            site_pair_name="matched-canyon-pair",
            observed_at_utc=observed_at_utc,
            interval_minutes=15.0,
            intervention_wbgt_c=intervention_wbgt_c,
            control_wbgt_c=control_wbgt_c,
            intervention_air_temperature_c=42.0,
            control_air_temperature_c=43.0,
            intervention_relative_humidity_percent=25.0,
            control_relative_humidity_percent=20.0,
            intervention_dew_point_c=17.0,
            control_dew_point_c=14.0,
            intervention_mean_radiant_temperature_c=55.0,
            control_mean_radiant_temperature_c=62.0,
            intervention_surface_temperature_c=45.0,
            control_surface_temperature_c=60.0,
            intervention_wind_speed_m_per_s=1.5,
            control_wind_speed_m_per_s=1.5,
            intervention_solar_radiation_w_per_m2=300.0,
            control_solar_radiation_w_per_m2=900.0,
            intervention_water_l=water_l,
            intervention_electricity_kwh=0.2,
            intervention_lifecycle_kgco2e=0.01,
            availability_fraction=0.95,
            accessible_service_fraction=0.90,
            vulnerability_weight=1.5,
            data_quality_factor=0.95,
            aerosol_eligibility_state=aerosol_state,
            humidity_corridor_satisfied=humidity_ok,
            treatment_status=treatment_status,
        )

    def test_shade_reports_positive_matched_wbgt_reduction(self) -> None:
        observations = (
            self.observation(
                "shade_structure",
                "2026-08-01T19:00:00Z",
                intervention_wbgt_c=34.0,
                control_wbgt_c=40.0,
                water_l=0.0,
            ),
        )

        summary = summarize_cooling_strategies(observations, self.weights)[0]

        self.assertEqual(summary.strategy_name, "shade_structure")
        self.assertAlmostEqual(summary.mean_wbgt_reduction_c, 6.0)
        self.assertEqual(summary.total_water_l, 0.0)
        self.assertGreater(summary.cumulative_delivered_benefit_c_minutes, 0.0)

    def test_water_based_pathway_is_excluded_when_aerosol_state_is_hold(self) -> None:
        observations = (
            self.observation(
                "contained_water_cooling",
                "2026-08-01T19:00:00Z",
                intervention_wbgt_c=35.0,
                control_wbgt_c=40.0,
                water_l=100.0,
                aerosol_state="hold_for_review",
            ),
        )

        summary = summarize_cooling_strategies(observations, self.weights)[0]

        self.assertEqual(summary.approved_observation_count, 0)
        self.assertEqual(summary.integrated_accountability_score, 0.0)
        self.assertIn("Evidence-collection only", summary.recommended_use_case)

    def test_portfolio_requires_sufficient_approved_evidence(self) -> None:
        observations = tuple(
            self.observation(
                "tree_canopy",
                f"2026-08-{day:02d}T19:00:00Z",
                intervention_wbgt_c=35.0,
                control_wbgt_c=40.0,
                water_l=5.0,
            )
            for day in range(1, 13)
        )

        summaries = summarize_cooling_strategies(observations, self.weights)
        recommendation = recommend_cooling_portfolio(
            summaries,
            minimum_approved_observations=12,
            minimum_accessible_service_fraction=0.70,
        )

        self.assertEqual(
            recommendation.evidence_status,
            "portfolio_candidates_supported_by_matched_evidence",
        )
        self.assertIn("tree_canopy", recommendation.recommended_portfolio)

    def test_humidity_failure_excludes_water_based_comparison(self) -> None:
        observations = (
            self.observation(
                "contained_water_cooling",
                "2026-08-01T19:00:00Z",
                intervention_wbgt_c=33.0,
                control_wbgt_c=40.0,
                water_l=80.0,
                aerosol_state="low",
                humidity_ok=False,
                treatment_status="verified_operational",
            ),
        )

        summary = summarize_cooling_strategies(observations, self.weights)[0]

        self.assertEqual(summary.approved_observation_count, 0)
        self.assertEqual(summary.integrated_accountability_score, 0.0)


if __name__ == "__main__":
    unittest.main()
