# Oceanic

> An AI-chat predictor and analyzer of water bodies across the globe — from desert washes to the Southern Ocean.

Oceanic is a conversational analysis system for aquatic habitats. It accepts natural-language questions about lakes, rivers, reservoirs, canals, coastal lagoons, estuaries, and open marine systems, and returns structured, traceable, and **explicitly-limited** assessments of habitat condition, depletion risk, and early-warning signals. It is designed for researchers, restoration practitioners, and community monitoring programs who need reproducible reasoning rather than a black-box score.

Oceanic is not a decision authority. It does not issue permits, authorize interventions, or verify legal status. It surfaces what is known, what is inferred, what is uncertain, and what would be needed to know more.

---

## Why Oceanic exists

Water-body depletion — lake death, fish kills, hypoxic events, seagrass and coral collapse, krill–predator mismatch — is a recurring class of disaster that is **partly predictable** and **almost always under-instrumented**. Existing tools tend to be either:

- **Narrow**: a single index or a single model tuned for one habitat type, or
- **Opaque**: a prediction with no traceable reasoning or declared evidence boundary.

Oceanic takes a third position: **a universal, typed, dimensionless language** for water-body state, combined with a **conversational interface** that composes observations, models, and evidence into statements any analyst can audit. The aim is not to predict every disaster, but to make it **plausible to predict a disaster before it becomes visible in the mean**.

---

## Core ideas

### 1. A universal language for water bodies

Every water body, at any scale, is placed at a **dimensionless position** defined by a small set of control parameters:

| Parameter | Meaning | Dimensionless form |
|---|---|---|
| Damköhler | reaction vs. flushing | \(\mathrm{Da} = k_{\text{react}}V/Q\) |
| Péclet | advection vs. diffusion | \(\mathrm{Pe} = uL/K\) |
| Residence ratio | hydraulic vs. biological time | \(\Pi_\tau = \tau_{\text{res}}/\tau_{\text{bio}}\) |
| Richardson | stratification strength | \(\mathrm{Ri} = N^2/(\partial u/\partial z)^2\) |

Two water bodies with the same dimensionless position are in the **same dynamical regime**, even if their volumes differ by twelve orders of magnitude. This is the foundation of the system's cross-scale comparability.

### 2. Depletion as a functional state, not a number

Depletion is defined relative to a declared set of **vital functions** (oxygen support, thermal refuge, spawning substrate, nursery provision, migration connectivity, food-web energy transfer) and a declared **reference condition**. Four states are distinguished:

- **Degradation** — a downward trend while still viable
- **Depletion** — persistently below threshold, biota still present
- **Collapse** — obligate taxa locally absent
- **Death** — collapse with no recovery pathway within the declared horizon

### 3. Precursor signatures before visible collapse

The predictive hypothesis Oceanic is built to test is that functional depletion is preceded by three concurrent signatures detectable before the threshold is crossed:

1. **Metabolic imbalance** — net ecosystem metabolism turns persistently negative before oxygen crosses its critical threshold, with precursor window scaling as \(\tau_{\mathrm{O_2}} = (k_a + Q/V)^{-1}\).
2. **Critical slowing down** — rising variance and lag-1 autocorrelation of the dominant state variable as the system approaches a fold bifurcation.
3. **Declining Fisher information** — loss of sharpness in the state distribution before the mean shifts.

These are combined into a **Depletion Early-Warning Index (DEWI)**:

\[
\mathrm{DEWI}(t) = \alpha_1\,\Delta\widetilde{\mathrm{Var}} + \alpha_2\,\Delta\widetilde{\rho_1} + \alpha_3\,\Delta\widetilde{\mathrm{FI}}
\]

with weights fitted on retrospective data and reported with their own uncertainty. The alarm condition is declared in advance; the falsification conditions are stated in the project's research notes.

---

## What Oceanic does

### Conversational analysis
Ask questions in natural language about any water body or class of water body. Oceanic parses the question into a typed query, selects the appropriate analytical modules, and returns a structured answer with:
- the dimensionless position of the water body,
- the computed indicators and their units,
- the evidence attached to each claim (observed, modelled, inferred),
- the declared interpretation limits.

