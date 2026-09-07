PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS fog_reason_taxonomy (
    reason_code TEXT PRIMARY KEY,
    reason_category TEXT NOT NULL CHECK (
        reason_category IN (
            'data_availability',
            'parameter_validity',
            'calibration',
            'model_scope',
            'temporal_scope',
            'spatial_scope',
            'consent',
            'retention',
            'risk',
            'accessibility',
            'integrity'
        )
    ),
    plain_language_label TEXT NOT NULL,
    advisory_effect TEXT NOT NULL CHECK (
        advisory_effect IN (
            'informational_only',
            'human_review_required',
            'withhold'
        )
    ),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
) STRICT;

INSERT OR IGNORE INTO fog_reason_taxonomy (
    reason_code,
    reason_category,
    plain_language_label,
    advisory_effect
) VALUES
    ('missing_medium', 'data_availability', 'The relevant environmental medium was not represented in the evidence.', 'human_review_required'),
    ('missing_parameter', 'parameter_validity', 'A required model or source parameter is missing.', 'withhold'),
    ('parameter_expired', 'parameter_validity', 'A required parameter is outside its approved validity period.', 'withhold'),
    ('calibration_failure', 'calibration', 'Calibration evidence is missing, failed, or outside the allowed range.', 'withhold'),
    ('unmodeled_media', 'model_scope', 'The model does not cover the observed medium or pathway.', 'human_review_required'),
    ('sediment_water_partition_uncertain', 'model_scope', 'Sediment and water-column partition behavior remains uncertain.', 'human_review_required'),
    ('sorption_hysteresis_unresolved', 'model_scope', 'Sorption or desorption hysteresis is not resolved by the current model.', 'human_review_required'),
    ('cold_survival_unresolved', 'model_scope', 'Cold-season persistence behavior is outside the validated model range.', 'human_review_required'),
    ('segmented_decay_required', 'model_scope', 'The observed drainage pattern requires more than one decay segment.', 'human_review_required'),
    ('detection_limit_missing', 'data_availability', 'The measurement detection limit was not recorded.', 'withhold'),
    ('sampling_window_missing', 'temporal_scope', 'The sample collection window was not recorded.', 'withhold'),
    ('matrix_missing', 'data_availability', 'The sampled material matrix was not recorded.', 'withhold'),
    ('resolution_incompatible', 'spatial_scope', 'The evidence cannot be safely combined at the requested spatial resolution.', 'withhold'),
    ('consent_withdrawal', 'consent', 'The permitted use of this evidence has been withdrawn.', 'withhold'),
    ('retention_expired', 'retention', 'The evidence has reached its retention limit.', 'withhold'),
    ('risk_boundary', 'risk', 'A non-compensating risk boundary was crossed.', 'withhold'),
    ('access_equivalence_missing', 'accessibility', 'An equivalent accessible review path is not available.', 'withhold'),
    ('integrity_failure', 'integrity', 'The evidence integrity or provenance check failed.', 'withhold');

CREATE TABLE IF NOT EXISTS advisory_fog_reason (
    advisory_id TEXT NOT NULL,
    reason_code TEXT NOT NULL REFERENCES fog_reason_taxonomy(reason_code),
    recorded_at_utc TEXT NOT NULL,
    details TEXT NOT NULL,
    PRIMARY KEY (advisory_id, reason_code)
) STRICT;

CREATE TABLE IF NOT EXISTS fog_state_transition (
    transition_id TEXT PRIMARY KEY,
    advisory_id TEXT NOT NULL,
    prior_state TEXT NOT NULL CHECK (
        prior_state IN (
            'clear',
            'unmodeled_media',
            'human_review_pending',
            'human_review_complete',
            'withhold'
        )
    ),
    next_state TEXT NOT NULL CHECK (
        next_state IN (
            'clear',
            'unmodeled_media',
            'human_review_pending',
            'human_review_complete',
            'withhold'
        )
    ),
    transition_reason TEXT NOT NULL,
    transitioned_at_utc TEXT NOT NULL,
    reviewer_reference TEXT,
    CHECK (
        NOT (
            prior_state = 'withhold'
            AND next_state = 'clear'
        )
    )
) STRICT;

CREATE TABLE IF NOT EXISTS ker_material_change (
    change_id TEXT PRIMARY KEY,
    advisory_id TEXT NOT NULL,
    owner_did TEXT NOT NULL,
    changed_at_utc TEXT NOT NULL,
    prior_k_factor REAL NOT NULL CHECK (prior_k_factor BETWEEN 0.0 AND 1.0),
    next_k_factor REAL NOT NULL CHECK (next_k_factor BETWEEN 0.0 AND 1.0),
    prior_e_factor REAL NOT NULL CHECK (prior_e_factor BETWEEN 0.0 AND 1.0),
    next_e_factor REAL NOT NULL CHECK (next_e_factor BETWEEN 0.0 AND 1.0),
    prior_r_factor REAL NOT NULL CHECK (prior_r_factor BETWEEN 0.0 AND 1.0),
    next_r_factor REAL NOT NULL CHECK (next_r_factor BETWEEN 0.0 AND 1.0),
    change_reason TEXT NOT NULL,
    model_version TEXT NOT NULL,
    parameter_version TEXT NOT NULL,
    review_status TEXT NOT NULL CHECK (
        review_status IN (
            'pending',
            'approved',
            'rejected',
            'superseded'
        )
    ),
    CHECK (
        owner_did = 'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7'
    )
) STRICT;

