package eco_restoration.biodegradation

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

object BiodegradationAssessment {
    private const val MINIMUM_SIGNAL_MG_L = 1e-12
    private const val MINIMUM_INOCULUM_VIABILITY = 0.60
    private const val MAXIMUM_SALINITY_DIFFERENCE_PPT = 5.0
    private const val MAXIMUM_RISK_FOR_ADVISORY = 0.35
    private const val MINIMUM_KNOWLEDGE_FOR_ADVISORY = 0.60

    enum class Matrix {
        WATER_COLUMN,
        BED_SEDIMENT,
        BANK_SEDIMENT,
        SOIL,
        COMPOST,
        UNKNOWN
    }

    enum class FogState {
        CLEAR,
        UNMODELED_TRANSFORMATION_PRODUCT,
        HUMAN_REVIEW_PENDING,
        WITHHOLD
    }

    enum class Status {
        ADVISORY,
        INFORMATIONAL,
        WITHHELD
    }

    data class InoculumContext(
        val sourceId: String,
        val viabilityFraction: Double,
        val blankMgL: Double,
        val observedMgL: Double,
        val salinityPpt: Double
    ) {
        init {
            require(sourceId.isNotBlank()) { "sourceId must not be blank." }
            requireProbability(viabilityFraction, "viabilityFraction")
            requireNonNegative(blankMgL, "blankMgL")
            requireNonNegative(observedMgL, "observedMgL")
            requireNonNegative(salinityPpt, "salinityPpt")
        }
    }

    data class KerProvenance(
        val sourceValid: Boolean,
        val parameterCurrent: Boolean,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean,
        val methodVersion: String,
        val calibrationVersion: String
    ) {
        init {
            require(methodVersion.isNotBlank()) { "methodVersion must not be blank." }
            require(calibrationVersion.isNotBlank()) {
                "calibrationVersion must not be blank."
            }
        }
    }

