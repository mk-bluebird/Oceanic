#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub::eco_restoration::network {

constexpr double kSymmetryTolerance = 1e-12;
constexpr double kEigenTolerance = 1e-10;
constexpr std::size_t kMaximumJacobiIterationsMultiplier = 100;

enum class FogState {
    Clear,
    HumanReviewPending,
    Withhold
};

enum class Status {
    AdvisoryCandidate,
    Withheld
};

struct Edge {
    std::size_t from{};
    std::size_t to{};
    double weight{};
    bool active{true};
};

struct NetworkScenario {
    std::string scenario_id;
    std::size_t node_count{};
    std::vector<Edge> edges;
    bool source_valid{};
    bool parameter_current{};
    bool consent_scope_valid{};
    bool retention_eligible{};
    bool community_review_available{};
    bool accessibility_equivalent{};
};

struct ResilienceResult {
    double baseline_lambda2{};
    double scenario_lambda2{};
    double connectivity_loss{};
    FogState fog_state{FogState::Withhold};
    Status status{Status::Withheld};
    std::string reason;
};

using Matrix = std::vector<std::vector<double>>;

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

void require_nonempty(std::string_view name, const std::string& value) {
    if (value.empty()) {
        throw std::invalid_argument(std::string(name) + " must not be empty");
    }
}

[[nodiscard]] Matrix zero_matrix(std::size_t size) {
    return Matrix(size, std::vector<double>(size, 0.0));
}

[[nodiscard]] Matrix laplacian(
    std::size_t node_count,
    const std::vector<Edge>& edges) {

    if (node_count < 2) {
        throw std::invalid_argument("network must contain at least two nodes");
    }

    Matrix adjacency = zero_matrix(node_count);

    for (const Edge& edge : edges) {
        if (!edge.active) {
            continue;
        }

        if (edge.from >= node_count || edge.to >= node_count || edge.from == edge.to) {
            throw std::invalid_argument("edge endpoints must be distinct valid node indexes");
        }

        if (!finite(edge.weight) || edge.weight < 0.0) {
            throw std::invalid_argument("edge weights must be finite and non-negative");
        }

        adjacency[edge.from][edge.to] += edge.weight;
        adjacency[edge.to][edge.from] += edge.weight;
    }

    Matrix result = zero_matrix(node_count);

    for (std::size_t row = 0; row < node_count; ++row) {
        double degree = 0.0;

        for (std::size_t column = 0; column < node_count; ++column) {
            degree += adjacency[row][column];

            if (row != column) {
                result[row][column] = -adjacency[row][column];
            }
        }

        result[row][row] = degree;
    }

    return result;
}

[[nodiscard]] std::vector<double> symmetric_eigenvalues(Matrix matrix) {
    const std::size_t size = matrix.size();

    if (size == 0) {
        throw std::invalid_argument("matrix must not be empty");
    }

    for (std::size_t row = 0; row < size; ++row) {
        if (matrix[row].size() != size) {
            throw std::invalid_argument("matrix must be square");
        }

        for (std::size_t column = 0; column < size; ++column) {
            if (!finite(matrix[row][column]) ||
                std::abs(matrix[row][column] - matrix[column][row]) > kSymmetryTolerance) {
                throw std::invalid_argument("matrix must be finite and symmetric");
            }
        }
    }

    const std::size_t maximum_iterations =
        kMaximumJacobiIterationsMultiplier * size * size;

    for (std::size_t iteration = 0; iteration < maximum_iterations; ++iteration) {
        std::size_t p = 0;
        std::size_t q = 1;
        double maximum_off_diagonal = 0.0;

        for (std::size_t row = 0; row < size; ++row) {
            for (std::size_t column = row + 1; column < size; ++column) {
                const double candidate = std::abs(matrix[row][column]);

                if (candidate > maximum_off_diagonal) {
                    maximum_off_diagonal = candidate;
                    p = row;
                    q = column;
                }
            }
        }

        if (maximum_off_diagonal <= kEigenTolerance) {
            std::vector<double> eigenvalues;
            eigenvalues.reserve(size);

            for (std::size_t index = 0; index < size; ++index) {
                eigenvalues.push_back(matrix[index][index]);
            }

            std::sort(eigenvalues.begin(), eigenvalues.end());
            return eigenvalues;
        }

        const double app = matrix[p][p];
        const double aqq = matrix[q][q];
        const double apq = matrix[p][q];
        const double angle = 0.5 * std::atan2(2.0 * apq, aqq - app);
        const double cosine = std::cos(angle);
        const double sine = std::sin(angle);

        for (std::size_t index = 0; index < size; ++index) {
            if (index == p || index == q) {
                continue;
            }

            const double aip = matrix[index][p];
            const double aiq = matrix[index][q];

            matrix[index][p] = cosine * aip - sine * aiq;
            matrix[p][index] = matrix[index][p];
            matrix[index][q] = sine * aip + cosine * aiq;
            matrix[q][index] = matrix[index][q];
        }

        matrix[p][p] =
            cosine * cosine * app -
            2.0 * sine * cosine * apq +
            sine * sine * aqq;

        matrix[q][q] =
            sine * sine * app +
            2.0 * sine * cosine * apq +
            cosine * cosine * aqq;

        matrix[p][q] = 0.0;
        matrix[q][p] = 0.0;
    }

    throw std::runtime_error("Jacobi eigensolver did not converge within the configured bound");
}

