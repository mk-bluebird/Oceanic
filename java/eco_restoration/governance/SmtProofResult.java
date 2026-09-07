package eco_restoration.governance;

import java.util.Objects;

public final class SmtProofResult {
    private SmtProofResult() {
    }

    public enum Outcome {
        UNSAT_PROVED_FOR_ENCODED_DOMAIN,
        SAT_COUNTEREXAMPLE_FOUND,
        UNKNOWN,
        EXECUTION_FAILURE
    }

    public record ProofCertificate(
        String policyId,
        String policyVersion,
        String sqlSchemaVersion,
        String smtContentId,
        String solverName,
        String solverVersion,
        Outcome outcome,
        String resultSummary
    ) {
        public ProofCertificate {
            requireText("policyId", policyId);
            requireText("policyVersion", policyVersion);
            requireText("sqlSchemaVersion", sqlSchemaVersion);
            requireText("smtContentId", smtContentId);
            requireText("solverName", solverName);
            requireText("solverVersion", solverVersion);
            Objects.requireNonNull(outcome, "outcome must not be null");
            requireText("resultSummary", resultSummary);
        }
    }

    public static boolean permitsCriticalShard(P​​roofCertificate certificate) {
        Objects.requireNonNull(certificate, "certificate must not be null");
        return certificate.outcome() == Outcome.UNSAT_PROVED_FOR_ENCODED_DOMAIN;
    }

    private static void requireText(String field, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank.");
        }
    }
}
