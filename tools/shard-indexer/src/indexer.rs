// tools/shard-indexer/src/indexer.rs

use crate::cli::Cli;
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::Serialize;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Minimal catalog row inserted into qpu_shard_catalog.
#[derive(Debug, Serialize)]
pub struct ShardCatalogEntry {
    pub repo_name: String,
    pub shard_path: String,
    pub shard_name: String,
    pub evidence_hex: String,
    pub discovered_at: DateTime<Utc>,
}

/// Run the indexing flow: scan particles, compute evidence_hex, insert rows.
pub async fn run_indexer(args: Cli) -> Result<(), Box<dyn std::error::Error>> {
    let particles_root = args.repo_root.join("qpudatashards").join("particles");

    let entries = collect_shards(&particles_root, &args.repo_name)?;
    if entries.is_empty() {
        println!("No shard files found under {:?}", particles_root);
        return Ok(());
    }

    let conn = Connection::open(&args.db_path)?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS qpu_shard_catalog (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            repo_name       TEXT NOT NULL,
            shard_path      TEXT NOT NULL,
            shard_name      TEXT NOT NULL,
            evidence_hex    TEXT NOT NULL,
            discovered_at   TEXT NOT NULL
        )",
        [],
    )?;

    let tx = conn.transaction()?;
    for entry in entries {
        tx.execute(
            "INSERT INTO qpu_shard_catalog (
                repo_name,
                shard_path,
                shard_name,
                evidence_hex,
                discovered_at
            ) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                entry.repo_name,
                entry.shard_path,
                entry.shard_name,
                entry.evidence_hex,
                entry.discovered_at.to_rfc3339(),
            ],
        )?;
    }
    tx.commit()?;

    println!(
        "Indexed {} shard(s) into qpu_shard_catalog at {:?}",
        entries.len(),
        args.db_path
    );

    Ok(())
}

/// Collect shard files (ALN/CSV) under qpudatashards/particles.
fn collect_shards(root: &Path, repo_name: &str) -> Result<Vec<ShardCatalogEntry>, Box<dyn std::error::Error>> {
    let mut out = Vec::new();
    if !root.exists() {
        return Ok(out);
    }

    for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();
        if !is_shard_file(path) {
            continue;
        }

        let shard_path = to_relative_string(path, root);
        let shard_name = path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "unknown".to_string());

        let evidence_hex = compute_evidence_hex(path)?;
        let discovered_at = Utc::now();

        out.push(ShardCatalogEntry {
            repo_name: repo_name.to_string(),
            shard_path,
            shard_name,
            evidence_hex,
            discovered_at,
        });
    }

    Ok(out)
}

/// Simple filter: include .aln and .csv shard files.
fn is_shard_file(path: &Path) -> bool {
    match path.extension().and_then(|e| e.to_str()) {
        Some("aln") | Some("csv") => true,
        _ => false,
    }
}

/// Convert a path under root to a normalized relative string.
fn to_relative_string(path: &Path, root: &Path) -> String {
    path.strip_prefix(root)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| path.to_string_lossy().to_string())
}

/// Evidence hex: simple, deterministic byte-to-hex over file content.
/// No blacklisted algorithms, just a direct mapping.
fn compute_evidence_hex(path: &Path) -> Result<String, Box<dyn std::error::Error>> {
    let mut file = fs::File::open(path)?;
    let mut buf = Vec::new();
    file.read_to_end(&mut buf)?;
    Ok(bytes_to_hex(&buf))
}

/// Byte-to-hex encoder.
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bytes_to_hex_is_deterministic() {
        let data = [0u8, 1u8, 255u8];
        let hex1 = bytes_to_hex(&data);
        let hex2 = bytes_to_hex(&data);
        assert_eq!(hex1, "0001ff");
        assert_eq!(hex1, hex2);
    }

    #[test]
    fn non_shard_extensions_are_filtered() {
        let root = PathBuf::from("/tmp/root");
        let path = root.join("file.txt");
        assert!(!is_shard_file(&path));
    }
}
