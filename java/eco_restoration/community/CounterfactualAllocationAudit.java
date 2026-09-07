package eco_restoration.community;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class CounterfactualAllocationAudit {
    private static final double DEFAULT_STABILITY_TOLERANCE = 1e-9;

    private CounterfactualAllocationAudit() {
    }

    public enum Status {
        AUDIT_PASSED_FOR_DECLARED_SCENARIOS,
        AUDIT_WITHHELD_INSUFFICIENT_STRUCTURAL_MODEL,
        AUDIT_WITHHELD_PROXY_RISK,
        AUDIT_WITHHELD_ACCESS_EQUIVALENCE_FAILURE,
        HUMAN_REVIEW_REQUIRED
    }

    public record AggregateAreaInput(
        String aggregateId,
        double ecologicalNeed,
        double knowledgeFactor,
        double ecoImpactValue,
        double harmRisk,
        double accessibilityImpact,
        double communityBurden,
        boolean sourceValid,
        boolean consentScopeValid,
        boolean retentionEligible,
        boolean accessEquivalent,
        boolean proxyRiskDetected
    ) {
        public AggregateAreaInput {
            requireText("aggregateId", aggregateId);
            requireUnitInterval("ecologicalNeed", ecologicalNeed);
            requireUnitInterval("knowledgeFactor", knowledgeFactor);
            requireUnitInterval("ecoImpactValue", ecoImpactValue);
            requireUnitInterval("harmRisk", harmRisk);
            requireUnitInterval("accessibilityImpact", accessibilityImpact);
            requireUnitInterval("communityBurden", communityBurden);
        }
    }

    public record StructuralScenario(
        String scenarioId,
        double ecologicalNeedMultiplier,
        double burdenMultiplier,
        double accessibilityMultiplier
    ) {
        public StructuralScenario {
            requireText("scenarioId", scenarioId);
            requireNonNegativeFinite("ecologicalNeedMultiplier", ecologicalNeedMultiplier);
            requireNonNegativeFinite("burdenMultiplier", burdenMultiplier);
            requireNonNegativeFinite("accessibilityMultiplier", accessibilityMultiplier);
        }
    }

    public record AllocationDecision(
        String aggregateId,
        double allocationPriority,
        Status status,
        String reason
    ) {
    }

    public record AuditResult(
        String aggregateId,
        double baselinePriority,
        List<Double> scenarioPriorities,
        double maximumObservedDifference,
        Status status,
        String reason
    ) {
    }

    public static AuditResult audit(
        AggregateAreaInput input,
        List<StructuralScenario> scenarios,
        double stabilityTolerance
    ) {
        Objects.requireNonNull(input, "input must not be null");
        Objects.requireNonNull(scenarios, "scenarios must not be null");
        requireNonNegativeFinite("stabilityTolerance", stabilityTolerance);

        if (!input.sourceValid() ||
            !input.consentScopeValid() ||
            !input.retentionEligible()) {
            return new AuditResult(
                input.aggregateId(),
                0.0,
                List.of(),
                0.0,
                Status.AUDIT_WITHHELD_INSUFFICIENT_STRUCTURAL_MODEL,
                "Source, consent, or retention eligibility is not valid."
            );
        }

        if (input.proxyRiskDetected()) {
            return new AuditResult(
                input.aggregateId(),
                0.0,
                List.of(),
                0.0,
                Status.AUDIT_WITHHELD_PROXY_RISK,
                "The proposed feature set has unresolved identity-proxy risk."
            );
        }

        if (!input.accessEquivalent()) {
            return new AuditResult(
                input.aggregateId(),
                0.0,
                List.of(),
                0.0,
                Status.AUDIT_WITHHELD_ACCESS_EQUIVALENCE_FAILURE,
                "An equivalent accessible review path is not available."
            );
        }

        if (scenarios.isEmpty()) {
            return new AuditResult(
                input.aggregateId(),
                0.0,
                List.of(),
                0.0,
                Status.AUDIT_WITHHELD_INSUFFICIENT_STRUCTURAL_MODEL,
                "At least one declared structural scenario is required."
            );
        }

        final double baseline = priority(
            input.ecologicalNeed(),
            input.knowledgeFactor(),
            input.ecoImpactValue(),
            input.harmRisk(),
            input.accessibilityImpact(),
            input.communityBurden()
        );

        final List<Double> scenarioPriorities = new ArrayList<>();
        double maximumDifference = 0.0;

        for (StructuralScenario scenario : scenarios) {
            final double scenarioPriority = priority(
                clamp01(input.ecologicalNeed() * scenario.ecologicalNeedMultiplier()),
                input.knowledgeFactor(),
                input.ecoImpactValue(),
                input.harmRisk(),
                clamp01(input.accessibilityImpact() * scenario.accessibilityMultiplier()),
                clamp01(input.communityBurden() * scenario.burdenMultiplier())
            );

            scenarioPriorities.add(scenarioPriority);
            maximumDifference = Math.max(
                maximumDifference,
                Math.abs(scenarioPriority - baseline)
            );
        }

        if (maximumDifference > stabilityTolerance) {
            return new AuditResult(
                input.aggregateId(),
                baseline,
                List.copyOf(scenarioPriorities),
                maximumDifference,
                Status.HUMAN_REVIEW_REQUIRED,
                "Declared structural scenarios change the allocation priority beyond the approved tolerance."
            );
        }

        return new AuditResult(
            input.aggregateId(),
            baseline,
            List.copyOf(scenarioPriorities),
            maximumDifference,
            Status.AUDIT_PASSED_FOR_DECLARED_SCENARIOS,
            "Aggregate-only allocation priority is stable across the declared structural scenarios."
        );
    }

    public static AllocationDecision propose(
        AggregateAreaInput input,
        List<StructuralScenario> scenarios
    ) {
        AuditResult audit = audit(input, scenarios, DEFAULT_STABILITY_TOLERANCE);

        if (audit.status() != Status.AUDIT_PASSED_FOR_DECLARED_SCENARIOS) {
            return new AllocationDecision(
                input.aggregateId(),
                0.0,
                audit.status(),
                audit.reason()
            );
        }

        return new AllocationDecision(
            input.aggregateId(),
            audit.baselinePriority(),
            Status.AUDIT_PASSED_FOR_DECLARED_SCENARIOS,
            "Advisory-only aggregate allocation priority is available for human review."
        );
    }

    private static double priority(
        double ecologicalNeed,
        double knowledgeFactor,
        double ecoImpactValue,
        double harmRisk,
        double accessibilityImpact,
        double communityBurden
    ) {
        return clamp01(
            ecologicalNeed *
                knowledgeFactor *
                ecoImpactValue *
                (1.0 - harmRisk) *
                (1.0 - accessibilityImpact) *
                (1.0 - communityBurden)
        );
    }

    private static void requireText(String name, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank.");
        }
    }

    private static void requireUnitInterval(String name, double value) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(name + " must be finite and within [0, 1].");
        }
    }

    private static void requireNonNegativeFinite(String name, double value) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }

    private static double clamp01(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }
}
