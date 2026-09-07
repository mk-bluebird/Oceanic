PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS evidence_quality_grade (
    grade_id TEXT PRIMARY KEY,
    grade_label TEXT NOT NULL UNIQUE CHECK (grade_label IN ('A', 'B', 'C', 'D', 'E')),
    min_k REAL NOT NULL CHECK (min_k >= 0.0 AND min_k <= 1.0),
    max_k REAL NOT NULL CHECK (max_k >= 0.0 AND max_k <= 1.0),
    description TEXT NOT NULL,
    CHECK (min_k <= max_k)
) STRICT;

INSERT OR IGNORE INTO evidence_quality_grade (
    grade_id,
    grade_label,
    min_k,
    max_k,
    description
) VALUES
    ('grade-a', 'A', 0.85, 1.00, 'Strongly documented and applicable evidence.'),
    ('grade-b', 'B', 0.70, 0.849999, 'Good evidence with bounded limitations.'),
    ('grade-c', 'C', 0.60, 0.699999, 'Limited evidence eligible only with clear limitations.'),
    ('grade-d', 'D', 0.35, 0.599999, 'Weak or materially uncertain evidence.'),
    ('grade-e', 'E', 0.00, 0.349999, 'Insufficient, invalid, expired, or non-applicable evidence.');

CREATE TABLE IF NOT EXISTS biodegradable_evidence (
    evidence_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    observed_at_utc TEXT NOT NULL,
    biodegradation_fraction REAL NOT NULL CHECK (biodegradation_fraction BETWEEN 0.0 AND 1.0),
    reference_validity REAL NOT NULL CHECK (reference_validity BETWEEN 0.0 AND 1.0),
    temperature_suitability REAL NOT NULL CHECK (temperature_suitability BETWEEN 0.0 AND 1.0),
    ph_suitability REAL NOT NULL CHECK (ph_suitability BETWEEN 0.0 AND 1.0),
    timing_suitability REAL NOT NULL CHECK (timing_suitability BETWEEN 0.0 AND 1.0),
    measurement_precision REAL NOT NULL CHECK (measurement_precision BETWEEN 0.0 AND 1.0),
    calibration_confidence REAL NOT NULL CHECK (calibration_confidence BETWEEN 0.0 AND 1.0),
    reproducibility REAL NOT NULL CHECK (reproducibility BETWEEN 0.0 AND 1.0),
    sample_representativeness REAL NOT NULL CHECK (sample_representativeness BETWEEN 0.0 AND 1.0),
    temporal_relevance REAL NOT NULL CHECK (temporal_relevance BETWEEN 0.0 AND 1.0),
    spatial_relevance REAL NOT NULL CHECK (spatial_relevance BETWEEN 0.0 AND 1.0),
    ecological_material_value REAL NOT NULL CHECK (ecological_material_value BETWEEN 0.0 AND 1.0),
    ecological_harm_risk REAL NOT NULL CHECK (ecological_harm_risk BETWEEN 0.0 AND 1.0),
    privacy_risk REAL NOT NULL CHECK (privacy_risk BETWEEN 0.0 AND 1.0),
    accessibility_impact_risk REAL NOT NULL CHECK (accessibility_impact_risk BETWEEN 0.0 AND 1.0),
    operational_risk REAL NOT NULL CHECK (operational_risk BETWEEN 0.0 AND 1.0),
    equity_risk REAL NOT NULL CHECK (equity_risk BETWEEN 0.0 AND 1.0),
    community_burden_risk REAL NOT NULL CHECK (community_burden_risk BETWEEN 0.0 AND 1.0),
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    parameter_current INTEGER NOT NULL CHECK (parameter_current IN (0, 1)),
    consent_scope_valid INTEGER NOT NULL CHECK (consent_scope_valid IN (0, 1)),
    retention_eligible INTEGER NOT NULL CHECK (retention_eligible IN (0, 1)),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (tombstoned IN (0, 1)),
    readiness REAL GENERATED ALWAYS AS (
        MIN(
            1.0,
            MAX(
                0.0,
                0.50 * biodegradation_fraction +
                0.20 * reference_validity +
                0.15 * temperature_suitability +
                0.10 * ph_suitability +
                0.05 * timing_suitability
            )
        )
    ) STORED,
    k_factor REAL GENERATED ALWAYS AS (
        MIN(
            1.0,
            MAX(
                0.0,
                0.25 * measurement_precision +
                0.20 * calibration_confidence +
                0.20 * reproducibility +
                0.15 * sample_representativeness +
                0.10 * temporal_relevance +
                0.10 * spatial_relevance
            )
        )
    ) STORED,
    r_factor REAL GENERATED ALWAYS AS (
        MAX(
            ecological_harm_risk,
            privacy_risk,
            accessibility_impact_risk,
            operational_risk,
            equity_risk,
            community_burden_risk
        )
    ) STORED,
    e_factor REAL GENERATED ALWAYS AS (
        MIN(
            1.0,
            MAX(
                0.0,
                readiness * ecological_material_value * (1.0 - r_factor)
            )
        )
    ) STORED
) STRICT;

CREATE INDEX IF NOT EXISTS biodegradable_evidence_active_hex_time_idx
    ON biodegradable_evidence (hex_anchor, observed_at_utc)
    WHERE tombstoned = 0;

CREATE VIEW IF NOT EXISTS biodegradable_advisory_view AS
SELECT
    evidence_id,
    hex_anchor,
    observed_at_utc,
    readiness,
    k_factor,
    e_factor,
    r_factor,
    CASE
        WHEN tombstoned = 1 THEN 'withheld'
        WHEN source_valid = 0
            OR parameter_current = 0
            OR consent_scope_valid = 0
            OR retention_eligible = 0 THEN 'withheld'
        WHEN r_factor > 0.35 THEN 'withheld'
        WHEN k_factor < 0.60 THEN 'withheld'
        WHEN readiness < 0.60 THEN 'informational'
        ELSE 'advisory'
    END AS advisory_status,
    CASE
        WHEN tombstoned = 1 THEN 'unresolved'
        WHEN source_valid = 0
            OR parameter_current = 0
            OR consent_scope_valid = 0
            OR retention_eligible = 0 THEN 'unresolved'
        WHEN r_factor > 0.35 THEN 'withhold_risk'
        WHEN k_factor < 0.60 THEN 'withhold_knowledge'
        WHEN k_factor < 0.80 THEN 'partial'
        ELSE 'resolved'
    END AS fog_state
FROM biodegradable_evidence
WHERE tombstoned = 0
  AND retention_until_utc > strftime('%Y-%m-%dT%H:%M:%SZ', 'now');

CREATE TABLE IF NOT EXISTS biodegradable_deletion_audit (
    deletion_id TEXT PRIMARY KEY,
    deleted_at_utc TEXT NOT NULL,
    deletion_reason TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    record_count INTEGER NOT NULL CHECK (record_count >= 0),
    human_verified INTEGER NOT NULL DEFAULT 0 CHECK (human_verified IN (0, 1)),
    payload_delete_status TEXT NOT NULL CHECK (
        payload_delete_status IN ('pending', 'completed', 'verified')
    )
) STRICT;
