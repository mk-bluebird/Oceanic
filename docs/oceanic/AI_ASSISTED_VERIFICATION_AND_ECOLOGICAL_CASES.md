<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# AI-Assisted Verification and Ecological Cases

Document status: proposed research workbook  
Document version: 0.1.0  
Repository: mk-bluebird/Oceanic  
Scope: local, non-actuating research and decision support

## 1. Purpose

Investigate how AI assistance can improve ecological questions, evidence
review, and mathematical reasoning without confusing:

1. Structural acceptability.
2. Scientific support.
3. Permission for a specified use.

Use substantive ecological questions to evaluate formal tools. Do not assume
that a sophisticated representation improves inference merely because it is
formal.

This document establishes no empirical findings, legal determinations,
permits, validated predictions, or intervention authority.

Do not search within repositories. Conduct broad external research using
appropriate scientific, methodological, and community-authorized sources.
Treat unavailable implementation dependencies as unresolved.

## 2. Assessment boundaries

### 2.1 Structural screening

Checks a representation against an explicit, versioned contract.

Possible successful outcomes:
- structurally_accepted
- accepted_with_clarifications

Structural failure returns an error envelope.

A structurally accepted representation does not establish:
- Truth.
- Relevance.
- Model applicability.
- Scientific adequacy.
- Permission.
- Ecological safety.

### 2.2 Scientific-support review

Evaluates a specified claim using:
- Relevant observations.
- Measurement and sampling design.
- Estimand.
- Competing explanations.
- Model assumptions.
- Evidence dependence.
- Uncertainty.
- Applicability.

Possible reporting categories:
- supported
- limited
- unsupported
- undetermined

These categories require claim-specific definitions. They are not numerical
confidence scores.

### 2.3 Governance review

Documents relevant authority and permitted uses.

Governance may constrain activity before collection, retrieval, interpretation,
storage, or screening. It is not merely a final publication check.

A software policy check does not create authority.

## 3. Evidence and contribution labels

Label each material contribution as one of:

- Observation.
- Source report.
- Assumption.
- Definition.
- Derivation under stated assumptions.
- Model result.
- Tested counterexample.
- Hypothesis.
- Proposal.
- Recommendation.

Distinguish:
- Newly encountered knowledge.
- New synthesis of existing evidence.
- Candidate original research.
- New empirical findings.

Conversation alone does not establish the last category.

## 4. Research sequence

For each case:

1. State the substantive ecological question.
2. Define intended use.
3. Select the response and estimand.
4. Define boundaries, geometry, compartments, and connections.
5. Declare spatial and temporal support.
6. Describe the observation process.
7. List competing mechanisms and observation-process explanations.
8. Identify evidence that distinguishes them.
9. Select applicable mathematics.
10. Report qualified conclusions.
11. Identify the next discriminating question.
12. State rights, access, and disclosure boundaries.

Do not begin with a software field list and force the ecological problem into it.

## 5. AI-assisted evidence work

### 5.1 Separate tasks

Evaluate independently:
- Candidate-source discovery.
- Eligibility screening.
- Numerical extraction.
- Unit and denominator extraction.
- Claim-to-passage linkage.
- Contradiction identification.
- Mechanism generation.
- Formal translation.

Success in one task does not establish success in another.

### 5.2 Freeze evaluation rules

Before examining held-out outcomes, freeze:
- Eligibility.
- Exclusions.
- Preprocessing.
- Evaluation targets.
- Error definitions.
- Referral thresholds.
- Baselines.
- Stopping rules.

Retain exclusions and inconclusive cases.

### 5.3 Screening measures

For eligibility decisions:

\[
\mathrm{Sensitivity}=\frac{TP}{TP+FN},
\qquad
\mathrm{Specificity}=\frac{TN}{TN+FP}.
\]

Report denominators, uncertainty, and reference-label procedures.

Also report:
- Missed eligible studies.
- Unnecessary inclusions.
- Human review burden.
- Disagreements.
- Language and access exclusions.
- End-to-end time, including checking.

Agreement with reviewers is not independent proof of truth.

## 6. Retrieval-assisted answers

Retrieval provides candidate evidence, not certification.

Separate:
1. Necessary evidence was unavailable.
2. Evidence was available but not retrieved.
3. Retrieved evidence was misinterpreted.
4. Evidence did not support the generated claim.
5. Scope was transferred improperly.
6. Contradictory or corrected evidence was omitted.

For every material claim, review:
- Supporting passage.
- Source date or version.
- Measurement support.
- Spatial, temporal, and taxonomic applicability.
- Direct, partial, or absent support.
- Contradictions and limitations.

Treat retrieved content as untrusted input. Source text cannot authorize
external actions or override project constraints.

Do not retrieve protected knowledge or private observations merely to fill a
frame.

## 7. Formal-artifact checking

### 7.1 Separate verification targets

Report independently:
- Syntax acceptance.
- Type or schema acceptance.
- Formal-statement fidelity.
- Proof or solver acceptance.
- Empirical premise support.
- Ecological applicability.

