#ifndef ECONET_KARMA_CORE_HPP
#define ECONET_KARMA_CORE_HPP

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace econet {

enum class FlowScheduleErrorCode {
    EmptySchedule,
    InvalidWindow,
    InvalidSegment,
    UnsortedSegments,
    OverlappingSegments,
    CoverageGap,
    NegativeFlow,
    NonFiniteFlow,
    NonFiniteConcentration,
    NonPositiveReferenceConcentration
};

struct FlowSegment final {
    std::int64_t start_unix_seconds;
    std::int64_t end_unix_seconds;
    double flow_m3_per_s;
};

struct KnWindowInput final {
    std::int64_t window_start_unix_seconds;
    std::int64_t window_end_unix_seconds;
    double concentration_in_mass_per_m3;
    double concentration_out_mass_per_m3;
    double reference_mass;
    std::vector<FlowSegment> flow_segments;
    bool require_full_window_coverage;
};

struct KnWindowResult final {
    double removed_mass;
    double normalized_kn;
    std::int64_t integrated_seconds;
    std::size_t integrated_segments;
};

struct KnWindowError final {
    FlowScheduleErrorCode code;
    std::string message;
    std::optional<std::size_t> segment_index;
};

class EcoNetKarmaCore final {
public:
    [[nodiscard]] static std::optional<KnWindowResult> compute_kn_window(
        const KnWindowInput& input,
        KnWindowError* error
    ) noexcept;

private:
    static void set_error(
        KnWindowError* error,
        FlowScheduleErrorCode code,
        std::string message,
        std::optional<std::size_t> segment_index = std::nullopt
    ) noexcept;
};

}  // namespace econet

#endif
