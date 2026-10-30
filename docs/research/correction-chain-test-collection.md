# Correction-chain test collection

Filename: correction-chain-test-collection.md
Destination: docs/research/correction-chain-test-collection.md

## Build summary

Define synthetic behavioral tests for a future correction resolver. These are
acceptance fixtures, not claims about actual studies or executed tests.
The supplied Lua notice screen does not implement graph resolution.

## Cases and expected behavior

| Named case | Synthetic change chain | Required behavior |
|---|---|---|
| partial_effect_measure | Tissue hazard was summarized as colony risk; corrected field and summary supplied | Prefer corrected unit and measure; preserve unaffected date; review derivatives |
| correction_of_correction | First correction gives neighboring-tissue estimate 1.6; next corrects it to 1.5 | Use 1.5 only after applicable review; preserve both change notices |
| concurrent_interpretations | Two explanations use the same observations | Keep both scoped interpretations; no implicit supersession |
| criterion_not_recovery | Reference threshold changes while observations do not | Report rule-driven classification change, not recovery |
| new_period_not_replacement | New survey covers a later season | Preserve the earlier observation for its historical period |
| overlapping_approved_branches | Two approved changes disagree on the same estimate | Return unresolved_branch; no latest-timestamp tie-break |
| disjoint_partial_branches | Independent corrections affect date and effect measure | Combine only after checking context consistency and dependencies |
| cyclic_changes | Version A replaces B and B replaces A | Return graph_error; do not select current support |
| source_concern | A concern notice appears; reliability unresolved | Add concern context and review routing; do not label false automatically |
| withdrawal_with_unaffected_data | Interpretation withdrawn, original measurement retained | Do not retrieve interpretation as support; retain eligible unaffected observation |
| protected_history | Superseded text contains sensitive locations | Apply retention and access rules to history, notices, logs, and exports |
| unresolved_proposal | A proposed correction lacks approved evidence review | Show the review issue; do not silently adopt replacement |

All numeric values here are synthetic fixture content.

## Harness contract

Before running tests, freeze resolver version, notice contract, permissions,
applicability rules, graph inputs, expected outputs, and tie handling.

Report each case as passed, failed, not run, or inconclusive with a reason.
Do not average away a cycle, privacy, or branch-resolution failure with many
simple successful cases. Retain failed cases and investigation notes under the
applicable access and retention policy.

## Mutation and scope tests

Repeat with notices in different input orders. Current-support results should
not depend on iteration order. Diagnostic source positions may differ if that
behavior is explicitly documented.

Test both a present-day query and a historical query against the same graph.
Test missing targets, invalid versions, unknown kinds, and unapproved notices.
The JSON companion contains a machine-readable case inventory, not executable
graph payloads or empirical ground truth.

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
