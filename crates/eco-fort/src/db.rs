// crates/eco-fort/src/db.rs

use sqlx::{postgres::PgPoolOptions, PgPool};

/// Create a PostgreSQL connection pool for the eco_fort schema.
///
/// Expects DATABASE_URL to be set, e.g.:
/// postgres://user:password@localhost:5432/your_db
pub async fn create_pool(max_connections: u32) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(max_connections)
        .connect(&std::env::var("DATABASE_URL").expect("DATABASE_URL not set"))
        .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scoring::{fort_eco_score, material_safety_score, topic_priority_score};
    use crate::models::{EcoMetric, Material, ResearchTopic};
    use chrono::{TimeZone, Utc};

    #[tokio::test]
    async fn pool_creation_fails_without_env() {
        std::env::remove_var("DATABASE_URL");
        let result = create_pool(1).await;
        assert!(result.is_err());
    }

    #[test]
    fn scoring_functions_are_bounded() {
        let metric = EcoMetric {
            metric_id: 1,
            fort_id: 1,
            metric_ts: Utc.with_ymd_and_hms(2026, 7, 24, 21, 0, 0).unwrap(),
            metric_source: "test".to_string(),
            heat_index_c: Some(40.0),
            soil_health_index: Some(70.0),
            water_quality_index: Some(80.0),
            biodiversity_index: Some(60.0),
            carbon_balance_kg: Some(-100.0),
            eco_risk_factor: Some(20.0),
            data_quality_flag: Some("ok".to_string()),
            created_at: Utc::now(),
        };
        let eco_score = fort_eco_score(&metric);
        assert!(eco_score >= 0.0 && eco_score <= 1.0);

        let material = Material {
            material_id: 1,
            material_code: "BIO-POLY-01".to_string(),
            name: "Test Material".to_string(),
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
        let safety_score = material_safety_score(&material);
        assert!(safety_score >= 0.0 && safety_score <= 1.0);

        let topic = ResearchTopic {
            topic_id: 1,
            topic_code: "DECOMPOSITION-PIPELINE-01".to_string(),
            title: "Decomposition Pipeline".to_string(),
            description: None,
            eco_impact_value: Some(90.0),
            knowledge_factor: Some(70.0),
            risk_factor: Some(20.0),
            is_active: true,
            created_by_identity: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        let priority_score = topic_priority_score(&topic);
        assert!(priority_score >= 0.0 && priority_score <= 1.0);
    }
}
