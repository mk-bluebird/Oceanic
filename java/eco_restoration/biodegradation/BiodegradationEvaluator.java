package eco_restoration.biodegradation;

import java.util.List;
import java.util.Objects;

public final class BiodegradationEvaluator {
    private static final double MINIMUM_READINESS_FOR_ADVISORY = 0.60;
    private static final double MAXIMUM_RISK_FOR_ADVISORY = 0.35;
    private static final double MINIMUM_KNOWLEDGE_FOR_ADVISORY = 0.60;

    private BiodegradationEvaluator() {
    }

    public enum FogState {
        RESOLVED,
        PARTIAL,
        UNRESOLVED,
        WITHHOLD_RISK,
        WITHHOLD_KNOWLEDGE
    }

    public enum Status {
        ADVISORY,
        INFORMATIONAL,
        WITHHELD
    }

    public record Evidence(
        String evidenceId,
        String hexAnchor,
        String observedAtUtc,
        double biodegradationFraction,
        double referenceValidity,
        double temperatureSuitability,
        double phSuitability,
        double timingSuitability,
        double measurementPrecision,
        double calibrationConfidence,
        double reproducibility,
        double sampleRepresentativeness,
        double temporalRelevance,
        double spatialRelevance,
        double ecologicalMaterialValue,
        double ecologicalHarmRisk,
        double privacyRisk,
        double accessibilityImpactRisk,
        double operationalRisk,
        double equityRisk,
        double communityBurdenRisk,
        boolean sourceValid,
        boolean parameterCurrent,
        boolean consentScopeValid,
        boolean retentionEligible
    ) {
        public Evidence {
            requireText("evidenceId", evidenceId);
            requireText("hexAnchor", hexAnchor);
            requireText("observedAtUtc", observedAtUtc);
            for (final double value : List.of(
                biodegradationFraction,
                referenceValidity,
                temperatureSuitability,
                phSuitability,
                timingSuitability,
                measurementPrecision,
                calibrationConfidence,
                reproducibility,
                sampleRepresentativeness,
                temporalRelevance,
                spatialRelevance,
                ecologicalMaterialValue,
                ecologicalHarmRisk,
                privacyRisk,
                accessibilityImpactRisk,
                operationalRisk,
                equityRisk,
                communityBurdenRisk
            )) {
                requireProbability(value);
            }
        }
    }

    public record Result(
        double readiness,
        double kFactor,
        double eFactor,
        double rFactor,
        FogState fogState,
        Status status,
        String reason
    ) {
    }

    public static Result evaluate(Evidence evidence) {
        Objects.requireNonNull(evidence, "evidence must not be null");

        final boolean eligible =
            evidence.sourceValid()
                && evidence.parameterCurrent()
                && evidence.consentScopeValid()
                && evidence.retentionEligible();

        final double readiness = clamp01(
            0.50 * evidence.biodegradationFraction()
                + 0.20 * evidence.referenceValidity()
                + 0.15 * evidence.temperatureSuitability()
                + 0.10 * evidence.phSuitability()
                + 0.05 * evidence.timingSuitability());

        final double kFactor = clamp01(
            0.25 * evidence.measurementPrecision()
                + 0.20 * evidence.calibrationConfidence()
                + 0.20 * evidence.reproducibility()
                + 0.15 * evidence.sampleRepresentativeness()
                + 0.10 * evidence.temporalRelevance()
                + 0.10 * evidence.spatialRelevance());

        final double rFactor = Math.max(
            Math.max(evidence.ecologicalHarmRisk(), evidence.privacyRisk()),
            Math.max(
                Math.max(evidence.accessibilityImpactRisk(), evidence.operationalRisk()),
                Math.max(evidence.equityRisk(), evidence.communityBurdenRisk())
            )
        );

        final double eFactor = clamp01(
            readiness * evidence.ecologicalMaterialValue() * (1.0 - rFactor));

        if (!eligible) {
            return new Result(
                readiness, kFactor, eFactor, rFactor, FogState.UNRESOLVED,
                Status.WITHHELD,
                "Source, parameter, consent, or retention eligibility is not valid."
            );
        }

        if (rFactor > MAXIMUM_RISK_FOR_ADVISORY) {
            return new Result(
                readiness, kFactor, eFactor, rFactor, FogState.WITHHOLD_RISK,
                Status.WITHHELD,
                "A non-compensating risk dimension exceeds the advisory threshold."
            );
        }

        if (kFactor < MINIMUM_KNOWLEDGE_FOR_ADVISORY) {
            return new Result(
                readiness, kFactor, eFactor, rFactor, FogState.WITHHOLD_KNOWLEDGE,
                Status.WITHHELD,
                "Knowledge factor is below the advisory threshold."
            );
        }

        if (readiness < MINIMUM_READINESS_FOR_ADVISORY) {
            return new Result(
                readiness, kFactor, eFactor, rFactor, FogState.PARTIAL,
                Status.INFORMATIONAL,
                "Evidence is eligible but readiness remains below the advisory threshold."
            );
        }

        final FogState fogState = kFactor < 0.80 ? FogState.PARTIAL : FogState.RESOLVED;
        return new Result(
            readiness, kFactor, eFactor, rFactor, fogState,
            Status.ADVISORY,
            "Bounded biodegradable-material readiness advisory."
        );
    }

    private static void requireText(String name, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank");
        }
    }

    private static void requireProbability(double value) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException("All normalized values must be finite and within [0, 1]");
        }
    }

    private static double clamp01(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
