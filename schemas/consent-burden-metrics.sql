PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS public_interfaces (
    interface_key TEXT PRIMARY KEY,
    interface_type TEXT NOT NULL CHECK (
        interface_type IN (
            'assistance_panel',
            'automatic_door',
            'environmental_sensor_display',
            'cooling_center_directory',
            'public_reserve_terminal'
        )
    ),
    display_name TEXT NOT NULL CHECK (
        length(display_name) BETWEEN 1 AND 160
    ),
    active INTEGER NOT NULL CHECK (
        active IN (0, 1)
    ),
    basic_environmental_data_access INTEGER NOT NULL CHECK (
        basic_environmental_data_access IN (0, 1)
    ),
    low_consent_alternative_available INTEGER NOT NULL CHECK (
        low_consent_alternative_available IN (0, 1)
    ),
    updated_at_utc TEXT NOT NULL CHECK (
        length(updated_at_utc) = 20
    )
) STRICT;

CREATE TABLE IF NOT EXISTS consent_burden_measurements (
    measurement_key TEXT PRIMARY KEY,
    interface_key TEXT NOT NULL REFERENCES public_interfaces(interface_key),
    measured_at_utc TEXT NOT NULL CHECK (
        length(measured_at_utc) = 20
    ),

    required_interactions REAL NOT NULL CHECK (
        required_interactions >= 0.0
    ),

    service_delivered_units REAL NOT NULL CHECK (
        service_delivered_units > 0.0
    ),

    data_requested_units REAL NOT NULL CHECK (
        data_requested_units >= 0.0
    ),

    data_necessary_units REAL NOT NULL CHECK (
        data_necessary_units > 0.0
    ),

    alternative_access INTEGER NOT NULL CHECK (
        alternative_access IN (0, 1)
    ),

    consent_burden_score REAL NOT NULL,
    burden_threshold REAL NOT NULL CHECK (
        burden_threshold >= 0.0
        AND burden_threshold <= 20.0
    ),

    measurement_status TEXT NOT NULL CHECK (
        measurement_status IN ('accepted', 'review_required', 'withheld')
    ),

    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    )
) STRICT;

CREATE TABLE IF NOT EXISTS consent_burden_events (
    event_key TEXT PRIMARY KEY,
    measurement_key TEXT NOT NULL REFERENCES consent_burden_measurements(
        measurement_key
    ),
    occurred_at_utc TEXT NOT NULL CHECK (
        length(occurred_at_utc) = 20
    ),
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'burden_threshold_exceeded',
            'low_consent_alternative_missing',
            'basic_service_consent_denial_detected',
            'redesign_required',
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

CREATE TABLE IF NOT EXISTS public_interface_service_outcomes (
    outcome_key TEXT PRIMARY KEY,
    interface_key TEXT NOT NULL REFERENCES public_interfaces(interface_key),
    occurred_at_utc TEXT NOT NULL CHECK (
        length(occurred_at_utc) = 20
    ),
    service_type TEXT NOT NULL CHECK (
        service_type IN (
            'basic_environmental_data',
            'cooling_center_directions',
            'public_reserve_information',
            'ker_explanation',
            'door_access',
            'accessibility_help'
        )
    ),
    consent_refused INTEGER NOT NULL CHECK (
        consent_refused IN (0, 1)
    ),
    service_outcome TEXT NOT NULL CHECK (
        service_outcome IN (
            'completed',
            'alternative_provided',
            'denied',
            'unavailable_with_explanation'
        )
    ),
    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    )
) STRICT;

CREATE TRIGGER IF NOT EXISTS consent_burden_formula_gate
BEFORE INSERT ON consent_burden_measurements
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.consent_burden_score != (
            NEW.required_interactions / NEW.service_delivered_units
            + NEW.data_requested_units / NEW.data_necessary_units
            - NEW.alternative_access
        )
        THEN RAISE(
            ABORT,
            'CONSENT_BURDEN_FORMULA_MISMATCH'
        )
    END;
END;

CREATE TRIGGER IF NOT EXISTS consent_burden_threshold_event
AFTER INSERT ON consent_burden_measurements
FOR EACH ROW
WHEN NEW.consent_burden_score > NEW.burden_threshold
BEGIN
    INSERT INTO consent_burden_events (
        event_key,
        measurement_key,
        occurred_at_utc,
        event_type,
        explanation_code,
        requires_human_review
    )
    VALUES (
        lower(hex(randomblob(16))),
        NEW.measurement_key,
        NEW.measured_at_utc,
        'burden_threshold_exceeded',
        'CONSENT_BURDEN_THRESHOLD_EXCEEDED',
        1
    );

    INSERT INTO consent_burden_events (
        event_key,
        measurement_key,
        occurred_at_utc,
        event_type,
        explanation_code,
        requires_human_review
    )
    VALUES (
        lower(hex(randomblob(16))),
        NEW.measurement_key,
        NEW.measured_at_utc,
        'redesign_required',
        'PUBLIC_INTERFACE_LOW_CONSENT_REDESIGN_REQUIRED',
        1
    );
END;

CREATE TRIGGER IF NOT EXISTS public_interface_low_consent_alternative_gate
BEFORE INSERT ON consent_burden_measurements
FOR EACH ROW
WHEN NOT EXISTS (
    SELECT 1
    FROM public_interfaces AS interface
    WHERE interface.interface_key = NEW.interface_key
      AND interface.low_consent_alternative_available = 1
)
BEGIN
    SELECT RAISE(
        ABORT,
        'PUBLIC_INTERFACE_LOW_CONSENT_ALTERNATIVE_REQUIRED'
    );
END;

CREATE TRIGGER IF NOT EXISTS basic_environmental_data_consent_refusal_gate
BEFORE INSERT ON public_interface_service_outcomes
FOR EACH ROW
WHEN NEW.service_type = 'basic_environmental_data'
 AND NEW.consent_refused = 1
 AND NEW.service_outcome = 'denied'
BEGIN
    SELECT RAISE(
        ABORT,
        'BASIC_ENVIRONMENTAL_DATA_MUST_NOT_BE_DENIED_FOR_CONSENT_REFUSAL'
    );
END;

CREATE VIEW IF NOT EXISTS consent_burden_audit_view AS
SELECT
    interface.interface_key,
    interface.interface_type,
    interface.display_name,
    interface.basic_environmental_data_access,
    interface.low_consent_alternative_available,
    measurement.measurement_key,
    measurement.measured_at_utc,
    measurement.required_interactions,
    measurement.service_delivered_units,
    measurement.data_requested_units,
    measurement.data_necessary_units,
    measurement.alternative_access,
    measurement.consent_burden_score,
    measurement.burden_threshold,
    CASE
        WHEN measurement.consent_burden_score > measurement.burden_threshold
            THEN 'redesign_required'
        WHEN interface.low_consent_alternative_available = 0
            THEN 'redesign_required'
        ELSE 'within_declared_burden_threshold'
    END AS consent_burden_governance_status
FROM consent_burden_measurements AS measurement
JOIN public_interfaces AS interface
    ON interface.interface_key = measurement.interface_key;
