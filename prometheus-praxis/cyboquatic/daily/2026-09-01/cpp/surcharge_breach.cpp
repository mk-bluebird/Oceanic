#include <algorithm>
#include <array>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

struct Event {
    std::string event_id;
    std::string canal_node;
    double flow_lps;
    double design_lps;
    double head_m;
    double freeboard_m;
    double bod_mg_l;
    double tss_mg_l;
    double cec_meq_100g;
    double downstream_m;
};

std::vector<std::string> split_csv(const std::string& line) {
    std::vector<std::string> fields;
    std::stringstream stream(line);
    std::string field;
    while (std::getline(stream, field, ',')) {
        fields.push_back(field);
    }
    return fields;
}

double parse_range(const std::string& value, const char* label, double minimum, double maximum) {
    std::size_t position = 0;
    const double parsed = std::stod(value, &position);
    if (position != value.size() || parsed < minimum || parsed > maximum) {
        throw std::invalid_argument(std::string("invalid ") + label);
    }
    return parsed;
}

Event parse_event(const std::string& line) {
    const auto fields = split_csv(line);
    if (fields.size() != 10 || fields[0].empty() || fields[1].empty()) {
        throw std::invalid_argument("expected 10 non-empty CSV fields");
    }

    return Event{
        fields[0],
        fields[1],
        parse_range(fields[2], "flow_lps", 0.0, 100000.0),
        parse_range(fields[3], "design_lps", 0.001, 100000.0),
        parse_range(fields[4], "head_m", 0.0, 100.0),
        parse_range(fields[5], "freeboard_m", 0.0, 20.0),
        parse_range(fields[6], "bod_mg_l", 0.0, 100000.0),
        parse_range(fields[7], "tss_mg_l", 0.0, 100000.0),
        parse_range(fields[8], "cec_meq_100g", 0.0, 500.0),
        parse_range(fields[9], "downstream_m", 0.001, 100000.0)
    };
}

int main() {
    try {
        std::string line;
        if (!std::getline(std::cin, line)) {
            throw std::invalid_argument("missing CSV input");
        }

        const Event event = parse_event(line);
        const double surcharge_ratio = event.flow_lps / event.design_lps;
        const double hydraulic_score = surcharge_ratio + std::max(0.0, 0.50 - event.freeboard_m);
        const double ecological_score =
            (event.bod_mg_l / 30.0) +
            (event.tss_mg_l / 100.0) +
            (std::max(0.0, 20.0 - event.cec_meq_100g) / 20.0);
        const double blast_radius_m = event.downstream_m * std::clamp(hydraulic_score / 2.0, 0.10, 1.00);

        std::string status = "contained";
        if (surcharge_ratio >= 1.30 || event.freeboard_m <= 0.20 || ecological_score >= 3.00) {
            status = "critical";
        } else if (surcharge_ratio >= 1.10 || ecological_score >= 1.75) {
            status = "elevated";
        }

        std::cout << std::fixed << std::setprecision(2)
                  << "event_id=" << event.event_id << '\n'
                  << "canal_node=" << event.canal_node << '\n'
                  << "surcharge_ratio=" << surcharge_ratio << '\n'
                  << "hydraulic_score=" << hydraulic_score << '\n'
                  << "ecological_score=" << ecological_score << '\n'
                  << "blast_radius_m=" << blast_radius_m << '\n'
                  << "containment_status=" << status << '\n'
                  << "operator_action="
                  << (status == "critical"
                      ? "notify human operator; preserve safe flow and isolate only under approved local procedure"
                      : status == "elevated"
                        ? "increase observation frequency; notify designated restoration operator"
                        : "continue normal monitored operation")
                  << '\n';
        return EXIT_SUCCESS;
    } catch (const std::exception& error) {
        std::cerr << "input_error=" << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