CREATE TABLE IF NOT EXISTS pfas_breakthrough_observation (
    evidence_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    observed_at_utc TEXT NOT NULL,
    sampling_window_start_utc TEXT NOT NULL,
    sampling_window_end_utc TEXT NOT NULL,
    medium TEXT NOT NULL CHECK (
        medium IN (
            'water_column',
            'bed_sediment',
            'bank_sediment',
            'porewater',
            'unknown'
        )
    ),
    matrix_description TEXT NOT NULL,
    analyte_code TEXT NOT NULL,
    concentration_value REAL,
    concentration_unit TEXT NOT NULL,
    detection_limit_value REAL NOT NULL CHECK (detection_limit_value >= 0.0),
    detection_limit_unit TEXT NOT NULL,
    detection_status TEXT NOT NULL CHECK (
        detection_status IN (
            'detected',
            'not_detected',
            'estimated',
            'invalid'
        )
    ),
    organic_carbon_fraction REAL CHECK (
        organic_carbon_fraction IS NULL
        OR organic_carbon_fraction BETWEEN 0.0 AND 1.0
    ),
    water_temperature_c REAL,
    cold_season_flag INTEGER NOT NULL DEFAULT 0 CHECK (cold_season_flag IN (0, 1)),
    sorption_hysteresis_assessed INTEGER NOT NULL DEFAULT 0 CHECK (
        sorption_hysteresis_assessed IN (0, 1)
    ),
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (tombstoned IN (0, 1)),
    CHECK (sampling_window_end_utc > sampling_window_start_utc),
    CHECK (
        (detection_status = 'detected' AND concentration_value IS NOT NULL)
        OR detection_status <> 'detected'
    )
) STRICT;

CREATE INDEX IF NOT EXISTS pfas_breakthrough_active_anchor_time_idx
ON pfas_breakthrough_observation (
    hex_anchor,
    medium,
    analyte_code,
    observed_at_utc
)
WHERE tombstoned = 0;

CREATE TABLE IF NOT EXISTS drainage_decay_observation (
    evidence_id TEXT PRIMARY KEY,
    canal_segment_id TEXT NOT NULL,
    hex_anchor TEXT NOT NULL,
    observed_at_utc TEXT NOT NULL,
    segment_kind TEXT NOT NULL CHECK (
        segment_kind IN (
            'early_flush',
            'settling',
            'mixed',
            'unknown'
        )
    ),
    bod_mg_l REAL CHECK (bod_mg_l >= 0.0),
    tss_mg_l REAL CHECK (tss_mg_l >= 0.0),
    cec_cmol_kg REAL CHECK (cec_cmol_kg >= 0.0),
    water_temperature_c REAL,
    residence_time_s REAL CHECK (residence_time_s >= 0.0),
    first_order_rate_per_s REAL CHECK (first_order_rate_per_s >= 0.0),
    slow_settling_rate_per_s REAL CHECK (slow_settling_rate_per_s >= 0.0),
    segment_break_time_s REAL CHECK (segment_break_time_s >= 0.0),
    model_scope_valid INTEGER NOT NULL CHECK (model_scope_valid IN (0, 1)),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (tombstoned IN (0, 1))
) STRICT;

CREATE TABLE IF NOT EXISTS participatory_monitoring_submission (
    submission_id TEXT PRIMARY KEY,
    submitted_at_utc TEXT NOT NULL,
    evidence_category TEXT NOT NULL CHECK (
        evidence_category IN (
            'ecological_material',
            'water_quality',
            'sediment_soil',
            'infrastructure_energy',
            'fog_uncertainty',
            'community_justice'
        )
    ),
    aggregation_window_start_utc TEXT NOT NULL,
    aggregation_window_end_utc TEXT NOT NULL,
    hex_resolution INTEGER NOT NULL CHECK (hex_resolution BETWEEN 0 AND 15),
    accessibility_impact REAL NOT NULL CHECK (
        accessibility_impact BETWEEN 0.0 AND 1.0
    ),
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL,
    consent_scope_valid INTEGER NOT NULL CHECK (consent_scope_valid IN (0, 1)),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (tombstoned IN (0, 1)),
    CHECK (aggregation_window_end_utc > aggregation_window_start_utc)
) STRICT;

CREATE TABLE IF NOT EXISTS deletion_audit (
    deletion_id TEXT PRIMARY KEY,
    executed_at_utc TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    deletion_reason TEXT NOT NULL,
    record_class TEXT NOT NULL,
    record_count INTEGER NOT NULL CHECK (record_count >= 0),
    human_verified INTEGER NOT NULL DEFAULT 0 CHECK (human_verified IN (0, 1)),
    backup_propagation_status TEXT NOT NULL CHECK (
        backup_propagation_status IN (
            'not_applicable',
            'pending',
            'verified'
        )
    )
) STRICT;
