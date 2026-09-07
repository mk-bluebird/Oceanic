package eco_restoration.community

import java.security.SecureRandom
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.sign

class DifferentialPrivacyAggregate(
    private val random: SecureRandom = SecureRandom()
) {
    enum class Status {
        RELEASE_CANDIDATE,
        WITHHELD
    }

    enum class FogState {
        CLEAR,
        HUMAN_REVIEW_PENDING,
        WITHHOLD
    }

    data class Contribution(
        val contributionId: String,
        val clippedValue: Double,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean,
        val accessibilityEquivalent: Boolean
    ) {
        init {
            require(contributionId.isNotBlank()) { "contributionId must not be blank." }
            require(clippedValue.isFinite() && clippedValue >= 0.0) {
                "clippedValue must be finite and non-negative."
            }
        }
    }

    data class ReleaseRequest(
        val aggregateId: String,
        val epsilon: Double,
        val sensitivity: Double,
        val minimumContributorCount: Int,
        val privacyBudgetRemaining: Double,
        val correctionPath: String,
        val appealPath: String
    ) {
        init {
            require(aggregateId.isNotBlank()) { "aggregateId must not be blank." }
            require(epsilon.isFinite() && epsilon > 0.0) { "epsilon must be finite and positive." }
            require(sensitivity.isFinite() && sensitivity > 0.0) {
                "sensitivity must be finite and positive."
            }
            require(minimumContributorCount > 0) {
                "minimumContributorCount must be positive."
            }
            require(privacyBudgetRemaining.isFinite() && privacyBudgetRemaining >= 0.0) {
                "privacyBudgetRemaining must be finite and non-negative."
            }
            require(correctionPath.isNotBlank()) { "correctionPath must not be blank." }
            require(appealPath.isNotBlank()) { "appealPath must not be blank." }
        }
    }

    data class ReleaseResult(
        val aggregateId: String,
        val rawAggregate: Double?,
        val noisyAggregate: Double?,
        val epsilonSpent: Double,
        val status: Status,
        val fogState: FogState,
        val reason: String
    )

    fun release(
        contributions: List<Contribution>,
        request: ReleaseRequest
    ): ReleaseResult {
        val eligible = contributions.filter {
            it.consentScopeValid &&
                it.retentionEligible &&
                it.accessibilityEquivalent
        }

        if (eligible.size < request.minimumContributorCount) {
            return ReleaseResult(
                request.aggregateId,
                null,
                null,
                0.0,
                Status.WITHHELD,
                FogState.HUMAN_REVIEW_PENDING,
                "The eligible aggregate does not meet the minimum contributor threshold."
            )
        }

        if (request.privacyBudgetRemaining < request.epsilon) {
            return ReleaseResult(
                request.aggregateId,
                null,
                null,
                0.0,
                Status.WITHHELD,
                FogState.WITHHOLD,
                "The remaining privacy budget is insufficient for this release."
            )
        }

        val rawAggregate = eligible.sumOf { contribution ->
            min(request.sensitivity, max(0.0, contribution.clippedValue))
        }

        val scale = request.sensitivity / request.epsilon
        val noisyAggregate = rawAggregate + laplaceNoise(scale)

        return ReleaseResult(
            request.aggregateId,
            rawAggregate,
            noisyAggregate,
            request.epsilon,
            Status.RELEASE_CANDIDATE,
            FogState.CLEAR,
            "Differentially private aggregate is available for human review and release authorization."
        )
    }

    private fun laplaceNoise(scale: Double): Double {
        val uniform = random.nextDouble() - 0.5
        return -scale * sign(uniform) * ln(1.0 - 2.0 * kotlin.math.abs(uniform))
    }
}