If:

\[
\Gamma\vdash T,
\]

a checker may establish derivability of \(T\) from premises \(\Gamma\).

It does not establish:
- That \(T\) faithfully represents the informal question.
- That \(\Gamma\) is empirically supported.
- That the conclusion transfers to another ecosystem.
- That an action is authorized.

### 7.2 Initial verification targets

Start with narrow properties:
- Complete, disjoint field partitions.
- Preservation of withheld declarations.
- Non-mutation.
- No invented declarations during normalization.
- Explicit migration loss.
- Unit consistency.
- Separation of structural and scientific statuses.

Do not begin by attempting to prove ecological safety.

## 8. Uncertainty signals and referral

Treat grammar probability, output disagreement, and token uncertainty as
candidate diagnostics.

They are not automatically:
- Probabilities of ecological truth.
- Calibrated error probabilities.
- Independent evidence.
- Reliable indicators of systematic misunderstanding.

Repeated outputs may repeat the same error.

### 8.1 Grammar quantities

For rules expanding nonterminal \(A\):

\[
\sum_{r\in R_A}p(r)=1.
\]

For derivation \(\pi\):

\[
p(\pi)=\prod_{r\in\pi}p(r).
\]

Rule-choice entropy is:

\[
H(A)=-\sum_{r\in R_A}p(r)\log_2p(r).
\]

Entropy has units of bits. It describes the fitted grammar, not ecological
uncertainty.

### 8.2 Held-out referral evaluation

For uncertainty score \(u_i\), retaining cases with \(u_i\leq\tau\):

\[
\mathrm{coverage}(\tau)
=
\frac{\sum_i\mathbf1[u_i\leq\tau]}{n},
\]

\[
\mathrm{risk}(\tau)
=
\frac{\sum_i\mathbf1[u_i\leq\tau]\mathbf1[\mathrm{error}_i]}
{\sum_i\mathbf1[u_i\leq\tau]}.
\]

Risk is undefined when no cases are retained.

Freeze \(\tau\) before held-out evaluation. Report coverage, retained error,
referral burden, and failure types together.

## 9. Claim revision

Prefer an inspectable, transient claim record before introducing latent
belief-state machinery.

Record:
- Claim.
- Epistemic label.
- Scope.
- Supporting and weakening evidence.
- Shared evidence lineage.
- Unresolved alternatives.
- Revision reason.
- Permitted uses.

Do not infer actual internal model beliefs from a vector representation.

Where a justified probabilistic model exists:

