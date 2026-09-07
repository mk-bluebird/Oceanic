PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS participatory_monitoring_aggregate (
    aggregate_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    hex_resolution INTEGER NOT NULL CHECK (
        hex_resolution BETWEEN 0 AND 15
    ),
    aggregation_start_utc TEXT NOT NULL,
    aggregation_end_utc TEXT NOT NULL,
    contributor_count INTEGER NOT NULL CHECK (
        contributor_count >= 0
    ),
    clipped_raw_aggregate REAL NOT NULL CHECK (
        clipped_raw_aggregate >= 0.0
    ),
    noisy_aggregate REAL NOT NULL,
    sensitivity REAL NOT NULL CHECK (
        sensitivity > 0.0
    ),
    epsilon_spent REAL NOT NULL CHECK (
        epsilon_spent > 0.0
    ),
    release_status TEXT NOT NULL CHECK (
        release_status IN (
            'release_candidate',
            'withheld',
            'released',
            'superseded'
        )
    ),
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'human_review_pending',
            'withhold'
        )
    ),
    contributor_threshold INTEGER NOT NULL CHECK (
        contributor_threshold > 0
    ),
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL,
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    CHECK (aggregation_end_utc > aggregation_start_utc),
    CHECK (contributor_count >= contributor_threshold OR release_status = 'withheld'),
    CHECK NOT (
        fog_state <> 'clear'
        AND release_status IN ('release_candidate', 'released')
    )
) STRICT;

CREATE TABLE IF NOT EXISTS participatory_privacy_budget (
    budget_scope_id TEXT PRIMARY KEY,
    epsilon_total REAL NOT NULL CHECK (epsilon_total > 0.0),
    epsilon_spent REAL NOT NULL DEFAULT 0.0 CHECK (
        epsilon_spent >= 0.0
        AND epsilon_spent <= epsilon_total
    ),
    updated_at_utc TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS participatory_privacy_release_audit (
    release_id TEXT PRIMARY KEY,
    aggregate_id TEXT NOT NULL REFERENCES participatory_monitoring_aggregate(aggregate_id),
    budget_scope_id TEXT NOT NULL REFERENCES participatory_privacy_budget(budget_scope_id),
    epsilon_spent REAL NOT NULL CHECK (epsilon_spent > 0.0),
    released_at_utc TEXT NOT NULL,
    human_verified INTEGER NOT NULL DEFAULT 0 CHECK (
        human_verified IN (0, 1)
    ),
    CHECK (epsilon_spent > 0.0)
) STRICT;

CREATE TRIGGER IF NOT EXISTS participatory_privacy_budget_guard
BEFORE INSERT ON participatory_privacy_release_audit
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM participatory_privacy_budget
            WHERE budget_scope_id = NEW.budget_scope_id
              AND epsilon_spent + NEW.epsilon_spent <= epsilon_total
        )
        THEN RAISE(ABORT, 'privacy budget exhausted')
    END;
END;

CREATE TRIGGER IF NOT EXISTS participatory_privacy_budget_consume
AFTER INSERT ON participatory_privacy_release_audit
BEGIN
    UPDATE participatory_privacy_budget
    SET epsilon_spent = epsilon_spent + NEW.epsilon_spent,
        updated_at_utc = NEW.released_at_utc
    WHERE budget_scope_id = NEW.budget_scope_id;
END;
