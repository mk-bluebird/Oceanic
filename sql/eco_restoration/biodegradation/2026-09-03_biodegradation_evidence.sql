PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS biodegradation_method_profile (
    method_profile_id TEXT PRIMARY KEY,
    method_family TEXT NOT NULL CHECK (
        method_family IN (
            'ISO_14851',
            'ISO_14855',
            'OECD_201',
            'OECD_202',
            'OECD_301'
        )
    ),
    method_version TEXT NOT NULL,
    inoculum_source_profile TEXT NOT NULL,
    readiness_threshold REAL NOT NULL CHECK (
        readiness_threshold >= 0.0
        AND readiness_threshold <= 1.0
    ),
    valid_from_utc TEXT NOT NULL,
    valid_to_utc TEXT,
    parameter_source_id TEXT NOT NULL,
    review_status TEXT NOT NULL CHECK (
        review_status IN (
            'pending',
            'accepted',
            'limited_use',
            'superseded',
            'rejected'
        )
    ),
    CHECK (
        valid_to_utc IS NULL
        OR valid_to_utc > valid_from_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS biodegradation_evidence (
    evidence_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    canal_segment_id TEXT,
    observed_at_utc TEXT NOT NULL,
    matrix TEXT NOT NULL CHECK (
        matrix IN (
            'water_column',
            'bed_sediment',
            'bank_sediment',
            'soil',
            'compost',
            'unknown'
        )
    ),
    method_profile_id TEXT NOT NULL REFERENCES biodegradation_method_profile(method_profile_id),
    method_version TEXT NOT NULL,
    inoculum_source TEXT NOT NULL,
    test_inoculum_source TEXT NOT NULL,
    reference_inoculum_source TEXT NOT NULL,
    test_inoculum_viability REAL NOT NULL CHECK (
        test_inoculum_viability BETWEEN 0.0 AND 1.0
    ),
    reference_inoculum_viability REAL NOT NULL CHECK (
        reference_inoculum_viability BETWEEN 0.0 AND 1.0
    ),
    test_blank_mg_l REAL NOT NULL CHECK (test_blank_mg_l >= 0.0),
    reference_blank_mg_l REAL NOT NULL CHECK (reference_blank_mg_l >= 0.0),
    test_mg_l REAL NOT NULL CHECK (test_mg_l >= 0.0),
    reference_mg_l REAL NOT NULL CHECK (reference_mg_l >= 0.0),
    detection_limit_mg_l REAL NOT NULL CHECK (detection_limit_mg_l >= 0.0),
    temperature_c REAL NOT NULL,
    ph REAL NOT NULL CHECK (ph BETWEEN 0.0 AND 14.0),
    test_salinity_ppt REAL NOT NULL CHECK (test_salinity_ppt >= 0.0),
    reference_salinity_ppt REAL NOT NULL CHECK (reference_salinity_ppt >= 0.0),
    transformation_product_flag INTEGER NOT NULL CHECK (
        transformation_product_flag IN (0, 1)
    ),
    transformation_product_scope_complete INTEGER NOT NULL CHECK (
        transformation_product_scope_complete IN (0, 1)
    ),
    biodegradation_fraction REAL NOT NULL CHECK (
        biodegradation_fraction BETWEEN 0.0 AND 1.0
    ),
    reference_validity REAL NOT NULL CHECK (
        reference_validity BETWEEN 0.0 AND 1.0
    ),
    temperature_suitability REAL NOT NULL CHECK (
        temperature_suitability BETWEEN 0.0 AND 1.0
    ),
    ph_suitability REAL NOT NULL CHECK (
        ph_suitability BETWEEN 0.0 AND 1.0
    ),
    timing_suitability REAL NOT NULL CHECK (
        timing_suitability BETWEEN 0.0 AND 1.0
    ),
    measurement_precision REAL NOT NULL CHECK (
        measurement_precision BETWEEN 0.0 AND 1.0
    ),
    calibration_confidence REAL NOT NULL CHECK (
        calibration_confidence BETWEEN 0.0 AND 1.0
    ),
    reproducibility REAL NOT NULL CHECK (
        reproducibility BETWEEN 0.0 AND 1.0
    ),
    sample_representativeness REAL NOT NULL CHECK (
        sample_representativeness BETWEEN 0.0 AND 1.0
    ),
    temporal_relevance REAL NOT NULL CHECK (
        temporal_relevance BETWEEN 0.0 AND 1.0
    ),
    spatial_relevance REAL NOT NULL CHECK (
        spatial_relevance BETWEEN 0.0 AND 1.0
    ),
    ecological_material_value REAL NOT NULL CHECK (
        ecological_material_value BETWEEN 0.0 AND 1.0
    ),
    ecological_harm_risk REAL NOT NULL CHECK (
        ecological_harm_risk BETWEEN 0.0 AND 1.0
    ),
    privacy_risk REAL NOT NULL CHECK (
        privacy_risk BETWEEN 0.0 AND 1.0
    ),
    accessibility_risk REAL NOT NULL CHECK (
        accessibility_risk BETWEEN 0.0 AND 1.0
    ),
    operational_risk REAL NOT NULL CHECK (
        operational_risk BETWEEN 0.0 AND 1.0
    ),
    equity_risk REAL NOT NULL CHECK (
        equity_risk BETWEEN 0.0 AND 1.0
    ),
    community_burden_risk REAL NOT NULL CHECK (
        community_burden_risk BETWEEN 0.0 AND 1.0
    ),
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    parameter_current INTEGER NOT NULL CHECK (parameter_current IN (0, 1)),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_eligible INTEGER NOT NULL CHECK (
        retention_eligible IN (0, 1)
    ),
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
    corrected_test_signal REAL GENERATED ALWAYS AS (
        MAX(0.0, test_mg_l - test_blank_mg_l)
    ) STORED,
    corrected_reference_signal REAL GENERATED ALWAYS AS (
        MAX(0.0, reference_mg_l - reference_blank_mg_l)
    ) STORED,
    corrected_ratio REAL GENERATED ALWAYS AS (
        CASE
            WHEN corrected_reference_signal > 0.000000000001 THEN
                MIN(1.0, MAX(0.0, corrected_test_signal / corrected_reference_signal))
            ELSE NULL
        END
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
            accessibility_risk,
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

CREATE TABLE IF NOT EXISTS biodegradation_fog_reason (
    evidence_id TEXT NOT NULL REFERENCES biodegradation_evidence(evidence_id),
    reason_code TEXT NOT NULL CHECK (
        reason_code IN (
            'missing_medium',
            'missing_parameter',
            'calibration_failure',
            'unmodeled_transformation_product',
            'consent_withdrawal',
            'retention_expired',
            'risk_boundary',
            'privacy_boundary',
            'accessibility_boundary',
            'reference_signal_invalid',
            'inoculum_viability_invalid',
            'salinity_incomparable'
        )
    ),
    recorded_at_utc TEXT NOT NULL,
    details TEXT NOT NULL,
    PRIMARY KEY (evidence_id, reason_code)
) STRICT;

CREATE TABLE IF NOT EXISTS biodegradation_material_change (
    change_id TEXT PRIMARY KEY,
    evidence_id TEXT NOT NULL REFERENCES biodegradation_evidence(evidence_id),
    owner_did TEXT NOT NULL CHECK (
        owner_did = 'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7'
    ),
    changed_at_utc TEXT NOT NULL,
    prior_k_factor REAL NOT NULL CHECK (prior_k_factor BETWEEN 0.0 AND 1.0),
    next_k_factor REAL NOT NULL CHECK (next_k_factor BETWEEN 0.0 AND 1.0),
    prior_e_factor REAL NOT NULL CHECK (prior_e_factor BETWEEN 0.0 AND 1.0),
    next_e_factor REAL NOT NULL CHECK (next_e_factor BETWEEN 0.0 AND 1.0),
    prior_r_factor REAL NOT NULL CHECK (prior_r_factor BETWEEN 0.0 AND 1.0),
    next_r_factor REAL NOT NULL CHECK (next_r_factor BETWEEN 0.0 AND 1.0),
    change_reason TEXT NOT NULL,
    consent_rechecked INTEGER NOT NULL CHECK (consent_rechecked IN (0, 1)),
    non_interference_rechecked INTEGER NOT NULL CHECK (
        non_interference_rechecked IN (0, 1)
    ),
    review_status TEXT NOT NULL CHECK (
        review_status IN ('pending', 'approved', 'rejected', 'superseded')
    )
) STRICT;

CREATE VIEW IF NOT EXISTS biodegradation_advisory_view AS
SELECT
    e.evidence_id,
    e.hex_anchor,
    e.canal_segment_id,
    e.observed_at_utc,
    e.matrix,
    e.readiness,
    e.corrected_test_signal,
    e.corrected_reference_signal,
    e.corrected_ratio,
    e.k_factor,
    e.e_factor,
    e.r_factor,
    CASE
        WHEN e.tombstoned = 1 THEN 'withheld'
        WHEN e.source_valid = 0
            OR e.parameter_current = 0
            OR e.consent_scope_valid = 0
            OR e.retention_eligible = 0 THEN 'withheld'
        WHEN e.retention_until_utc <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now') THEN 'withheld'
        WHEN e.matrix = 'unknown' THEN 'withheld'
        WHEN e.transformation_product_flag = 1
            AND e.transformation_product_scope_complete = 0 THEN 'withheld'
        WHEN e.test_inoculum_viability < 0.60
            OR e.reference_inoculum_viability < 0.60 THEN 'withheld'
        WHEN ABS(e.test_salinity_ppt - e.reference_salinity_ppt) > 5.0 THEN 'withheld'
        WHEN e.corrected_ratio IS NULL THEN 'withheld'
        WHEN e.r_factor > 0.35 THEN 'withheld'
        WHEN e.k_factor < 0.60 THEN 'withheld'
        ELSE 'advisory_candidate'
    END AS advisory_status,
    CASE
        WHEN e.tombstoned = 1 THEN 'withhold'
        WHEN e.source_valid = 0
            OR e.parameter_current = 0
            OR e.consent_scope_valid = 0
            OR e.retention_eligible = 0 THEN 'withhold'
        WHEN e.retention_until_utc <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now') THEN 'withhold'
        WHEN e.matrix = 'unknown' THEN 'human_review_pending'
        WHEN e.transformation_product_flag = 1
            AND e.transformation_product_scope_complete = 0 THEN 'unmodeled_transformation_product'
        WHEN e.test_inoculum_viability < 0.60
            OR e.reference_inoculum_viability < 0.60 THEN 'withhold'
        WHEN ABS(e.test_salinity_ppt - e.reference_salinity_ppt) > 5.0 THEN 'withhold'
        WHEN e.corrected_ratio IS NULL THEN 'withhold'
        WHEN e.r_factor > 0.35 THEN 'withhold'
        WHEN e.k_factor < 0.60 THEN 'withhold'
        ELSE 'clear'
    END AS fog_state
FROM biodegradation_evidence AS e
WHERE e.tombstoned = 0;

CREATE INDEX IF NOT EXISTS biodegradation_active_hex_time_idx
ON biodegradation_evidence (hex_anchor, observed_at_utc)
WHERE tombstoned = 0;
