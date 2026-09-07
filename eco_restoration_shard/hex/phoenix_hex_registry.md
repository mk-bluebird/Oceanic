# Phoenix Hex Registry

## Purpose

This registry defines the local identifiers used by ecological-restoration
advisory examples. It is a software interoperability artifact, not a public
registry, certification system, land-rights record, person registry, or
location-verification service.

## Canonical anchor form

The example anchor form is:

`phx-local-hex-<resolution>-<row>-<column>`

Example:

`phx-local-hex-07-000042-000019`

The identifier is valid only when all of the following are present in the
associated evidence record:

- The spatial scheme version.
- The coordinate reference or reproducible geometry derivation.
- The declared resolution.
- A temporal validity interval.
- A positional uncertainty or distortion budget.
- A boundary-assignment rule.
- A provenance reference for the anchor derivation.

An anchor identifier alone is not evidence of geographic accuracy, ownership,
occupancy, personhood, eligibility, or an authoritative institutional boundary.

## Resolution compatibility

A record may be combined with another record only when:

1. Both use a registered anchor scheme and compatible version.
2. Their validity intervals overlap the advisory window.
3. Their relationship is identical-anchor, permitted parent-child, or an
   explicitly registered neighborhood relation.
4. The applicable domain permits aggregation at the requested resolution.
5. The estimated spatial uncertainty remains within the domain-specific budget.
6. The join does not disclose more precise location information than the
   stated purpose and consent scope permit.

## Privacy boundary

Do not publish raw anchor histories or precise observation timing when the
combination could expose a sensitive site, person, household, private
operation, or voluntary self-description. Use aggregate cells, coarser time
buckets, or locally retained records where necessary.
