# Karma Initialization Policy

## Purpose

This policy governs creation of an initial Karma value for contribution-scoped,
service-routing, or pilot-participation decisions.

Karma is not a measure of human worth, identity, health, augmentation status,
communication ability, institutional status, credibility, or eligibility.

## Default state

New records must use:

- `status: uninitialized`
- `karma_current: null`

No implementation may assign a fixed numeric Karma value solely because a new
identity record was created.

## Permitted evidence

A governance decision may consider only evidence relevant to its stated scope:

- Reproducible build, test, or formal-verification artifacts
- Verified artifact-integrity records
- Documented contribution-review outcomes
- Source provenance and correction history
- Explicitly consented, scope-limited operational commitments

## Prohibited evidence

A governance decision must not use:

- Identity, demographics, disability, health, augmentation, neural, biometric,
  physiological, or private companion-system information
- Communication style, grammar, pacing, assistive communication, metadata, or
  refusal to disclose information
- Unverified reputation claims or opaque automated inferences

## Decision requirements

An active or provisional numerical Karma decision requires:

- A versioned policy basis
- A stated purpose and narrow scope
- A reviewable evidence record
- At least two authorized governance approvals meeting the declared quorum
- Conflict-of-interest declarations
- A subject signature where the subject chooses to participate
- A correction and appeal route
- A future review date

## DID signature binding

The subject DID is a voluntary reference to a verification method authorized by
that DID's controlling account. The system must verify a signature over the
canonical decision payload before accepting a decision as bound to that DID.

The DID string alone is not identity proof, a credential, a ranking, a technical
assessment, or a claim of eligibility.

## Material changes

A new decision must supersede rather than overwrite an existing decision when
policy, evidence, score, purpose, scope, or approval status changes materially.
