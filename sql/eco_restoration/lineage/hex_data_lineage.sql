PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS hex_lineage_node (
    content_id TEXT PRIMARY KEY CHECK (
        length(content_id) = 64
    ),
    schema_version TEXT NOT NULL,
    data_class TEXT NOT NULL,
    hex_anchor TEXT NOT NULL,
    spatial_scheme_version TEXT NOT NULL,
    observed_at_utc TEXT NOT NULL,
    valid_from_utc TEXT,
    valid_to_utc TEXT,
    model_version TEXT NOT NULL,
    parameter_version TEXT NOT NULL,
    provenance_class TEXT NOT NULL CHECK (
        provenance_class IN (
            'observation',
            'parameter',
            'transformation',
            'advisory',
            'proof_certificate',
            'aggregate_summary'
        )
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    CHECK (
        valid_to_utc IS NULL
        OR valid_from_utc IS NULL
        OR valid_to_utc > valid_from_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS hex_lineage_edge (
    child_content_id TEXT NOT NULL REFERENCES hex_lineage_node(content_id),
    parent_content_id TEXT NOT NULL REFERENCES hex_lineage_node(content_id),
    relationship_type TEXT NOT NULL CHECK (
        relationship_type IN (
            'derived_from',
            'parameterized_by',
            'aggregated_from',
            'reviewed_from',
            'proved_against'
        )
    ),
    registered_at_utc TEXT NOT NULL,
    PRIMARY KEY (
        child_content_id,
        parent_content_id,
        relationship_type
    ),
    CHECK (
        child_content_id <> parent_content_id
    )
) STRICT;

CREATE INDEX IF NOT EXISTS hex_lineage_node_anchor_time_idx
ON hex_lineage_node (
    hex_anchor,
    observed_at_utc
)
WHERE tombstoned = 0;

CREATE INDEX IF NOT EXISTS hex_lineage_edge_parent_idx
ON hex_lineage_edge (parent_content_id);
