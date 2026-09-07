package eco_restoration.foundation

import kotlin.math.max
import kotlin.math.min

object CrossDomainKER {
    private const val MAXIMUM_RISK_FOR_ADVISORY = 0.35
    private const val MINIMUM_KNOWLEDGE_FOR_ADVISORY = 0.60

    enum class FogState {
        CLEAR,
        UNMODELED_MEDIA,
        HUMAN_REVIEW_PENDING,
        HUMAN_REVIEW_COMPLETE,
        WITHHOLD
    }

    enum class Status {
        ADVISORY_CANDIDATE,
        INFORMATIONAL,
        WITHHOLD_RISK,
        WITHHOLD_KNOWLEDGE,
        WITHHOLD_FOG,
        WITHHOLD_PROVENANCE
    }

    data class KerTriad(
        val knowledgeFactor: Double,
        val ecoImpactValue: Double,
        val harmRisk: Double,
        val fogState: FogState,
        val sourceValid: Boolean,
        val parameterCurrent: Boolean,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean
    ) {
        init {
            listOf(knowledgeFactor, ecoImpactValue, harmRisk).forEach {
                require(it.isFinite() && it in 0.0..1.0) {
                    "KER components must be finite and within [0, 1]."
                }
            }
        }

        val eligible: Boolean
            get() = sourceValid &&
                parameterCurrent &&
                consentScopeValid &&
                retentionEligible
    }

    data class Assessment(
        val combined: KerTriad,
        val status: Status,
        val reason: String
    )

    fun aggregate(domains: List<KerTriad>): Assessment {
        require(domains.isNotEmpty()) { "At least one domain triad is required." }

        val maxRisk = domains.maxOf(KerTriad::harmRisk)
        val minKnowledge = domains.minOf(KerTriad::knowledgeFactor)
        val minimumEcoValue = domains.minOf(KerTriad::ecoImpactValue)
        val anyIneligible = domains.any { !it.eligible }
        val anyFog = domains.any { it.fogState != FogState.CLEAR }

        val combined = KerTriad(
            knowledgeFactor = minKnowledge,
            ecoImpactValue = minimumEcoValue,
            harmRisk = maxRisk,
            fogState = if (anyFog) FogState.WITHHOLD else FogState.CLEAR,
            sourceValid = !anyIneligible,
            parameterCurrent = !anyIneligible,
            consentScopeValid = !anyIneligible,
            retentionEligible = !anyIneligible
        )

        return when {
            anyIneligible -> Assessment(
                combined,
                Status.WITHHOLD_PROVENANCE,
                "At least one domain lacks valid source, parameter, consent, or retention eligibility."
            )

            anyFog -> Assessment(
                combined,
                Status.WITHHOLD_FOG,
                "At least one domain has unresolved uncertainty or a pending review state."
            )

            maxRisk > MAXIMUM_RISK_FOR_ADVISORY -> Assessment(
                combined,
                Status.WITHHOLD_RISK,
                "A non-compensating domain risk exceeds the advisory threshold."
            )

            minKnowledge < MINIMUM_KNOWLEDGE_FOR_ADVISORY -> Assessment(
                combined,
                Status.WITHHOLD_KNOWLEDGE,
                "At least one domain knowledge factor is below the advisory threshold."
            )

            else -> Assessment(
                combined,
                Status.ADVISORY_CANDIDATE,
                "All selected domains satisfy the bounded advisory gates."
            )
        }
    }

    fun kerScore(triad: KerTriad): Double {
        return clamp01(
            triad.knowledgeFactor *
                triad.ecoImpactValue *
                (1.0 - triad.harmRisk)
        )
    }

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
