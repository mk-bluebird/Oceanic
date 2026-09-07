PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS energy_profile_telemetry (
    profile_id TEXT PRIMARY KEY,
    observed_at_utc TEXT NOT NULL,
    hex_anchor TEXT NOT NULL,
    capacitance_coefficient REAL NOT NULL CHECK (
        capacitance_coefficient >= 0.0
    ),
    voltage_v REAL NOT NULL CHECK (voltage_v >= 0.0),
    frequency_hz REAL NOT NULL CHECK (frequency_hz >= 0.0),
    static_power_w REAL NOT NULL CHECK (static_power_w >= 0.0),
    duration_s REAL NOT NULL CHECK (duration_s >= 0.0),
    predicted_temperature_c REAL NOT NULL,
    temperature_standard_deviation_c REAL NOT NULL CHECK (
        temperature_standard_deviation_c >= 0.0
    ),
    safe_temperature_c REAL NOT NULL,
    thermal_uncertainty_multiplier REAL NOT NULL CHECK (
        thermal_uncertainty_multiplier >= 0.0
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
    ),
    energyreq_j REAL GENERATED ALWAYS AS (
        (
            static_power_w +
            capacitance_coefficient *
                voltage_v *
                voltage_v *
                frequency_hz
        ) * duration_s
    ) STORED,
    upper_temperature_c REAL GENERATED ALWAYS AS (
        predicted_temperature_c +
        thermal_uncertainty_multiplier *
            temperature_standard_deviation_c
    ) STORED
) STRICT;

CREATE INDEX IF NOT EXISTS energy_profile_telemetry_active_hex_time_idx
ON energy_profile_telemetry (hex_anchor, observed_at_utc)
WHERE tombstoned = 0;

CREATE VIEW IF NOT EXISTS dvfs_advisory_view AS
SELECT
    profile_id,
    observed_at_utc,
    hex_anchor,
    energyreq_j,
    upper_temperature_c,
    CASE
        WHEN source_valid = 0
            OR parameter_current = 0
            OR consent_scope_valid = 0
            OR retention_eligible = 0 THEN 'withheld'
        WHEN retention_until_utc <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now') THEN 'withheld'
        WHEN upper_temperature_c > safe_temperature_c THEN 'withheld'
        ELSE 'advisory_candidate'
    END AS status
FROM energy_profile_telemetry
WHERE tombstoned = 0;
