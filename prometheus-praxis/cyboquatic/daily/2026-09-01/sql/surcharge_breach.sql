PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;

CREATE TABLE IF NOT EXISTS canal_nodes (
    canal_node TEXT PRIMARY KEY NOT NULL,
    node_label TEXT NOT NULL,
    design_lps REAL NOT NULL CHECK (design_lps > 0.0 AND design_lps <= 100000.0),
    minimum_freeboard_m REAL NOT NULL CHECK (minimum_freeboard_m >= 0.0 AND minimum_freeboard_m <= 20.0),
    downstream_control_distance_m REAL NOT NULL CHECK (
        downstream_control_distance_m > 0.0 AND downstream_control_distance_m <= 100000.0
    ),
    fog_media_state TEXT NOT NULL CHECK (
        fog_media_state IN ('modeled', 'unmodeled', 'mixed', 'unknown')
    ),
    fog_fallback_route TEXT NOT NULL CHECK (
        fog_fallback_route IN ('human_review', 'containment_hold', 'offline_alarm')
    ),
    canal_sensitive_receptor INTEGER NOT NULL DEFAULT 0 CHECK (
        canal_sensitive_receptor IN (0, 1)
    ),
    created_at_utc TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;

CREATE TABLE IF NOT EXISTS ker_governance (
    governance_key TEXT PRIMARY KEY NOT NULL,
    knowledge_factor REAL NOT NULL CHECK (knowledge_factor >= 0.0 AND knowledge_factor <= 1.0),
    eco_impact_value REAL NOT NULL CHECK (eco_impact_value >= 0.0 AND eco_impact_value <= 1.0),
    harm_risk REAL NOT NULL CHECK (harm_risk >= 0.0 AND harm_risk <= 1.0),
    rights_alignment REAL NOT NULL CHECK (rights_alignment >= 0.0 AND rights_alignment <= 1.0),
    accessibility_impact REAL NOT NULL CHECK (accessibility_impact >= 0.0 AND accessibility_impact <= 1.0),
    review_status TEXT NOT NULL CHECK (
        review_status IN ('approved', 'conditional', 'review_required', 'blocked')
    ),
    reviewed_at_utc TEXT NOT NULL,
    reviewer_role TEXT NOT NULL CHECK (
        reviewer_role IN ('operator', 'environmental_steward', 'safety_reviewer', 'community_representative')
    )
) STRICT;

CREATE TABLE IF NOT EXISTS surcharge_breach_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    canal_node TEXT NOT NULL REFERENCES canal_nodes(canal_node),
    governance_key TEXT NOT NULL REFERENCES ker_governance(governance_key),
    observed_at_utc TEXT NOT NULL,
    flow_lps REAL NOT NULL CHECK (flow_lps >= 0.0 AND flow_lps <= 100000.0),
    head_m REAL NOT NULL CHECK (head_m >= 0.0 AND head_m <= 100.0),
    freeboard_m REAL NOT NULL CHECK (freeboard_m >= 0.0 AND freeboard_m <= 20.0),
    bod_mg_l REAL NOT NULL CHECK (bod_mg_l >= 0.0 AND bod_mg_l <= 100000.0),
    tss_mg_l REAL NOT NULL CHECK (tss_mg_l >= 0.0 AND tss_mg_l <= 100000.0),
    cec_meq_100g REAL NOT NULL CHECK (cec_meq_100g >= 0.0 AND cec_meq_100g <= 500.0),
    telemetry_consent_scope TEXT NOT NULL CHECK (
        telemetry_consent_scope = 'machinery_safety_and_restoration_containment'
    ),
    retention_until_utc TEXT NOT NULL,
    deletion_requested_at_utc TEXT,
    operator_explanation TEXT NOT NULL,
    human_review_state TEXT NOT NULL CHECK (
        human_review_state IN ('not_required', 'pending', 'acknowledged', 'resolved')
    ),
    CHECK (retention_until_utc >= observed_at_utc),
    CHECK (
        deletion_requested_at_utc IS NULL
        OR deletion_requested_at_utc >= observed_at_utc
    )
) STRICT;

