PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS heat_island_conversion_factors (
    conversion_factor_key TEXT PRIMARY KEY,
    component_type TEXT NOT NULL CHECK (
        component_type IN (
            'shade_equivalent',
            'evapotranspiration_benefit',
            'albedo_improvement',
            'waste_heat_burden'
        )
    ),
    source_unit TEXT NOT NULL CHECK (
        length(source_unit) BETWEEN 1 AND 64
    ),
    target_unit TEXT NOT NULL CHECK (
        target_unit = 'equivalent_tree_canopy_m2'
    ),
    factor_value REAL NOT NULL CHECK (
        factor_value > 0.0
    ),
    factor_uncertainty_fraction REAL NOT NULL CHECK (
        factor_uncertainty_fraction >= 0.0
        AND factor_uncertainty_fraction <= 1.0
    ),
    method_summary TEXT NOT NULL CHECK (
        length(method_summary) BETWEEN 12 AND 1600
    ),
    valid_from_utc TEXT NOT NULL CHECK (
        length(valid_from_utc) = 20
    ),
    valid_until_utc TEXT NOT NULL CHECK (
        length(valid_until_utc) = 20
    ),
    review_status TEXT NOT NULL CHECK (
        review_status IN ('approved', 'provisional', 'expired', 'revoked')
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_island_recovery_measurements (
    measurement_key TEXT PRIMARY KEY,
    facility_key TEXT NOT NULL CHECK (
        length(facility_key) BETWEEN 1 AND 160
    ),
    accounting_period_start_utc TEXT NOT NULL CHECK (
        length(accounting_period_start_utc) = 20
    ),
    accounting_period_end_utc TEXT NOT NULL CHECK (
        length(accounting_period_end_utc) = 20
    ),

    facility_footprint_m2 REAL NOT NULL CHECK (
        facility_footprint_m2 > 0.0
    ),

    shade_equivalent_source_value REAL NOT NULL CHECK (
        shade_equivalent_source_value >= 0.0
    ),
    shade_equivalent_factor_key TEXT NOT NULL REFERENCES heat_island_conversion_factors(
        conversion_factor_key
    ),

    evapotranspiration_source_value REAL NOT NULL CHECK (
        evapotranspiration_source_value >= 0.0
    ),
    evapotranspiration_factor_key TEXT NOT NULL REFERENCES heat_island_conversion_factors(
        conversion_factor_key
    ),

    albedo_source_value REAL NOT NULL CHECK (
        albedo_source_value >= 0.0
    ),
    albedo_factor_key TEXT NOT NULL REFERENCES heat_island_conversion_factors(
        conversion_factor_key
    ),

    waste_heat_source_value REAL NOT NULL CHECK (
        waste_heat_source_value >= 0.0
    ),
    waste_heat_factor_key TEXT NOT NULL REFERENCES heat_island_conversion_factors(
        conversion_factor_key
    ),

    shade_equivalent_canopy_m2 REAL NOT NULL CHECK (
        shade_equivalent_canopy_m2 >= 0.0
    ),
    evapotranspiration_benefit_canopy_m2 REAL NOT NULL CHECK (
        evapotranspiration_benefit_canopy_m2 >= 0.0
    ),
    albedo_improvement_canopy_m2 REAL NOT NULL CHECK (
        albedo_improvement_canopy_m2 >= 0.0
    ),
    waste_heat_burden_canopy_m2 REAL NOT NULL CHECK (
        waste_heat_burden_canopy_m2 >= 0.0
    ),

    hirci_point_estimate REAL NOT NULL,
    hirci_lower_bound REAL NOT NULL,
    hirci_upper_bound REAL NOT NULL,

    measurement_status TEXT NOT NULL CHECK (
        measurement_status IN (
            'accepted',
            'provisional',
            'withheld',
            'review_required'
        )
    ),

    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    ),

    CHECK (
        accounting_period_end_utc > accounting_period_start_utc
    ),

    CHECK (
        hirci_lower_bound <= hirci_point_estimate
        AND hirci_point_estimate <= hirci_upper_bound
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_island_recovery_events (
    event_key TEXT PRIMARY KEY,
    measurement_key TEXT NOT NULL REFERENCES heat_island_recovery_measurements(
        measurement_key
    ),
    occurred_at_utc TEXT NOT NULL CHECK (
        length(occurred_at_utc) = 20
    ),
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'measurement_accepted',
            'negative_hirci_detected',
            'human_review_requested',
            'remedy_pathway_opened',
            'public_claim_withheld'
        )
    ),
    explanation_code TEXT NOT NULL CHECK (
        length(explanation_code) BETWEEN 3 AND 160
    ),
    requires_human_review INTEGER NOT NULL CHECK (
        requires_human_review IN (0, 1)
    )
) STRICT;

CREATE TRIGGER IF NOT EXISTS heat_island_recovery_formula_gate
BEFORE INSERT ON heat_island_recovery_measurements
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.shade_equivalent_canopy_m2 !=
            NEW.shade_equivalent_source_value * (
                SELECT factor_value
                FROM heat_island_conversion_factors
                WHERE conversion_factor_key = NEW.shade_equivalent_factor_key
                  AND component_type = 'shade_equivalent'
                  AND review_status = 'approved'
            )
        THEN RAISE(
            ABORT,
            'HIRCI_SHADE_EQUIVALENT_CONVERSION_MISMATCH'
        )
    END;

    SELECT CASE
        WHEN NEW.evapotranspiration_benefit_canopy_m2 !=
            NEW.evapotranspiration_source_value * (
                SELECT factor_value
                FROM heat_island_conversion_factors
                WHERE conversion_factor_key = NEW.evapotranspiration_factor_key
                  AND component_type = 'evapotranspiration_benefit'
                  AND review_status = 'approved'
            )
        THEN RAISE(
            ABORT,
            'HIRCI_EVAPOTRANSPIRATION_CONVERSION_MISMATCH'
        )
    END;

    SELECT CASE
        WHEN NEW.albedo_improvement_canopy_m2 !=
            NEW.albedo_source_value * (
                SELECT factor_value
                FROM heat_island_conversion_factors
                WHERE conversion_factor_key = NEW.albedo_factor_key
                  AND component_type = 'albedo_improvement'
                  AND review_status = 'approved'
            )
        THEN RAISE(
            ABORT,
            'HIRCI_ALBEDO_CONVERSION_MISMATCH'
        )
    END;

    SELECT CASE
        WHEN NEW.waste_heat_burden_canopy_m2 !=
            NEW.waste_heat_source_value * (
                SELECT factor_value
                FROM heat_island_conversion_factors
                WHERE conversion_factor_key = NEW.waste_heat_factor_key
                  AND component_type = 'waste_heat_burden'
                  AND review_status = 'approved'
            )
        THEN RAISE(
            ABORT,
            'HIRCI_WASTE_HEAT_CONVERSION_MISMATCH'
        )
    END;

    SELECT CASE
        WHEN NEW.hirci_point_estimate != (
            (
                NEW.shade_equivalent_canopy_m2
                + NEW.evapotranspiration_benefit_canopy_m2
                + NEW.albedo_improvement_canopy_m2
                - NEW.waste_heat_burden_canopy_m2
            ) / NEW.facility_footprint_m2
        )
        THEN RAISE(
            ABORT,
            'HIRCI_POINT_ESTIMATE_FORMULA_MISMATCH'
        )
    END;
END;

CREATE TRIGGER IF NOT EXISTS heat_island_negative_index_review
AFTER INSERT ON heat_island_recovery_measurements
FOR EACH ROW
WHEN NEW.hirci_point_estimate < 0.0
BEGIN
    INSERT INTO heat_island_recovery_events (
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
        NEW.accounting_period_end_utc,
        'negative_hirci_detected',
        'NEGATIVE_HEAT_ISLAND_RECOVERY_INDEX',
        1
    );

    INSERT INTO heat_island_recovery_events (
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
        NEW.accounting_period_end_utc,
        'public_claim_withheld',
        'HEAT_ISLAND_RECOVERY_CLAIM_WITHHELD_PENDING_REVIEW',
        1
    );
END;

CREATE VIEW IF NOT EXISTS heat_island_recovery_audit_view AS
SELECT
    measurement.measurement_key,
    measurement.facility_key,
    measurement.accounting_period_start_utc,
    measurement.accounting_period_end_utc,
    measurement.facility_footprint_m2,
    measurement.shade_equivalent_canopy_m2,
    measurement.evapotranspiration_benefit_canopy_m2,
    measurement.albedo_improvement_canopy_m2,
    measurement.waste_heat_burden_canopy_m2,
    measurement.hirci_point_estimate,
    measurement.hirci_lower_bound,
    measurement.hirci_upper_bound,
    measurement.measurement_status,
    measurement.explanation_code,
    CASE
        WHEN measurement.hirci_upper_bound < 0.0
            THEN 'negative_with_high_confidence'
        WHEN measurement.hirci_point_estimate < 0.0
            THEN 'negative_review_required'
        WHEN measurement.hirci_lower_bound < 0.0
            THEN 'uncertain_crosses_zero_review_required'
        ELSE 'nonnegative_within_reported_bounds'
    END AS hirci_governance_status
FROM heat_island_recovery_measurements AS measurement;
