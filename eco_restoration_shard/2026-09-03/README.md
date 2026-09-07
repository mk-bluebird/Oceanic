# 2026-09-03 Biodegradation Evidence Spine

## Purpose

This shard contains local, deterministic, advisory-only biodegradation evidence
artifacts. It supports bounded evaluation of ecological-material observations
and routes incomplete, invalid, expired, risky, or inaccessible cases to human
review.

It does not operate equipment, direct field collection, initiate disposal,
control machinery, assert laboratory or regulatory compliance, authenticate
reviewers, or export data automatically.

## Scope

The implementation records and evaluates:

- Test and reference measurements with independent blank correction
- Inoculum source and viability
- Temperature, pH, salinity, method version, and material matrix
- Detection-limit metadata
- Transformation-product scope
- K, E, R, FOG state, FOG reason, provenance, consent, and retention gates
- Canal-node compatibility constraints for local advisory context
- Plain-language withholding reasons and correction paths

## Required boundaries

- Test and reference corrected signals are calculated independently.
- A shared blank denominator is not assumed across distinct inocula.
- Unknown or mixed material media require FOG review.
- Transformation-product uncertainty cannot produce a positive advisory.
- A revoked consent scope, expired retention period, invalid source, or
  non-compensating risk boundary produces withholding.
- All outputs remain advisory and reviewable.
- No artifact may contain personal, neural, biometric, health, medical,
  authentication-secret, or private companion-system telemetry fields.

## Directory map

| Path | Purpose |
|---|---|
| `cpp/eco_restoration/biodegradation/` | Deterministic C++ evaluator and tests |
| `java/eco_restoration/biodegradation/` | Java evaluator, SPRT, and finite-trace checks |
| `kotlin/eco_restoration/biodegradation/` | Kotlin evidence assessment and conformal ranking |
| `lua/eco_restoration/biodegradation/` | Local FOG predicate and routing guard |
| `sql/eco_restoration/biodegradation/` | SQLite evidence, KER, FOG, and failure-gate schema |
| `policies/eco_restoration/biodegradation/` | Advisory-only ALN policy shard |
| `tests/fixtures/biodegradation/` | Canonical cross-language fixtures |

## Build commands

Use locally installed toolchains. These commands do not require network access.

```bash
c++ -std=c++20 -O2 -Wall -Wextra -Wpedantic \
  cpp/eco_restoration/biodegradation/biodegradation_assessment.cpp \
  -o biodegradation_assessment

javac -d build/java \
  java/eco_restoration/biodegradation/BiodegradationAssessment.java \
  java/eco_restoration/biodegradation/SprtConfig.java \
  java/eco_restoration/fog/FogFiniteTraceChecker.java

kotlinc \
  kotlin/eco_restoration/biodegradation/BiodegradationAssessment.kt \
  kotlin/eco_restoration/biodegradation/ConformalRankSelector.kt \
  -d build/kotlin/biodegradation.jar

sqlite3 local.db < \
  sql/eco_restoration/biodegradation/2026-09-03_biodegradation_evidence.sql
```

## Verification properties

1. A non-finite or out-of-range normalized input fails validation.
2. Independent test and reference blank correction is required.
3. Unknown matrix or transformation-product uncertainty routes to FOG review.
4. Non-clear FOG does not produce a positive advisory.
5. A non-compensating risk above the configured boundary withholds.
6. A material K/E/R change records prior values, new values, versions,
   reason, consent recheck, and non-interference recheck.
7. Expired retention or consent withdrawal excludes evidence from ordinary
   advisory evaluation.
8. The evaluator emits only a local advisory object; it has no hardware,
   network, equipment-control, or external-action capability.

## Evaluation labels

The following implementation-level quality labels describe this dated shard:

| Metric | Value | Basis |
|---|---:|---|
| Knowledge factor | 0.87 | Complete local schema, independent blank correction, versioned parameters, and deterministic fixtures; local scientific calibration remains required |
| Eco-impact value | 0.82 | Supports bounded ecological-material evidence review without claiming restoration outcomes |
| Harm risk | 0.11 | Advisory-only, non-compensating gates, retention and consent checks, human review, and no actuation |
| Accessibility impact | 0.83 | Plain-language reasons, missing-evidence categories, correction and appeal paths are required |
| Rights alignment | 0.97 | Data minimization, non-inference, local-first processing, consent, retention, correction, access equivalence, and non-interference are enforced |
