<!-- tools/shard-indexer/README.md -->

# shard-indexer: Eco-Fort QPU Shard Catalog Populator

`shard-indexer` is a non-actuating Rust CLI tool that scans the `qpudatashards/particles` directory of the Eco-Fort repository, computes deterministic `evidence_hex` strings for ALN/CSV shard files, and populates the `qpu_shard_catalog` table in the SQLite constellation index DB.

## ✨ Role

- Discover canonical shard files (`*.aln`, `*.csv`) under `qpudatashards/particles`.
- Compute a simple byte-to-hex `evidence_hex` for each shard (no blacklisted algorithms).
- Insert catalog rows into `qpu_shard_catalog` with `repo_name`, `shard_path`, `shard_name`, `evidence_hex`, and `discovered_at`.

This keeps Eco-Fort aligned with the frozen ecosafety grammar by ensuring all shards are discoverable and traceable without any physical-world actuation.

## 🧩 Usage

From the root of the Eco-Fort repo:

```bash
cargo run -p shard-indexer -- \
  --repo-root . \
  --db-path ./constellation.db \
  --repo-name Eco-Fort
```

Arguments:

- `--repo-root`: Path to the Eco-Fort repository root (where `qpudatashards/` lives).
- `--db-path`: Path to the SQLite constellation DB (e.g., `constellation.db`).
- `--repo-name`: Logical name of the repo being indexed (e.g., `Eco-Fort`, `EcoNet`).

## 📊 Catalog Schema

If `qpu_shard_catalog` does not exist, `shard-indexer` creates a minimal table:

```sql
CREATE TABLE IF NOT EXISTS qpu_shard_catalog (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name     TEXT NOT NULL,
    shard_path    TEXT NOT NULL,
    shard_name    TEXT NOT NULL,
    evidence_hex  TEXT NOT NULL,
    discovered_at TEXT NOT NULL
);
```

This schema is intentionally simple so that other tools in the constellation can join it with more detailed corridor and schema metadata from the Eco-Fort `db/` SQL files.

## 🛡️ Safety Invariants

- No actuation: `shard-indexer` only reads files and writes metadata to SQLite.
- No blacklisted cryptography: `evidence_hex` is a direct byte-to-hex encoding of shard contents.
- Deterministic lineage: identical shard content always yields identical `evidence_hex`.

Use `shard-indexer` whenever new shards are added or modified so the EcoNet constellation can reliably discover and reason about them.
