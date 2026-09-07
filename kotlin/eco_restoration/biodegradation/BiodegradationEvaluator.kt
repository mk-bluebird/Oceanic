package eco_restoration.biodegradation

import kotlin.math.max
import kotlin.math.min

object BiodegradationEvaluator {
    private const val MINIMUM_READINESS_FOR_ADVISORY = 0.60
    private const val MAXIMUM_RISK_FOR_ADVISORY = 0.35
    private const val MINIMUM_KNOWLEDGE_FOR_ADVISORY = 0.60

    enum class FogState {
        RESOLVED,
        PARTIAL,
        UNRESOLVED,
        WITHHOLD_RISK,
        WITHHOLD_KNOWLEDGE
    }

    enum class Status {
        ADVISORY,
        INFORMATIONAL,
        WITHHELD
    }

    data class Evidence(
        val evidenceId: String,
        val hexAnchor: String,
        val observedAtUtc: String,
        val biodegradationFraction: Double,
        val referenceValidity: Double,
        val temperatureSuitability: Double,
        val phSuitability: Double,
        val timingSuitability: Double,
        val measurementPrecision: Double,
        val calibrationConfidence: Double,
        val reproducibility: Double,
        val sampleRepresentativeness: Double,
        val temporalRelevance: Double,
        val spatialRelevance: Double,
        val ecologicalMaterialValue: Double,
        val ecologicalHarmRisk: Double,
        val privacyRisk: Double,
        val accessibilityImpactRisk: Double,
        val operationalRisk: Double,
        val equityRisk: Double,
        val communityBurdenRisk: Double,
        val sourceValid: Boolean,
        val parameterCurrent: Boolean,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean
    ) {
        init {
            require(evidenceId.isNotBlank()) { "evidenceId must not be blank" }
            require(hexAnchor.isNotBlank()) { "hexAnchor must not be blank" }
            require(observedAtUtc.isNotBlank()) { "observedAtUtc must not be blank" }

            listOf(
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
            ).forEach(::requireProbability)
        }
    }

    data class Result(
        val readiness: Double,
        val kFactor: Double,
        val eFactor: Double,
        val rFactor: Double,
        val fogState: FogState,
        val status: Status,
        val reason: String
    )

    fun evaluate(evidence: Evidence): Result {
        val eligible = evidence.sourceValid &&
            evidence.parameterCurrent &&
            evidence.consentScopeValid &&
            evidence.retentionEligible

        val readiness = clamp01(
            0.50 * evidence.biodegradationFraction +
                0.20 * evidence.referenceValidity +
                0.15 * evidence.temperatureSuitability +
                0.10 * evidence.phSuitability +
                0.05 * evidence.timingSuitability
        )

        val kFactor = clamp01(
            0.25 * evidence.measurementPrecision +
                0.20 * evidence.calibrationConfidence +
                0.20 * evidence.reproducibility +
                0.15 * evidence.sampleRepresentativeness +
                0.10 * evidence.temporalRelevance +
                0.10 * evidence.spatialRelevance
        )

        val rFactor = listOf(
            evidence.ecologicalHarmRisk,
            evidence.privacyRisk,
            evidence.accessibilityImpactRisk,
            evidence.operationalRisk,
            evidence.equityRisk,
            evidence.communityBurdenRisk
        ).max()

        val eFactor = clamp01(
            readiness * evidence.ecologicalMaterialValue * (1.0 - rFactor)
        )

        return when {
            !eligible -> Result(
                readiness,
                kFactor,
                eFactor,
                rFactor,
                FogState.UNRESOLVED,
                Status.WITHHELD,
                "Source, parameter, consent, or retention eligibility is not valid."
            )

            rFactor > MAXIMUM_RISK_FOR_ADVISORY -> Result(
                readiness,
                kFactor,
                eFactor,
                rFactor,
                FogState.WITHHOLD_RISK,
                Status.WITHHELD,
                "A non-compensating risk dimension exceeds the advisory threshold."
            )

            kFactor < MINIMUM_KNOWLEDGE_FOR_ADVISORY -> Result(
                readiness,
                kFactor,
                eFactor,
                rFactor,
                FogState.WITHHOLD_KNOWLEDGE,
                Status.WITHHELD,
                "Knowledge factor is below the advisory threshold."
            )

            readiness < MINIMUM_READINESS_FOR_ADVISORY -> Result(
                readiness,
                kFactor,
                eFactor,
                rFactor,
                FogState.PARTIAL,
                Status.INFORMATIONAL,
                "Evidence is eligible but readiness remains below the advisory threshold."
            )

            else -> Result(
                readiness,
                kFactor,
                eFactor,
                rFactor,
                if (kFactor < 0.80) FogState.PARTIAL else FogState.RESOLVED,
                Status.ADVISORY,
                "Bounded biodegradable-material readiness advisory."
            )
        }
    }

    private fun requireProbability(value: Double) {
        require(value.isFinite() && value in 0.0..1.0) {
            "All normalized values must be finite and within [0, 1]."
        }
    }

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
