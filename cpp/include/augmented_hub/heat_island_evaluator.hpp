#ifndef AUGMENTED_HUB_HEAT_ISLAND_EVALUATOR_HPP
#define AUGMENTED_HUB_HEAT_ISLAND_EVALUATOR_HPP

#include <cmath>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub {

struct HeatIslandComponent {
    double source_value;
    double conversion_factor;
    double relative_uncertainty;
};

struct HeatIslandTelemetry {
    double facility_footprint_m2;
    HeatIslandComponent shade_equivalent;
    HeatIslandComponent evapotranspiration_benefit;
    HeatIslandComponent albedo_improvement;
    HeatIslandComponent waste_heat_burden;
};

struct HeatIslandEstimate {
    double point_estimate;
    double lower_bound;
    double upper_bound;
    double normalized_shade_equivalent;
    double normalized_evapotranspiration_benefit;
    double normalized_albedo_improvement;
    double normalized_waste_heat_burden;
    bool negative_point_estimate;
    bool uncertainty_crosses_zero;
};

class HeatIslandEvaluator final {
public:
    [[nodiscard]] static HeatIslandEstimate evaluate(
        const HeatIslandTelemetry& telemetry
    ) {
        require_positive(telemetry.facility_footprint_m2, "facility_footprint_m2");

        const ComponentEstimate shade =
            convert(telemetry.shade_equivalent, "shade_equivalent");

        const ComponentEstimate evapotranspiration =
            convert(
                telemetry.evapotranspiration_benefit,
                "evapotranspiration_benefit"
            );

        const ComponentEstimate albedo =
            convert(telemetry.albedo_improvement, "albedo_improvement");

        const ComponentEstimate waste_heat =
            convert(telemetry.waste_heat_burden, "waste_heat_burden");

        const double numerator =
            shade.point
            + evapotranspiration.point
            + albedo.point
            - waste_heat.point;

        const double lower_numerator =
            shade.lower
            + evapotranspiration.lower
            + albedo.lower
            - waste_heat.upper;

        const double upper_numerator =
            shade.upper
            + evapotranspiration.upper
            + albedo.upper
            - waste_heat.lower;

        const double point = numerator / telemetry.facility_footprint_m2;
        const double lower = lower_numerator / telemetry.facility_footprint_m2;
        const double upper = upper_numerator / telemetry.facility_footprint_m2;

        return {
            point,
            lower,
            upper,
            shade.point,
            evapotranspiration.point,
            albedo.point,
            waste_heat.point,
            point < 0.0,
            lower < 0.0 && upper > 0.0
        };
    }

private:
    struct ComponentEstimate {
        double point;
        double lower;
        double upper;
    };

    [[nodiscard]] static ComponentEstimate convert(
        const HeatIslandComponent& component,
        std::string_view component_name
    ) {
        require_nonnegative(component.source_value, component_name);
        require_positive(component.conversion_factor, "conversion_factor");

        if (!std::isfinite(component.relative_uncertainty)
            || component.relative_uncertainty < 0.0
            || component.relative_uncertainty > 1.0) {
            throw std::invalid_argument(
                std::string(component_name)
                + " relative_uncertainty must be finite and within 0.0..1.0."
            );
        }

        const double point = component.source_value * component.conversion_factor;
        const double uncertainty = point * component.relative_uncertainty;

        return {
            point,
            point - uncertainty,
            point + uncertainty
        };
    }

    static void require_nonnegative(
        double value,
        std::string_view field_name
    ) {
        if (!std::isfinite(value) || value < 0.0) {
            throw std::invalid_argument(
                std::string(field_name) + " must be finite and non-negative."
            );
        }
    }

    static void require_positive(
        double value,
        std::string_view field_name
    ) {
        if (!std::isfinite(value) || value <= 0.0) {
            throw std::invalid_argument(
                std::string(field_name) + " must be finite and greater than zero."
            );
        }
    }
};

}  // namespace augmented_hub

#endif
