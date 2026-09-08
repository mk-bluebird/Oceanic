# kersafety-prover

## Status

Proposed local definition and verification component.

## Purpose

`kersafety-prover` contains bounded Kani proof harnesses for the K-E-R scoring kernel. It produces a JSON report recording whether the configured proof harnesses passed in the executing environment.

## K-E-R semantics

- `E`: bounded evidence input on the inclusive fixed-point interval `[0, 10000]`.
- `R`: bounded risk input on the inclusive fixed-point interval `[0, 10000]`.
- `K`: fixed-point score `floor(E × (10000 - R) / 10000)` on `[0, 10000]`.

Inputs greater than `10000` saturate to `10000`.

## Invariants

- K is bounded between zero and one fixed-point unit.
- K is monotone non-decreasing in E when R is fixed.
- K is monotone non-increasing in R when E is fixed.
- E and R saturation behavior is explicit and deterministic.
- Raising E while lowering R cannot lower K.

## Provenance anchor

The report records the supplied Bostrom DID anchor as a provenance label:

`bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

This anchor is not a public identity assertion, identity verification result, credential, rank, eligibility condition, or technical attestation.

## Verification boundary

A passing Kani run proves the declared harness properties for the compiled model and verification configuration. It does not prove correctness of external data sources, operational governance, or any real-world environmental, institutional, personal, or system claim.