[[nodiscard]] double algebraic_connectivity(
    std::size_t node_count,
    const std::vector<Edge>& edges) {

    const std::vector<double> eigenvalues =
        symmetric_eigenvalues(laplacian(node_count, edges));

    if (eigenvalues.size() < 2) {
        throw std::invalid_argument("network must have at least two eigenvalues");
    }

    return std::max(0.0, eigenvalues[1]);
}

[[nodiscard]] ResilienceResult evaluate(
    const NetworkScenario& baseline,
    const NetworkScenario& scenario) {

    require_nonempty("baseline scenario id", baseline.scenario_id);
    require_nonempty("scenario id", scenario.scenario_id);

    if (baseline.node_count != scenario.node_count) {
        throw std::invalid_argument("baseline and scenario must use the same node count");
    }

    const bool eligible =
        baseline.source_valid &&
        baseline.parameter_current &&
        baseline.consent_scope_valid &&
        baseline.retention_eligible &&
        scenario.source_valid &&
        scenario.parameter_current &&
        scenario.consent_scope_valid &&
        scenario.retention_eligible;

    if (!eligible) {
        return {
            0.0,
            0.0,
            0.0,
            FogState::Withhold,
            Status::Withheld,
            "Source, parameter, consent, or retention eligibility is not valid."
        };
    }

    if (!scenario.community_review_available || !scenario.accessibility_equivalent) {
        return {
            0.0,
            0.0,
            0.0,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Network scenario requires accessible community review before redesign interpretation."
        };
    }

    const double baseline_lambda2 =
        algebraic_connectivity(baseline.node_count, baseline.edges);

    const double scenario_lambda2 =
        algebraic_connectivity(scenario.node_count, scenario.edges);

    const double loss = std::max(0.0, baseline_lambda2 - scenario_lambda2);

    if (scenario_lambda2 <= kEigenTolerance) {
        return {
            baseline_lambda2,
            scenario_lambda2,
            loss,
            FogState::HumanReviewPending,
            Status::Withheld,
            "The declared scenario disconnects the network or leaves negligible algebraic connectivity."
        };
    }

    return {
        baseline_lambda2,
        scenario_lambda2,
        loss,
        FogState::Clear,
        Status::AdvisoryCandidate,
        "Structural resilience comparison is available for human review; it does not authorize network redesign."
    };
}

[[nodiscard]] std::string_view to_string(FogState value) {
    switch (value) {
        case FogState::Clear:
            return "clear";
        case FogState::HumanReviewPending:
            return "human_review_pending";
        case FogState::Withhold:
            return "withhold";
    }
    return "withhold";
}

[[nodiscard]] std::string_view to_string(Status value) {
    switch (value) {
        case Status::AdvisoryCandidate:
            return "advisory_candidate";
        case Status::Withheld:
            return "withheld";
    }
    return "withheld";
}

}  // namespace augmented_hub::eco_restoration::network

int main() {
    using namespace augmented_hub::eco_restoration::network;

    const NetworkScenario baseline{
        "baseline-network",
        4,
        {
            {0, 1, 1.0, true},
            {1, 2, 1.0, true},
            {2, 3, 1.0, true},
            {3, 0, 1.0, true}
        },
        true,
        true,
        true,
        true,
        true,
        true
    };

    const NetworkScenario scenario{
        "edge-removal-scenario",
        4,
        {
            {0, 1, 1.0, true},
            {1, 2, 1.0, true},
            {2, 3, 1.0, true},
            {3, 0, 1.0, false}
        },
        true,
        true,
        true,
        true,
        true,
        true
    };

    try {
        const ResilienceResult result = evaluate(baseline, scenario);

        std::cout << std::fixed << std::setprecision(8)
                  << "{"
                  << "\"baseline_lambda2\":" << result.baseline_lambda2 << ","
                  << "\"scenario_lambda2\":" << result.scenario_lambda2 << ","
                  << "\"connectivity_loss\":" << result.connectivity_loss << ","
                  << "\"fog_state\":\"" << to_string(result.fog_state) << "\","
                  << "\"status\":\"" << to_string(result.status) << "\","
                  << "\"reason\":\"" << result.reason << "\""
                  << "}\n";

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "{\"status\":\"withheld\",\"reason\":\""
                  << error.what() << "\"}\n";
        return 1;
    }
}
