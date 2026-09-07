#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::eco_restoration::biodegradation {

constexpr double kMinimumSignalMgL = 1e-12;
constexpr double kMinimumInoculumViability = 0.60;
constexpr double kMaximumSalinityDifferencePpt = 5.0;
constexpr double kMaximumRiskForAdvisory = 0.35;
constexpr double kMinimumKnowledgeForAdvisory = 0.60;

enum class Matrix {
    WaterColumn,
    BedSediment,
    BankSediment,
    Soil,
    Compost,
    Unknown
};

enum class FogState {
    Clear,
    UnmodeledTransformationProduct,
    HumanReviewPending,
    Withhold
};

enum class Status {
    Advisory,
    Informational,
    Withheld
};

struct InoculumContext {
    std::string source_id;
    double viability_fraction{};
    double blank_mg_l{};
    double observed_mg_l{};
    double salinity_ppt{};
};

struct KerProvenance {
    bool source_valid{};
    bool parameter_current{};
    bool consent_scope_valid{};
    bool retention_eligible{};
    std::string method_version;
    std::string calibration_version;
};

struct Evidence {
    std::string evidence_id;
    Matrix matrix{Matrix::Unknown};
    std::string observed_at_utc;
    InoculumContext test_inoculum;
    InoculumContext reference_inoculum;
    double temperature_c{};
    double ph{};
    double detection_limit_mg_l{};
    bool transformation_product_flag{};
    bool transformation_product_scope_complete{};
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
    double accessibility_risk{};
    double operational_risk{};
    double equity_risk{};
    double community_burden_risk{};
    KerProvenance provenance;
};

struct Result {
    double corrected_test_signal{};
    double corrected_reference_signal{};
    std::optional<double> corrected_ratio;
    double readiness{};
    double knowledge_factor{};
    double eco_impact_value{};
    double harm_risk{};
    FogState fog_state{FogState::Withhold};
    Status status{Status::Withheld};
    std::string reason;
};

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

[[nodiscard]] double clamp01(double value) {
    return std::clamp(value, 0.0, 1.0);
}

void require_nonempty(std::string_view name, const std::string& value) {
    if (value.empty()) {
        throw std::invalid_argument(std::string(name) + " must not be empty");
    }
}

void require_probability(std::string_view name, double value) {
    if (!finite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(std::string(name) + " must be within [0, 1]");
    }
}

void require_nonnegative(std::string_view name, double value) {
    if (!finite(value) || value < 0.0) {
        throw std::invalid_argument(std::string(name) + " must be nonnegative");
    }
}

void validate_inoculum(const InoculumContext& value, std::string_view prefix) {
    require_nonempty(std::string(prefix) + ".source_id", value.source_id);
    require_probability(std::string(prefix) + ".viability_fraction", value.viability_fraction);
    require_nonnegative(std::string(prefix) + ".blank_mg_l", value.blank_mg_l);
    require_nonnegative(std::string(prefix) + ".observed_mg_l", value.observed_mg_l);
    require_nonnegative(std::string(prefix) + ".salinity_ppt", value.salinity_ppt);
}

void validate(const Evidence& evidence) {
    require_nonempty("evidence_id", evidence.evidence_id);
    require_nonempty("observed_at_utc", evidence.observed_at_utc);
    require_nonempty("method_version", evidence.provenance.method_version);
    require_nonempty("calibration_version", evidence.provenance.calibration_version);
    validate_inoculum(evidence.test_inoculum, "test_inoculum");
    validate_inoculum(evidence.reference_inoculum, "reference_inoculum");

    if (!finite(evidence.temperature_c) || !finite(evidence.ph) ||
        evidence.ph < 0.0 || evidence.ph > 14.0) {
        throw std::invalid_argument("temperature and pH must be finite; pH must be within [0, 14]");
    }

    require_nonnegative("detection_limit_mg_l", evidence.detection_limit_mg_l);

    for (const auto [name, value] : {
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
             {"accessibility_risk", evidence.accessibility_risk},
             {"operational_risk", evidence.operational_risk},
             {"equity_risk", evidence.equity_risk},
             {"community_burden_risk", evidence.community_burden_risk},
         }) {
        require_probability(name, value);
    }
}

[[nodiscard]] double corrected_signal(double observed_mg_l, double blank_mg_l) {
    return std::max(0.0, observed_mg_l - blank_mg_l);
}

[[nodiscard]] Result withheld(
    double corrected_test,
    double corrected_reference,
    std::optional<double> ratio,
    double readiness,
    double knowledge,
    double eco_impact,
    double risk,
    std::string reason) {

    return {
        corrected_test,
        corrected_reference,
        ratio,
        readiness,
        knowledge,
        eco_impact,
        risk,
        FogState::Withhold,
        Status::Withheld,
        std::move(reason)
    };
}

