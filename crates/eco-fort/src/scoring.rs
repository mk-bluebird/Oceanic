// crates/eco-fort/src/scoring.rs

use crate::models::{EcoMetric, Material, ResearchTopic};

/// Normalized eco score (0.0 – 1.0) derived from eco_risk_factor and carbon balance.
pub fn fort_eco_score(metric: &EcoMetric) -> f32 {
    let risk = metric.eco_risk_factor.unwrap_or(50.0);
    let carbon = metric.carbon_balance_kg.unwrap_or(0.0);

    let risk_component = 1.0 - (risk.clamp(0.0, 100.0) / 100.0);
    let carbon_component = if carbon < 0.0 {
        (1.0 + (carbon / -1000.0)).clamp(0.0, 1.0)
    } else {
        (1.0 - (carbon / 1000.0)).clamp(0.0, 1.0)
    };

    0.6 * risk_component + 0.4 * carbon_component
}

/// Material safety score (0.0 – 1.0) based on biodegradability and toxicity.
pub fn material_safety_score(material: &Material) -> f32 {
    let biodeg = material.biodegradability_score.unwrap_or(50.0);
    let human_tox = material.human_toxicity_score.unwrap_or(50.0);
    let animal_tox = material.animal_toxicity_score.unwrap_or(50.0);

    let biodeg_component = biodeg.clamp(0.0, 100.0) / 100.0;
    let toxicity_component =
        1.0 - ((human_tox.clamp(0.0, 100.0) + animal_tox.clamp(0.0, 100.0)) / 200.0);

    0.7 * biodeg_component + 0.3 * toxicity_component
}

/// Topic priority score (0.0 – 1.0) emphasizing high impact and high rigor, penalizing risk.
pub fn topic_priority_score(topic: &ResearchTopic) -> f32 {
    let impact = topic.eco_impact_value.unwrap_or(50.0);
    let knowledge = topic.knowledge_factor.unwrap_or(50.0);
    let risk = topic.risk_factor.unwrap_or(50.0);

    let impact_component = impact.clamp(0.0, 100.0) / 100.0;
    let knowledge_component = knowledge.clamp(0.0, 100.0) / 100.0;
    let risk_component = 1.0 - (risk.clamp(0.0, 100.0) / 100.0);

    0.4 * impact_component + 0.4 * knowledge_component + 0.2 * risk_component
}
