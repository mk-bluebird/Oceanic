#include <algorithm>
#include <array>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::eco_restoration::biodegradation {

constexpr double kMinimumReadinessForAdvisory = 0.60;
constexpr double kMaximumRiskForAdvisory = 0.35;
constexpr double kMinimumKnowledgeForAdvisory = 0.60;
constexpr double kEpsilon = 1e-12;

enum class FogState {
    Resolved,
    Partial,
    Unresolved,
    WithholdRisk,
    WithholdKnowledge
};

enum class AdvisoryStatus {
    Advisory,
    Informational,
    Withheld
};

struct LabEvidence {
    std::string evidence_id;
    std::string hex_anchor;
    std::string observed_at_utc;
    double biodegradation_fraction{};
    double reference_validity{};
    double temperature_suitability{};
    double ph_suitability{};
    double timing_suitability{};
    double measurement_precision{};
    double calibration_confidence{};
    double reproducibility{};
    double sample_representativeness{};
    double temporal_relevance{};
    double spatial_relevance{};
    double ecological_material_value{};
    double ecological_harm_risk{};
    double privacy_risk{};
    double accessibility_impact_risk{};
    double operational_risk{};
    double equity_risk{};
    double community_burden_risk{};
    bool source_valid{};
    bool parameter_current{};
    bool consent_scope_valid{};
    bool retention_eligible{};
};

struct Evaluation {
    double readiness{};
    double knowledge_factor{};
    double ecological_value{};
    double combined_risk{};
    FogState fog_state{FogState::Unresolved};
    AdvisoryStatus advisory_status{AdvisoryStatus::Withheld};
    std::string reason;
};

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

[[nodiscard]] double clamp01(double value) {
    return std::clamp(value, 0.0, 1.0);
}

void require_probability(std::string_view field, double value) {
    if (!finite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(std::string(field) + " must be finite and within [0, 1]");
    }
}

void require_nonempty(std::string_view field, const std::string& value) {
    if (value.empty()) {
        throw std::invalid_argument(std::string(field) + " must not be empty");
    }
}

void validate(const LabEvidence& evidence) {
    require_nonempty("evidence_id", evidence.evidence_id);
    require_nonempty("hex_anchor", evidence.hex_anchor);
    require_nonempty("observed_at_utc", evidence.observed_at_utc);

    for (const auto [name, value] : std::array{
             std::pair{"biodegradation_fraction", evidence.biodegradation_fraction},
             {"reference_validity", evidence.reference_validity},
             {"temperature_suitability", evidence.temperature_suitability},
             {"ph_suitability", evidence.ph_suitability},
             {"timing_suitability", evidence.timing_suitability},
             {"measurement_precision", evidence.measurement_precision},
             {"calibration_confidence", evidence.calibration_confidence},
             {"reproducibility", evidence.reproducibility},
             {"sample_representativeness", evidence.sample_representativeness},
             {"temporal_relevance", evidence.temporal_relevance},
             {"spatial_relevance", evidence.spatial_relevance},
             {"ecological_material_value", evidence.ecological_material_value},
             {"ecological_harm_risk", evidence.ecological_harm_risk},
             {"privacy_risk", evidence.privacy_risk},
             {"accessibility_impact_risk", evidence.accessibility_impact_risk},
             {"operational_risk", evidence.operational_risk},
             {"equity_risk", evidence.equity_risk},
             {"community_burden_risk", evidence.community_burden_risk},
         }) {
        require_probability(name, value);
    }
}

[[nodiscard]] double readiness(const LabEvidence& evidence) {
    return clamp01(
        0.50 * evidence.biodegradation_fraction +
        0.20 * evidence.reference_validity +
        0.15 * evidence.temperature_suitability +
        0.10 * evidence.ph_suitability +
        0.05 * evidence.timing_suitability);
}

[[nodiscard]] double knowledge_factor(const LabEvidence& evidence) {
    return clamp01(
        0.25 * evidence.measurement_precision +
        0.20 * evidence.calibration_confidence +
        0.20 * evidence.reproducibility +
        0.15 * evidence.sample_representativeness +
        0.10 * evidence.temporal_relevance +
        0.10 * evidence.spatial_relevance);
}

[[nodiscard]] double overall_risk(const LabEvidence& evidence) {
    return std::max({
        evidence.ecological_harm_risk,
        evidence.privacy_risk,
        evidence.accessibility_impact_risk,
        evidence.operational_risk,
        evidence.equity_risk,
        evidence.community_burden_risk
    });
}