[[nodiscard]] Result evaluate(const Evidence& evidence) {
    validate(evidence);

    const double corrected_test = corrected_signal(
        evidence.test_inoculum.observed_mg_l,
        evidence.test_inoculum.blank_mg_l);
    const double corrected_reference = corrected_signal(
        evidence.reference_inoculum.observed_mg_l,
        evidence.reference_inoculum.blank_mg_l);

    const std::optional<double> corrected_ratio =
        corrected_reference > kMinimumSignalMgL
            ? std::optional<double>{clamp01(corrected_test / corrected_reference)}
            : std::nullopt;

    const double readiness = clamp01(
        0.50 * evidence.biodegradation_fraction +
        0.20 * evidence.reference_validity +
        0.15 * evidence.temperature_suitability +
        0.10 * evidence.ph_suitability +
        0.05 * evidence.timing_suitability);

    const double knowledge = clamp01(
        0.25 * evidence.measurement_precision +
        0.20 * evidence.calibration_confidence +
        0.20 * evidence.reproducibility +
        0.15 * evidence.sample_representativeness +
        0.10 * evidence.temporal_relevance +
        0.10 * evidence.spatial_relevance);

    const double risk = std::max({
        evidence.ecological_harm_risk,
        evidence.privacy_risk,
        evidence.accessibility_risk,
        evidence.operational_risk,
        evidence.equity_risk,
        evidence.community_burden_risk
    });

    const double eco_impact = clamp01(
        readiness * evidence.ecological_material_value * (1.0 - risk));

    const bool provenance_eligible =
        evidence.provenance.source_valid &&
        evidence.provenance.parameter_current &&
        evidence.provenance.consent_scope_valid &&
        evidence.provenance.retention_eligible;

    if (!provenance_eligible) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "source, parameter, consent, or retention provenance is not eligible");
    }

    if (evidence.matrix == Matrix::Unknown) {
        return {
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk, FogState::HumanReviewPending, Status::Withheld,
            "material matrix is unknown and requires medium-specific review"
        };
    }

    if (evidence.transformation_product_flag &&
        !evidence.transformation_product_scope_complete) {
        return {
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk, FogState::UnmodeledTransformationProduct, Status::Withheld,
            "transformation-product scope is incomplete"
        };
    }

    if (evidence.test_inoculum.viability_fraction < kMinimumInoculumViability ||
        evidence.reference_inoculum.viability_fraction < kMinimumInoculumViability) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "test or reference inoculum viability is below the configured evidence floor");
    }

    if (std::abs(evidence.test_inoculum.salinity_ppt -
                 evidence.reference_inoculum.salinity_ppt) >
        kMaximumSalinityDifferencePpt) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "test and reference salinity conditions are not comparable");
    }

    if (!corrected_ratio.has_value()) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "reference blank-corrected signal is insufficient for a stable ratio");
    }

    if (risk > kMaximumRiskForAdvisory) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "a non-compensating risk boundary was crossed");
    }

    if (knowledge < kMinimumKnowledgeForAdvisory) {
        return withheld(
            corrected_test, corrected_reference, corrected_ratio, readiness, knowledge,
            eco_impact, risk,
            "knowledge factor is below the advisory threshold");
    }

    return {
        corrected_test,
        corrected_reference,
        corrected_ratio,
        readiness,
        knowledge,
        eco_impact,
        risk,
        FogState::Clear,
        Status::Advisory,
        "bounded biodegradable-material advisory is eligible for human review"
    };
}

[[nodiscard]] std::string_view to_string(FogState state) {
    switch (state) {
        case FogState::Clear:
            return "clear";
        case FogState::UnmodeledTransformationProduct:
            return "unmodeled_transformation_product";
        case FogState::HumanReviewPending:
            return "human_review_pending";
        case FogState::Withhold:
            return "withhold";
    }
    return "withhold";
}

[[nodiscard]] std::string_view to_string(Status status) {
    switch (status) {
        case Status::Advisory:
            return "advisory";
        case Status::Informational:
            return "informational";
        case Status::Withheld:
            return "withheld";
    }
    return "withheld";
}

}  // namespace augmented_hub::eco_restoration::biodegradation

int main() {
    using namespace augmented_hub::eco_restoration::biodegradation;

    const Evidence evidence{
        "biodegradation-example-20260903-001",
        Matrix::WaterColumn,
        "2026-09-03T18:00:00Z",
        {"test-inoculum-local-a", 0.91, 1.0, 8.2, 2.1},
        {"reference-inoculum-local-b", 0.93, 0.8, 9.5, 2.8},
        23.0,
        7.1,
        0.05,
        false,
        true,
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
        {true, true, true, true, "biodegradation-v1", "calibration-v1"}
    };

    try {
        const Result result = evaluate(evidence);
        std::cout << std::fixed << std::setprecision(6)
                  << "{"
                  << "\"corrected_test_signal\":" << result.corrected_test_signal << ","
                  << "\"corrected_reference_signal\":" << result.corrected_reference_signal << ","
                  << "\"corrected_ratio\":"
                  << (result.corrected_ratio ? std::to_string(*result.corrected_ratio) : "null")
                  << ","
                  << "\"readiness\":" << result.readiness << ","
                  << "\"knowledge_factor\":" << result.knowledge_factor << ","
                  << "\"eco_impact_value\":" << result.eco_impact_value << ","
                  << "\"harm_risk\":" << result.harm_risk << ","
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
