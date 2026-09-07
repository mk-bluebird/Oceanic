PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS pfas_rate_parameter (
    parameter_id TEXT PRIMARY KEY,
    analyte_code TEXT NOT NULL,
    matrix TEXT NOT NULL CHECK (
        matrix IN (
            'water_column',
            'bed_sediment',
            'bank_sediment',
            'porewater'
        )
    ),
    model_version TEXT NOT NULL,
    base_rate_per_day REAL NOT NULL CHECK (base_rate_per_day > 0.0),
    reference_temperature_c REAL NOT NULL,
    reference_ph REAL NOT NULL,
    temperature_sensitivity_per_c REAL NOT NULL,
    ph_sensitivity_per_unit REAL NOT NULL,
    parameter_source_id TEXT NOT NULL,
    valid_from_utc TEXT NOT NULL,
    valid_until_utc TEXT,
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
        valid_until_utc IS NULL
        OR valid_until_utc > valid_from_utc
    )
) STRICT;

CREATE TABLE IF NOT EXISTS pfas_rate_parameter_covariance (
    covariance_id TEXT PRIMARY KEY,
    parameter_id TEXT NOT NULL REFERENCES pfas_rate_parameter(parameter_id),
    covariance_temperature_ph REAL NOT NULL,
    estimated_at_utc TEXT NOT NULL,
    method_version TEXT NOT NULL,
    source_reference TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS pfas_half_life_uncertainty_observation (
    evidence_id TEXT PRIMARY KEY,
    parameter_id TEXT NOT NULL REFERENCES pfas_rate_parameter(parameter_id),
    hex_anchor TEXT NOT NULL,
    canal_node_id TEXT,
    observed_at_utc TEXT NOT NULL,
    temperature_c REAL NOT NULL,
    ph REAL NOT NULL CHECK (ph BETWEEN 0.0 AND 14.0),
    temperature_standard_deviation_c REAL NOT NULL CHECK (
        temperature_standard_deviation_c >= 0.0
    ),
    ph_standard_deviation REAL NOT NULL CHECK (
        ph_standard_deviation >= 0.0
    ),
    matrix_supported INTEGER NOT NULL CHECK (matrix_supported IN (0, 1)),
    cold_survival_supported INTEGER NOT NULL CHECK (
        cold_survival_supported IN (0, 1)
    ),
    sediment_partition_supported INTEGER NOT NULL CHECK (
        sediment_partition_supported IN (0, 1)
    ),
    uncertainty_threshold_half_life_days REAL NOT NULL CHECK (
        uncertainty_threshold_half_life_days >= 0.0
    ),
    source_valid INTEGER NOT NULL CHECK (source_valid IN (0, 1)),
    parameter_current INTEGER NOT NULL CHECK (
        parameter_current IN (0, 1)
    ),
    consent_scope_valid INTEGER NOT NULL CHECK (
        consent_scope_valid IN (0, 1)
    ),
    retention_eligible INTEGER NOT NULL CHECK (
        retention_eligible IN (0, 1)
    ),
    retention_until_utc TEXT NOT NULL,
    tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (
        tombstoned IN (0, 1)
    )
) STRICT;

CREATE VIEW IF NOT EXISTS pfas_half_life_uncertainty_view AS
SELECT
    observation.evidence_id,
    observation.hex_anchor,
    observation.canal_node_id,
    observation.observed_at_utc,
    parameter.analyte_code,
    parameter.matrix,
    parameter.model_version,
    parameter.base_rate_per_day *
        exp(
            parameter.temperature_sensitivity_per_c *
                (observation.temperature_c - parameter.reference_temperature_c) +
            parameter.ph_sensitivity_per_unit *
                (observation.ph - parameter.reference_ph)
        ) AS lambda_per_day,
    CASE
        WHEN observation.source_valid = 0
            OR observation.parameter_current = 0
            OR observation.consent_scope_valid = 0
            OR observation.retention_eligible = 0 THEN 'withhold'
        WHEN observation.matrix_supported = 0 THEN 'unmodeled_media'
        WHEN observation.cold_survival_supported = 0 THEN 'human_review_pending'
        WHEN observation.sediment_partition_supported = 0 THEN 'human_review_pending'
        ELSE 'clear'
    END AS fog_state
FROM pfas_half_life_uncertainty_observation AS observation
JOIN pfas_rate_parameter AS parameter
    ON parameter.parameter_id = observation.parameter_id
WHERE observation.tombstoned = 0
  AND observation.retention_until_utc > strftime('%Y-%m-%dT%H:%M:%SZ', 'now');
