package eco_restoration.heat;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;

public final class ReviewedHeatScenarioMdp {
    private static final double CONVERGENCE_TOLERANCE = 1e-10;

    private ReviewedHeatScenarioMdp() {
    }

    public enum Status {
        ADVISORY_CANDIDATE,
        WITHHELD
    }

    public enum FogState {
        CLEAR,
        HUMAN_REVIEW_PENDING,
        WITHHOLD
    }

    public record RewardWeights(
        String version,
        double heatReductionWeight,
        double waterDemandWeight,
        double habitatValueWeight,
        double accessibilityWeight,
        double communityBurdenWeight,
        boolean humanApproved
    ) {
        public RewardWeights {
            requireText("version", version);
            requireFinite(heatReductionWeight, "heatReductionWeight");
            requireFinite(waterDemandWeight, "waterDemandWeight");
            requireFinite(habitatValueWeight, "habitatValueWeight");
            requireFinite(accessibilityWeight, "accessibilityWeight");
            requireFinite(communityBurdenWeight, "communityBurdenWeight");
        }
    }

    public record ScenarioModel(
        String modelVersion,
        int stateCount,
        int actionCount,
        int horizon,
        double discountFactor,
        double[][][] transitionProbability,
        double[][] rewards,
        boolean sourceValid,
        boolean parameterCurrent,
        boolean consentScopeValid,
        boolean retentionEligible,
        boolean humanReviewAvailable,
        boolean rewardWeightsApproved
    ) {
        public ScenarioModel {
            requireText("modelVersion", modelVersion);
            if (stateCount <= 0 || actionCount <= 0 || horizon <= 0) {
                throw new IllegalArgumentException("State count, action count, and horizon must be positive.");
            }
            if (!Double.isFinite(discountFactor) || discountFactor < 0.0 || discountFactor > 1.0) {
                throw new IllegalArgumentException("discountFactor must be within [0, 1].");
            }
            Objects.requireNonNull(transitionProbability, "transitionProbability must not be null");
            Objects.requireNonNull(rewards, "rewards must not be null");
            validateDimensions(stateCount, actionCount, transitionProbability, rewards);
            validateTransitionRows(transitionProbability);
        }
    }

    public record PlanResult(
        int[] recommendedActionsByState,
        double[] stateValues,
        Status status,
        FogState fogState,
        String reason
    ) {
    }

    public static PlanResult solve(
        ScenarioModel model,
        RewardWeights weights
    ) {
        Objects.requireNonNull(model, "model must not be null");
        Objects.requireNonNull(weights, "weights must not be null");

        if (!model.sourceValid() ||
            !model.parameterCurrent() ||
            !model.consentScopeValid() ||
            !model.retentionEligible()) {
            return withheld(
                model.stateCount(),
                "Source, parameter, consent, or retention eligibility is not valid."
            );
        }

        if (!model.humanReviewAvailable() ||
            !model.rewardWeightsApproved() ||
            !weights.humanApproved()) {
            return new PlanResult(
                new int[model.stateCount()],
                new double[model.stateCount()],
                Status.WITHHELD,
                FogState.HUMAN_REVIEW_PENDING,
                "Reward weights and scenario interpretation require documented human review."
            );
        }

        double[] value = new double[model.stateCount()];
        int[] policy = new int[model.stateCount()];

        for (int iteration = 0; iteration < model.horizon(); iteration++) {
            double[] nextValue = new double[model.stateCount()];
            int[] nextPolicy = new int[model.stateCount()];

            for (int state = 0; state < model.stateCount(); state++) {
                double bestValue = Double.NEGATIVE_INFINITY;
                int bestAction = 0;

                for (int action = 0; action < model.actionCount(); action++) {
                    double candidate = model.rewards()[state][action] +
                        model.discountFactor() *
                            expectedValue(
                                model.transitionProbability()[state][action],
                                value
                            );

                    if (candidate > bestValue) {
                        bestValue = candidate;
                        bestAction = action;
                    }
                }

                nextValue[state] = bestValue;
                nextPolicy[state] = bestAction;
            }

            double difference = maxDifference(value, nextValue);
            value = nextValue;
            policy = nextPolicy;

            if (difference < CONVERGENCE_TOLERANCE) {
                break;
            }
        }

        return new PlanResult(
            policy,
            value,
            Status.ADVISORY_CANDIDATE,
            FogState.CLEAR,
            "Finite-horizon scenario recommendations are available for human review; they do not authorize restoration action."
        );
    }

    private static PlanResult withheld(int stateCount, String reason) {
        return new PlanResult(
            new int[stateCount],
            new double[stateCount],
            Status.WITHHELD,
            FogState.WITHHOLD,
            reason
        );
    }

    private static double expectedValue(double[] probability, double[] value) {
        double total = 0.0;

        for (int state = 0; state < probability.length; state++) {
            total += probability[state] * value[state];
        }

        return total;
    }

    private static void validateDimensions(
        int stateCount,
        int actionCount,
        double[][][] transitionProbability,
        double[][] rewards
    ) {
        if (transitionProbability.length != stateCount || rewards.length != stateCount) {
            throw new IllegalArgumentException("State dimensions do not match model configuration.");
        }

        for (int state = 0; state < stateCount; state++) {
            if (transitionProbability[state].length != actionCount ||
                rewards[state].length != actionCount) {
                throw new IllegalArgumentException("Action dimensions do not match model configuration.");
            }

            for (int action = 0; action < actionCount; action++) {
                if (transitionProbability[state][action].length != stateCount) {
                    throw new IllegalArgumentException("Transition target dimension does not match state count.");
                }

                if (!Double.isFinite(rewards[state][action])) {
                    throw new IllegalArgumentException("Rewards must be finite.");
                }
            }
        }
    }

    private static void validateTransitionRows(double[][][] transitionProbability) {
        for (double[][] stateTransitions : transitionProbability) {
            for (double[] actionTransitions : stateTransitions) {
                double sum = Arrays.stream(actionTransitions).sum();

                if (!Double.isFinite(sum) || Math.abs(sum - 1.0) > 1e-9) {
                    throw new IllegalArgumentException(
                        "Every transition-probability row must sum to one."
                    );
                }

                for (double probability : actionTransitions) {
                    if (!Double.isFinite(probability) || probability < 0.0) {
                        throw new IllegalArgumentException(
                            "Transition probabilities must be finite and non-negative."
                        );
                    }
                }
            }
        }
    }

    private static double maxDifference(double[] left, double[] right) {
        double maximum = 0.0;

        for (int index = 0; index < left.length; index++) {
            maximum = Math.max(maximum, Math.abs(left[index] - right[index]));
        }

        return maximum;
    }

    private static void requireText(String name, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank.");
        }
    }

    private static void requireFinite(double value, String name) {
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException(name + " must be finite.");
        }
    }
}
