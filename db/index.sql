-- =====================================================================
-- Eco-Fort Index Skeleton
-- Target: Prometheus-Praxis mono-repo / EcoNet-aligned Eco-Fort grammar
-- Compatibility: PostgreSQL (recommended) or any ANSI SQL engine
-- License: MIT OR Apache-2.0
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Core schema (namespace)
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS eco_fort;

SET search_path TO eco_fort;

-- ---------------------------------------------------------------------
-- 1. Identity & provenance (Bostrom / ALN / ERC-20 anchors)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS identities (
    identity_id         BIGSERIAL PRIMARY KEY,
    label               VARCHAR(128) NOT NULL,            -- e.g. 'primary', 'alternate', 'safe-alt'
    did_bostrom         VARCHAR(128),                     -- e.g. 'bostrom18sd2u...'
    aln_address         VARCHAR(128),                     -- ALN anchor where relevant
    erc20_address       VARCHAR(128),                     -- e.g. '0x519fC0eB4...'
    is_primary          BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_identities_did_bostrom
    ON identities (did_bostrom)
    WHERE did_bostrom IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_identities_aln_address
    ON identities (aln_address)
    WHERE aln_address IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_identities_erc20_address
    ON identities (erc20_address)
    WHERE erc20_address IS NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Eco-Fort sites (physical / cyboquatic installations)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fort_sites (
    fort_id             BIGSERIAL PRIMARY KEY,
    fort_code           VARCHAR(64) NOT NULL,             -- short human code, e.g. 'PHX-HEAT-01'
    name                VARCHAR(256) NOT NULL,            -- descriptive name
    description         TEXT,                             -- narrative, non-fictive but free-form
    latitude_deg        NUMERIC(9,6),                     -- e.g. 33.448377
    longitude_deg       NUMERIC(9,6),                     -- e.g. -112.074037
    elevation_m         NUMERIC(10,2),                    -- optional elevation
    location_region     VARCHAR(128),                     -- e.g. 'Phoenix, AZ, US'
    eco_biome_tag       VARCHAR(64),                      -- e.g. 'urban-heat-island', 'riparian'
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_identity BIGINT REFERENCES identities(identity_id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fort_sites_fort_code
    ON fort_sites (fort_code);

CREATE INDEX IF NOT EXISTS idx_fort_sites_biome
    ON fort_sites (eco_biome_tag);

CREATE INDEX IF NOT EXISTS idx_fort_sites_location_region
    ON fort_sites (location_region);

-- ---------------------------------------------------------------------
-- 3. Material library (biodegradable / recycled compounds)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS materials (
    material_id         BIGSERIAL PRIMARY KEY,
    material_code       VARCHAR(64) NOT NULL,              -- short code, e.g. 'BIO-POLY-01'
    name                VARCHAR(256) NOT NULL,
    description         TEXT,
    origin_type         VARCHAR(64),                       -- 'recycled', 'biogenic', 'hybrid'
    use_category        VARCHAR(64),                       -- 'structural', 'coating', 'fill', etc.
    biodegradability_score NUMERIC(5,2),                   -- 0.00–100.00, higher = better
    human_toxicity_score   NUMERIC(5,2),                   -- 0.00–100.00, higher = more harmful
    animal_toxicity_score  NUMERIC(5,2),
    lifecycle_co2_kg_per_kg NUMERIC(12,4),                 -- cradle-to-grave estimate
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_materials_code
    ON materials (material_code);

CREATE INDEX IF NOT EXISTS idx_materials_origin_type
    ON materials (origin_type);

CREATE INDEX IF NOT EXISTS idx_materials_biodegradability
    ON materials (biodegradability_score);

-- ---------------------------------------------------------------------
-- 4. Fort–Material bindings (what is deployed where)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fort_materials (
    fort_material_id    BIGSERIAL PRIMARY KEY,
    fort_id             BIGINT NOT NULL REFERENCES fort_sites(fort_id) ON DELETE CASCADE,
    material_id         BIGINT NOT NULL REFERENCES materials(material_id),
    deployment_phase    VARCHAR(64),                       -- 'concept', 'prototype', 'live'
    quantity_kg         NUMERIC(14,4),                     -- deployed or planned quantity
    exposure_profile    VARCHAR(64),                       -- 'soil-contact', 'water-contact', etc.
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fort_materials_fort_material_unique
    ON fort_materials (fort_id, material_id, deployment_phase);

CREATE INDEX IF NOT EXISTS idx_fort_materials_material_id
    ON fort_materials (material_id);

-- ---------------------------------------------------------------------
-- 5. Eco impact metrics (per fort, per time)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS eco_metrics (
    metric_id           BIGSERIAL PRIMARY KEY,
    fort_id             BIGINT NOT NULL REFERENCES fort_sites(fort_id) ON DELETE CASCADE,
    metric_ts           TIMESTAMPTZ NOT NULL,
    metric_source       VARCHAR(64) NOT NULL,              -- 'sensor', 'simulation', 'audit'
    heat_index_c        NUMERIC(7,2),                      -- local heat index
    soil_health_index   NUMERIC(7,2),                      -- composite soil score
    water_quality_index NUMERIC(7,2),                      -- composite water score
    biodiversity_index  NUMERIC(7,2),                      -- species richness/health proxy
    carbon_balance_kg   NUMERIC(16,4),                     -- negative is carbon-negative
    eco_risk_factor     NUMERIC(7,2),                      -- 0.00–100.00 risk, higher = worse
    data_quality_flag   VARCHAR(32),                       -- 'ok', 'estimated', 'missing-partial'
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_eco_metrics_fort_ts
    ON eco_metrics (fort_id, metric_ts);

CREATE INDEX IF NOT EXISTS idx_eco_metrics_risk_factor
    ON eco_metrics (eco_risk_factor);

-- ---------------------------------------------------------------------
-- 6. Knowledge & research topics (high-value Eco-Fort threads)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS research_topics (
    topic_id            BIGSERIAL PRIMARY KEY,
    topic_code          VARCHAR(64) NOT NULL,              -- e.g. 'DECOMPOSITION-PIPELINE-01'
    title               VARCHAR(256) NOT NULL,
    description         TEXT,                              -- eco-restoration / cyboquatic focus
    eco_impact_value    NUMERIC(7,2),                      -- 0.00–100.00 potential benefit
    knowledge_factor    NUMERIC(7,2),                      -- 0.00–100.00 maturity/rigor
    risk_factor         NUMERIC(7,2),                      -- 0.00–100.00 risk if misused
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_identity BIGINT REFERENCES identities(identity_id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_research_topics_code
    ON research_topics (topic_code);

CREATE INDEX IF NOT EXISTS idx_research_topics_eco_impact
    ON research_topics (eco_impact_value);

CREATE INDEX IF NOT EXISTS idx_research_topics_risk_factor
    ON research_topics (risk_factor);

-- ---------------------------------------------------------------------
-- 7. Topic–Fort bindings (which topics are studied at which sites)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fort_topics (
    fort_topic_id       BIGSERIAL PRIMARY KEY,
    fort_id             BIGINT NOT NULL REFERENCES fort_sites(fort_id) ON DELETE CASCADE,
    topic_id            BIGINT NOT NULL REFERENCES research_topics(topic_id) ON DELETE CASCADE,
    role_label          VARCHAR(64),                       -- 'primary-lab', 'field-test', etc.
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fort_topics_unique
    ON fort_topics (fort_id, topic_id);

-- ---------------------------------------------------------------------
-- 8. Hex-stamp ledger (cryptographic-style evidence strings)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hex_stamps (
    stamp_id            BIGSERIAL PRIMARY KEY,
    stamp_hex           VARCHAR(256) NOT NULL,             -- verified hex string (no blacklist algos)
    stamp_label         VARCHAR(128),                      -- human meaning, e.g. 'eco-metric-snapshot'
    linked_table        VARCHAR(64),                       -- e.g. 'eco_metrics', 'materials'
    linked_pk           BIGINT,                            -- PK in linked_table (soft reference)
    issued_by_identity  BIGINT REFERENCES identities(identity_id),
    issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    eco_impact_value    NUMERIC(7,2),                      -- impact of the stamped asset
    knowledge_factor    NUMERIC(7,2),                      -- rigor of underlying data
    risk_factor         NUMERIC(7,2)                       -- risk if altered or misinterpreted
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_hex_stamps_stamp_hex
    ON hex_stamps (stamp_hex);

CREATE INDEX IF NOT EXISTS idx_hex_stamps_link
    ON hex_stamps (linked_table, linked_pk);

-- ---------------------------------------------------------------------
-- 9. Global scoring view (per asset)
-- ---------------------------------------------------------------------

-- This is a skeleton; you can evolve the scoring math over time.
CREATE VIEW IF NOT EXISTS v_fort_risk_profile AS
SELECT
    f.fort_id,
    f.fort_code,
    f.name,
    avg(e.eco_risk_factor)          AS avg_eco_risk_factor,
    avg(e.carbon_balance_kg)        AS avg_carbon_balance_kg,
    max(e.metric_ts)                AS last_metric_ts
FROM fort_sites f
LEFT JOIN eco_metrics e
    ON e.fort_id = f.fort_id
GROUP BY f.fort_id, f.fort_code, f.name;

CREATE VIEW IF NOT EXISTS v_material_safety_profile AS
SELECT
    m.material_id,
    m.material_code,
    m.name,
    m.biodegradability_score,
    m.human_toxicity_score,
    m.animal_toxicity_score,
    m.lifecycle_co2_kg_per_kg
FROM materials m;

-- ---------------------------------------------------------------------
-- 10. Minimal seed insert (optional; can be removed in production)
-- ---------------------------------------------------------------------

INSERT INTO identities (label, did_bostrom, aln_address, erc20_address, is_primary)
VALUES
    (
        'primary',
        'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
        'aln18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7',
        '0x519fC0eB4111323Cac44b70e1aE31c30e405802D',
        TRUE
    )
ON CONFLICT (did_bostrom) DO NOTHING;
