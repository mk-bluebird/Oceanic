# Eco Restoration Shard

This directory contains offline-first, advisory-only ecological-restoration
artifacts. Components analyze bounded evidence, generate reviewable summaries,
and support human decision-making. They do not operate equipment, control
physical systems, initiate external actions, assert regulatory compliance, or
infer personal identity, health, augmentation, eligibility, or credibility.

## Directory map

| Directory | Purpose |
|---|---|
| `hex/` | Phoenix local hex-anchor documentation and compatibility rules |
| `biodegradation/` | Material-evidence readiness examples and shared test fixtures |
| `governance/` | KER, FOG, consent, retention, review, and non-interference artifacts |
| `water/` | Water-quality and hydrology advisory models |
| `soil/` | Sediment, soil-function, and carbon-pool advisory models |
| `infrastructure/` | Offline telemetry and efficiency evidence models |
| `community/` | Participatory monitoring, accessibility, burden, and benefit workflows |

## Local verification

Run language-specific compilers and interpreters locally, then compare each
implementation against the JSON fixtures in `tests/fixtures/biodegradation/`.

All implementations must preserve:

- Normalized finite values in the closed interval from 0.0 to 1.0.
- Non-compensating risk withholding.
- Source, parameter, consent, and retention eligibility checks.
- Plain-language withheld or informational status.
- No hardware, network, actuator, or external-action capability.
