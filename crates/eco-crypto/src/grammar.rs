// crates/eco-crypto/src/grammar.rs

use crate::model::EcoTransaction;
use chrono::{DateTime, Utc};

/// Allowed role-bands for eco repositories.
#[derive(Debug, Clone, Copy)]
pub enum RoleBand {
    Spine,
    Engine,
    App,
}

/// Result of grammar linting.
#[derive(Debug, Clone)]
pub struct GrammarReport {
    pub is_valid: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
}

impl GrammarReport {
    pub fn ok() -> Self {
        Self {
            is_valid: true,
            errors: Vec::new(),
            warnings: Vec::new(),
        }
    }

    pub fn with_error(mut self, msg: impl Into<String>) -> Self {
        self.is_valid = false;
        self.errors.push(msg.into());
        self
    }

    pub fn with_warning(mut self, msg: impl Into<String>) -> Self {
        self.warnings.push(msg.into());
        self
    }
}

/// Canonical list of safe actions for Eco-Fort / EcoNet.
/// Agents should prefer these over free-form verbs.
pub fn canonical_actions() -> &'static [&'static str] {
    &[
        "register_shard",
        "update_schema_ref",
        "record_eco_metric_snapshot",
        "register_corridor_definition",
        "update_qpu_shard_tags",
    ]
}

/// Lint an EcoTransaction against ecosafety grammar.
///
/// Checks:
/// - eco_impact_score, knowledge_factor, risk_factor ∈ [0.0, 1.0].
/// - action is in canonical list for SPINE role-band.
/// - repo_name matches known eco repos (Eco-Fort, EcoNet, Virta-Sys).
pub fn lint_transaction(tx: &EcoTransaction, role: RoleBand) -> GrammarReport {
    let mut report = GrammarReport::ok();

    // Bounds checks: 0.0–1.0.
    if !in_unit_interval(tx.eco_impact_score) {
        report = report.with_error(format!(
            "eco_impact_score {} is out of bounds [0.0, 1.0]",
            tx.eco_impact_score
        ));
    }
    if !in_unit_interval(tx.knowledge_factor) {
        report = report.with_error(format!(
            "knowledge_factor {} is out of bounds [0.0, 1.0]",
            tx.knowledge_factor
        ));
    }
    if !in_unit_interval(tx.risk_factor) {
        report = report.with_error(format!(
            "risk_factor {} is out of bounds [0.0, 1.0]",
            tx.risk_factor
        ));
    }

    // Repo name invariants.
    match tx.repo_name.as_str() {
        "Eco-Fort" | "EcoNet" | "Virta-Sys" => {}
        other => {
            report = report.with_warning(format!(
                "repo_name '{}' is not in canonical set [Eco-Fort, EcoNet, Virta-Sys]",
                other
            ));
        }
    }

    // Role-band specific action constraints.
    if matches!(role, RoleBand::Spine) {
        if !canonical_actions().contains(&tx.action.as_str()) {
            report = report.with_error(format!(
                "action '{}' is not in canonical SPINE actions: {:?}",
                tx.action,
                canonical_actions()
            ));
        }
    }

    // Actor DID presence.
    if tx.actor_did.trim().is_empty() {
        report = report.with_error("actor_did must not be empty");
    }

    // Context presence (small but non-empty).
    if tx.context.trim().is_empty() {
        report = report.with_warning("context is empty; consider adding shard or corridor details");
    }

    report
}

fn in_unit_interval(x: f32) -> bool {
    x >= 0.0 && x <= 1.0
}

/// Suggest canonical action names that are close to a given action string.
///
/// For now this is a simple substring-based hint, not fuzzy search.
pub fn suggest_action_variants(action: &str) -> Vec<String> {
    let mut out = Vec::new();
    for &candidate in canonical_actions() {
        if candidate.contains(action) || action.contains(candidate) {
            out.push(candidate.to_string());
        }
    }
    if out.is_empty() {
        for &candidate in canonical_actions() {
            out.push(candidate.to_string());
        }
    }
    out
}

/// Demo transaction tailored to the primary Bostrom DID and Eco-Fort SPINE role-band.
///
/// Uses:
/// - actor_did: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
/// - repo_name: "Eco-Fort"
/// - action: "register_shard"
pub fn demo_transaction() -> EcoTransaction {
    EcoTransaction {
        actor_did: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
        repo_name: "Eco-Fort".to_string(),
        action: "register_shard".to_string(),
        eco_impact_score: 0.9,
        knowledge_factor: 0.8,
        risk_factor: 0.2,
        context: "Register a new PhoenixMarCyboquaticKER shard into qpu_shard_catalog for eco-restoration analysis."
            .to_string(),
        created_at: Utc::now(),
    }
}

/// Human-readable explanation of a transaction and its grammar report.
pub fn explain_transaction(tx: &EcoTransaction, report: &GrammarReport) -> String {
    let mut out = String::new();

    out.push_str(&format!(
        "Actor DID {} proposes '{}' on repo '{}' with eco_impact_score={}, knowledge_factor={}, risk_factor={}.\n",
        tx.actor_did,
        tx.action,
        tx.repo_name,
        tx.eco_impact_score,
        tx.knowledge_factor,
        tx.risk_factor
    ));

    if report.is_valid {
        out.push_str("Grammar lint: VALID. Transaction respects ecosafety bounds and SPINE role-band.\n");
    } else {
        out.push_str("Grammar lint: INVALID. Errors:\n");
        for e in &report.errors {
            out.push_str(&format!("- {e}\n"));
        }
    }

    if !report.warnings.is_empty() {
        out.push_str("Warnings:\n");
        for w in &report.warnings {
            out.push_str(&format!("- {w}\n"));
        }
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_transaction_is_valid_for_spine() {
        let tx = demo_transaction();
        let report = lint_transaction(&tx, RoleBand::Spine);
        assert!(report.is_valid);
        assert!(report.errors.is_empty());
    }

    #[test]
    fn out_of_bounds_scores_are_rejected() {
        let tx = EcoTransaction {
            actor_did: "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7".to_string(),
            repo_name: "Eco-Fort".to_string(),
            action: "register_shard".to_string(),
            eco_impact_score: 1.2,
            knowledge_factor: -0.1,
            risk_factor: 0.5,
            context: "Test".to_string(),
            created_at: Utc::now(),
        };
        let report = lint_transaction(&tx, RoleBand::Spine);
        assert!(!report.is_valid);
        assert!(report.errors.len() >= 2);
    }
}
