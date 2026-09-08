#![forbid(unsafe_code)]

use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{self, Read};
use std::path::Path;
use subtle::ConstantTimeEq;
use thiserror::Error;

const SHA256_HEX_LENGTH: usize = 64;
const BUFFER_SIZE: usize = 64 * 1024;

#[derive(Debug, Error)]
pub enum EvidenceIntegrityError {
    #[error("could not read CSV shard `{path}`: {source}")]
    Read {
        path: String,
        #[source]
        source: io::Error,
    },

    #[error("missing required evidencehex for CSV shard `{path}`")]
    MissingEvidenceHex { path: String },

    #[error(
        "invalid evidencehex for CSV shard `{path}`: expected exactly 64 lowercase or uppercase hexadecimal characters"
    )]
    InvalidEvidenceHex { path: String },

    #[error(
        "evidence integrity mismatch for CSV shard `{path}`: declared SHA-256 does not match exact file bytes"
    )]
    DigestMismatch { path: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedEvidence {
    pub sha256_hex: String,
    pub byte_len: u64,
}

pub fn verify_csv_evidence(
    csv_path: &Path,
    declared_evidencehex: Option<&str>,
) -> Result<VerifiedEvidence, EvidenceIntegrityError> {
    let expected = normalize_sha256(csv_path, declared_evidencehex)?;
    let (actual, byte_len) = sha256_file(csv_path)?;

    if expected
        .as_bytes()
        .ct_eq(actual.as_bytes())
        .unwrap_u8()
        != 1
    {
        return Err(EvidenceIntegrityError::DigestMismatch {
            path: csv_path.display().to_string(),
        });
    }

    Ok(VerifiedEvidence {
        sha256_hex: actual,
        byte_len,
    })
}

fn normalize_sha256(
    csv_path: &Path,
    declared_evidencehex: Option<&str>,
) -> Result<String, EvidenceIntegrityError> {
    let path = csv_path.display().to_string();
    let candidate = declared_evidencehex
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| EvidenceIntegrityError::MissingEvidenceHex {
            path: path.clone(),
        })?;

    if candidate.len() != SHA256_HEX_LENGTH
        || !candidate.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        return Err(EvidenceIntegrityError::InvalidEvidenceHex { path });
    }

    Ok(candidate.to_ascii_lowercase())
}

fn sha256_file(csv_path: &Path) -> Result<(String, u64), EvidenceIntegrityError> {
    let path = csv_path.display().to_string();
    let mut file = File::open(csv_path)
        .map_err(|source| EvidenceIntegrityError::Read {
            path: path.clone(),
            source,
        })?;

    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; BUFFER_SIZE];
    let mut byte_len = 0_u64;

    loop {
        let count = file
            .read(&mut buffer)
            .map_err(|source| EvidenceIntegrityError::Read {
                path: path.clone(),
                source,
            })?;

        if count == 0 {
            break;
        }

        hasher.update(&buffer[..count]);
        byte_len = byte_len.saturating_add(count as u64);
    }

    Ok((hex::encode(hasher.finalize()), byte_len))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temporary_csv_path() -> std::path::PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock should be after UNIX epoch")
            .as_nanos();

        std::env::temp_dir().join(format!("centralaz-evidence-{nanos}.csv"))
    }

    #[test]
    fn accepts_matching_sha256() {
        let path = temporary_csv_path();
        fs::write(&path, b"time,value\n2026-01-01T00:00:00Z,42\n").expect("write CSV");

        let digest =
            "b53467d97890e34070805f553bad9b0a0a56f74fb813a388da0cd33a6f511dc8";

        let verified = verify_csv_evidence(&path, Some(digest)).expect("matching digest");

        assert_eq!(verified.sha256_hex, digest);
        assert!(verified.byte_len > 0);

        fs::remove_file(path).expect("remove CSV");
    }

    #[test]
    fn rejects_tampered_file() {
        let path = temporary_csv_path();
        fs::write(&path, b"time,value\n2026-01-01T00:00:00Z,43\n").expect("write CSV");

        let original_digest =
            "b53467d97890e34070805f553bad9b0a0a56f74fb813a388da0cd33a6f511dc8";

        let error =
            verify_csv_evidence(&path, Some(original_digest)).expect_err("tampering must fail");

        assert!(matches!(error, EvidenceIntegrityError::DigestMismatch));

        fs::remove_file(path).expect("remove CSV");
    }

    #[test]
    fn rejects_absent_or_malformed_metadata() {
        let path = temporary_csv_path();
        fs::write(&path, b"time,value\n").expect("write CSV");

        assert!(matches!(
            verify_csv_evidence(&path, None),
            Err(EvidenceIntegrityError::MissingEvidenceHex { .. })
        ));

        assert!(matches!(
            verify_csv_evidence(&path, Some("not-a-sha256")),
            Err(EvidenceIntegrityError::InvalidEvidenceHex { .. })
        ));

        fs::remove_file(path).expect("remove CSV");
    }
}
