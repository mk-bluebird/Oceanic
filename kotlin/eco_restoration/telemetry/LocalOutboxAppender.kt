package eco_restoration.telemetry

import java.sql.Connection
import java.sql.PreparedStatement
import java.sql.SQLException

class LocalOutboxAppender(
    private val connectionProvider: () -> Connection
) {
    data class TelemetryInput(
        val telemetryId: String,
        val idempotencyKey: String,
        val observedAtUtc: String,
        val hexAnchor: String,
        val energyreqJ: Double,
        val sourceValid: Boolean,
        val consentScopeValid: Boolean,
        val retentionUntilUtc: String,
        val outboxId: String,
        val createdAtUtc: String
    ) {
        init {
            require(telemetryId.isNotBlank()) { "telemetryId must not be blank." }
            require(idempotencyKey.isNotBlank()) { "idempotencyKey must not be blank." }
            require(observedAtUtc.isNotBlank()) { "observedAtUtc must not be blank." }
            require(hexAnchor.isNotBlank()) { "hexAnchor must not be blank." }
            require(energyreqJ.isFinite() && energyreqJ >= 0.0) {
                "energyreqJ must be finite and non-negative."
            }
            require(retentionUntilUtc.isNotBlank()) {
                "retentionUntilUtc must not be blank."
            }
            require(outboxId.isNotBlank()) { "outboxId must not be blank." }
            require(createdAtUtc.isNotBlank()) { "createdAtUtc must not be blank." }
        }
    }

    fun append(input: TelemetryInput): Boolean {
        connectionProvider().use { connection ->
            connection.autoCommit = false

            try {
                insertTelemetry(connection, input)
                insertOutbox(connection, input)
                connection.commit()
                return true
            } catch (error: SQLException) {
                connection.rollback()
                if (isUniqueViolation(error)) {
                    return false
                }
                throw error
            } finally {
                connection.autoCommit = true
            }
        }
    }

    private fun insertTelemetry(connection: Connection, input: TelemetryInput) {
        connection.prepareStatement(
            """
            INSERT INTO telemetry_record (
                telemetry_id,
                idempotency_key,
                observed_at_utc,
                hex_anchor,
                energyreq_j,
                source_valid,
                consent_scope_valid,
                retention_until_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """.trimIndent()
        ).use { statement ->
            statement.bindTelemetry(input)
            statement.executeUpdate()
        }
    }

    private fun insertOutbox(connection: Connection, input: TelemetryInput) {
        connection.prepareStatement(
            """
            INSERT INTO telemetry_outbox (
                outbox_id,
                telemetry_id,
                idempotency_key,
                created_at_utc,
                delivery_state
            ) VALUES (?, ?, ?, ?, 'queued')
            """.trimIndent()
        ).use { statement ->
            statement.setString(1, input.outboxId)
            statement.setString(2, input.telemetryId)
            statement.setString(3, input.idempotencyKey)
            statement.setString(4, input.createdAtUtc)
            statement.executeUpdate()
        }
    }

    private fun PreparedStatement.bindTelemetry(input: TelemetryInput) {
        setString(1, input.telemetryId)
        setString(2, input.idempotencyKey)
        setString(3, input.observedAtUtc)
        setString(4, input.hexAnchor)
        setDouble(5, input.energyreqJ)
        setInt(6, if (input.sourceValid) 1 else 0)
        setInt(7, if (input.consentScopeValid) 1 else 0)
        setString(8, input.retentionUntilUtc)
    }

    private fun isUniqueViolation(error: SQLException): Boolean {
        return error.message?.contains("UNIQUE constraint failed") == true
    }
}
