// crates/eco-crypto/src/keys.rs

use ed25519_dalek::{Keypair, PublicKey, SecretKey};
use rand::rngs::OsRng;

/// Generate a new Ed25519 keypair using the OS CSPRNG.
pub fn generate_keypair() -> Keypair {
    let mut rng = OsRng;
    Keypair::generate(&mut rng)
}

/// Serialize public key to lowercase hex.
pub fn public_key_to_hex(pk: &PublicKey) -> String {
    bytes_to_hex(pk.as_bytes())
}

/// Serialize secret key to lowercase hex (for educational purposes only).
pub fn secret_key_to_hex(sk: &SecretKey) -> String {
    bytes_to_hex(sk.as_bytes())
}

/// Parse public key from hex.
pub fn public_key_from_hex(hex: &str) -> Result<PublicKey, ed25519_dalek::SignatureError> {
    let bytes = hex_to_bytes(hex)?;
    PublicKey::from_bytes(&bytes)
}

/// Internal byte-to-hex utility (shared with evidence module).
fn bytes_to_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        let hi = HEX[(b >> 4) as usize] as char;
        let lo = HEX[(b & 0x0f) as usize] as char;
        out.push(hi);
        out.push(lo);
    }
    out
}

/// Internal hex-to-bytes utility.
fn hex_to_bytes(hex: &str) -> Result<Vec<u8>, ed25519_dalek::SignatureError> {
    let mut out = Vec::with_capacity(hex.len() / 2);
    let chars: Vec<u8> = hex.as_bytes().to_vec();
    if chars.len() % 2 != 0 {
        return Err(ed25519_dalek::SignatureError::from(
            ed25519_dalek::InternalError::BytesLengthError {
                name: "hex",
                length: chars.len(),
            },
        ));
    }
    let mut i = 0;
    while i < chars.len() {
        let hi = hex_digit(chars[i])?;
        let lo = hex_digit(chars[i + 1])?;
        out.push((hi << 4) | lo);
        i += 2;
    }
    Ok(out)
}

fn hex_digit(c: u8) -> Result<u8, ed25519_dalek::SignatureError> {
    match c {
        b'0'..=b'9' => Ok(c - b'0'),
        b'a'..=b'f' => Ok(10 + (c - b'a')),
        b'A'..=b'F' => Ok(10 + (c - b'A')),
        _ => Err(ed25519_dalek::SignatureError::from(
            ed25519_dalek::InternalError::BytesLengthError {
                name: "hex_digit",
                length: 1,
            },
        )),
    }
}