[[nodiscard]] FogState determine_fog(
    bool eligibility_valid,
    double k_factor,
    double r_factor) {

    if (!eligibility_valid) {
        return FogState::Unresolved;
    }
    if (r_factor > kMaximumRiskForAdvisory) {
        return FogState::WithholdRisk;
    }
    if (k_factor < kMinimumKnowledgeForAdvisory) {
        return FogState::WithholdKnowledge;
    }
    if (k_factor < 0.80) {
        return FogState::Partial;
    }
    return FogState::Resolved;
}

[[nodiscard]] std::string_view to_string(FogState state) {
    switch (state) {
        case FogState::Resolved:
            return "resolved";
        case FogState::Partial:
            return "partial";
        case FogState::Unresolved:
            return "unresolved";
        case FogState::WithholdRisk:
            return "withhold_risk";
        case FogState::WithholdKnowledge:
            return "withhold_knowledge";
    }
    return "unresolved";
}

[[nodiscard]] std::string_view to_string(AdvisoryStatus status) {
    switch (status) {
        case AdvisoryStatus::Advisory:
            return "advisory";
        case AdvisoryStatus::Informational:
            return "informational";
        case AdvisoryStatus::Withheld:
            return "withheld";
    }
    return "withheld";
}

[[nodiscard]] Evaluation evaluate(const LabEvidence& evidence) {
    validate(evidence);

    const bool eligibility_valid =
        evidence.source_valid &&
        evidence.parameter_current &&
        evidence.consent_scope_valid &&
        evidence.retention_eligible;

    const double readiness_value = readiness(evidence);
    const double knowledge_value = knowledge_factor(evidence);
    const double risk_value = overall_risk(evidence);
    const double ecological_value = clamp01(
        readiness_value * evidence.ecological_material_value * (1.0 - risk_value));

    const FogState fog = determine_fog(eligibility_valid, knowledge_value, risk_value);

    Evaluation result{
        readiness_value,
        knowledge_value,
        ecological_value,
        risk_value,
        fog,
        AdvisoryStatus::Withheld,
        "withheld pending evidence and governance review"
    };

    if (!eligibility_valid) {
        result.reason = "source, parameter, consent, or retention eligibility is not valid";
        return result;
    }

    if (risk_value > kMaximumRiskForAdvisory) {
        result.reason = "a non-compensating risk dimension exceeds the advisory threshold";
        return result;
    }

    if (knowledge_value < kMinimumKnowledgeForAdvisory) {
        result.reason = "knowledge factor is below the advisory threshold";
        return result;
    }

    if (readiness_value < kMinimumReadinessForAdvisory) {
        result.advisory_status = AdvisoryStatus::Informational;
        result.reason = "evidence is eligible but readiness remains below the advisory threshold";
        return result;
    }

    result.advisory_status = AdvisoryStatus::Advisory;
    result.reason = "bounded biodegradable-material readiness advisory";
    return result;
}

void print_json(const Evaluation& result) {
    std::cout << std::fixed << std::setprecision(6)
              << "{"
              << "\"readiness\":" << result.readiness << ","
              << "\"k_factor\":" << result.knowledge_factor << ","
              << "\"e_factor\":" << result.ecological_value << ","
              << "\"r_factor\":" << result.combined_risk << ","
              << "\"fog_state\":\"" << to_string(result.fog_state) << "\","
              << "\"status\":\"" << to_string(result.advisory_status) << "\","
              << "\"reason\":\"" << result.reason << "\""
              << "}\n";
}

}  // namespace augmented_hub::eco_restoration::biodegradation

int main() {
    using namespace augmented_hub::eco_restoration::biodegradation;

    const LabEvidence evidence{
        "bio-example-20260903-001",
        "phx-local-hex-07-000042-000019",
        "2026-09-03T18:00:00Z",
        0.78,
        0.92,
        0.88,
        0.90,
        0.84,
        0.93,
        0.90,
        0.86,
        0.79,
        0.91,
        0.89,
        0.82,
        0.08,
        0.00,
        0.00,
        0.05,
        0.04,
        0.06,
        true,
        true,
        true,
        true
    };

    try {
        print_json(evaluate(evidence));
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "{\"status\":\"withheld\",\"reason\":\""
                  << error.what() << "\"}\n";
        return 1;
    }
}
