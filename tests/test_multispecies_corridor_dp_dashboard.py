import unittest

from python.multispecies_corridor_dp_dashboard import (
    CorridorDesign,
    DashboardOperationalSnapshot,
    DifferentialPrivacyPolicy,
    SpeciesConnectivityRequirement,
    build_governance_dashboard,
    optimize_multispecies_corridor,
    release_dp_count,
)


class MultispeciesCorridorDpDashboardTests(unittest.TestCase):
    def test_maximin_design_protects_lowest_connectivity_species(self) -> None:
        requirements = (
            SpeciesConnectivityRequirement(
                species_name="desert_pollinator",
                weight=1.0,
                minimum_core_width_m=15.0,
                edge_effect_width_m=5.0,
                mobility_range_m=300.0,
                maximum_gap_m=200.0,
                resistance_scale=10.0,
                minimum_connectivity=0.30,
                required_vegetation_quality=0.70,
            ),
            SpeciesConnectivityRequirement(
                species_name="ground_dweller",
                weight=1.0,
                minimum_core_width_m=40.0,
                edge_effect_width_m=15.0,
                mobility_range_m=100.0,
                maximum_gap_m=100.0,
                resistance_scale=10.0,
                minimum_connectivity=0.30,
                required_vegetation_quality=0.80,
            ),
        )
        designs = (
            CorridorDesign(
                design_name="narrow-floral-strip",
                position_id="alignment-a",
                total_width_m=30.0,
                path_resistance_by_species={
                    "desert_pollinator": 2.0,
                    "ground_dweller": 2.0,
                },
                vegetation_quality_by_species={
                    "desert_pollinator": 0.95,
                    "ground_dweller": 0.90,
                },
                restoration_cost=50.0,
            ),
            CorridorDesign(
                design_name="wide-layered-corridor",
                position_id="alignment-b",
                total_width_m=80.0,
                path_resistance_by_species={
                    "desert_pollinator": 3.0,
                    "ground_dweller": 3.0,
                },
                vegetation_quality_by_species={
                    "desert_pollinator": 0.90,
                    "ground_dweller": 0.90,
                },
                restoration_cost=90.0,
            ),
        )

        result = optimize_multispecies_corridor(
            designs=designs,
            requirements=requirements,
            maximum_restoration_cost=100.0,
        )

        self.assertEqual(result.selected_design_name, "wide-layered-corridor")
        self.assertTrue(result.meets_all_species_minimums)
        self.assertGreaterEqual(result.minimum_species_connectivity, 0.30)

    def test_dp_count_is_suppressed_for_small_groups(self) -> None:
        policy = DifferentialPrivacyPolicy(
            epsilon_per_release=0.5,
            total_epsilon_budget=2.0,
            minimum_aggregation_count=20,
        )
        released = release_dp_count(
            metric_name="complaint_reports",
            raw_count=8,
            contribution_limit=1,
            policy=policy,
            cumulative_epsilon_spent=0.0,
            seed=7,
        )

        self.assertIsNone(released.released_count)
        self.assertEqual(
            released.suppression_reason,
            "below_minimum_aggregation_count",
        )

    def test_dp_count_reports_epsilon_likelihood_bound(self) -> None:
        policy = DifferentialPrivacyPolicy(
            epsilon_per_release=0.5,
            total_epsilon_budget=2.0,
            minimum_aggregation_count=5,
        )
        released = release_dp_count(
            metric_name="maintenance_report_count",
            raw_count=25,
            contribution_limit=1,
            policy=policy,
            cumulative_epsilon_spent=0.0,
            seed=11,
        )

        self.assertIsNotNone(released.released_count)
        self.assertGreater(released.privacy_likelihood_ratio_bound, 1.0)
        self.assertLess(released.privacy_likelihood_ratio_bound, 2.0)

    def test_dashboard_retains_exact_non_personal_operational_metrics(self) -> None:
        operational = DashboardOperationalSnapshot(
            observed_at_utc="2026-08-27T22:39:00Z",
            water_use_rate_l_per_min=15.0,
            treatment_status="verified_operational",
            aerosol_risk_level="low",
            thermal_benefit_wbgt_reduction_c=1.2,
            operational_state="operating_with_reviewable_corridors",
            data_quality_factor=0.95,
        )
        policy = DifferentialPrivacyPolicy()
        dashboard = build_governance_dashboard(
            operational=operational,
            private_aggregates=(),
            privacy_policy=policy,
            grievance_status="accessible_review_channel_available",
            review_status="independent_audit_current",
        )

        self.assertEqual(
            dashboard.operational.water_use_rate_l_per_min,
            15.0,
        )
        self.assertEqual(
            dashboard.operational.aerosol_risk_level,
            "low",
        )


if __name__ == "__main__":
    unittest.main()
