// tools/shard-indexer/src/cli.rs

use clap::Parser;
use std::path::PathBuf;

/// Shard indexer CLI for Eco-Fort.
///
/// Scans qpudatashards/particles, computes evidencehex-style hashes,
/// and populates the qpu_shard_catalog table in the SQLite constellation DB.
#[derive(Parser, Debug)]
#[command(
    name = "shard-indexer",
    version,
    about = "Index Eco-Fort qpudatashards into the EcoNet constellation catalog",
    long_about = None
)]
pub struct Cli {
    /// Root of the Eco-Fort repo (e.g., ../../ from tools/shard-indexer).
    #[arg(long, value_name = "PATH")]
    pub repo_root: PathBuf,

    /// Path to the SQLite constellation DB.
    #[arg(long, value_name = "PATH")]
    pub db_path: PathBuf,

    /// Logical repo name (e.g., EcoNet, Eco-Fort).
    #[arg(long, value_name = "NAME")]
    pub repo_name: String,
}
