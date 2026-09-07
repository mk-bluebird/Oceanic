PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS review_token (
    token_id TEXT PRIMARY KEY,
    issued_at_utc TEXT NOT NULL,
    expires_at_utc TEXT NOT NULL,
    used_at_utc TEXT,
    revoked_at_utc TEXT,
    purpose TEXT NOT NULL CHECK (
        purpose IN (
            'human_review',
            'correction',
            'appeal'
        )
    ),
    CHECK (expires_at_utc > issued_at_utc)
) STRICT;

CREATE TABLE IF NOT EXISTS advisory_event (
    event_id TEXT PRIMARY KEY,
    advisory_id TEXT NOT NULL,
    sequence_number INTEGER NOT NULL CHECK (sequence_number > 0),
    previous_event_id TEXT,
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'created',
            'fog_transition',
            'review_requested',
            'review_completed',
            'material_change',
            'retention_tombstoned',
            'deletion_completed'
        )
    ),
    occurred_at_utc TEXT NOT NULL,
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'unmodeled_media',
            'human_review_pending',
            'human_review_complete',
            'withhold'
        )
    ),
    replacement_evidence_id TEXT,
    consent_rechecked INTEGER NOT NULL DEFAULT 0 CHECK (
        consent_rechecked IN (0, 1)
    ),
    token_id TEXT REFERENCES review_token(token_id),
    payload_json TEXT NOT NULL,
    PRIMARY KEY (advisory_id, sequence_number),
    UNIQUE (event_id)
) STRICT;

CREATE TRIGGER IF NOT EXISTS advisory_event_chain_guard
BEFORE INSERT ON advisory_event
BEGIN
    SELECT CASE
        WHEN NEW.sequence_number = 1
            AND NEW.previous_event_id IS NOT NULL
        THEN RAISE(ABORT, 'first advisory event must not have a previous event')
    END;

    SELECT CASE
        WHEN NEW.sequence_number > 1
            AND NOT EXISTS (
                SELECT 1
                FROM advisory_event AS prior
                WHERE prior.advisory_id = NEW.advisory_id
                  AND prior.sequence_number = NEW.sequence_number - 1
                  AND prior.event_id = NEW.previous_event_id
            )
        THEN RAISE(ABORT, 'previous event does not match the immediately prior sequence')
    END;

    SELECT CASE
        WHEN NEW.sequence_number > 1
            AND NOT EXISTS (
                SELECT 1
                FROM advisory_event AS prior
                WHERE prior.advisory_id = NEW.advisory_id
                  AND prior.sequence_number = NEW.sequence_number - 1
            )
        THEN RAISE(ABORT, 'sequence number is not contiguous')
    END;

    SELECT CASE
        WHEN NEW.token_id IS NOT NULL
            AND NOT EXISTS (
                SELECT 1
                FROM review_token AS token
                WHERE token.token_id = NEW.token_id
                  AND token.used_at_utc IS NULL
                  AND token.revoked_at_utc IS NULL
                  AND token.expires_at_utc > NEW.occurred_at_utc
            )
        THEN RAISE(ABORT, 'review token is expired, revoked, or already used')
    END;

    SELECT CASE
        WHEN NEW.event_type = 'review_completed'
            AND (
                NEW.replacement_evidence_id IS NULL
                OR NEW.consent_rechecked <> 1
            )
        THEN RAISE(ABORT, 'review completion requires replacement evidence and consent recheck')
    END;

    SELECT CASE
        WHEN NEW.fog_state = 'clear'
            AND EXISTS (
                SELECT 1
                FROM advisory_event AS prior
                WHERE prior.advisory_id = NEW.advisory_id
                  AND prior.sequence_number = NEW.sequence_number - 1
                  AND prior.fog_state = 'withhold'
            )
        THEN RAISE(ABORT, 'withhold cannot transition directly to clear')
    END;
END;

CREATE TRIGGER IF NOT EXISTS advisory_event_token_consume
AFTER INSERT ON advisory_event
WHEN NEW.token_id IS NOT NULL
BEGIN
    UPDATE review_token
    SET used_at_utc = NEW.occurred_at_utc
    WHERE token_id = NEW.token_id
      AND used_at_utc IS NULL;
END;

CREATE TABLE IF NOT EXISTS retention_deletion_candidate (
    candidate_id TEXT PRIMARY KEY,
    record_class TEXT NOT NULL,
    record_id TEXT NOT NULL,
    retention_until_utc TEXT NOT NULL,
    marked_at_utc TEXT NOT NULL,
    review_required INTEGER NOT NULL CHECK (review_required IN (0, 1)),
    deletion_status TEXT NOT NULL CHECK (
        deletion_status IN (
            'pending_human_review',
            'eligible_for_deletion',
            'deleted',
            'cancelled'
        )
    ),
    UNIQUE (record_class, record_id)
) STRICT;

CREATE VIEW IF NOT EXISTS retention_expiry_candidates AS
SELECT
    'biodegradation_evidence' AS record_class,
    evidence_id AS record_id,
    retention_until_utc
FROM biodegradation_evidence
WHERE tombstoned = 0
  AND retention_until_utc <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