CREATE INDEX IF NOT EXISTS idx_surcharge_breach_events_node_time
ON surcharge_breach_events(canal_node, observed_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_surcharge_breach_events_review
ON surcharge_breach_events(human_review_state, observed_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_surcharge_breach_events_retention
ON surcharge_breach_events(retention_until_utc);

CREATE VIEW IF NOT EXISTS surcharge_blast_radius AS
SELECT
    e.event_id,
    e.canal_node,
    e.observed_at_utc,
    e.flow_lps,
    n.design_lps,
    ROUND(e.flow_lps / n.design_lps, 4) AS surcharge_ratio,
    e.head_m,
    e.freeboard_m,
    e.bod_mg_l,
    e.tss_mg_l,
    e.cec_meq_100g,
    n.fog_media_state,
    n.fog_fallback_route,
    ROUND(
        (e.flow_lps / n.design_lps)
        + CASE
            WHEN e.freeboard_m < 0.50 THEN 0.50 - e.freeboard_m
            ELSE 0.0
          END,
        4
    ) AS hydraulic_score,
    ROUND(
        (e.bod_mg_l / 30.0)
        + (e.tss_mg_l / 100.0)
        + CASE
            WHEN e.cec_meq_100g < 20.0 THEN (20.0 - e.cec_meq_100g) / 20.0
            ELSE 0.0
          END,
        4
    ) AS ecological_score,
    ROUND(
        n.downstream_control_distance_m
        * MIN(
            1.0,
            MAX(
                0.10,
                (
                    (e.flow_lps / n.design_lps)
                    + CASE
                        WHEN e.freeboard_m < 0.50 THEN 0.50 - e.freeboard_m
                        ELSE 0.0
                      END
                ) / 2.0
            )
        ),
        2
    ) AS blast_radius_m,
    CASE
        WHEN n.fog_media_state IN ('unmodeled', 'unknown')
            THEN 'human_review_required'
        WHEN e.flow_lps / n.design_lps >= 1.30
            OR e.freeboard_m <= 0.20
            OR (
                (e.bod_mg_l / 30.0)
                + (e.tss_mg_l / 100.0)
                + CASE
                    WHEN e.cec_meq_100g < 20.0 THEN (20.0 - e.cec_meq_100g) / 20.0
                    ELSE 0.0
                  END
            ) >= 3.00
            THEN 'critical'
        WHEN e.flow_lps / n.design_lps >= 1.10
            OR (
                (e.bod_mg_l / 30.0)
                + (e.tss_mg_l / 100.0)
                + CASE
                    WHEN e.cec_meq_100g < 20.0 THEN (20.0 - e.cec_meq_100g) / 20.0
                    ELSE 0.0
                  END
            ) >= 1.75
            THEN 'elevated'
        ELSE 'contained'
    END AS containment_status,
    k.knowledge_factor,
    k.eco_impact_value,
    k.harm_risk,
    k.rights_alignment,
    k.accessibility_impact,
    k.review_status
FROM surcharge_breach_events AS e
JOIN canal_nodes AS n ON n.canal_node = e.canal_node
JOIN ker_governance AS k ON k.governance_key = e.governance_key;

CREATE TRIGGER IF NOT EXISTS enforce_review_for_unmodeled_media
BEFORE INSERT ON surcharge_breach_events
FOR EACH ROW
WHEN (
    SELECT fog_media_state
    FROM canal_nodes
    WHERE canal_node = NEW.canal_node
) IN ('unmodeled', 'unknown')
AND NEW.human_review_state = 'not_required'
BEGIN
    SELECT RAISE(ABORT, 'unmodeled FOG media requires accessible human review');
END;

CREATE TRIGGER IF NOT EXISTS prevent_unapproved_governance_use
BEFORE INSERT ON surcharge_breach_events
FOR EACH ROW
WHEN (
    SELECT review_status
    FROM ker_governance
    WHERE governance_key = NEW.governance_key
) = 'blocked'
BEGIN
    SELECT RAISE(ABORT, 'blocked KER governance record cannot authorize machinery telemetry');
END;
