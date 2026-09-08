#include "EcoNetKarmaCore.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace econet {

void EcoNetKarmaCore::set_error(
    KnWindowError* error,
    FlowScheduleErrorCode code,
    std::string message,
    std::optional<std::size_t> segment_index
) noexcept {
    if (error != nullptr) {
        *error = KnWindowError{
            .code = code,
            .message = std::move(message),
            .segment_index = segment_index,
        };
    }
}

std::optional<KnWindowResult> EcoNetKarmaCore::compute_kn_window(
    const KnWindowInput& input,
    KnWindowError* error
) noexcept {
    if (input.window_end_unix_seconds <= input.window_start_unix_seconds) {
        set_error(
            error,
            FlowScheduleErrorCode::InvalidWindow,
            "window_end_unix_seconds must be greater than window_start_unix_seconds"
        );
        return std::nullopt;
    }

    if (!std::isfinite(input.concentration_in_mass_per_m3)
        || !std::isfinite(input.concentration_out_mass_per_m3)) {
        set_error(
            error,
            FlowScheduleErrorCode::NonFiniteConcentration,
            "concentration values must be finite"
        );
        return std::nullopt;
    }

    if (!std::isfinite(input.reference_mass) || input.reference_mass <= 0.0) {
        set_error(
            error,
            FlowScheduleErrorCode::NonPositiveReferenceConcentration,
            "reference_mass must be finite and greater than zero"
        );
        return std::nullopt;
    }

    if (input.flow_segments.empty()) {
        set_error(
            error,
            FlowScheduleErrorCode::EmptySchedule,
            "flow_segments must contain at least one segment"
        );
        return std::nullopt;
    }

    std::vector<FlowSegment> segments = input.flow_segments;
    std::sort(
        segments.begin(),
        segments.end(),
        [](const FlowSegment& left, const FlowSegment& right) {
            if (left.start_unix_seconds != right.start_unix_seconds) {
                return left.start_unix_seconds < right.start_unix_seconds;
            }
            return left.end_unix_seconds < right.end_unix_seconds;
        }
    );

    for (std::size_t index = 0; index < segments.size(); ++index) {
        const FlowSegment& segment = segments[index];

        if (segment.end_unix_seconds <= segment.start_unix_seconds) {
            set_error(
                error,
                FlowScheduleErrorCode::InvalidSegment,
                "each flow segment must have end_unix_seconds greater than start_unix_seconds",
                index
            );
            return std::nullopt;
        }

        if (!std::isfinite(segment.flow_m3_per_s)) {
            set_error(
                error,
                FlowScheduleErrorCode::NonFiniteFlow,
                "flow_m3_per_s must be finite",
                index
            );
            return std::nullopt;
        }

        if (segment.flow_m3_per_s < 0.0) {
            set_error(
                error,
                FlowScheduleErrorCode::NegativeFlow,
                "flow_m3_per_s must be non-negative",
                index
            );
            return std::nullopt;
        }

        if (index > 0
            && segments[index - 1].end_unix_seconds > segment.start_unix_seconds) {
            set_error(
                error,
                FlowScheduleErrorCode::OverlappingSegments,
                "flow segments must not overlap",
                index
            );
            return std::nullopt;
        }
    }

    std::int64_t cursor = input.window_start_unix_seconds;
    std::int64_t integrated_seconds = 0;
    std::size_t integrated_segments = 0;
    long double integrated_volume_m3 = 0.0L;

    for (const FlowSegment& segment : segments) {
        const std::int64_t effective_start = std::max(
            segment.start_unix_seconds,
            input.window_start_unix_seconds
        );
        const std::int64_t effective_end = std::min(
            segment.end_unix_seconds,
            input.window_end_unix_seconds
        );

        if (effective_end <= effective_start) {
            continue;
        }

        if (input.require_full_window_coverage && effective_start > cursor) {
            set_error(
                error,
                FlowScheduleErrorCode::CoverageGap,
                "flow schedule does not fully cover the requested computation window"
            );
            return std::nullopt;
        }

        const std::int64_t duration_seconds = effective_end - effective_start;
        integrated_volume_m3 += static_cast<long double>(segment.flow_m3_per_s)
            * static_cast<long double>(duration_seconds);
        integrated_seconds += duration_seconds;
        integrated_segments += 1;
        cursor = std::max(cursor, effective_end);
    }

    if (input.require_full_window_coverage && cursor < input.window_end_unix_seconds) {
        set_error(
            error,
            FlowScheduleErrorCode::CoverageGap,
            "flow schedule ends before the requested computation window"
        );
        return std::nullopt;
    }

    const long double delta_concentration =
        static_cast<long double>(input.concentration_in_mass_per_m3)
        - static_cast<long double>(input.concentration_out_mass_per_m3);

    const long double removed_mass = delta_concentration * integrated_volume_m3;
    const long double normalized_kn = removed_mass
        / static_cast<long double>(input.reference_mass);

    if (!std::isfinite(static_cast<double>(removed_mass))
        || !std::isfinite(static_cast<double>(normalized_kn))) {
        set_error(
            error,
            FlowScheduleErrorCode::InvalidSegment,
            "computed K_n is not finite"
        );
        return std::nullopt;
    }

    return KnWindowResult{
        .removed_mass = static_cast<double>(removed_mass),
        .normalized_kn = static_cast<double>(normalized_kn),
        .integrated_seconds = integrated_seconds,
        .integrated_segments = integrated_segments,
    };
}

}  // namespace econet