    data class Evidence(
        val evidenceId: String,
        val matrix: Matrix,
        val observedAtUtc: String,
        val testInoculum: InoculumContext,
        val referenceInoculum: InoculumContext,
        val temperatureC: Double,
        val ph: Double,
        val detectionLimitMgL: Double,
        val transformationProductFlag: Boolean,
        val transformationProductScopeComplete: Boolean,
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
        val accessibilityRisk: Double,
        val operationalRisk: Double,
        val equityRisk: Double,
        val communityBurdenRisk: Double,
        val kerProvenance: KerProvenance
    ) {
        init {
            require(evidenceId.isNotBlank()) { "evidenceId must not be blank." }
            require(observedAtUtc.isNotBlank()) { "observedAtUtc must not be blank." }
            require(temperatureC.isFinite()) { "temperatureC must be finite." }
            require(ph.isFinite() && ph in 0.0..14.0) { "ph must be within [0, 14]." }
            requireNonNegative(detectionLimitMgL, "detectionLimitMgL")

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
                accessibilityRisk,
                operationalRisk,
                equityRisk,
                communityBurdenRisk
            ).forEach { requireProbability(it, "normalized field") }
        }
    }

    data class Result(
        val correctedTestSignal: Double,
        val correctedReferenceSignal: Double,
        val correctedRatio: Double?,
        val readiness: Double,
        val knowledgeFactor: Double,
        val ecoImpactValue: Double,
        val harmRisk: Double,
        val fogState: FogState,
        val status: Status,
        val reason: String
    )

    fun evaluate(evidence: Evidence): Result {
        val correctedTest = correctedSignal(
            evidence.testInoculum.observedMgL,
            evidence.testInoculum.blankMgL
        )
        val correctedReference = correctedSignal(
            evidence.referenceInoculum.observedMgL,
            evidence.referenceInoculum.blankMgL
        )
        val ratio = if (correctedReference > MINIMUM_SIGNAL_MG_L) {
            clamp01(correctedTest / correctedReference)
        } else {
            null
        }

        val readiness = clamp01(
            0.50 * evidence.biodegradationFraction +
                0.20 * evidence.referenceValidity +
                0.15 * evidence.temperatureSuitability +
                0.10 * evidence.phSuitability +
                0.05 * evidence.timingSuitability
        )

        val knowledge = clamp01(
            0.25 * evidence.measurementPrecision +
                0.20 * evidence.calibrationConfidence +
                0.20 * evidence.reproducibility +
                0.15 * evidence.sampleRepresentativeness +
                0.10 * evidence.temporalRelevance +
                0.10 * evidence.spatialRelevance
        )

        val risk = maxOf(
            evidence.ecologicalHarmRisk,
            evidence.privacyRisk,
            evidence.accessibilityRisk,
            evidence.operationalRisk,
            evidence.equityRisk,
            evidence.communityBurdenRisk
        )

        val ecoImpact = clamp01(readiness * evidence.ecologicalMaterialValue * (1.0 - risk))
        val eligibleProvenance = evidence.kerProvenance.sourceValid &&
            evidence.kerProvenance.parameterCurrent &&
            evidence.kerProvenance.consentScopeValid &&
            evidence.kerProvenance.retentionEligible

        if (!eligibleProvenance) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "Source, parameter, consent, or retention provenance is not eligible."
            )
        }

        if (evidence.matrix == Matrix.UNKNOWN) {
            return reviewRequired(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                FogState.HUMAN_REVIEW_PENDING,
                "Material matrix is unknown and requires medium-specific review."
            )
        }

        if (evidence.transformationProductFlag && !evidence.transformationProductScopeComplete) {
            return reviewRequired(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                FogState.UNMODELED_TRANSFORMATION_PRODUCT,
                "Transformation-product scope is incomplete."
            )
        }

        if (evidence.testInoculum.viabilityFraction < MINIMUM_INOCULUM_VIABILITY ||
            evidence.referenceInoculum.viabilityFraction < MINIMUM_INOCULUM_VIABILITY) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "Test or reference inoculum viability is below the configured evidence floor."
            )
        }

        if (abs(evidence.testInoculum.salinityPpt - evidence.referenceInoculum.salinityPpt) >
            MAXIMUM_SALINITY_DIFFERENCE_PPT) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "Test and reference salinity conditions are not comparable."
            )
        }

        if (ratio == null) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "Reference blank-corrected signal is not sufficient for a stable ratio."
            )
        }

        if (risk > MAXIMUM_RISK_FOR_ADVISORY) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "A non-compensating risk boundary was crossed."
            )
        }

        if (knowledge < MINIMUM_KNOWLEDGE_FOR_ADVISORY) {
            return withheld(
                correctedTest,
                correctedReference,
                ratio,
                readiness,
                knowledge,
                ecoImpact,
                risk,
                "Knowledge factor is below the advisory threshold."
            )
        }

        return Result(
            correctedTestSignal = correctedTest,
            correctedReferenceSignal = correctedReference,
            correctedRatio = ratio,
            readiness = readiness,
            knowledgeFactor = knowledge,
            ecoImpactValue = ecoImpact,
            harmRisk = risk,
            fogState = FogState.CLEAR,
            status = Status.ADVISORY,
            reason = "Bounded biodegradable-material advisory is eligible for human review."
        )
    }

    private fun correctedSignal(observedMgL: Double, blankMgL: Double): Double {
        return max(0.0, observedMgL - blankMgL)
    }

    private fun withheld(
        correctedTest: Double,
        correctedReference: Double,
        ratio: Double?,
        readiness: Double,
        knowledge: Double,
        ecoImpact: Double,
        risk: Double,
        reason: String
    ): Result = Result(
        correctedTest,
        correctedReference,
        ratio,
        readiness,
        knowledge,
        ecoImpact,
        risk,
        FogState.WITHHOLD,
        Status.WITHHELD,
        reason
    )

    private fun reviewRequired(
        correctedTest: Double,
        correctedReference: Double,
        ratio: Double?,
        readiness: Double,
        knowledge: Double,
        ecoImpact: Double,
        risk: Double,
        fogState: FogState,
        reason: String
    ): Result = Result(
        correctedTest,
        correctedReference,
        ratio,
        readiness,
        knowledge,
        ecoImpact,
        risk,
        fogState,
        Status.WITHHELD,
        reason
    )

    private fun requireProbability(value: Double, name: String) {
        require(value.isFinite() && value in 0.0..1.0) {
            "$name must be finite and within [0, 1]."
        }
    }

    private fun requireNonNegative(value: Double, name: String) {
        require(value.isFinite() && value >= 0.0) {
            "$name must be finite and non-negative."
        }
    }

    private fun clamp01(value: Double): Double = min(1.0, max(0.0, value))
}
