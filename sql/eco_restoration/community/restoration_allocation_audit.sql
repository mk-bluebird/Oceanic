PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS aggregate_restoration_allocation_input (
    aggregate_id TEXT PRIMARY KEY,
    observed_at_utc TEXT NOT NULL,
    hex_resolution INTEGER NOT NULL CHECK (
        hex_resolution BETWEEN 0 AND 15
    ),
    aggregation_window_start_utc TEXT NOT NULL,
    aggregation_window_end_utc TEXT NOT NULL,
    ecological_need REAL NOT NULL CHECK (
        ecological_need BETWEEN 0.0 AND 1.0
    ),
    knowledge_factor REAL NOT NULL CHECK (
        knowledge_factor BETWEEN 0.0 AND 1.0
    ),
    eco_impact_value REAL NOT NULL CHECK (
        eco_impact_value BETWEEN 0.0 AND 1.0
    ),
    harm_risk REAL NOT NULL CHECK (
        harm_risk BETWEEN 0.0 AND 1.0
    ),
    accessibility_impact REAL NOT NULL CHECK (
        accessibility_impact BETWEEN 0.0 AND 1.0
    ),
    community_burden REAL NOT NULL CHECK (
        community_burden BETWEEN 0.0 AND 1.0
    ),
    source_valid INTEGER NOT NULL CHECK (
        source_valid IN (0, 1)
    ),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_eligible INTEGER NOT NULL CHECK (
        retention_eligible IN (0, 1)
    ),
    access_equivalent INTEGER NOT NULL CHECK (
        access_equivalent IN (0, 1)
    ),
    proxy_risk_detected INTEGER NOT NULL CHECK (
        proxy_risk_detected IN (0, 1)
    ),
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL,
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    CHECK (
        aggregation_window_end_utc > aggregation_window_start_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS restoration_allocation_fairness_audit (
    audit_id TEXT PRIMARY KEY,
    aggregate_id TEXT NOT NULL REFERENCES aggregate_restoration_allocation_input(aggregate_id),
    structural_model_version TEXT NOT NULL,
    scenario_set_version TEXT NOT NULL,
    baseline_priority REAL NOT NULL CHECK (
        baseline_priority BETWEEN 0.0 AND 1.0
    ),
    maximum_observed_difference REAL NOT NULL CHECK (
        maximum_observed_difference BETWEEN 0.0 AND 1.0
    ),
    audit_status TEXT NOT NULL CHECK (
        audit_status IN (
            'audit_passed_for_declared_scenarios',
            'audit_withheld_insufficient_structural_model',
            'audit_withheld_proxy_risk',
            'audit_withheld_access_equivalence_failure',
            'human_review_required'
        )
    ),
    reviewed_at_utc TEXT NOT NULL,
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL
) STRICT;

CREATE VIEW IF NOT EXISTS restoration_allocation_review_view AS
SELECT
    input.aggregate_id,
    input.hex_resolution,
    input.aggregation_window_start_utc,
    input.aggregation_window_end_utc,
    input.ecological_need,
    input.knowledge_factor,
    input.eco_impact_value,
    input.harm_risk,
    input.accessibility_impact,
    input.community_burden,
    audit.audit_status,
    audit.maximum_observed_difference,
    input.correction_path,
    input.appeal_path
FROM aggregate_restoration_allocation_input AS input
LEFT JOIN restoration_allocation_fairness_audit AS audit
    ON audit.aggregate_id = input.aggregate_id
WHERE input.tombstoned = 0
  AND input.source_valid = 1
  AND input.consent_scope_valid = 1
  AND input.retention_eligible = 1
  AND input.access_equivalent = 1
  AND input.proxy_risk_detected = 0
  AND input.retention_until_utc > strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
