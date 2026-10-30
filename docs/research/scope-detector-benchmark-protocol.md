# Study-grouped scope-detector benchmark

Filename: scope-detector-benchmark-protocol.md
Destination: docs/research/scope-detector-benchmark-protocol.md

## Build summary

Evaluate structured screening, semantic assistance, and human review against a
frozen adjudicated claim set. This is not an executed benchmark.

## Estimand and evaluation unit

Target: detection of unsupported claim expansion for a declared use.
Unit scored: claim-source-use packet. Also report source-study counts, because
multiple packets from one study are not independent replications.

## Dataset and labels

Include actual-style errors, valid inferential bridges, faithful narrow claims,
missing methods, incomplete source access, and ambiguous cases.
Use only approved public or appropriately governed material. Restricted-data
behavior should use synthetic fixtures rather than protected real locations.

Adjudicated labels:
- unsupported_expansion
- supported_within_scope
- unresolved

Detector actions:
- flag_for_review
- no_flag
- abstain

Keep adjudicated unresolved packets in the report. Do not relabel them as
negative examples merely to make a binary score possible.

## Splitting

Group all excerpts, revisions, and paraphrases from the same underlying study
in one split. Track shared datasets and research programs that could connect
nominally different publications. Use development data for thresholds and
prompts; keep evaluation studies untouched. Freeze extraction, vocabulary,
model configuration, prompts, and retrieval sources before evaluation.

## Comparators

- Human-only review.
- Structured mismatch screen.
- Semantic assistant with cited evidence and abstention.
- Human review assisted by the structured or semantic screen.

The change-notice screen supplied in this package is not the scope detector.
Evaluate the earlier scope screen only after its contract is separately frozen.

## Metrics

For resolved labels and non-abstained outputs, define TP, FP, FN, and TN.
Report precision TP/(TP+FP) and conditional recall TP/(TP+FN), with undefined
states when denominators are zero. Also report all positive cases and positive
abstentions; end-to-end detected-positive coverage is TP/(all adjudicated
unsupported cases), so abstention cannot silently inflate apparent recall.

Report abstention fraction, no-flag errors, reviewer disagreement, source-access
coverage, and performance by mismatch dimension. For an assisted workflow,
score final human decisions separately from the assistant's raw outputs.

Use study-cluster-aware uncertainty analyses where justified. Predeclare the
method and retain unsuccessful runs. No fixed sample count or performance
threshold is asserted here; select them from the intended error consequences
and desired precision before seeing held-out outcomes.

## Reviewer cost

Record setup, evidence retrieval, review, correction, and adjudication time
separately. Compute labor cost from time and declared rates without collecting
unnecessary personal information. Compare errors detected and errors missed,
not cost per flag alone. A cheap but indiscriminate flagger can increase total
review burden.

## Acceptance and falsification

Predefine minimum useful detection, maximum false-review burden, coverage,
and privacy boundaries. A detector is not operationally supported merely
because it beats a random flagger. Compare against the useful human and simple
structured baselines. No-flag is never a scientific approval.

Report supported_within_test_scope, evidence_against_intended_use, or
inconclusive. Later revisions require new versions and new untouched tests.

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
