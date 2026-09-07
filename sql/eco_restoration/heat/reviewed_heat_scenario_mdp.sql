PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS heat_scenario_state (
    state_id TEXT PRIMARY KEY,
    model_version TEXT NOT NULL,
    heat_risk_band INTEGER NOT NULL CHECK (
        heat_risk_band BETWEEN 0 AND 4
    ),
    water_stress_band INTEGER NOT NULL CHECK (
        water_stress_band BETWEEN 0 AND 4
    ),
    habitat_condition_band INTEGER NOT NULL CHECK (
        habitat_condition_band BETWEEN 0 AND 4
    ),
    accessibility_band INTEGER NOT NULL CHECK (
        accessibility_band BETWEEN 0 AND 4
    ),
    community_burden_band INTEGER NOT NULL CHECK (
        community_burden_band BETWEEN 0 AND 4
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_scenario_action (
    action_id TEXT PRIMARY KEY,
    model_version TEXT NOT NULL,
    action_label TEXT NOT NULL,
    advisory_only INTEGER NOT NULL DEFAULT 1 CHECK (
        advisory_only = 1
    ),
    human_approval_required INTEGER NOT NULL DEFAULT 1 CHECK (
        human_approval_required = 1
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_scenario_transition (
    model_version TEXT NOT NULL,
    from_state_id TEXT NOT NULL REFERENCES heat_scenario_state(state_id),
    action_id TEXT NOT NULL REFERENCES heat_scenario_action(action_id),
    to_state_id TEXT NOT NULL REFERENCES heat_scenario_state(state_id),
    probability REAL NOT NULL CHECK (
        probability >= 0.0
        AND probability <= 1.0
    ),
    source_valid INTEGER NOT NULL CHECK (
        source_valid IN (0, 1)
    ),
    parameter_current INTEGER NOT NULL CHECK (
        parameter_current IN (0, 1)
    ),
    PRIMARY KEY (
        model_version,
        from_state_id,
        action_id,
        to_state_id
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_scenario_reward_profile (
    reward_profile_id TEXT PRIMARY KEY,
    model_version TEXT NOT NULL,
    weight_version TEXT NOT NULL,
    heat_reduction_weight REAL NOT NULL,
    water_demand_weight REAL NOT NULL,
    habitat_value_weight REAL NOT NULL,
    accessibility_weight REAL NOT NULL,
    community_burden_weight REAL NOT NULL,
    human_approved INTEGER NOT NULL CHECK (
        human_approved IN (0, 1)
    ),
    approved_at_utc TEXT,
    retention_until_utc TEXT NOT NULL,
    CHECK (
        human_approved = 0
        OR approved_at_utc IS NOT NULL
    )
) STRICT;

CREATE TABLE IF NOT EXISTS heat_scenario_plan (
    plan_id TEXT PRIMARY KEY,
    model_version TEXT NOT NULL,
    reward_profile_id TEXT NOT NULL REFERENCES heat_scenario_reward_profile(reward_profile_id),
    generated_at_utc TEXT NOT NULL,
    status TEXT NOT NULL CHECK (
        status IN (
            'advisory_candidate',
            'withheld',
            'superseded'
        )
    ),
    fog_state TEXT NOT NULL CHECK (
        fog_state IN (
            'clear',
            'human_review_pending',
            'withhold'
        )
    ),
    plain_language_summary TEXT NOT NULL,
    correction_path TEXT NOT NULL,
    appeal_path TEXT NOT NULL,
    CHECK NOT (
        fog_state <> 'clear'
        AND status = 'advisory_candidate'
    )
) STRICT;
