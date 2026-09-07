PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS aggregate_heat_community_features (
    aggregate_id TEXT PRIMARY KEY,
    hex_anchor TEXT NOT NULL,
    hex_resolution INTEGER NOT NULL CHECK (
        hex_resolution BETWEEN 0 AND 15
    ),
    aggregation_start_utc TEXT NOT NULL,
    aggregation_end_utc TEXT NOT NULL,
    contributor_count INTEGER NOT NULL CHECK (
        contributor_count >= 0
    ),
    heat_exposure_index REAL NOT NULL,
    surface_temperature_c REAL,
    nighttime_temperature_c REAL,
    shade_access_index REAL CHECK (
        shade_access_index IS NULL
        OR shade_access_index BETWEEN 0.0 AND 1.0
    ),
    cooling_service_access_index REAL CHECK (
        cooling_service_access_index IS NULL
        OR cooling_service_access_index BETWEEN 0.0 AND 1.0
    ),
    transit_access_index REAL CHECK (
        transit_access_index IS NULL
        OR transit_access_index BETWEEN 0.0 AND 1.0
    ),
    public_service_access_index REAL CHECK (
        public_service_access_index IS NULL
        OR public_service_access_index BETWEEN 0.0 AND 1.0
    ),
    aggregation_method_version TEXT NOT NULL,
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    ),
    CHECK (aggregation_end_utc > aggregation_start_utc)
) STRICT;

CREATE VIEW IF NOT EXISTS aggregate_heat_cca_eligible_view AS
SELECT
    aggregate_id,
    hex_anchor,
    hex_resolution,
    aggregation_start_utc,
    aggregation_end_utc,
    heat_exposure_index,
    surface_temperature_c,
    nighttime_temperature_c,
    shade_access_index,
    cooling_service_access_index,
    transit_access_index,
    public_service_access_index,
    aggregation_method_version
FROM aggregate_heat_community_features
WHERE contributor_count >= 20
  AND source_valid = 1
  AND consent_scope_valid = 1
  AND tombstoned = 0
  AND retention_until_utc > strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
