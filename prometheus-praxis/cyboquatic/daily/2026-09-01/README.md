# Cyboquatic Surcharge-Breach Containment — 2026-09-01

This artifact set implements a local, energy-aware blast-radius classifier for surcharge breaches in cyboquatic restoration machinery.

## Layout

- `sql/surcharge_breach.sql` — SQLite schema, strict invariants, KER/FOG/Canal parameters, indexed containment queries.
- `cpp/surcharge_breach.cpp` — C++20 command-line classifier using CSV inputs and no third-party dependency.
- `java/SurchargeBreachClassifier.java` — Java 21-compatible classifier with equivalent deterministic rules.
- `kotlin/SurchargeBreachClassifier.kt` — Kotlin/JVM classifier with input validation and accessible explanations.
- `lua/surcharge_breach.lua` — Lua 5.4 routing predicate for low-power controller use.
- `aln/surcharge_breach.aln` — ALN v2 policy shard defining consent, retention, KER triad, FOG and Canal constraints.

## Input format

Each implementation accepts one CSV record:

`event_id,canal_node,flow_lps,design_lps,head_m,freeboard_m,bod_mg_l,tss_mg_l,cec_meq_100g,downstream_m`

Example:

`event-20260901-a,canal-west-03,92,70,1.8,0.25,38,140,18,430`

## Classifier rules

- `surcharge_ratio = flow_lps / design_lps`
- `hydraulic_score = surcharge_ratio + max(0, 0.50 - freeboard_m)`
- `ecological_score = (bod_mg_l / 30) + (tss_mg_l / 100) + max(0, 20 - cec_meq_100g) / 20`
- `blast_radius_m = downstream_m * clamp(hydraulic_score / 2, 0.10, 1.00)`
- A breach is `critical` when surcharge ratio is at least 1.30, freeboard is at most 0.20 m, or ecological score is at least 3.00.
- A breach is `elevated` when surcharge ratio is at least 1.10 or ecological score is at least 1.75.
- Otherwise it is `contained`.

## Operational boundary

This software provides decision support only. It must not autonomously close valves, disable assistive controls, change chemical dosing, or deny service. Controllers must preserve offline operation and route critical results to a human operator using the accessibility channel configured for the site.

## Validation

Run the SQL schema with SQLite 3.37 or later. Compile C++ with a C++20 compiler. Compile Java with JDK 21 or later. Compile Kotlin with Kotlin 2.x or later. Run Lua with Lua 5.4.
