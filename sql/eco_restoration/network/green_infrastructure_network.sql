PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS green_network_node (
    node_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    node_class TEXT NOT NULL CHECK (
        node_class IN (
            'canopy',
            'shade_structure',
            'water_feature',
            'habitat_patch',
            'soil_restoration',
            'community_cooling_access',
            'other'
        )
    ),
    active INTEGER NOT NULL DEFAULT 1 CHECK (
        active IN (0, 1)
    ),
    source_valid INTEGER NOT NULL CHECK (
        source_valid IN (0, 1)
    ),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    )
) STRICT;

CREATE TABLE IF NOT EXISTS green_network_edge (
    edge_id TEXT PRIMARY KEY,
    from_node_id TEXT NOT NULL REFERENCES green_network_node(node_id),
    to_node_id TEXT NOT NULL REFERENCES green_network_node(node_id),
    edge_weight REAL NOT NULL CHECK (
        edge_weight >= 0.0
    ),
    active INTEGER NOT NULL DEFAULT 1 CHECK (
        active IN (0, 1)
    ),
    source_valid INTEGER NOT NULL CHECK (
        source_valid IN (0, 1)
    ),
    parameter_current INTEGER NOT NULL CHECK (
        parameter_current IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    CHECK (from_node_id <> to_node_id),
    UNIQUE (from_node_id, to_node_id)
) STRICT;

CREATE TABLE IF NOT EXISTS green_network_resilience_assessment (
    assessment_id TEXT PRIMARY KEY,
    baseline_scenario_id TEXT NOT NULL,
    compared_scenario_id TEXT NOT NULL,
    algebraic_connectivity_baseline REAL NOT NULL CHECK (
        algebraic_connectivity_baseline >= 0.0
    ),
    algebraic_connectivity_scenario REAL NOT NULL CHECK (
        algebraic_connectivity_scenario >= 0.0
    ),
    connectivity_loss REAL NOT NULL CHECK (
        connectivity_loss >= 0.0
    ),
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'human_review_pending',
            'withhold'
        )
    ),
    status TEXT NOT NULL CHECK (
        status IN (
            'advisory_candidate',
            'withheld'
        )
    ),
    reviewed_at_utc TEXT NOT NULL,
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL,
    CHECK NOT (
        fog_state <> 'clear'
        AND status = 'advisory_candidate'
    )
) STRICT;

CREATE INDEX IF NOT EXISTS green_network_edge_active_from_idx
ON green_network_edge (from_node_id, to_node_id)
WHERE active = 1
  AND tombstoned = 0;
