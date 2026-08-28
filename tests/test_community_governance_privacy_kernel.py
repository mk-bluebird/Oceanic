import unittest

from python.community_governance_privacy_kernel import (
    GovernanceReadiness,
    HeatNeedIndicator,
    HeatNeedProfile,
    PrivacyPolicy,
    equity_weights,
    release_bounded_dp_count,
)


class CommunityGovernancePrivacyKernelTests(unittest.TestCase):
    def test_equity_sensitivity_changes_aggregate_planning_weights(self) -> None:
        profiles = (
            HeatNeedProfile(
                planning_area_id="area-high-need",
                indicators=(
                    HeatNeedIndicator("heat_exposure", 0.9, 1.0, 0.05),
                    HeatNeedIndicator("cooling_access_deficit", 0.8, 1.0, 0.10),
                ),
            ),
            HeatNeedProfile(
                planning_area_id="area-lower-need",
                indicators=(
                    HeatNeedIndicator("heat_exposure", 0.3, 1.0, 0.05),
                    HeatNeedIndicator("cooling_access_deficit", 0.2, 1.0, 0.10),
                ),
            ),
        )

        equal = equity_weights(profiles, equity_sensitivity_p=0.0)
        proportional = equity_weights(profiles, equity_sensitivity_p=1.0)

        self.assertEqual(equal["area-high-need"], 0.5)
        self.assertGreater(
            proportional["area-high-need"],
            proportional["area-lower-need"],
        )

    def test_small_group_is_suppressed_before_public_count_release(self) -> None:
        policy = PrivacyPolicy(
            epsilon_per_release=0.5,
            epsilon_period_budget=2.0,
            minimum_aggregation_count=20,
            contribution_limit_per_person=1,
        )

        release = release_bounded_dp_count(
            metric_name="access_barrier_reports",
            raw_aggregate_count=8,
            cumulative_epsilon_spent=0.0,
            policy=policy,
            seed=1,
        )

        self.assertTrue(release.suppressed)
        self.assertIsNone(release.released_aggregate_count)
        self.assertEqual(
            release.suppression_reason,
            "below_minimum_aggregation_count",
        )

    def test_dp_count_exposes_likelihood_ratio_not_posterior_claim(self) -> None:
        policy = PrivacyPolicy(
            epsilon_per_release=0.5,
            epsilon_period_budget=2.0,
            minimum_aggregation_count=20,
            contribution_limit_per_person=1,
        )

        release = release_bounded_dp_count(
            metric_name="aggregated_maintenance_reports",
            raw_aggregate_count=40,
            cumulative_epsilon_spent=0.0,
            policy=policy,
            seed=7,
        )

        self.assertFalse(release.suppressed)
        self.assertIsNotNone(release.released_aggregate_count)
        self.assertGreater(release.likelihood_ratio_bound, 1.0)
        self.assertLess(release.likelihood_ratio_bound, 2.0)

    def test_governance_readiness_requires_all_public_rights_artifacts(self) -> None:
        readiness = GovernanceReadiness(
            vulnerability_method_published=True,
            participation_record_published=True,
            dissent_record_published=True,
            accessibility_supports_available=True,
            grievance_channel_available=True,
            privacy_policy_published=True,
            privacy_budget_within_limit=True,
            dashboard_excludes_person_linked_fields=True,
            review_date_published=True,
            uncertainty_statement_published=True,
        )

        self.assertEqual(readiness.rights_alignment, 1.0)
        self.assertTrue(readiness.ready_for_public_decision_support)


if __name__ == "__main__":
    unittest.main()
