package eco_restoration.energy

import kotlin.math.max

object AdvisoryDvfsScheduler {
    enum class Status {
        ADVISORY_CANDIDATE,
        WITHHELD
    }

    enum class FogState {
        CLEAR,
        HUMAN_REVIEW_PENDING,
        WITHHOLD
    }

    data class CandidateProfile(
        val profileId: String,
        val capacitanceCoefficient: Double,
        val voltageV: Double,
        val frequencyHz: Double,
        val staticPowerW: Double,
        val durationSeconds: Double,
        val predictedTemperatureC: Double,
        val temperatureStandardDeviationC: Double,
        val safeTemperatureC: Double,
        val thermalUncertaintyMultiplier: Double,
        val sourceValid: Boolean,
        val parameterCurrent: Boolean,
        val consentScopeValid: Boolean,
        val retentionEligible: Boolean
    ) {
        init {
            require(profileId.isNotBlank()) { "profileId must not be blank." }
            listOf(
                capacitanceCoefficient,
                voltageV,
                frequencyHz,
                staticPowerW,
                durationSeconds,
                predictedTemperatureC,
                temperatureStandardDeviationC,
                safeTemperatureC,
                thermalUncertaintyMultiplier
            ).forEach {
                require(it.isFinite() && it >= 0.0) {
                    "Profile values must be finite and non-negative."
                }
            }
        }
    }

    data class Recommendation(
        val profileId: String?,
        val estimatedEnergyJ: Double?,
        val upperTemperatureC: Double?,
        val status: Status,
        val fogState: FogState,
        val reason: String
    )

    fun recommend(candidates: List<CandidateProfile>): Recommendation {
        require(candidates.isNotEmpty()) { "At least one candidate profile is required." }

        val eligible = candidates.filter {
            it.sourceValid &&
                it.parameterCurrent &&
                it.consentScopeValid &&
                it.retentionEligible
        }

        if (eligible.isEmpty()) {
            return Recommendation(
                null,
                null,
                null,
                Status.WITHHELD,
                FogState.WITHHOLD,
                "No profile has valid source, parameter, consent, and retention eligibility."
            )
        }

        val thermallySafe = eligible.filter {
            val upperTemperature = it.predictedTemperatureC +
                it.thermalUncertaintyMultiplier * it.temperatureStandardDeviationC
            upperTemperature <= it.safeTemperatureC
        }

        if (thermallySafe.isEmpty()) {
            return Recommendation(
                null,
                null,
                null,
                Status.WITHHELD,
                FogState.HUMAN_REVIEW_PENDING,
                "No candidate remains within the uncertainty-adjusted thermal limit."
            )
        }

        val selected = thermallySafe.minByOrNull(::estimatedEnergyJ)
            ?: error("A non-empty thermally safe list must have a minimum.")

        return Recommendation(
            profileId = selected.profileId,
            estimatedEnergyJ = estimatedEnergyJ(selected),
            upperTemperatureC = upperTemperatureC(selected),
            status = Status.ADVISORY_CANDIDATE,
            fogState = FogState.CLEAR,
            reason = "Lowest estimated-energy candidate within the uncertainty-adjusted thermal limit."
        )
    }

    fun estimatedEnergyJ(profile: CandidateProfile): Double {
        val dynamicPowerW = profile.capacitanceCoefficient *
            profile.voltageV *
            profile.voltageV *
            profile.frequencyHz

        val totalPowerW = max(0.0, profile.staticPowerW + dynamicPowerW)
        return totalPowerW * profile.durationSeconds
    }

    fun upperTemperatureC(profile: CandidateProfile): Double {
        return profile.predictedTemperatureC +
            profile.thermalUncertaintyMultiplier * profile.temperatureStandardDeviationC
    }
}
