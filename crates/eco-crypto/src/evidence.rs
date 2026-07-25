// crates/eco-crypto/src/evidence.rs

use std::fs;
use std::io::Read;
use std::path::Path;

/// Compute evidence hex from file content (ALN/CSV shard).
pub fn evidence_hex_from_file(path: &Path) -> Result<String, Box<dyn std::error::Error>> {
    let mut file = fs::File::open(path)?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf)?;
    Ok(bytes_to_hex(&buf))
}

/// Compute evidence hex from arbitrary bytes (cross-language input).
pub fn evidence_hex_from_bytes(bytes: &[u8]) -> String {
    bytes_to_hex(bytes)
}

/// Byte-to-hex encoder, identical to shard-indexer logic.
pub fn bytes_to_hex(bytes: &[u8]) -> String {
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
