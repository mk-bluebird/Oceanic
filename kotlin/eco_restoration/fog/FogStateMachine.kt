package eco_restoration.fog

import java.time.Instant

object FogStateMachine {
    enum class State {
        CLEAR,
        UNMODELED_MEDIA,
        HUMAN_REVIEW_PENDING,
        HUMAN_REVIEW_COMPLETE,
        WITHHOLD
    }

    enum class ReasonCode {
        MISSING_MEDIUM,
        MISSING_PARAMETER,
        PARAMETER_EXPIRED,
        CALIBRATION_FAILURE,
        UNMODELED_MEDIA,
        SEDIMENT_WATER_PARTITION_UNCERTAIN,
        SORPTION_HYSTERESIS_UNRESOLVED,
        COLD_SURVIVAL_UNRESOLVED,
        SEGMENTED_DECAY_REQUIRED,
        DETECTION_LIMIT_MISSING,
        SAMPLING_WINDOW_MISSING,
        MATRIX_MISSING,
        RESOLUTION_INCOMPATIBLE,
        CONSENT_WITHDRAWAL,
        RETENTION_EXPIRED,
        RISK_BOUNDARY,
        ACCESS_EQUIVALENCE_MISSING,
        INTEGRITY_FAILURE
    }

    data class Transition(
        val advisoryId: String,
        val from: State,
        val to: State,
        val reason: ReasonCode,
        val transitionedAt: Instant,
        val reviewerReference: String? = null
    ) {
        init {
            require(advisoryId.isNotBlank()) { "advisoryId must not be blank." }
            require(!(from == State.WITHHOLD && to == State.CLEAR)) {
                "A withheld advisory cannot transition directly to clear."
            }
            require(
                !(to == State.HUMAN_REVIEW_COMPLETE && reviewerReference.isNullOrBlank())
            ) {
                "Human review completion requires a reviewer reference."
            }
        }
    }

    fun canTransition(from: State, to: State): Boolean {
        return when (from) {
            State.CLEAR -> to in setOf(
                State.CLEAR,
                State.UNMODELED_MEDIA,
                State.HUMAN_REVIEW_PENDING,
                State.WITHHOLD
            )

            State.UNMODELED_MEDIA -> to in setOf(
                State.UNMODELED_MEDIA,
                State.HUMAN_REVIEW_PENDING,
                State.WITHHOLD
            )

            State.HUMAN_REVIEW_PENDING -> to in setOf(
                State.HUMAN_REVIEW_PENDING,
                State.HUMAN_REVIEW_COMPLETE,
                State.WITHHOLD
            )

            State.HUMAN_REVIEW_COMPLETE -> to in setOf(
                State.HUMAN_REVIEW_COMPLETE,
                State.CLEAR,
                State.UNMODELED_MEDIA,
                State.HUMAN_REVIEW_PENDING,
                State.WITHHOLD
            )

            State.WITHHOLD -> to in setOf(
                State.WITHHOLD,
                State.HUMAN_REVIEW_PENDING
            )
        }
    }

    fun validate(transition: Transition): Transition {
        require(canTransition(transition.from, transition.to)) {
            "Prohibited FOG state transition: ${transition.from} -> ${transition.to}."
        }
        return transition
    }

    fun requiresWithholding(reason: ReasonCode): Boolean {
        return reason in setOf(
            ReasonCode.MISSING_PARAMETER,
            ReasonCode.PARAMETER_EXPIRED,
            ReasonCode.CALIBRATION_FAILURE,
            ReasonCode.DETECTION_LIMIT_MISSING,
            ReasonCode.SAMPLING_WINDOW_MISSING,
            ReasonCode.MATRIX_MISSING,
            ReasonCode.RESOLUTION_INCOMPATIBLE,
            ReasonCode.CONSENT_WITHDRAWAL,
            ReasonCode.RETENTION_EXPIRED,
            ReasonCode.RISK_BOUNDARY,
            ReasonCode.ACCESS_EQUIVALENCE_MISSING,
            ReasonCode.INTEGRITY_FAILURE
        )
    }

    fun requiredState(reason: ReasonCode): State {
        return if (requiresWithholding(reason)) {
            State.WITHHOLD
        } else {
            State.HUMAN_REVIEW_PENDING
        }
    }
}
