// crates/eco-crypto/src/signing.rs

use crate::model::{EcoTransaction, SignedEcoTransaction};
use crate::keys::public_key_to_hex;
use chrono::Utc;
use ed25519_dalek::{Keypair, PublicKey, Signer, Verifier};
use serde_json;

/// Sign an EcoTransaction with an Ed25519 keypair.
pub fn sign_transaction(
    kp: &Keypair,
    mut tx: EcoTransaction,
    evidence_hex: Option<String>,
) -> SignedEcoTransaction {
    if tx.created_at.timestamp() == 0 {
        tx.created_at = Utc::now();
    }

    let payload = serde_json::to_vec(&tx).expect("serialization must succeed");
    let signature = kp.sign(&payload);

    SignedEcoTransaction {
        transaction: tx,
        public_key_hex: public_key_to_hex(&kp.public),
        signature_hex: bytes_to_hex(signature.as_bytes()),
        evidence_hex,
    }
}

/// Verify a SignedEcoTransaction given its embedded public key hex.
pub fn verify_signed_transaction(
    signed: &SignedEcoTransaction,
) -> Result<(), ed25519_dalek::SignatureError> {
    let pk = crate::keys::public_key_from_hex(&signed.public_key_hex)?;
    let payload = serde_json::to_vec(&signed.transaction)
        .map_err(|_| ed25519_dalek::SignatureError::from(
            ed25519_dalek::InternalError::BytesLengthError { name: "payload", length: 0 },
        ))?;
    let sig_bytes = crate::keys::hex_to_bytes(&signed.signature_hex)?;
    let signature = ed25519_dalek::Signature::from_bytes(&sig_bytes)?;
    pk.verify(&payload, &signature)
}

/// Local byte-to-hex helper (delegates to keys module).
fn bytes_to_hex(bytes: &[u8]) -> String {
    crate::keys::public_key_to_hex(
        &ed25519_dalek::PublicKey::from_bytes(bytes).unwrap_or_else(|_| {
            ed25519_dalek::PublicKey::from_bytes(&[0u8; 32]).unwrap()
        }),
    )
}
