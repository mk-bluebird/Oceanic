# Eco Restoration Daily Rotation Manifest

## Purpose

This manifest records deterministic daily domain assignments for local,
advisory-only ecological-restoration artifacts. It supports discoverability,
fixture planning, and review without inferring identity, eligibility,
capability, health, location, augmentation status, or institutional status.

## Domain classes

| Key | Domain | Required boundary |
|---|---|---|
| a | Ecological material and biodegradation | Evidence is advisory only; method, matrix, inoculum, and transformation-product scope are explicit |
| b | PFAS, residual corridors, and cold-season fate | Detection limit, matrix, scope, hysteresis, and uncertainty are explicit |
| c | FOG uncertainty routing | State and reason are separate; non-clear outcomes cannot silently self-clear |
| d | Cyboquatic workload energy and residual telemetry | Local analysis only; no scheduling or physical control |
| e | Drainage decay, water quality, sediment, and soil | Model-transfer limits and segmented regimes are explicit |
| f | Governance, KER, consent, retention, and review | K/E/R material changes require versioned records and review |
| g | Surcharge, blast-radius, indexes, and query-plan evidence | Benchmarks remain local; outputs are advisory and non-actuating |

## Dated assignments

| Date | Assigned domain set | Required artifact folder | Required fixture family |
|---|---|---|---|
| 2026-09-03 | a | `2026-09-03_biodegradation/` | Independent inoculum correction, method profile, transformation-product, KER/FOG |
| 2026-09-04 | a, e | `2026-09-04_pollinator_soil/` | Resistance path, FOG edge, soil-carbon monotonicity, nitrate/horizon |
| 2026-09-06 | f, g | `2026-09-06_governance_energy/` | FOG finite trace, event chain, token isolation, index-plan classification |

## Dated-folder requirements

Every dated artifact folder must include:

1. A `README.md` describing purpose, scope, data class, boundaries, build
   commands, test commands, fixture names, and accessibility expectations.
2. A link to `hex/phoenix_hex_registry.md` when spatial anchors are used.
3. A reference to the relevant policy shard.
4. A list of required source and parameter versions.
5. A statement that the output is advisory-only and has no physical-control,
   hardware-control, or external automatic-action capability.
6. A local fixture list with expected status, FOG state, and reason code.
7. The five evaluation labels: knowledge factor, eco-impact value, harm risk,
   accessibility impact, and rights alignment.

## Supported implementation boundary

The dated artifact sets may use C++20, Java 17, Kotlin 1.9.x, Lua 5.4,
SQLite 3.x, ALN v2, Markdown, JSON, and HTML.

The dated artifact sets do not introduce Rust crates, Python components,
digital twins, hardware-control modules, automatic external exports, or
automatic physical intervention.
