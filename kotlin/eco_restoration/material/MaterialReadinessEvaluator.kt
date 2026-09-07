package eco_restoration.material

import kotlin.math.max
import kotlin.math.min

object MaterialReadinessEvaluator {
    enum class TestStandard {
        ISO_14851,
        ISO_14855,
        OECD_301,
        OECD_201,
        OECD_202
    }

    enum class Medium {
        WATER_COLUMN,
        BED_SEDIMENT,
        BANK_SEDIMENT,
        SOIL,
        COMPOST,
        MIXED,
        UNKNOWN
    }

    enum class TransformationStatus {
        NOT_ASSESSED,
        NO_TRANSFORMATION_PRODUCTS_DETECTED,
        TRANSFORMATION_PRODUCTS_DETECTED,
        INSUFFICIENT_METHOD_SCOPE
    }

    data class StandardProfile(
        val standard: TestStandard,
        val standardEdition: String,
        val inoculumSourceProfile: String,
        val readinessThreshold: Double,
        val validFromUtc: String,
        val validToUtc: String?,
        val sourceReference: String
    ) {
        init {
            require(standardEdition.isNotBlank()) { "standardEdition must not be blank." }
            require(inoculumSourceProfile.isNotBlank()) {
                "inoculumSourceProfile must not be blank."
            }
            require(sourceReference.isNotBlank()) { "sourceReference must not be blank." }
            requireProbability(readinessThreshold)
            require(validFromUtc.isNotBlank()) { "validFromUtc must not be blank." }
        }
    }

    data class Inoculum(
        val sourceId: String,
        val viabilityFraction: Double,
        val salinityPpt: Double,
        val blankReferenceMgL: Double,
        val referenceControlMgL: Double,
        val testControlMgL: Double
    ) {
        init {
            require(sourceId.isNotBlank()) { "sourceId must not be blank." }
            requireProbability(viabilityFraction)
            require(salinityPpt >= 0.0 && salinityPpt.isFinite()) {
                "salinityPpt must be finite and non-negative."
            }
            require(blankReferenceMgL >= 0.0 && blankReferenceMgL.isFinite()) {
                "blankReferenceMgL must be finite and non-negative."
            }
            require(referenceControlMgL >= 0.0 && referenceControlMgL.isFinite()) {
                "referenceControlMgL must be finite and non-negative."
            }
            require(testControlMgL >= 0.0 && testControlMgL.isFinite()) {
                "testControlMgL must be finite and non-negative."
            }
        }
    }

    data class MaterialEvidence(
        val evidenceId: String,
        val medium: Medium,
        val biodegradationFraction: Double,
        val referenceValidity: Double,
        val temperatureSuitability: Double,
        val phSuitability: Double,
        val timingSuitability: Double,
        val transformationStatus: TransformationStatus,
        val metaboliteChainAssessed: Boolean,
        val testInoculum: Inoculum,
        val referenceInoculum: Inoculum,
        val profile: StandardProfile
    ) {
        init {
            require(evidenceId.isNotBlank()) { "evidenceId must not be blank." }
            requireProbability(biodegradationFraction)
            requireProbability(referenceValidity)
            requireProbability(temperatureSuitability)
            requireProbability(phSuitability)
            requireProbability(timingSuitability)
        }
    }

    data class Assessment(
        val readiness: Double,
        val threshold: Double,
        val eligible: Boolean,
        val status: String,
        val reason: String
    )

    fun evaluate(evidence: MaterialEvidence): Assessment {
        val readiness = clamp01(
            0.50 * evidence.biodegradationFraction +
                0.20 * evidence.referenceValidity +
                0.15 * evidence.temperatureSuitability +
                0.10 * evidence.phSuitability +
                0.05 * evidence.timingSuitability
        )

        if (evidence.medium == Medium.UNKNOWN || evidence.medium == Medium.MIXED) {
            return Assessment(
                readiness = readiness,
                threshold = evidence.profile.readinessThreshold,
                eligible = false,
                status = "withheld",
                reason = "A medium-specific assessment is required before advisory use."
            )
        }

        if (!evidence.metaboliteChainAssessed ||
            evidence.transformationStatus == TransformationStatus.INSUFFICIENT_METHOD_SCOPE) {
            return Assessment(
                readiness = readiness,
                threshold = evidence.profile.readinessThreshold,
                eligible = false,
                status = "withheld",
                reason = "Transformation products or metabolite-chain scope is incomplete."
            )
        }

        if (evidence.testInoculum.viabilityFraction < 0.60 ||
            evidence.referenceInoculum.viabilityFraction < 0.60) {
            return Assessment(
                readiness = readiness,
                threshold = evidence.profile.readinessThreshold,
                eligible = false,
                status = "withheld",
                reason = "Inoculum viability is below the configured evaluation floor."
            )
        }

        val salinityDifference = kotlin.math.abs(
            evidence.testInoculum.salinityPpt - evidence.referenceInoculum.salinityPpt
        )

        if (salinityDifference > 5.0) {
            return Assessment(
                readiness = readiness,
                threshold = evidence.profile.readinessThreshold,
                eligible = false,
                status = "withheld",
                reason = "Test and reference salinity conditions are not comparable."
            )
        }

        val testCorrected = correctedConcentration(
            evidence.testInoculum.testControlMgL,
            evidence.testInoculum.blankReferenceMgL
        )
        val referenceCorrected = correctedConcentration(
            evidence.referenceInoculum.referenceControlMgL,
            evidence.referenceInoculum.blankReferenceMgL
        )

        if (testCorrected <= 0.0 || referenceCorrected <= 0.0) {
            return Assessment(
                readiness = readiness,
                threshold = evidence.profile.readinessThreshold,
                eligible = false,
                status = "withheld",
                reason = "Independent blank correction does not yield usable test and reference signals."
            )
        }

        val eligible = readiness >= evidence.profile.readinessThreshold
        return Assessment(
            readiness = readiness,
            threshold = evidence.profile.readinessThreshold,
            eligible = eligible,
            status = if (eligible) "advisory" else "informational",
            reason = if (eligible) {
                "Readiness meets the versioned profile threshold."
            } else {
                "Readiness is below the versioned profile threshold."
            }
        )
    }

    private fun correctedConcentration(rawMgL: Double, blankMgL: Double): Double {
        return max(0.0, rawMgL - blankMgL)
    }

    private fun requireProbability(value: Double) {
        require(value.isFinite() && value in 0.0..1.0) {
            "A normalized value must be finite and within [0, 1]."
        }
    }

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
