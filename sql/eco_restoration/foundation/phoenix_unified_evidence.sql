PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS parameter_source (
    source_id TEXT PRIMARY KEY,
    source_type TEXT NOT NULL CHECK (
        source_type IN (
            'peer_reviewed',
            'lab_report',
            'field_study',
            'standard_method',
            'local_calibration',
            'other'
        )
    ),
    source_identifier TEXT NOT NULL,
    author_or_steward TEXT NOT NULL,
    institution_or_publisher TEXT NOT NULL,
    published_at_utc TEXT NOT NULL,
    evidence_quality REAL NOT NULL CHECK (
        evidence_quality BETWEEN 0.0 AND 1.0
    ),
    review_status TEXT NOT NULL CHECK (
        review_status IN (
            'pending',
            'accepted',
            'limited_use',
            'superseded',
            'rejected',
            'withdrawn'
        )
    ),
    valid_from_utc TEXT NOT NULL,
    valid_until_utc TEXT,
    scope_note TEXT NOT NULL,
    CHECK (
        valid_until_utc IS NULL
        OR valid_until_utc > valid_from_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS hex_resolution_registry (
    hex_anchor TEXT PRIMARY KEY,
    spatial_scheme TEXT NOT NULL,
    spatial_scheme_version TEXT NOT NULL,
    h3_resolution INTEGER NOT NULL CHECK (
        h3_resolution BETWEEN 0 AND 15
    ),
    parent_hex_anchor TEXT,
    valid_from_utc TEXT NOT NULL,
    valid_to_utc TEXT,
    positional_uncertainty_m REAL NOT NULL CHECK (
        positional_uncertainty_m >= 0.0
    ),
    boundary_assignment_rule TEXT NOT NULL,
    CHECK (
        valid_to_utc IS NULL
        OR valid_to_utc > valid_from_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS phoenix_unified_evidence (
    evidence_id TEXT PRIMARY KEY,
    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'ecological_material',
            'water_quality',
            'sediment_soil',
            'thermal',
            'connectivity',
            'infrastructure_energy',
            'fog_uncertainty',
            'community_justice',
            'negative_evidence'
        )
    ),
    hex_anchor TEXT NOT NULL REFERENCES hex_resolution_registry(hex_anchor),
    canal_node_id TEXT,
    observed_at_utc TEXT NOT NULL,
    valid_from_utc TEXT,
    valid_to_utc TEXT,
    domain_payload_json TEXT NOT NULL,
    parameter_source_id TEXT REFERENCES parameter_source(source_id),
    k_factor REAL NOT NULL CHECK (k_factor BETWEEN 0.0 AND 1.0),
    e_factor REAL NOT NULL CHECK (e_factor BETWEEN 0.0 AND 1.0),
    r_factor REAL NOT NULL CHECK (r_factor BETWEEN 0.0 AND 1.0),
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'unmodeled_media',
            'human_review_pending',
            'human_review_complete',
            'withhold'
        )
    ),
    fog_reason TEXT,
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    created_at_utc TEXT NOT NULL,
    CHECK (
        valid_to_utc IS NULL
        OR valid_from_utc IS NULL
        OR valid_to_utc > valid_from_utc
    ),
    CHECK NOT (
        fog_state = 'clear'
        AND consent_scope_valid = 0
    )
) STRICT;

CREATE TABLE IF NOT EXISTS negative_evidence (
    evidence_id TEXT PRIMARY KEY REFERENCES phoenix_unified_evidence(evidence_id),
    hypothesis_tested TEXT NOT NULL,
    result_finding TEXT NOT NULL CHECK (
        result_finding IN (
            'not_detected',
            'no_effect',
            'not_significant'
        )
    ),
    detection_limit TEXT,
    method TEXT NOT NULL,
    matrix_description TEXT NOT NULL,
    sampling_window_start_utc TEXT NOT NULL,
    sampling_window_end_utc TEXT NOT NULL,
    CHECK (
        sampling_window_end_utc > sampling_window_start_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS advisory_candidate (
    advisory_id TEXT PRIMARY KEY,
    aggregation_window_start_utc TEXT NOT NULL,
    aggregation_window_end_utc TEXT NOT NULL,
    status TEXT NOT NULL CHECK (
        status IN (
            'advisory_candidate',
            'informational',
            'withheld',
            'superseded'
        )
    ),
    max_risk REAL NOT NULL CHECK (max_risk BETWEEN 0.0 AND 1.0),
    min_knowledge REAL NOT NULL CHECK (
        min_knowledge BETWEEN 0.0 AND 1.0
    ),
    combined_k_factor REAL NOT NULL CHECK (
        combined_k_factor BETWEEN 0.0 AND 1.0
    ),
    combined_e_factor REAL NOT NULL CHECK (
        combined_e_factor BETWEEN 0.0 AND 1.0
    ),
    combined_r_factor REAL NOT NULL CHECK (
        combined_r_factor BETWEEN 0.0 AND 1.0
    ),
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'unmodeled_media',
            'human_review_pending',
            'human_review_complete',
            'withhold'
        )
    ),
    CHECK (
        aggregation_window_end_utc > aggregation_window_start_utc
    ),
    CHECK NOT (
        fog_state = 'withhold'
        AND status = 'advisory_candidate'
    ),
    CHECK NOT (
        fog_state = 'unmodeled_media'
        AND status = 'advisory_candidate'
    ),
    CHECK NOT (
        max_risk > 0.35
        AND status = 'advisory_candidate'
    ),
    CHECK NOT (
        min_knowledge < 0.60
        AND status = 'advisory_candidate'
    )
) STRICT;

CREATE TABLE IF NOT EXISTS advisory_evidence_provenance (
    advisory_id TEXT NOT NULL REFERENCES advisory_candidate(advisory_id),
    source_evidence_id TEXT NOT NULL REFERENCES phoenix_unified_evidence(evidence_id),
    transformation_chain_json TEXT NOT NULL,
    registered_at_utc TEXT NOT NULL,
    PRIMARY KEY (advisory_id, source_evidence_id)
) STRICT;

CREATE INDEX IF NOT EXISTS phoenix_unified_evidence_active_hex_time_idx
ON phoenix_unified_evidence (
    evidence_type,
    hex_anchor,
    observed_at_utc
)
WHERE tombstoned = 0;
