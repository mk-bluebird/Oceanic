# 2026-09-04 Pollinator and Soil Carbon Evidence

## Purpose

This shard contains deterministic, advisory-only examples for pollinator
resistance paths and soil-carbon first-order decay pools. It is designed for
local evidence evaluation and human review, not for automated land management,
wildlife intervention, irrigation control, or direct machinery operation.

## Scope

- Least-cost pollinator path calculations with maximum path-length constraints
- FOG withholding for unmodeled resistance media
- Soil-carbon pool decay with source-bound and interval-bounded rate constants
- Nitrate evidence gates for biochar-persistence advisories
- Explicit horizon protection and uncertainty handling
- Shared fixture structure for C++, Java, Kotlin, Lua, and SQLite checks

## Required boundaries

- A least-cost route is not a claim that a species is present, absent, healthy,
  or likely to use the route.
- Higher nonnegative resistance must not reduce the cost of a fixed path.
- A FOG-marked edge does not participate in a positive route advisory.
- Soil carbon is evaluated only inside the documented time horizon.
- Temperature and moisture response factors are stored as separate transformed
  rates; they do not silently change source-bound pool constants.
- Missing nitrate evidence withholds the biochar-persistence advisory.
- Outputs remain local, advisory-only, and human-reviewable.

## Directory map

| Path | Purpose |
|---|---|
| `cpp/eco_restoration/pollinator/` | Bounded least-cost path implementation |
| `java/eco_restoration/soil/` | First-order carbon pool evaluator |
| `sql/eco_restoration/soil/` | Nitrate and horizon gate fixtures |
| `tests/fixtures/pollinator/` | Three deterministic path fixtures |
| `tests/fixtures/soil_carbon/` | Decay and nitrate boundary fixtures |

## Verification properties

1. Increasing a nonnegative edge resistance cannot reduce the cost of the same route.
2. A lower-cost route exceeding its length limit is excluded.
3. An unmodeled resistance medium produces withholding.
4. For positive decay rates, \(SOC(t_2) \leq SOC(t_1)\) when \(t_2 > t_1\).
5. A rate outside its source-bound interval produces withholding.
6. A horizon beyond the validated interval produces withholding.
7. Nitrate below the configured bound is informational or advisory only when all other gates pass.
8. Missing or above-bound nitrate evidence withholds the biochar-persistence result.

## Evaluation labels

| Metric | Value | Basis |
|---|---:|---|
| Knowledge factor | 0.84 | Deterministic solver and decay properties are clear; source-specific ecological parameters remain required |
| Eco-impact value | 0.81 | Supports habitat and soil-carbon research review while avoiding biological or restoration guarantees |
| Harm risk | 0.13 | Length, FOG, horizon, rate, and nitrate gates constrain overreach |
| Accessibility impact | 0.82 | Human-readable route and withholding summaries are required |
| Rights alignment | 0.96 | No identity inference, no direct control, local review, correction, and data minimization |
