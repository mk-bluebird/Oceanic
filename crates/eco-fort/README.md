# eco-fort: Eco-Fort Postgres Spine Library

`eco-fort` is a non-actuating Rust library crate that binds strongly-typed Rust structs to the Eco-Fort Postgres schema and exposes eco/knowledge/risk scoring functions for EcoNet-aligned agents and tools.

It is designed to be the Rust-side mirror of the Eco-Fort SQL spine, letting you query sites, materials, metrics, topics, and hex-stamps in a way that preserves ecosafety grammar and makes scoring decisions explicit in code.

## ✨ Features

- Strongly-typed models for core Eco-Fort tables:
  - `identities` (Bostrom / ALN / ERC-20 anchors).
  - `fort_sites` (Eco-Fort installations / cyboquatic sites).
  - `materials` (biodegradable / recycled compounds with toxicity and CO₂).
  - `eco_metrics` (time-series eco impact snapshots).
  - `research_topics` (high-impact EcoNet research threads).
  - `hex_stamps` (evidence-hex ledger entries).

- Scoring functions:
  - `fort_eco_score`: normalizes eco risk and carbon balance into a \(0.0\)–\(1.0\) score.
  - `material_safety_score`: evaluates material safety from biodegradability and toxicity.
  - `topic_priority_score`: ranks research topics by eco impact, knowledge factor, and risk.

- Postgres connection helper:
  - `create_pool(max_connections)`: builds a `sqlx::PgPool` using `DATABASE_URL`.

All logic is strictly read-only and diagnostic; it does not perform any actuation, control, or physical-world routing.

## 📦 Installation

This crate is intended to live under `crates/eco-fort` inside the Eco-Fort repository and be part of the root Cargo workspace:

```toml
[workspace]
members = [
    "tools/shard-indexer",
    "crates/eco-fort",
]
```

Dependencies (managed at workspace level or per crate):

```toml
[dependencies]
tokio = { version = "1.40.0", features = ["rt-multi-thread", "macros"] }
sqlx = { version = "0.7.4", features = ["runtime-tokio", "postgres", "chrono"] }
chrono = { version = "0.4.38", features = ["clock"] }
```

## 🗄️ Database Configuration

`eco-fort` expects a PostgreSQL database with the Eco-Fort schema applied (e.g., the `eco_fort` schema created by your SQL files).

Set the `DATABASE_URL` environment variable to your Postgres connection string, for example:

```bash
export DATABASE_URL="postgres://user:password@localhost:5432/eco_fort"
```

The general Postgres format is:

```text
postgres://user:password@host:port/database
```

`create_pool` uses this variable to connect and reuse a `PgPool` for queries. [web:65][web:66][web:69]

## 🔍 Example: Connecting and Fetching Fort Sites

```rust
use eco_fort::db::create_pool;
use eco_fort::models::FortSite;
use sqlx::Row;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_pool(4).await?;

    let rows = sqlx::query("SELECT fort_id, fort_code, name, description, latitude_deg, longitude_deg, elevation_m, location_region, eco_biome_tag, is_active, created_by_identity, created_at, updated_at FROM eco_fort.fort_sites")
        .fetch_all(&pool)
        .await?;

    let sites: Vec<FortSite> = rows
        .into_iter()
        .map(|row| FortSite {
            fort_id: row.get("fort_id"),
            fort_code: row.get("fort_code"),
            name: row.get("name"),
            description: row.get::<Option<String>, _>("description"),
            latitude_deg: row.get::<Option<f64>, _>("latitude_deg"),
            longitude_deg: row.get::<Option<f64>, _>("longitude_deg"),
            elevation_m: row.get::<Option<f64>, _>("elevation_m"),
            location_region: row.get::<Option<String>, _>("location_region"),
            eco_biome_tag: row.get::<Option<String>, _>("eco_biome_tag"),
            is_active: row.get("is_active"),
            created_by_identity: row.get::<Option<i64>, _>("created_by_identity"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        })
        .collect();

    println!("Loaded {} Eco-Fort site(s)", sites.len());
    Ok(())
}
```

## 📊 Scoring Usage

Once you have data, you can compute normalized scores:

```rust
use eco_fort::models::{EcoMetric, Material, ResearchTopic};
use eco_fort::scoring::{fort_eco_score, material_safety_score, topic_priority_score};

// Given instances `metric`, `material`, `topic` loaded from the database:
let eco = fort_eco_score(&metric);
let safety = material_safety_score(&material);
let priority = topic_priority_score(&topic);

println!("fort_eco_score = {eco}");
println!("material_safety_score = {safety}");
println!("topic_priority_score = {priority}");
```

These scores are bounded between \(0.0\) and \(1.0\), making them suitable for downstream scheduling, governance, or visualization without risking unbounded values.

## 🧪 Verification & Tests

- Unit tests ensure scoring functions are bounded and that pool creation fails safely when `DATABASE_URL` is missing.
- Kani verification proofs (e.g., in `tests/kani_scoring.rs`) assert that scoring functions never return values outside the \([0.0, 1.0]\) interval for representative inputs, strengthening ecosafety guarantees at compile time. [web:44][web:53]

## 🛡️ Safety Invariants

- Read-only and diagnostic: no actuation logic, no motor/valve/power routing.
- Explicit eco/knowledge/risk scoring: all risk-related decisions pass through well-defined functions.
- Compatible with EcoNet governance: traits and scores can be consumed by higher-level orchestrators while keeping Eco-Fort itself strictly a spine library.

Use `eco-fort` whenever you need to inspect Eco-Fort data or compute eco-aligned scores inside your Rust tooling, without violating the frozen grammar or non-actuating role-band of the Eco-Fort repository.