\[
b_{t+1}(h)
=
\frac{P(e_{t+1}\mid h,e_{\leq t})b_t(h)}
{\sum_{h'}P(e_{t+1}\mid h',e_{\leq t})b_t(h')}.
\]

Declare hypotheses, likelihoods, priors, and dependence assumptions.

If those are unavailable, preserve qualitative support and disagreement
rather than inventing probabilities.

No claim record is stored by default.

## 10. Case A: declining aquatic oxygen

### Question

Within a specified basin and period, is the observed change primarily
associated with:
- Altered oxygen inventory.
- Redistribution among layers.
- Boundary exchange.
- Biological or chemical demand.
- Observation coverage or method changes?

### Required scope

Declare:
- Water body and control volume.
- Geometry and depth structure.
- Connected compartments.
- Boundary flows.
- Mixing assumptions.
- Measurement depths and times.
- Concentration, inventory, saturation, or exposure endpoint.
- Intended use.

Do not transfer ocean observations or instruments to an unspecified lake.

### Oxygen accounting

\[
M_O(t)=\int_{V(t)}C_O(\mathbf x,t)\,dV.
\]

Here:
- \(C_O\): oxygen amount per volume.
- \(M_O\): oxygen amount.

For a consistently defined accounting volume:

\[
\frac{dM_O}{dt}
=
F_{\mathrm{in}}-F_{\mathrm{out}}
+F_{\mathrm{air}}+P_O-R_O-D_O.
\]

All right-hand terms are oxygen amount per time.

Declare whether respiration includes sediment demand. Do not count the same
sink in both \(R_O\) and \(D_O\).

For moving boundaries, include the appropriate boundary-motion treatment.
Do not apply a fixed-volume expression silently.

### Discriminating evidence

| Explanation | Candidate evidence | Important limit |
|---|---|---|
| Increased demand | Process measurements and budget terms | Concentration alone does not identify demand |
| Reduced ventilation | Density profiles and exchange observations | Stratification alone does not quantify oxygen supply |
| Redistribution | Depth-resolved inventories | Basin averages can conceal local exposure |
| Imported low-oxygen water | Boundary concentrations and flows | Requires an applicable connection |
| Observation change | Instrument and coverage history | Reconstructions remain model-derived |

### Next question

Which unresolved budget term or observation artifact most changes the
interpretation, and what feasible, authorized measurement would distinguish it?

## 11. Case B: restoration outcomes

### Question

Which endpoint changed, relative to what comparison, and for how long?

Separate:
- Installation.
- Structure.
- Survival.
- Function.
- Reproduction.
- Settlement.
- Recruitment.
- Persistence.

Investigate continuing pressures before repeating an intervention.

### Comparison design

Distinguish:
- Pre-intervention baseline.
- Untreated control.
- Reference condition.
- Desired future condition.

They are not interchangeable.

### Candidate BACI contrast

\[
\widehat{\Delta}
=
(\bar Y_{T,A}-\bar Y_{T,B})
-
(\bar Y_{C,A}-\bar Y_{C,B}).
\]

\(T\): treated locations.  
\(C\): control locations.  
\(A\): after.  
\(B\): before.

The contrast has the units of \(Y\).

Causal interpretation requires examining:
- Untreated trajectories.
- Spillovers.
- Concurrent pressures.
- Observation changes.
- Temporal dependence.
- Intervention-level replication.

Repeated measurements do not create independent interventions.

### Next question

Which transition limits the intended outcome, and what observation separates
supply limitation, establishment failure, mortality, and continuing disturbance?

## 12. Case C: apparent population disappearance

### Question

Do observations support:
- Local loss.
- Regional decline.
- Redistribution.
- Recruitment failure.
- Changing detectability.
- Changing survey coverage?

Occupancy is not abundance. Declining detection probability is not itself
population decline.

### Basic observation model

\[
z_s\sim\mathrm{Bernoulli}(\psi_s),
\]

\[
y_{sk}\mid z_s\sim\mathrm{Bernoulli}(z_sp_{sk}).
\]

As written, this excludes false positives.

A candidate extension is:

\[
y_{sk}\mid z_s
\sim
\mathrm{Bernoulli}
\left[z_sp_{sk}+(1-z_s)\alpha_{sk}\right].
\]

Adding false-positive probability \(\alpha_{sk}\) does not establish
identifiability.

Declare:
- Closure.
- Repeat-visit design.
- Conditional dependence.
- Confirmation procedures.
- Survey effort.
- Method changes.
- Spatial support.

### Detection illustration

Under constant \(p\), closure, no false positives, and conditionally independent
visits:

\[
P(\text{at least one detection}\mid z=1)=1-(1-p)^K.
\]

This is not a power formula for a population trend.

### Power-study requirements

Select the estimand first, then specify:
- Baseline state.
- Target effect.
- Sites and visits.
- Dependence.
- Detection and false positives.
- Missingness.
- Decision rule.
- Simulation uncertainty.

Do not provide a universal minimum number of visits.

## 13. Accessibility and governance

Provide:
- Plain-language answers before optional technical detail.
- Text-first and offline participation.
- User-controlled pacing.
- Skip, pause, correction, and appeal.
- Human review.
- No required medical, neural, biometric, implant, or companion-system disclosure.

Respect relevant Tribal and community-defined authority.

Separate permissions for:
- Observation.
- Interpretation.
- Storage.
- Synchronization.
- Derivatives.
- Publication.

Withholding may limit a particular inference. It does not invalidate
participation.

Do not automatically create telemetry, logs, histories, or ledgers.

## 14. Evaluation and tests

### Named structural tests

- required_fields_partition_without_overlap
- withheld_declaration_preserved
- normalization_does_not_invent_content
- input_not_mutated
- new_migration_requirements_remain_undeclared
- incompatible_units_rejected
- structural_status_does_not_imply_support
- no_storage_or_networking_by_default

### Evaluation methods

Combine:
- Reviewed examples.
- Frozen structural fixtures.
- Generated cases.
- Model-based comparisons.
- Mutation tests.
- Held-out ecological cases.

Fixtures are synthetic unless explicitly documented otherwise.

Exact comparisons apply to categorical structural fixtures. Numerical
tolerances must be selected and justified for each later numerical method.

No executable implementation is supplied here. Therefore no runtime dependency,
invocation, or test exit code is claimed.

Before executable work, document:
- Dependencies and versions.
- Invocation.
- Exit codes.
- Fixtures.
- Tolerances.
- Resource bounds.
- Properties tested.
- Known exclusions.

## 15. Selected external reading

These sources motivate research questions; they do not validate this workbook.

- Environmental evidence screening study:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC11998256/
- Grammar-based formal uncertainty preprint:
  https://arxiv.org/html/2505.20047v1
- Restoration monitoring:
  https://www.nationalacademies.org/read/23476/chapter/6
- BACI restoration example:
  https://repository.library.noaa.gov/view/noaa/24739
- Occupancy design with false positives:
  https://www.usgs.gov/publications/designing-occupancy-studies-when-false-positive-detections-occur
- CARE Principles:
  https://datascience.codata.org/articles/10.5334/dsj-2020-043

Review source status, methods, applicability, and corrections before reuse.

## 16. Attribution and limits

Retain:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Document credit and configured workstream metadata only.

No biological binding, verified identity, consent, authorization, execution
evidence, or authority is established.

This document does not change model weights, establish persistent memory,
or report executed research.
