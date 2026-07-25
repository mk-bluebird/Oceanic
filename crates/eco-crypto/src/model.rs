// crates/eco-crypto/src/model.rs

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// High-level eco transaction that an AI agent can describe and sign.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EcoTransaction {
    /// Logical actor DID (e.g., Bostrom / ALN).
    pub actor_did: String,
    /// Repository or domain this transaction targets (e.g., "Eco-Fort").
    pub repo_name: String,
    /// Human-readable action description (e.g., "register new PhoenixMarCyboquatic shard").
    pub action: String,
    /// Eco impact score in 0.0–1.0, higher = more positive.
    pub eco_impact_score: f32,
    /// Knowledge factor 0.0–1.0, higher = more rigorous.
    pub knowledge_factor: f32,
    /// Risk factor 0.0–1.0, higher = more risk.
    pub risk_factor: f32,
    /// Arbitrary context blob, usually small JSON as string.
    pub context: String,
    /// Timestamp when the transaction was constructed.
    pub created_at: DateTime<Utc>,
}

/// Signed eco transaction, ready for ledger or catalog use.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedEcoTransaction {
    pub transaction: EcoTransaction,
    /// Public key in hex (Ed25519, 32 bytes).
    pub public_key_hex: String,
    /// Signature in hex (Ed25519, 64 bytes).
    pub signature_hex: String,
    /// Optional evidence hex (e.g., hash of shard content).
    pub evidence_hex: Option<String>,
}
