// crates/eco-fort/tests/kani_scoring.rs

use eco_fort::models::{EcoMetric, Material, ResearchTopic};
use eco_fort::scoring::{fort_eco_score, material_safety_score, topic_priority_score};
use chrono::{TimeZone, Utc};

#[kani::proof]
fn kani_fort_eco_score_in_bounds() {
    let metric = EcoMetric {
        metric_id: 1,
        fort_id: 1,
        metric_ts: Utc.with_ymd_and_hms(2026, 7, 24, 21, 0, 0).unwrap(),
        metric_source: "kani".to_string(),
        heat_index_c: Some(40.0),
        soil_health_index: Some(70.0),
        water_quality_index: Some(80.0),
        biodiversity_index: Some(60.0),
        carbon_balance_kg: Some(-100.0),
        eco_risk_factor: Some(20.0),
        data_quality_flag: Some("ok".to_string()),
        created_at: Utc::now(),
    };
    let s = fort_eco_score(&metric);
    kani::assert!(s >= 0.0 && s <= 1.0);
}

#[kani::proof]
fn kani_material_safety_score_in_bounds() {
    let material = Material {
        material_id: 1,
        material_code: "BIO-POLY-01".to_string(),
        name: "Kani Material".to_string(),
        description: None,
        origin_type: Some("recycled".to_string()),
        use_category: Some("structural".to_string()),
        biodegradability_score: Some(80.0),
        human_toxicity_score: Some(10.0),
        animal_toxicity_score: Some(15.0),
        lifecycle_co2_kg_per_kg: Some(-2.5),
        is_active: true,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    let s = material_safety_score(&material);
    kani::assert!(s >= 0.0 && s <= 1.0);
}

#[kani::proof]
fn kani_topic_priority_score_in_bounds() {
    let topic = ResearchTopic {
        topic_id: 1,
        topic_code: "DECOMPOSITION-PIPELINE-01".to_string(),
        title: "Kani Topic".to_string(),
        description: None,
        eco_impact_value: Some(90.0),
        knowledge_factor: Some(70.0),
        risk_factor: Some(20.0),
        is_active: true,
        created_by_identity: None,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    let s = topic_priority_score(&topic);
    kani::assert!(s >= 0.0 && s <= 1.0);
}
