#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::eco_restoration::pfas {

constexpr double kLn2 = 0.69314718055994530942;
constexpr double kMinimumRatePerDay = 1e-12;

enum class FogState {
    Clear,
    UnmodeledMedia,
    HumanReviewPending,
    Withhold
};

enum class Status {
    AdvisoryCandidate,
    Informational,
    Withheld
};

struct RateModel {
    double base_rate_per_day{};
    double reference_temperature_c{};
    double reference_ph{};
    double temperature_sensitivity_per_c{};
    double ph_sensitivity_per_unit{};
};

struct Observation {
    std::string evidence_id;
    std::string analyte_code;
    std::string matrix;
    std::string observed_at_utc;
    double temperature_c{};
    double ph{};
    double temperature_standard_deviation_c{};
    double ph_standard_deviation{};
    double temperature_ph_covariance{};
    double uncertainty_threshold_half_life_days{};
    bool source_valid{};
    bool parameter_current{};
    bool consent_scope_valid{};
    bool retention_eligible{};
    bool matrix_supported{};
    bool cold_survival_supported{};
    bool sediment_partition_supported{};
};

struct Result {
    double lambda_per_day{};
    double lambda_standard_deviation{};
    double half_life_days{};
    double half_life_standard_deviation_days{};
    FogState fog_state{FogState::Withhold};
    Status status{Status::Withheld};
    std::string reason;
};

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

void require_finite(std::string_view name, double value) {
    if (!finite(value)) {
        throw std::invalid_argument(std::string(name) + " must be finite");
    }
}

void require_nonnegative(std::string_view name, double value) {
    require_finite(name, value);
    if (value < 0.0) {
        throw std::invalid_argument(std::string(name) + " must be non-negative");
    }
}

void validate(const RateModel& model, const Observation& observation) {
    if (observation.evidence_id.empty() ||
        observation.analyte_code.empty() ||
        observation.matrix.empty() ||
        observation.observed_at_utc.empty()) {
        throw std::invalid_argument("evidence identity, analyte, matrix, and time are required");
    }

    require_nonnegative("base_rate_per_day", model.base_rate_per_day);
    require_finite("reference_temperature_c", model.reference_temperature_c);
    require_finite("reference_ph", model.reference_ph);
    require_finite("temperature_sensitivity_per_c", model.temperature_sensitivity_per_c);
    require_finite("ph_sensitivity_per_unit", model.ph_sensitivity_per_unit);

    require_finite("temperature_c", observation.temperature_c);
    require_finite("ph", observation.ph);
    require_nonnegative(
        "temperature_standard_deviation_c",
        observation.temperature_standard_deviation_c);
    require_nonnegative("ph_standard_deviation", observation.ph_standard_deviation);
    require_finite("temperature_ph_covariance", observation.temperature_ph_covariance);
    require_nonnegative(
        "uncertainty_threshold_half_life_days",
        observation.uncertainty_threshold_half_life_days);
}

[[nodiscard]] double rate(
    const RateModel& model,
    const Observation& observation) {

    const double exponent =
        model.temperature_sensitivity_per_c *
            (observation.temperature_c - model.reference_temperature_c) +
        model.ph_sensitivity_per_unit *
            (observation.ph - model.reference_ph);

    const double value = model.base_rate_per_day * std::exp(exponent);

    if (!finite(value) || value <= kMinimumRatePerDay) {
        throw std::invalid_argument("rate is non-positive or outside the numeric model range");
    }

    return value;
}

[[nodiscard]] Result evaluate(
    const RateModel& model,
    const Observation& observation) {

    validate(model, observation);

    const bool provenance_eligible =
        observation.source_valid &&
        observation.parameter_current &&
        observation.consent_scope_valid &&
        observation.retention_eligible;

    if (!provenance_eligible) {
        return {
            0.0, 0.0, 0.0, 0.0,
            FogState::Withhold,
            Status::Withheld,
            "Source, parameter, consent, or retention eligibility is not valid."
        };
    }

    if (!observation.matrix_supported) {
        return {
            0.0, 0.0, 0.0, 0.0,
            FogState::UnmodeledMedia,
            Status::Withheld,
            "The current rate model does not cover the observed environmental matrix."
        };
    }

    if (!observation.cold_survival_supported) {
        return {
            0.0, 0.0, 0.0, 0.0,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Cold-season persistence is outside the validated rate-model scope."
        };
    }

    if (!observation.sediment_partition_supported) {
        return {
            0.0, 0.0, 0.0, 0.0,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Sediment-water partition behavior is outside the validated rate-model scope."
        };
    }

    const double lambda = rate(model, observation);

    const double derivative_temperature =
        lambda * model.temperature_sensitivity_per_c;
    const double derivative_ph =
        lambda * model.ph_sensitivity_per_unit;

    const double variance_lambda =
        derivative_temperature * derivative_temperature *
            observation.temperature_standard_deviation_c *
            observation.temperature_standard_deviation_c +
        derivative_ph * derivative_ph *
            observation.ph_standard_deviation *
            observation.ph_standard_deviation +
        2.0 *
            derivative_temperature *
            derivative_ph *
            observation.temperature_ph_covariance;

    if (!finite(variance_lambda) || variance_lambda < 0.0) {
        return {
            lambda, 0.0, 0.0, 0.0,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Parameter covariance produces an invalid propagated uncertainty result."
        };
    }

    const double sigma_lambda = std::sqrt(variance_lambda);
    const double half_life = kLn2 / lambda;
    const double half_life_derivative = -kLn2 / (lambda * lambda);
    const double half_life_variance =
        half_life_derivative * half_life_derivative * variance_lambda;
    const double sigma_half_life = std::sqrt(half_life_variance);

    if (sigma_half_life > observation.uncertainty_threshold_half_life_days) {
        return {
            lambda,
            sigma_lambda,
            half_life,
            sigma_half_life,
            FogState::HumanReviewPending,
            Status::Withheld,
            "Half-life uncertainty exceeds the configured review threshold."
        };
    }

    return {
        lambda,
        sigma_lambda,
        half_life,
        sigma_half_life,
        FogState::Clear,
        Status::AdvisoryCandidate,
        "Bounded temperature and pH uncertainty propagation is eligible for human review."
    };
}

[[nodiscard]] std::string_view to_string(FogState value) {
    switch (value) {
        case FogState::Clear:
            return "clear";
        case FogState::UnmodeledMedia:
            return "unmodeled_media";
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
        case Status::Informational:
            return "informational";
        case Status::Withheld:
            return "withheld";
    }
    return "withheld";
}

}  // namespace augmented_hub::eco_restoration::pfas

int main() {
    using namespace augmented_hub::eco_restoration::pfas;

    const RateModel model{
        0.002,
        20.0,
        7.0,
        0.030,
        -0.015
    };

    const Observation observation{
        "pfas-half-life-example-001",
        "PFAS-GENERIC-RESEARCH",
        "water_column",
        "2026-09-06T23:49:00Z",
        24.0,
        7.4,
        0.4,
        0.10,
        0.01,
        30.0,
        true,
        true,
        true,
        true,
        true,
        true,
        true
    };

    try {
        const Result result = evaluate(model, observation);
        std::cout << std::fixed << std::setprecision(8)
                  << "{"
                  << "\"lambda_per_day\":" << result.lambda_per_day << ","
                  << "\"lambda_standard_deviation\":" << result.lambda_standard_deviation << ","
                  << "\"half_life_days\":" << result.half_life_days << ","
                  << "\"half_life_standard_deviation_days\":"
                  << result.half_life_standard_deviation_days << ","
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
