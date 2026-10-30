# Operational inferential-bridge protocol

Filename: inferential-bridge-protocol.md
Destination: docs/research/inferential-bridge-protocol.md

## Build summary

Determine what evidence is required when a claim differs from its source's
analysis unit, outcome, effect measure, population, or time support.
A bridge declaration is not verification. This is a proposed review method.

## Required representation

Record separately:

- Observational unit and measurement procedure.
- Treatment-assignment unit, if relevant.
- Analysis unit and dependence structure.
- Target population and sampling frame.
- Outcome, units, denominator, and effect measure.
- Spatial and temporal support.
- Source analysis versus intended claim.
- Bridge type, supporting analysis, assumptions, and limitations.

No universal tissue-to-colony-to-population rank is assumed.

## Review procedure

1. Freeze the intended estimand and exact claim.
2. Verify source fields and evidence locations.
3. Identify each changed dimension; also inspect unchanged text for ambiguity.
4. Classify the proposed bridge: model-based aggregation, design-based
   generalization, effect-measure conversion, temporal transfer, spatial
   transfer, or unresolved.
5. Examine the specific design, equations, uncertainty propagation, and
   applicability supporting that bridge.
6. Record supported_within_scope, unsupported, or unresolved for each bridge.
7. Retain the source claim if the broader one is not supported.
8. Obtain separate release approval if publication is proposed.

## Synthetic worked cases

| Case | Assessment |
|---|---|
| Tissue-death hazard ratio described as whole-colony risk ratio | Unsupported without an explicit outcome model and conversion; wording substitution is not a bridge |
| Tissue measurements analyzed in a documented hierarchical model for a specified colony outcome | Potentially supported after reviewing model, colony endpoint, dependence, and uncertainty; not automatically invalid |
| Representative colony sample used to estimate a declared population quantity | Potentially supported by the design and analysis; review sampling frame and inclusion probabilities or modeling assumptions |
| Many tissue regions from one colony described as many independent colonies | Unsupported replication claim |
| A hazard ratio converted to horizon-specific risk using a supported survival model and baseline hazard | Potentially supported; baseline risk, horizon, competing events, assumptions, and uncertainty must be explicit |
| A survey-site estimate applied to every reef in a region | Unresolved or unsupported without transfer evidence |
| Matching field labels with a different denominator hidden in prose | Possible semantic mismatch; mechanical label equality does not clear review |

These are conditional assessment examples, not validation of any named study.

## Mapping source-reported functional extinction

Preserve the original role-based definition and attribution. For each proposed
Oceanic function assessment, independently check function, geographic scope,
reference, threshold, duration, and observation rule. A source label does not
satisfy missing criteria. Recruitment detection does not alone restore a
reef-building role. No irreversible ecosystem-death verdict follows.

## Review artifact

Record the supported narrower claim, excluded broader claim, evidence needed,
and uncertainty. Prefer a narrower answer when it satisfies the question
without requiring sensitive information. Human correction and appeal remain
available; no automatic intervention or adverse participation decision follows.

## Status, source basis, and rights

Version: 0.1.0. Date: 2026-10-30. Status: proposed, awaiting human review.
Repository: mk-bluebird/Oceanic.

This artifact is derived from the supplied conversation. External sources were
not re-fetched for its preparation. Examples and fixtures are synthetic research
designs, not ecological observations. No repository state, executed Lua tests,
scientific validation, or deployment is asserted. File creation in this response
is separate from an external repository write.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Credit and configured metadata only; not identity verification, consent,
authorization, execution evidence, or authority. No persistent assistant memory
is claimed.

Observation, interpretation, review, storage, synchronization, indexing, and
publication require separate applicable permissions. Do not include sensitive
habitat locations, raw protected observations, private participant details, or
protected knowledge in unrestricted artifacts. Review history and backups as
well as current files. Respect relevant Tribal and community-defined authority.
Provide text-first, offline review where feasible, flexible pacing, correction,
and appeal. No physiological or companion-system disclosure is required.
