// crates/eco-fort/src/models.rs

use chrono::{DateTime, Utc};
use sqlx::FromRow;

/// Identity anchors (Bostrom / ALN / ERC-20).
#[derive(Debug, Clone, FromRow)]
pub struct Identity {
    pub identity_id: i64,
    pub label: String,
    pub did_bostrom: Option<String>,
    pub aln_address: Option<String>,
    pub erc20_address: Option<String>,
    pub is_primary: bool,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Eco-Fort physical / cyboquatic site.
#[derive(Debug, Clone, FromRow)]
pub struct FortSite {
    pub fort_id: i64,
    pub fort_code: String,
    pub name: String,
    pub description: Option<String>,
    pub latitude_deg: Option<f64>,
    pub longitude_deg: Option<f64>,
    pub elevation_m: Option<f64>,
    pub location_region: Option<String>,
    pub eco_biome_tag: Option<String>,
    pub is_active: bool,
    pub created_by_identity: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Material with eco / toxicity parameters.
#[derive(Debug, Clone, FromRow)]
pub struct Material {
    pub material_id: i64,
    pub material_code: String,
    pub name: String,
    pub description: Option<String>,
    pub origin_type: Option<String>,
    pub use_category: Option<String>,
    pub biodegradability_score: Option<f32>,
    pub human_toxicity_score: Option<f32>,
    pub animal_toxicity_score: Option<f32>,
    pub lifecycle_co2_kg_per_kg: Option<f32>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Eco metrics snapshot at a fort.
#[derive(Debug, Clone, FromRow)]
pub struct EcoMetric {
    pub metric_id: i64,
    pub fort_id: i64,
    pub metric_ts: DateTime<Utc>,
    pub metric_source: String,
    pub heat_index_c: Option<f32>,
    pub soil_health_index: Option<f32>,
    pub water_quality_index: Option<f32>,
    pub biodiversity_index: Option<f32>,
    pub carbon_balance_kg: Option<f64>,
    pub eco_risk_factor: Option<f32>,
    pub data_quality_flag: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// Research topic with scoring.
#[derive(Debug, Clone, FromRow)]
pub struct ResearchTopic {
    pub topic_id: i64,
    pub topic_code: String,
    pub title: String,
    pub description: Option<String>,
    pub eco_impact_value: Option<f32>,
    pub knowledge_factor: Option<f32>,
    pub risk_factor: Option<f32>,
    pub is_active: bool,
    pub created_by_identity: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Hex stamp ledger entry.
#[derive(Debug, Clone, FromRow)]
pub struct HexStamp {
    pub stamp_id: i64,
    pub stamp_hex: String,
    pub stamp_label: Option<String>,
    pub linked_table: Option<String>,
    pub linked_pk: Option<i64>,
    pub issued_by_identity: Option<i64>,
    pub issued_at: DateTime<Utc>,
    pub eco_impact_value: Option<f32>,
    pub knowledge_factor: Option<f32>,
    pub risk_factor: Option<f32>,
}