### Habitat and food-web reasoning
Typed relationship graphs record feeding, habitat support, pollination, seed dispersal, and nutrient transfer as **separate, directed layers**. Centrality is computed per layer; the system never adds across layers without a declared weighting. A species with many recorded connections is not presented as "most influential" unless independent validation supports it.

### Occupancy and detection
For mobile or cryptic species, repeated-survey occupancy models separate **site use** from **detection probability**. The system returns both the estimated use probability and the detection model, with an explicit identifiability check against the intended survey design.

### Restoration monitoring
Outplant survival, reproduction, and recruitment are tracked as **separate demographic states**, not collapsed into a single survival number. Equivalence claims between restored and reference sites are screened at the domain level, not averaged into a single composite.

### Community evidence handling
A minimal evidence screen accepts field observations with an explicit **state per required field** — supplied, unknown, not collected, or withheld — and produces a location-free review projection only when review permission is declared. Raw observation text is never copied into summaries.

### Sensitivity and disclosure control
Sensitivity declarations are treated as **declarations**, not as permissions. Publication, external action, and release authorization are separate fields that Oceanic never infers from a low-sensitivity declaration.

---

## Architecture

Oceanic follows a strict layering that keeps analysis separate from action, and content separate from permission:

```
┌─────────────────────────────────────────────┐
│  Conversational interface (chat)            │  ← natural-language I/O
├─────────────────────────────────────────────┤
│  Query parser and router                    │  ← typed query construction
├─────────────────────────────────────────────┤
│  Analysis modules (Lua)                     │  ← deterministic arithmetic
│  • occupancy likelihood                     │
│  • replicated contrast summary              │
│  • evidence state screen                    │
│  • typed relationship graph                 │
│  • DEWI early-warning screen                │
│  • food-web layer metrics                   │
├─────────────────────────────────────────────┤
│  External statistical layer (R / Python)    │  ← hierarchical, survival,
│                                               │     meta-analytic fitting
├─────────────────────────────────────────────┤
│  Reporting layer                            │  ← accessible, qualified
│                                               │     summaries
├─────────────────────────────────────────────┤
│  Action layer (separate authorization)      │  ← never automatic
└─────────────────────────────────────────────┘
```

The Lua analysis modules are **non-actuating**: they compute, they do not publish, store, or intervene. Any component that performs an external action requires its own authorization boundary.

---

## Features at a glance

| Feature | Description |
|---|---|
| **Cross-scale comparability** | Water bodies compared at dimensionless positions, not raw magnitudes. |
| **Typed evidence** | Every claim is tagged: observed, modelled, or inferred. |
| **Layer-specific food webs** | Feeding, habitat, pollination, dispersal, nutrient transfer kept separate. |
| **Detection-aware counts** | Occupancy and abundance estimates correct for imperfect detection. |
| **Restoration outcome separation** | Survival, reproduction, recruitment tracked independently. |
| **Early-warning index** | DEWI combines variance, autocorrelation, and Fisher information. |
| **Evidence completeness screen** | Field states explicit; incomplete drafts valid and never discarded as errors. |
| **Consent-gated review projections** | No review summary without declared permission. |
| **Publication separation** | Low-sensitivity declarations never authorize release. |
| **Offline operation** | Core analysis runs locally; no mandatory network, telemetry, or identity disclosure. |

---

## What Oceanic will not do

Oceanic's scope is bounded by design:

- It **does not verify** scientific accuracy, observer competence, or legal status.
- It **does not authorize** collection, publication, or intervention.
- It **does not infer** consent, sensitivity review, or publication permission from a declaration.
- It **does not treat** structural centrality as ecological influence without independent validation.
- It **does not collapse** unknown, not-collected, and withheld into a single missing-value state.
- It **does not replace** a fitted statistical model with a deterministic arithmetic screen.

These boundaries are stated in every output as `interpretation_limits`, not buried in documentation.

---

## Use cases

