#include "../EcoNetKarmaCore.hpp"

#include <cassert>
#include <cmath>
#include <vector>

int main() {
    const econet::KnWindowInput input{
        .window_start_unix_seconds = 0,
        .window_end_unix_seconds = 300,
        .concentration_in_mass_per_m3 = 10.0,
        .concentration_out_mass_per_m3 = 4.0,
        .reference_mass = 1800.0,
        .flow_segments = std::vector<econet::FlowSegment>{
            {
                .start_unix_seconds = 0,
                .end_unix_seconds = 120,
                .flow_m3_per_s = 1.0,
            },
            {
                .start_unix_seconds = 120,
                .end_unix_seconds = 300,
                .flow_m3_per_s = 2.0,
            },
        },
        .require_full_window_coverage = true,
    };

    econet::KnWindowError error{};
    const auto result = econet::EcoNetKarmaCore::compute_kn_window(input, &error);

    assert(result.has_value());
    assert(std::abs(result->removed_mass - 2880.0) < 1e-12);
    assert(std::abs(result->normalized_kn - 1.6) < 1e-12);
    assert(result->integrated_seconds == 300);
    assert(result->integrated_segments == 2);

    const econet::KnWindowInput invalid_input{
        .window_start_unix_seconds = 0,
        .window_end_unix_seconds = 300,
        .concentration_in_mass_per_m3 = 10.0,
        .concentration_out_mass_per_m3 = 4.0,
        .reference_mass = 1800.0,
        .flow_segments = std::vector<econet::FlowSegment>{
            {
                .start_unix_seconds = 0,
                .end_unix_seconds = 100,
                .flow_m3_per_s = 1.0,
            },
            {
                .start_unix_seconds = 99,
                .end_unix_seconds = 300,
                .flow_m3_per_s = 1.0,
            },
        },
        .require_full_window_coverage = true,
    };

    const auto invalid_result =
        econet::EcoNetKarmaCore::compute_kn_window(invalid_input, &error);

    assert(!invalid_result.has_value());
    assert(error.code == econet::FlowScheduleErrorCode::OverlappingSegments);

    return 0;
}
