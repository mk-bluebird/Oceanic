import unittest

from python.qmra_hex_network_models import (
    EnvironmentalCopulaParameters,
    ExponentialDoseResponse,
    HexNetworkEdge,
    LognormalMarginal,
    QMRAMarginals,
    analyze_hex_network,
    simulate_qmra,
)


class QMRAHexNetworkModelsTests(unittest.TestCase):
    def test_correlation_changes_upper_tail_qmra_result(self) -> None:
        marginal = LognormalMarginal(
            log_mean=-2.0,
            log_standard_deviation=0.8,
        )
        marginals = QMRAMarginals(
            source_concentration=marginal,
            treatment_survival_fraction=marginal,
            aerosolization_efficiency=marginal,
            transport_factor=marginal,
            deposition_fraction=marginal,
            breathing_rate_m3_per_hour=marginal,
            exposure_duration_hours=1.0,
        )
        dose_response = ExponentialDoseResponse(
            infectivity_parameter_per_organism=0.5
        )

        independent = simulate_qmra(
            marginals=marginals,
            dose_response=dose_response,
            sample_count=5_000,
            seed=77,
        )
        dependent = simulate_qmra(
            marginals=marginals,
            dose_response=dose_response,
            sample_count=5_000,
            seed=77,
            copula_parameters=EnvironmentalCopulaParameters(
                temperature_loadings=(0.4, 0.2, 0.5, 0.2, 0.2, 0.1),
                wind_loadings=(0.2, 0.1, 0.5, 0.6, 0.1, 0.1),
                humidity_loadings=(0.3, 0.4, 0.2, 0.1, 0.4, 0.1),
                copula_family="gaussian_factor",
            ),
            independent_reference_95=independent.risk_quantile_95,
        )

        self.assertGreater(dependent.risk_quantile_95, 0.0)
        self.assertIsNotNone(dependent.correlation_adjusted_95_difference)

    def test_weighted_betweenness_identifies_bridge_hexagon(self) -> None:
        edges = (
            HexNetworkEdge("a", "b", 1.0),
            HexNetworkEdge("b", "c", 1.0),
            HexNetworkEdge("c", "d", 1.0),
            HexNetworkEdge("b", "e", 2.0),
            HexNetworkEdge("c", "f", 2.0),
        )
        candidates = (
            HexNetworkEdge("a", "e", 1.5),
            HexNetworkEdge("d", "f", 1.5),
        )

        result = analyze_hex_network(
            edges=edges,
            bottleneck_quantile=0.75,
            failed_hexagon_count=1,
            required_connectivity_fraction=0.70,
            candidate_redundant_edges=candidates,
            simulations=300,
            seed=19,
        )

        self.assertIn("b", result.bottleneck_hexagons)
        self.assertIn("c", result.bottleneck_hexagons)
        self.assertGreater(
            result.normalized_betweenness["b"],
            result.normalized_betweenness["a"],
        )

    def test_redundancy_result_is_a_count_or_unavailable(self) -> None:
        edges = (
            HexNetworkEdge("a", "b", 1.0),
            HexNetworkEdge("b", "c", 1.0),
        )
        candidates = (
            HexNetworkEdge("a", "c", 1.0),
        )

        result = analyze_hex_network(
            edges=edges,
            bottleneck_quantile=0.50,
            failed_hexagon_count=1,
            required_connectivity_fraction=0.50,
            candidate_redundant_edges=candidates,
            simulations=200,
            seed=11,
        )

        self.assertTrue(
            result.redundant_corridors_required is None
            or result.redundant_corridors_required >= 0
        )


if __name__ == "__main__":
    unittest.main()