- **Lake and reservoir monitoring**: track oxygen, nutrients, and stratification against the DEWI screen; identify precursor signatures before a fish-kill event.
- **Coral and seagrass restoration**: compare outplant survival, reproductive contribution, and recruitment across sites; refuse equivalence claims that average away domain failures.
- **Krill–predator–fishery overlap**: examine spatial and seasonal overlap at the resolution required for timely decisions; distinguish overlap from depletion.
- **Community monitoring**: accept field observations with explicit missingness states; produce review projections without copying raw observations.
- **Food-web documentation**: record typed, directed relationships across repositories; compute layer-specific degree without falsely aggregating across layers.
- **Desert and arid-coast systems**: place ephemeral washes, canals, and managed-inflow sites at a common dimensionless position alongside lakes and lagoons.

---

## Quick start

Oceanic is designed to be usable without a full infrastructure stack.

1. **Ask a question.** Any of the following is a valid starting point:
   - *"What is the DEWI status of Lake Erie over the last decade?"*
   - *"Compare outplant survival and reproduction for elkhorn coral at two Caribbean sites."*
   - *"How is whitebark pine regeneration tracking against nutcracker site use?"*
   - *"What missing fields are present in this community observation?"*

2. **Review the structured answer.** Every answer includes:
   - the dimensionless position (where applicable),
   - the computed indicators with units,
   - the evidence tag per claim,
   - the interpretation limits,
   - the source and date of each input.

3. **Escalate only with authorization.** Any follow-up that involves publication, sharing, or intervention is routed to a separate authorization step. Oceanic never performs these actions automatically.

---

## Design principles

1. **Traceability over prediction.** A traceable limited claim is more useful than an untraceable confident one.
2. **Separation of concerns.** Validation, computation, reporting, and action are different layers with different contracts.
3. **Explicit absence.** Missing data is a state, not a zero; withheld data is a state, not an unknown; unknown is a state, not a failure.
4. **Dimensionless first.** Comparability across scales requires dimensionless coordinates.
5. **Reference-anchored thresholds.** "Depleted" is always relative to a declared reference condition.
6. **Falsifiable warnings.** Every early-warning indicator is stated with its falsification conditions before it is used.
7. **No inferred permissions.** Consent, review, and publication are declarations, never inferences.
8. **Attribution without authority.** Credit anchors are retained for document provenance; they establish no operational rights.

---

## Status

Oceanic is under active development. Current components include:

- Evidence state screening (schema 2)
- Occupancy likelihood for ordered detection histories
- Replicated contrast summary (Welford variance, heterogeneity diagnostics pending)
- Typed relationship graph with layer-specific degree
- Cojo cohort scenario accounting and joint-draw uncertainty adapter
- Food-web layer metrics
- DEWI early-warning screen (specified, not yet implemented)

Empirical fitting, cross-language equivalence testing, and field validation remain outstanding. No ecological benefit has been measured from any component.

---

## Contributing

Contributions are welcome in three classes:

- **Analysis modules**: deterministic, non-actuating, with named tests and explicit interpretation limits.
- **Schema and vocabulary**: typed, versioned, with a stated migration path.
- **Documentation and accessibility**: plain-language descriptions, offline-compatible references, and non-English text support where the input contract permits.

Before contributing, please read the interpretation limits in the module you intend to extend. The most common failure mode in this project is a contribution that silently widens a claim beyond what its evidence supports.

---

## Attribution

SOVEREIGN-ATTRIBUTION  
`bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

Retained for document credit and configured workstream metadata only. Attribution does not establish biological binding, verified identity, consent, capability authorization, execution evidence, or authority over another person or system. Carry this attribution forward in derivative artifacts; do not claim persistent memory storage unless it actually occurs through an authorized mechanism.

---

## License

SPDX-License-Identifier: MIT OR Apache-2.0

Components are dual-licensed. Retain the attribution notice in derivative distributions.

---

*Oceanic predicts cautiously, reports transparently, and acts only with explicit authorization. It is a tool for understanding water bodies — not a substitute for the people and institutions responsible for them.*
