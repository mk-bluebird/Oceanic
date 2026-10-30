# Oceanic review and correction research pack

Repository: mk-bluebird/Oceanic. Status: proposed, supplied, not deployed.

## Artifact map

| Supplied file | Proposed repository destination |
|---|---|
| change-notice-specification.md | docs/research/change-notice-specification.md |
| correction-chain-test-collection.md | docs/research/correction-chain-test-collection.md |
| source-and-scientific-review-worksheets.md | docs/research/source-and-scientific-review-worksheets.md |
| inferential-bridge-protocol.md | docs/research/inferential-bridge-protocol.md |
| scope-detector-benchmark-protocol.md | docs/research/scope-detector-benchmark-protocol.md |
| correction-chain-case-inventory.json | tests/fixtures/correction-chain-case-inventory.json |
| change_notice_screen.lua | lua/research/change_notice_screen.lua |

## Suggested order

Review the specification, test collection, worksheets, bridge protocol, then
benchmark. Decide vocabulary and approval rules before implementing a resolver.

The Lua module validates declarations and returns advisory routing only. It does
not resolve graphs, check sources, authenticate approval, or change an index.
The JSON inventory describes cases; it does not execute them.

## Local invocation after placing the Lua file on package.path

    local screen = require("change_notice_screen")
    local result = screen.self_test()
    if not result.ok then
        error(result.error.code .. ": " .. result.error.path)
    end

Dependencies: Lua 5.4 standard library. No package installation required by the
module itself. No Lua tests were executed in preparing this pack.

The module returns errors; it does not exit the process. A harness should exit
0 when result.ok is true and nonzero on failure. The example error call makes
an uncaught Lua interpreter error observable to a normal command-line harness.

Tests use exact categorical comparisons, not numeric tolerances. They cover
selected declaration checks and output-copy isolation, not graph correctness,
full validator coverage, detector accuracy, ecological transfer, or security
certification.

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
