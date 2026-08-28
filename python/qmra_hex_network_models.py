from __future__ import annotations

from dataclasses import dataclass
from math import erf, exp, isfinite, log, sqrt
from random import Random
from statistics import NormalDist
from typing import Iterable, Mapping, Sequence


STANDARD_NORMAL = NormalDist()


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _probability(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 < value < 1.0:
        raise ValueError(f"{name} must be strictly between zero and one.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class LognormalMarginal:
    """
    Lognormal marginal distribution specified on natural-log scale.

    The QMRA model uses individual marginals for:
      source concentration,
      treatment survival fraction,
      aerosolization efficiency,
      transport factor,
      deposition fraction,
      breathing rate.

    Values must be in consistent units so that their product produces an
    inhaled pathogen dose per exposure event.
    """

    log_mean: float
    log_standard_deviation: float

    def __post_init__(self) -> None:
        if not isfinite(self.log_mean):
            raise ValueError("log_mean must be finite.")
        _positive("log_standard_deviation", self.log_standard_deviation)

    def inverse_cdf(self, uniform_value: float) -> float:
        _probability("uniform_value", uniform_value)
        return exp(
            self.log_mean
            + self.log_standard_deviation
            * STANDARD_NORMAL.inv_cdf(uniform_value)
        )


@dataclass(frozen=True)
class QMRAMarginals:
    source_concentration: LognormalMarginal
    treatment_survival_fraction: LognormalMarginal
    aerosolization_efficiency: LognormalMarginal
    transport_factor: LognormalMarginal
    deposition_fraction: LognormalMarginal
    breathing_rate_m3_per_hour: LognormalMarginal
    exposure_duration_hours: float

    def __post_init__(self) -> None:
        _positive("exposure_duration_hours", self.exposure_duration_hours)


@dataclass(frozen=True)
class EnvironmentalCopulaParameters:
    """
    Shared environmental latent factors.

    Each coefficient represents a standardized loading of an exposure input on
    a shared latent environmental state:

      Z_i = loading_temperature_i * Z_temperature
          + loading_wind_i * Z_wind
          + loading_humidity_i * Z_humidity
          + residual_i

    The residual variance is selected so each Z_i retains unit variance.

    This factor-copula form is suitable where temperature, wind, and humidity
    are measured drivers of several inputs simultaneously. It is more
    interpretable than an unconstrained correlation matrix and can be expanded
    to include diurnal or seasonal random effects.
    """

    temperature_loadings: tuple[float, float, float, float, float, float]
    wind_loadings: tuple[float, float, float, float, float, float]
    humidity_loadings: tuple[float, float, float, float, float, float]
    copula_family: str = "gaussian_factor"

    def __post_init__(self) -> None:
        if self.copula_family not in {"gaussian_factor", "t_factor"}:
            raise ValueError(
                "copula_family must be 'gaussian_factor' or 't_factor'."
            )
        vectors = (
            self.temperature_loadings,
            self.wind_loadings,
            self.humidity_loadings,
        )
        if any(len(vector) != 6 for vector in vectors):
            raise ValueError("Each environmental loading vector must contain six values.")

        for index in range(6):
            variance_explained = (
                self.temperature_loadings[index] ** 2
                + self.wind_loadings[index] ** 2
                + self.humidity_loadings[index] ** 2
            )
            if variance_explained >= 1.0:
                raise ValueError(
                    "The sum of squared latent-factor loadings must be less than one."
                )


@dataclass(frozen=True)
class ExponentialDoseResponse:
    """
    Exponential dose-response model:

      P_infection = 1 - exp(-r*dose)

    r must be selected from organism- and endpoint-specific evidence. The
    artifact does not treat it as a generic Legionella or bioaerosol constant.
    """

    infectivity_parameter_per_organism: float

    def __post_init__(self) -> None:
        _positive(
            "infectivity_parameter_per_organism",
            self.infectivity_parameter_per_organism,
        )


@dataclass(frozen=True)
class QMRASimulationResult:
    sample_count: int
    dependence_model: str
    risk_quantile_50: float
    risk_quantile_95: float
    risk_quantile_99: float
    mean_risk: float
    correlation_adjusted_95_difference: float | None
    interpretation: str


def _quantile(sorted_values: Sequence[float], probability: float) -> float:
    _probability("probability", probability)
    if not sorted_values:
        raise ValueError("sorted_values must not be empty.")

    index = probability * (len(sorted_values) - 1)
    lower = int(index)
    upper = min(lower + 1, len(sorted_values) - 1)
    weight = index - lower
    return sorted_values[lower] * (1.0 - weight) + sorted_values[upper] * weight


def _factor_copula_uniforms(
    rng: Random,
    parameters: EnvironmentalCopulaParameters,
) -> tuple[float, float, float, float, float, float]:
    """
    Draw correlated uniforms from a Gaussian or Student-t factor copula.

    The t-factor option supplies symmetric tail dependence. It is appropriate
    only when observed joint extremes justify it. A vine copula becomes
    preferable if the validated dependence is asymmetric or pair-specific.
    """
    temperature = rng.gauss(0.0, 1.0)
    wind = rng.gauss(0.0, 1.0)
    humidity = rng.gauss(0.0, 1.0)

    normal_scores: list[float] = []
    for index in range(6):
        systematic = (
            parameters.temperature_loadings[index] * temperature
            + parameters.wind_loadings[index] * wind
            + parameters.humidity_loadings[index] * humidity
        )
        residual_standard_deviation = sqrt(
            1.0
            - parameters.temperature_loadings[index] ** 2
            - parameters.wind_loadings[index] ** 2
            - parameters.humidity_loadings[index] ** 2
        )
        normal_scores.append(systematic + residual_standard_deviation * rng.gauss(0.0, 1.0))

    if parameters.copula_family == "t_factor":
        degrees_of_freedom = 5
        chi_square = sum(rng.gauss(0.0, 1.0) ** 2 for _ in range(degrees_of_freedom))
        scale = sqrt(degrees_of_freedom / chi_square)
        normal_scores = [value * scale for value in normal_scores]

    return tuple(
        min(
            1.0 - 1e-12,
            max(1e-12, STANDARD_NORMAL.cdf(score)),
        )
        for score in normal_scores
    )


def _independent_uniforms(rng: Random) -> tuple[float, float, float, float, float, float]:
    return tuple(
        min(1.0 - 1e-12, max(1e-12, rng.random()))
        for _ in range(6)
    )


def _risk_from_uniforms(
    uniforms: tuple[float, float, float, float, float, float],
    marginals: QMRAMarginals,
    dose_response: ExponentialDoseResponse,
) -> float:
    source, survival, aerosolization, transport, deposition, breathing = (
        marginals.source_concentration.inverse_cdf(value)
        for value in uniforms
    )

    dose = (
        source
        * survival
        * aerosolization
        * transport
        * deposition
        * breathing
        * marginals.exposure_duration_hours
    )
    return 1.0 - exp(-dose_response.infectivity_parameter_per_organism * dose)


def simulate_qmra(
    marginals: QMRAMarginals,
    dose_response: ExponentialDoseResponse,
    sample_count: int,
    seed: int,
    copula_parameters: EnvironmentalCopulaParameters | None = None,
    independent_reference_95: float | None = None,
) -> QMRASimulationResult:
    """
    Run Monte Carlo QMRA with either independent or dependence-aware sampling.

    The model produces event-level infection risk. Annualized risk should be
    computed only after defining exposure-event frequency, independence across
    events, and an appropriate recurrence model.
    """
    if sample_count < 1_000:
        raise ValueError("sample_count must be at least 1000 for tail estimation.")

    rng = Random(seed)
    risks: list[float] = []
    for _ in range(sample_count):
        uniforms = (
            _independent_uniforms(rng)
            if copula_parameters is None
            else _factor_copula_uniforms(rng, copula_parameters)
        )
        risks.append(_risk_from_uniforms(uniforms, marginals, dose_response))

    risks.sort()
    p95 = _quantile(risks, 0.95)
    adjusted_difference = (
        None
        if independent_reference_95 is None
        else p95 - independent_reference_95
    )

    dependence_name = (
        "independent_monte_carlo"
        if copula_parameters is None
        else copula_parameters.copula_family
    )
    interpretation = (
        "Inputs were sampled independently; the upper-tail result does not "
        "represent shared weather-driven co-occurrence."
        if copula_parameters is None
        else (
            "Inputs were sampled through measured-driver latent factors. "
            "Positive co-movement among source, aerosolization, transport, "
            "deposition, and breathing can increase upper-tail risk relative "
            "to an independent-input model."
        )
    )

    return QMRASimulationResult(
        sample_count=sample_count,
        dependence_model=dependence_name,
        risk_quantile_50=_quantile(risks, 0.50),
        risk_quantile_95=p95,
        risk_quantile_99=_quantile(risks, 0.99),
        mean_risk=sum(risks) / len(risks),
        correlation_adjusted_95_difference=adjusted_difference,
        interpretation=interpretation,
    )


@dataclass(frozen=True)
class HexNetworkEdge:
    """
    Undirected ecological corridor link.

    resistance must be strictly positive. Lower resistance represents a more
    permeable route for the focal species or ecological process.
    """

    hexagon_a: str
    hexagon_b: str
    ecological_resistance: float

    def __post_init__(self) -> None:
        if not self.hexagon_a.strip() or not self.hexagon_b.strip():
            raise ValueError("Hexagon identifiers must not be empty.")
        if self.hexagon_a == self.hexagon_b:
            raise ValueError("A corridor edge must link distinct hexagons.")
        _positive("ecological_resistance", self.ecological_resistance)


@dataclass(frozen=True)
class HexNetworkResilienceResult:
    normalized_betweenness: dict[str, float]
    bottleneck_hexagons: tuple[str, ...]
    baseline_largest_component_fraction: float
    random_failure_connectivity_threshold: float
    redundant_corridors_required: int | None
    explanation: str


def _adjacency(
    edges: Iterable[HexNetworkEdge],
    excluded_nodes: frozenset[str] = frozenset(),
) -> dict[str, dict[str, float]]:
    graph: dict[str, dict[str, float]] = {}
    for edge in edges:
        if edge.hexagon_a in excluded_nodes or edge.hexagon_b in excluded_nodes:
            continue
        graph.setdefault(edge.hexagon_a, {})[edge.hexagon_b] = edge.ecological_resistance
        graph.setdefault(edge.hexagon_b, {})[edge.hexagon_a] = edge.ecological_resistance
    return graph


def _dijkstra(
    graph: Mapping[str, Mapping[str, float]],
    source: str,
) -> tuple[dict[str, float], dict[str, list[str]]]:
    unvisited = set(graph)
    distances = {node: float("inf") for node in graph}
    predecessors = {node: [] for node in graph}
    distances[source] = 0.0

    while unvisited:
        current = min(unvisited, key=lambda node: distances[node])
        if distances[current] == float("inf"):
            break
        unvisited.remove(current)

        for neighbor, weight in graph[current].items():
            candidate = distances[current] + weight
            if candidate < distances[neighbor] - 1e-12:
                distances[neighbor] = candidate
                predecessors[neighbor] = [current]
            elif abs(candidate - distances[neighbor]) <= 1e-12:
                predecessors[neighbor].append(current)

    return distances, predecessors


def weighted_betweenness_centrality(
    edges: Sequence[HexNetworkEdge],
) -> dict[str, float]:
    """
    Brandes-style weighted node betweenness using ecological resistance as
    shortest-path distance. Results are normalized to [0, 1] for an undirected
    network where possible.
    """
    graph = _adjacency(edges)
    nodes = list(graph)
    if len(nodes) < 3:
        return {node: 0.0 for node in nodes}

    centrality = {node: 0.0 for node in nodes}
    for source in nodes:
        stack: list[str] = []
        predecessors = {node: [] for node in nodes}
        sigma = {node: 0.0 for node in nodes}
        distance = {node: float("inf") for node in nodes}
        sigma[source] = 1.0
        distance[source] = 0.0
        frontier = {source}

        while frontier:
            current = min(frontier, key=lambda node: distance[node])
            frontier.remove(current)
            stack.append(current)

            for neighbor, weight in graph[current].items():
                candidate = distance[current] + weight
                if candidate < distance[neighbor] - 1e-12:
                    distance[neighbor] = candidate
                    frontier.add(neighbor)
                    sigma[neighbor] = sigma[current]
                    predecessors[neighbor] = [current]
                elif abs(candidate - distance[neighbor]) <= 1e-12:
                    sigma[neighbor] += sigma[current]
                    predecessors[neighbor].append(current)

        dependency = {node: 0.0 for node in nodes}
        while stack:
            node = stack.pop()
            for predecessor in predecessors[node]:
                dependency[predecessor] += (
                    sigma[predecessor] / sigma[node]
                ) * (1.0 + dependency[node])
            if node != source:
                centrality[node] += dependency[node]

    normalization = 1.0 / ((len(nodes) - 1) * (len(nodes) - 2))
    return {node: value * normalization for node, value in centrality.items()}


def _largest_component_fraction(
    graph: Mapping[str, Mapping[str, float]],
    original_node_count: int,
) -> float:
    if original_node_count == 0:
        return 0.0
    remaining = set(graph)
    largest = 0

    while remaining:
        start = remaining.pop()
        component = {start}
        frontier = [start]
        while frontier:
            node = frontier.pop()
            for neighbor in graph[node]:
                if neighbor not in component:
                    component.add(neighbor)
                    remaining.discard(neighbor)
                    frontier.append(neighbor)
        largest = max(largest, len(component))

    return largest / original_node_count


def random_failure_connectivity(
    edges: Sequence[HexNetworkEdge],
    failed_hexagon_count: int,
    simulations: int,
    seed: int,
) -> float:
    """
    Estimate expected largest-connected-component fraction after uniform random
    hexagon failure. This is the connectivity-resilience metric; it is not
    inferred from centrality alone.
    """
    if simulations < 1:
        raise ValueError("simulations must be positive.")
    if failed_hexagon_count < 0:
        raise ValueError("failed_hexagon_count must be non-negative.")

    base_graph = _adjacency(edges)
    nodes = sorted(base_graph)
    if failed_hexagon_count > len(nodes):
        raise ValueError("failed_hexagon_count cannot exceed node count.")

    rng = Random(seed)
    fractions: list[float] = []
    for _ in range(simulations):
        failed = frozenset(rng.sample(nodes, failed_hexagon_count))
        graph = _adjacency(edges, failed)
        fractions.append(_largest_component_fraction(graph, len(nodes)))

    return sum(fractions) / len(fractions)


def required_redundant_corridors(
    edges: Sequence[HexNetworkEdge],
    candidate_redundant_edges: Sequence[HexNetworkEdge],
    failed_hexagon_count: int,
    required_connectivity_fraction: float,
    simulations: int,
    seed: int,
) -> int | None:
    """
    Determine the minimum number of candidate redundant links needed to meet an
    expected post-failure largest-component threshold.

    Candidate links are evaluated greedily by their resilience gain. For a
    global exact minimum across a large design space, use a MILP or exhaustive
    bounded search with the same random-failure objective.
    """
    _unit_interval(
        "required_connectivity_fraction",
        required_connectivity_fraction,
    )
    chosen: list[HexNetworkEdge] = []
    remaining = list(candidate_redundant_edges)

    baseline = random_failure_connectivity(
        edges,
        failed_hexagon_count,
        simulations,
        seed,
    )
    if baseline >= required_connectivity_fraction:
        return 0

    while remaining:
        best_edge: HexNetworkEdge | None = None
        best_score = -1.0
        for candidate in remaining:
            score = random_failure_connectivity(
                [*edges, *chosen, candidate],
                failed_hexagon_count,
                simulations,
                seed,
            )
            if score > best_score:
                best_score = score
                best_edge = candidate

        if best_edge is None:
            return None

        chosen.append(best_edge)
        remaining.remove(best_edge)

        current = random_failure_connectivity(
            [*edges, *chosen],
            failed_hexagon_count,
            simulations,
            seed,
        )
        if current >= required_connectivity_fraction:
            return len(chosen)

    return None


def analyze_hex_network(
    edges: Sequence[HexNetworkEdge],
    bottleneck_quantile: float,
    failed_hexagon_count: int,
    required_connectivity_fraction: float,
    candidate_redundant_edges: Sequence[HexNetworkEdge],
    simulations: int,
    seed: int,
) -> HexNetworkResilienceResult:
    """
    Produce centrality and random-failure resilience outputs together.

    A high-betweenness hex is a flow bottleneck candidate. It becomes a
    restoration-priority bottleneck only after removal experiments show material
    connectivity loss under the stated ecological-resistance model.
    """
    _probability("bottleneck_quantile", bottleneck_quantile)
    centrality = weighted_betweenness_centrality(edges)
    sorted_scores = sorted(centrality.values())
    threshold = _quantile(sorted_scores, bottleneck_quantile)
    bottlenecks = tuple(
        node
        for node, score in sorted(centrality.items())
        if score >= threshold and score > 0.0
    )

    baseline_graph = _adjacency(edges)
    baseline_fraction = _largest_component_fraction(
        baseline_graph,
        len(baseline_graph),
    )
    failure_fraction = random_failure_connectivity(
        edges,
        failed_hexagon_count,
        simulations,
        seed,
    )
    redundancy = required_redundant_corridors(
        edges,
        candidate_redundant_edges,
        failed_hexagon_count,
        required_connectivity_fraction,
        simulations,
        seed,
    )

    return HexNetworkResilienceResult(
        normalized_betweenness=centrality,
        bottleneck_hexagons=bottlenecks,
        baseline_largest_component_fraction=baseline_fraction,
        random_failure_connectivity_threshold=failure_fraction,
        redundant_corridors_required=redundancy,
        explanation=(
            "Betweenness identifies weighted shortest-path bottleneck "
            "candidates; Monte Carlo node-failure simulation measures "
            "connectivity resilience and determines redundancy demand."
        ),
    )
