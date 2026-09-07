package eco_restoration.fog

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class FogStateMachineTest {
    @Test
    fun validFiniteTraceIsAccepted() {
        val transitions = listOf(
            FogStateMachine.Transition(
                advisoryId = "advisory-fog-trace-001",
                from = FogStateMachine.State.CLEAR,
                to = FogStateMachine.State.UNMODELED_MEDIA,
                reason = FogStateMachine.ReasonCode.UNMODELED_MEDIA,
                transitionedAt = Instant.parse("2026-09-06T18:00:00Z")
            ),
            FogStateMachine.Transition(
                advisoryId = "advisory-fog-trace-001",
                from = FogStateMachine.State.UNMODELED_MEDIA,
                to = FogStateMachine.State.HUMAN_REVIEW_PENDING,
                reason = FogStateMachine.ReasonCode.SEDIMENT_WATER_PARTITION_UNCERTAIN,
                transitionedAt = Instant.parse("2026-09-06T18:05:00Z")
            ),
            FogStateMachine.Transition(
                advisoryId = "advisory-fog-trace-001",
                from = FogStateMachine.State.HUMAN_REVIEW_PENDING,
                to = FogStateMachine.State.HUMAN_REVIEW_COMPLETE,
                reason = FogStateMachine.ReasonCode.UNMODELED_MEDIA,
                transitionedAt = Instant.parse("2026-09-06T18:15:00Z"),
                reviewerReference = "review-local-001"
            ),
            FogStateMachine.Transition(
                advisoryId = "advisory-fog-trace-001",
                from = FogStateMachine.State.HUMAN_REVIEW_COMPLETE,
                to = FogStateMachine.State.CLEAR,
                reason = FogStateMachine.ReasonCode.UNMODELED_MEDIA,
                transitionedAt = Instant.parse("2026-09-06T18:20:00Z")
            )
        )

        transitions.forEach(FogStateMachine::validate)
        assertTrue(transitions.isNotEmpty())
    }

    @Test
    fun prohibitedWithholdToClearTraceIsRejected() {
        val transition = FogStateMachine.Transition(
            advisoryId = "advisory-fog-trace-002",
            from = FogStateMachine.State.WITHHOLD,
            to = FogStateMachine.State.CLEAR,
            reason = FogStateMachine.ReasonCode.RISK_BOUNDARY,
            transitionedAt = Instant.parse("2026-09-06T18:30:00Z")
        )

        assertFailsWith<IllegalArgumentException> {
            FogStateMachine.validate(transition)
        }
    }

    @Test
    fun coldSurvivalUncertaintyRequiresHumanReview() {
        val state = FogStateMachine.requiredState(
            FogStateMachine.ReasonCode.COLD_SURVIVAL_UNRESOLVED
        )

        assertTrue(state == FogStateMachine.State.HUMAN_REVIEW_PENDING)
    }

    @Test
    fun consentWithdrawalRequiresWithholding() {
        val state = FogStateMachine.requiredState(
            FogStateMachine.ReasonCode.CONSENT_WITHDRAWAL
        )

        assertTrue(state == FogStateMachine.State.WITHHOLD)
    }
}
