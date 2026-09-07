PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS telemetry_record (
    telemetry_id TEXT PRIMARY KEY,
    idempotency_key TEXT NOT NULL UNIQUE,
    observed_at_utc TEXT NOT NULL,
    hex_anchor TEXT NOT NULL,
    energyreq_j REAL NOT NULL CHECK (energyreq_j >= 0.0),
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    )
) STRICT;

CREATE TABLE IF NOT EXISTS telemetry_outbox (
    outbox_id TEXT PRIMARY KEY,
    telemetry_id TEXT NOT NULL UNIQUE REFERENCES telemetry_record(telemetry_id),
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at_utc TEXT NOT NULL,
    delivery_state TEXT NOT NULL CHECK (
        delivery_state IN (
            'queued',
            'retry_pending',
            'acknowledged',
            'withheld',
            'retention_expired'
        )
    ),
    delivery_attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (
        delivery_attempt_count >= 0
    ),
    last_attempt_at_utc TEXT,
    last_error_code TEXT
) STRICT;

CREATE TABLE IF NOT EXISTS telemetry_sink_receipt (
    sink_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    received_at_utc TEXT NOT NULL,
    receipt_state TEXT NOT NULL CHECK (
        receipt_state IN (
            'accepted',
            'duplicate_ignored',
            'rejected'
        )
    ),
    PRIMARY KEY (sink_id, idempotency_key)
) STRICT;

CREATE TRIGGER IF NOT EXISTS telemetry_outbox_eligibility_guard
BEFORE INSERT ON telemetry_outbox
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM telemetry_record
            WHERE telemetry_id = NEW.telemetry_id
              AND idempotency_key = NEW.idempotency_key
              AND source_valid = 1
              AND consent_scope_valid = 1
              AND tombstoned = 0
              AND retention_until_utc > NEW.created_at_utc
        )
        THEN RAISE(ABORT, 'telemetry is not eligible for outbox delivery')
    END;
END;
