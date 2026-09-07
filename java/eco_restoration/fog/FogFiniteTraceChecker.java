package eco_restoration.fog;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class FogFiniteTraceChecker {
    private FogFiniteTraceChecker() {
    }

    public enum State {
        CLEAR,
        UNMODELED_MEDIA,
        HUMAN_REVIEW_PENDING,
        HUMAN_REVIEW_COMPLETE,
        WITHHOLD
    }

    public enum Reason {
        MISSING_MEDIUM,
        MISSING_PARAMETER,
        CALIBRATION_FAILURE,
        CONSENT_WITHDRAWAL,
        RISK_BOUNDARY,
        PRIVACY_BOUNDARY,
        ACCESSIBILITY_BOUNDARY,
        COLD_SURVIVAL_UNRESOLVED,
        PFAS_FATE_UNRESOLVED,
        SEDIMENT_ORGANIC_CARBON_UNRESOLVED
    }

    public record Transition(
        String advisoryId,
        State from,
        State to,
        Reason reason,
        Instant at,
        String reviewerReference,
        String replacementEvidenceId,
        boolean consentRechecked
    ) {
        public Transition {
            requireText("advisoryId", advisoryId);
            Objects.requireNonNull(from, "from must not be null");
            Objects.requireNonNull(to, "to must not be null");
            Objects.requireNonNull(reason, "reason must not be null");
            Objects.requireNonNull(at, "at must not be null");
        }
    }

    public static void verify(List<Transition> trace) {
        if (trace == null || trace.isEmpty()) {
            throw new IllegalArgumentException("A finite trace must contain at least one transition.");
        }

        State previousNext = null;

        for (Transition transition : trace) {
            if (previousNext != null && transition.from() != previousNext) {
                throw new IllegalArgumentException(
                    "Trace continuity failure at advisory " + transition.advisoryId()
                );
            }

            if (!allowed(transition.from(), transition.to())) {
                throw new IllegalArgumentException(
                    "Prohibited FOG transition: " + transition.from() + " -> " + transition.to()
                );
            }

            if (transition.to() == State.HUMAN_REVIEW_COMPLETE &&
                (isBlank(transition.reviewerReference()) ||
                 isBlank(transition.replacementEvidenceId()) ||
                 !transition.consentRechecked())) {
                throw new IllegalArgumentException(
                    "Human review completion requires reviewer reference, replacement evidence, and consent recheck."
                );
            }

            if (transition.from() == State.HUMAN_REVIEW_COMPLETE &&
                transition.to() == State.CLEAR &&
                (isBlank(transition.replacementEvidenceId()) ||
                 !transition.consentRechecked())) {
                throw new IllegalArgumentException(
                    "Clear state after review completion requires replacement evidence and consent recheck."
                );
            }

            previousNext = transition.to();
        }
    }

    private static boolean allowed(State from, State to) {
        return switch (from) {
            case CLEAR -> to == State.CLEAR
                || to == State.UNMODELED_MEDIA
                || to == State.HUMAN_REVIEW_PENDING
                || to == State.WITHHOLD;
            case UNMODELED_MEDIA -> to == State.UNMODELED_MEDIA
                || to == State.HUMAN_REVIEW_PENDING
                || to == State.WITHHOLD;
            case HUMAN_REVIEW_PENDING -> to == State.HUMAN_REVIEW_PENDING
                || to == State.HUMAN_REVIEW_COMPLETE
                || to == State.WITHHOLD;
            case HUMAN_REVIEW_COMPLETE -> to == State.HUMAN_REVIEW_COMPLETE
                || to == State.CLEAR
                || to == State.UNMODELED_MEDIA
                || to == State.HUMAN_REVIEW_PENDING
                || to == State.WITHHOLD;
            case WITHHOLD -> to == State.WITHHOLD
                || to == State.HUMAN_REVIEW_PENDING;
        };
    }

    private static void requireText(String field, String value) {
        if (isBlank(value)) {
            throw new IllegalArgumentException(field + " must not be blank.");
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
