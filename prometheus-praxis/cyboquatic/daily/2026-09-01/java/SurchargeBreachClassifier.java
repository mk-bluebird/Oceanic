import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.Locale;

public final class SurchargeBreachClassifier {
    private record Event(
        String eventId,
        String canalNode,
        double flowLps,
        double designLps,
        double headM,
        double freeboardM,
        double bodMgL,
        double tssMgL,
        double cecMeq100g,
        double downstreamM
    ) {}

    private static double ranged(String value, String label, double minimum, double maximum) {
        final double parsed;
        try {
            parsed = Double.parseDouble(value);
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("invalid " + label);
        }
        if (!Double.isFinite(parsed) || parsed < minimum || parsed > maximum) {
            throw new IllegalArgumentException("invalid " + label);
        }
        return parsed;
    }

    private static Event parse(String line) {
        String[] fields = line.split(",", -1);
        if (fields.length != 10 || fields[0].isBlank() || fields[1].isBlank()) {
            throw new IllegalArgumentException("expected 10 non-empty CSV fields");
        }
        return new Event(
            fields[0],
            fields[1],
            ranged(fields[2], "flow_lps", 0.0, 100000.0),
            ranged(fields[3], "design_lps", 0.001, 100000.0),
            ranged(fields[4], "head_m", 0.0, 100.0),
            ranged(fields[5], "freeboard_m", 0.0, 20.0),
            ranged(fields[6], "bod_mg_l", 0.0, 100000.0),
            ranged(fields[7], "tss_mg_l", 0.0, 100000.0),
            ranged(fields[8], "cec_meq_100g", 0.0, 500.0),
            ranged(fields[9], "downstream_m", 0.001, 100000.0)
        );
    }

    public static void main(String[] args) throws Exception {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in))) {
            Event event = parse(reader.readLine());
            double surchargeRatio = event.flowLps() / event.designLps();
            double hydraulicScore = surchargeRatio + Math.max(0.0, 0.50 - event.freeboardM());
            double ecologicalScore =
                event.bodMgL() / 30.0 +
                event.tssMgL() / 100.0 +
                Math.max(0.0, 20.0 - event.cecMeq100g()) / 20.0;
            double blastRadiusM = event.downstreamM() * Math.clamp(hydraulicScore / 2.0, 0.10, 1.00);

            String status = "contained";
            if (surchargeRatio >= 1.30 || event.freeboardM() <= 0.20 || ecologicalScore >= 3.00) {
                status = "critical";
            } else if (surchargeRatio >= 1.10 || ecologicalScore >= 1.75) {
                status = "elevated";
            }

            String action = switch (status) {
                case "critical" -> "notify human operator; preserve safe flow and isolate only under approved local procedure";
                case "elevated" -> "increase observation frequency; notify designated restoration operator";
                default -> "continue normal monitored operation";
            };

            System.out.printf(Locale.ROOT,
                "event_id=%s%ncanal_node=%s%nsurcharge_ratio=%.2f%nhydraulic_score=%.2f%necological_score=%.2f%nblast_radius_m=%.2f%ncontainment_status=%s%noperator_action=%s%n",
                event.eventId(), event.canalNode(), surchargeRatio, hydraulicScore, ecologicalScore,
                blastRadiusM, status, action
            );
        }
    }
}
