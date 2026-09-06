PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS canal_nodes (
    canal_node_key TEXT PRIMARY KEY,
    display_name TEXT NOT NULL CHECK (
        length(display_name) BETWEEN 1 AND 160
    ),

    human_max_discharge_temperature_c REAL NOT NULL CHECK (
        human_max_discharge_temperature_c >= -10.0
        AND human_max_discharge_temperature_c <= 100.0
    ),

    aquatic_max_discharge_temperature_c REAL NOT NULL CHECK (
        aquatic_max_discharge_temperature_c >= -10.0
        AND aquatic_max_discharge_temperature_c <= 100.0
    ),

    riparian_max_discharge_temperature_c REAL NOT NULL CHECK (
        riparian_max_discharge_temperature_c >= -10.0
        AND riparian_max_discharge_temperature_c <= 100.0
    ),

    avian_max_discharge_temperature_c REAL NOT NULL CHECK (
        avian_max_discharge_temperature_c >= -10.0
        AND avian_max_discharge_temperature_c <= 100.0
    ),

    threshold_source_status TEXT NOT NULL CHECK (
        threshold_source_status IN (
            'approved',
            'provisional',
            'expired',
            'missing',
            'review_required'
        )
    ),

    threshold_valid_until_utc TEXT NOT NULL CHECK (
        length(threshold_valid_until_utc) = 20
    ),

    updated_at_utc TEXT NOT NULL CHECK (
        length(updated_at_utc) = 20
    )
) STRICT;

CREATE TABLE IF NOT EXISTS canal_thermal_discharges (
    discharge_key TEXT PRIMARY KEY,
    canal_node_key TEXT NOT NULL REFERENCES canal_nodes(canal_node_key),
    recorded_at_utc TEXT NOT NULL CHECK (
        length(recorded_at_utc) = 20
    ),

    discharge_temperature_c REAL NOT NULL CHECK (
        discharge_temperature_c >= -10.0
        AND discharge_temperature_c <= 100.0
    ),

    permit_status TEXT NOT NULL CHECK (
        permit_status IN ('permitted', 'denied', 'pending_review')
    ),

    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    ),

    human_reviewed INTEGER NOT NULL CHECK (
        human_reviewed IN (0, 1)
    )
) STRICT;

CREATE TABLE IF NOT EXISTS canal_thermal_constraint_events (
    event_key TEXT PRIMARY KEY,
    discharge_key TEXT NOT NULL REFERENCES canal_thermal_discharges(discharge_key),
    occurred_at_utc TEXT NOT NULL CHECK (
        length(occurred_at_utc) = 20
    ),
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'threshold_exceeded',
            'species_data_missing',
            'permit_denied',
            'human_review_requested'
        )
    ),
    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    ),
    requires_human_review INTEGER NOT NULL CHECK (
        requires_human_review IN (0, 1)
    )
) STRICT;

CREATE TRIGGER IF NOT EXISTS canal_discharge_species_threshold_gate
BEFORE INSERT ON canal_thermal_discharges
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM canal_nodes AS node
            WHERE node.canal_node_key = NEW.canal_node_key
              AND node.threshold_source_status = 'approved'
              AND node.threshold_valid_until_utc >= NEW.recorded_at_utc
        )
        THEN RAISE(
            ABORT,
            'CANAL_SPECIES_THERMAL_DATA_MISSING_OR_NOT_CURRENT_FAIL_CLOSED'
        )
    END;

    SELECT CASE
        WHEN NEW.discharge_temperature_c > (
            SELECT MIN(
                MIN(
                    human_max_discharge_temperature_c,
                    aquatic_max_discharge_temperature_c
                ),
                MIN(
                    riparian_max_discharge_temperature_c,
                    avian_max_discharge_temperature_c
                )
            )
            FROM canal_nodes
            WHERE canal_node_key = NEW.canal_node_key
        )
        AND NEW.permit_status = 'permitted'
        THEN RAISE(
            ABORT,
            'CANAL_DISCHARGE_EXCEEDS_MOST_SENSITIVE_SPECIES_THRESHOLD'
        )
    END;
END;

CREATE TRIGGER IF NOT EXISTS canal_discharge_threshold_event
AFTER INSERT ON canal_thermal_discharges
FOR EACH ROW
WHEN NEW.permit_status = 'denied'
BEGIN
    INSERT INTO canal_thermal_constraint_events (
        event_key,
        discharge_key,
        occurred_at_utc,
        event_type,
        explanation_code,
        requires_human_review
    )
    VALUES (
        lower(hex(randomblob(16))),
        NEW.discharge_key,
        NEW.recorded_at_utc,
        'permit_denied',
        NEW.explanation_code,
        1
    );
END;
