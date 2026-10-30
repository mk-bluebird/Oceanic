# Oceanic Research Discoverability Plan

Version: 0.1.0
Document date: 2026-10-30
Status: Proposed; awaiting human review
Repository: mk-bluebird/Oceanic
Intended path: docs/research/research-discoverability-plan.md

## Build summary

This document specifies a small, permission-aware research catalogue and a
fixed evaluation protocol for AI-chat retrieval.

The initial pilot contains five corrected Day 1 research entries. Its purpose
is to test whether an assistant can retrieve relevant evidence while preserving
geography, units, methods, uncertainty, correction history, and release limits.

This is a supplied specification, not an implemented system. It does not
establish that a scheduled job was changed, sources were independently
reverified during document preparation, catalogue files were created, or any
retrieval pipeline was executed, tested, validated, or deployed.

## Attribution

Configured attribution:

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

This attribution is retained for credit and configured project metadata only.
It does not establish identity verification, biological binding, consent,
authorization, execution evidence, or authority over another person or system.

## 1. Purpose and scope

### 1.1 Research purpose

Make reviewed aquatic research easier to:

- Find through plain-language and technical questions.
- Interpret without losing the scope of the underlying evidence.
- Trace to publications, source reports, and review decisions.
- Correct without leaving superseded claims as default answers.
- Use through accessible, text-first, and offline workflows.
- Withhold from indexing or publication when permissions require it.

### 1.2 Pilot scope

The pilot covers:

- Florida Acropora mortality and source-reported functional extinction.
- Northern Gulf of Mexico midsummer hypoxia.
- Tissue-level disease associations during a Florida Keys bleaching event.
- Caribbean coral-reef ecosystem-risk assessment.
- Initial offshore biogeochemical float observations reported for USVI waters.

The selected reef region and adjacent Gulf region are comparison regions.
No experimental control design is documented.

The rotation's seven-day nonrepeat rule is a user-declared scheduling
constraint. This document does not audit compliance with that rule.

### 1.3 Non-goals

This plan does not:

- Authorize ecological interventions or hardware actions.
- Provide permits, legal determinations, or verified ecological predictions.
- Adopt functional depletion as an Oceanic screen state.
- Validate an operational early-warning indicator.
- Establish that a publication's conclusions transfer to other sites or events.
- Authorize collection, storage, synchronization, or publication.
- Require neural, biometric, medical, implant, or companion-system disclosure.
- Rank the intrinsic worth of species or participants.

## 2. Evidence and provenance conventions

### 2.1 Preparation basis

Pilot content is derived from the corrected Day 1 digest and associated review
provided in the conversation.

Bibliographic links are research locators carried forward from that material.
Their presence does not mean every destination was independently checked during
preparation of this document.

Before promoting a card to source-verified status, a reviewer must examine the
relevant source passage, confirm the bibliographic metadata, and record the
review date.

### 2.2 Separate evidence categories

Each claim must distinguish the following categories where applicable:

- Observation: a measurement or documented event.
- Source report: a statement attributed to an institution or publication.
- Statistical estimate: a quantity estimated through an explicit analysis.
- Derivation: a quantity calculated from declared inputs and assumptions.
- Interpretation: an ecological meaning assigned to evidence.
- Model projection: an outcome conditional on a model and scenario.
- Hypothesis: a testable proposition not established by the current evidence.
- Proposal: a suggested definition, method, or action.
- Recommendation: decision support with an explicit basis and limits.

A card may contain multiple categories. They must not be merged into a single
undifferentiated evidence label.

### 2.3 Missingness vocabulary

Use these states distinctly:

| State | Meaning |
|---|---|
| Missing | An expected value is absent from the available record |
| Unknown | The available evidence does not establish the value or state |
| Not collected | The relevant observation was not collected |
| Not surveyed | The stated survey was not performed for the question |
| Surveyed but not detected | An observation effort occurred without detection |
| Withheld | Information exists but is intentionally not disclosed |
| Not applicable | The field does not apply |
| Zero | A supported numerical value of zero under a stated method |

Do not replace any of the first seven states with zero.

### 2.4 Observation support

Record the spatial and temporal support of every measurement.

Where modeling depends on them, specify:

- Habitat and water-body boundaries.
- Geometry, depth, and relevant storage.
- Exchange pathways and mixing assumptions.
- Observation coverage.
- Exposure duration and sampling frequency.

Net storage flow must not be labeled water exchange. Basin averages must not
be used to establish local safety.

## 3. Catalogue organization

### 3.1 Initial representation

The pilot evidence cards are embedded in this document.

No separate catalogue files are claimed to exist. If approved, a later step
may produce equivalent Markdown and JSON or CSV representations.

Use descriptive names, relative paths, and versions for internal navigation.
Do not introduce opaque object identifiers or object-number schemes.

### 3.2 Human and machine views

A future implementation should maintain:

1. A human-readable summary with adjacent qualifications.
2. A structured representation of the same reviewed content.
3. A source-location record sufficient to check the claim.

A structured export must not silently omit limitations, review status, or
release restrictions.

Do not duplicate full copyrighted source text merely to improve retrieval.
Retain permitted excerpts or precise source locations as appropriate.

### 3.3 Minimum retrieval unit

Retrieve a bounded claim together with:

- Geographic and temporal scope.
- Evidence category.
- Unit of analysis and effect measure, where applicable.
- Important limitations.
- Review and correction status.
- Source attribution.
- Applicable release conditions.

Do not retrieve an isolated number when its interpretation depends on nearby
qualifications.

## 4. Evidence-card fields

| Field | Required content |
|---|---|
| Descriptive name | Human-readable name for the research claim |
| Version | Version of the reviewed card |
| Research question | The question the evidence addresses |
| Supported claim | A bounded statement, not a headline alone |
| Evidence components | Observation, estimate, interpretation, projection, or other categories |
| Ecological scope | Species, habitat, water body, and population scope |
| Spatial support | Survey boundary, depth, and coverage when known |
| Temporal support | Observation period, exposure period, and relevant follow-up |
| Method | Sampling and analysis methods, or explicit unknown status |
| Quantity and units | Measured or estimated quantities and units |
| Unit of analysis | Tissue, colony, population, region, profile, or other stated unit |
| Comparison | Reference group, baseline, or scenario |
| Uncertainty | Intervals and uncertainty sources when available |
| Detection and missingness | Effort, detection limits, censoring, exclusions, and missing states |
| Source trail | Primary publication and secondary reporting separately |
| Source location | Relevant abstract, section, table, figure, or other locator |
| Dates | Observation, publication, review, and version dates separately |
| Applicability | Where the claim may and may not be used |
| Correction history | Superseded wording and reason for correction |
| Related questions | Follow-up questions and competing interpretations |
| Review status | Draft, reviewed, unresolved, superseded, or withdrawn |
| Release permissions | Separate storage, indexing, sync, and publication decisions |
| Attribution | Credit without implying consent or authority |

Unknown fields must remain explicitly unknown. Schema completeness is not
source verification, scientific validity, or release authorization.

## 5. Glossary and search rules

| Term | Catalogue meaning and retrieval rule |
|---|---|
| Functional extinction | Preserve the source's scope and definition; do not translate into zero surviving individuals |
| Functional depletion | Proposed function-specific assessment; not adopted as a screen state |
| Mortality proportion | A proportion dying over a specified period and denominator |
| Hazard ratio | A ratio of modeled instantaneous event hazards; not a cumulative mortality risk ratio |
| Risk ratio | A ratio of event probabilities over a specified period |
| Tissue | A within-colony unit; do not upgrade to colony-level evidence |
| Colony | A distinct analytical unit; do not upgrade to population-level evidence |
| Recruitment | Preserve the study's operational definition and life stage |
| Recovery | Specify whether activity, structure, function, reproduction, recruitment, or persistence is meant |
| Critically Endangered | An assessment category; not a synonym for observed collapse |
| Hypoxic footprint | Area meeting a stated oxygen criterion during a stated survey |
| Candidate precursor | A proposed indicator requiring validation; not an operational warning |
| First reported observation | An attributed historical claim whose scope must be retained |
| Comparison region | A region used for comparison without implying an experimental control |
| Control | Use only when an actual control design is documented |

Search aliases may connect common and scientific names, abbreviations, and
alternative phrasing. Aliases must not erase distinctions.

Examples:

- Link elkhorn coral with Acropora palmata.
- Link staghorn coral with Acropora cervicornis.
- Link Gulf dead zone with northern Gulf hypoxia.
- Relate functional extinction and functional depletion without treating them
  as synonyms.
- Relate recruitment and recovery without treating detection as recovery.
- Relate mortality risk and hazard while preserving their different meanings.

## 6. Review and correction handling

### 6.1 Workflow

1. Draft the claim from an identified source.
2. Resolve scope, units, evidence categories, and important unknowns.
3. Check the relevant source passage.
4. Complete scientific and release review separately.
5. Approve a version for a specified use.
6. Index only material approved for that index.
7. Re-review when corrections or new evidence materially affect the claim.

### 6.2 Correction rules

When correcting a claim:

- Preserve a concise description of the prior error.
- Explain what changed and why.
- Make the corrected version the default retrieval target.
- Mark the old version as superseded or withdrawn.
- Update every authorized representation and derived summary.
- Evaluate whether prior releases require a correction notice.
- Retain uncertainty when a discrepancy cannot be resolved.

Do not rewrite an old claim without making the correction visible.

Do not retain sensitive withdrawn content in unrestricted history merely for
audit convenience. Review history, logs, backups, and prior exports under the
applicable retention and remedy rules.

### 6.3 Retrieval behavior

A normal research answer should prioritize the latest approved applicable
version, not simply the most recent timestamp.

A correction-history query may retrieve superseded material, but must label it
and include the corrected interpretation.

## 7. Rights and release boundaries

### 7.1 Separate permissions

The following decisions are independent:

- Observation or collection.
- Interpretation.
- Human review.
- Local storage.
- Search indexing.
- Synchronization.
- Publication.
- Derivative use.

Approval for one does not imply approval for another.

Public availability, low apparent sensitivity, attribution, or schema validity
does not authorize redistribution.

### 7.2 Default boundaries

Keep the following out of general summaries and unrestricted indexes:

- Sensitive remnant-colony locations.
- Restricted raw observations.
- Private participant details.
- Protected community or Tribal knowledge.
- Information withheld under source or community conditions.

Aggregation does not guarantee anonymity.

Where relevant, follow Tribal and community-defined authority over purpose,
access, interpretation, attribution, retention, benefits, derivatives,
publication, and remedy. Not recording knowledge is a valid outcome.

### 7.3 Public and restricted views

Release review must occur before material enters an unrestricted index.

Do not depend solely on a chat assistant to conceal sensitive material after
retrieval. A public view should contain only approved content.

This document does not claim that separate indexes or enforceable access
controls have been implemented.

### 7.4 Accessible participation

Provide:

- Plain-language summaries.
- Text-first navigation.
- Offline review where feasible.
- Optional technical detail.
- Human correction and appeal.
- Flexible pacing without inferring reduced competence.

No participant must disclose neural, biometric, medical, implant, or companion
system information to participate.

## 8. Pilot catalogue

All five cards have the following shared preparation status:

- Basis: corrected Day 1 digest and review in the conversation.
- Independent source verification during this document preparation: not performed.
- Review date for this document: 2026-10-30.
- Repository insertion: not performed.
- Retrieval testing: not performed.
- Public-release approval: not established.
- Sensitive coordinates: excluded.

### Florida Acropora mortality and functional interpretation

Version: 0.1.0

Research question:
What mortality was reported following the 2023 heatwave, and how did the study
authors interpret its ecological significance?

Supported claim:
Reported colony mortality reached 97.8–100% in the Florida Keys and Dry
Tortugas, compared with 37.9% offshore southeast Florida. The study authors
characterize the losses, together with preceding depletion, as functional
extinction of elkhorn and staghorn corals from Florida's Coral Reef.

Evidence components:

- Colony mortality: reported observational result.
- Functional extinction: source-reported ecological interpretation.
- Reproductive status of every surviving remnant: not established here.

Ecological scope:
Acropora palmata and Acropora cervicornis on Florida's Coral Reef.

Spatial support:
Keys and Dry Tortugas mortality must remain distinct from offshore southeast
Florida mortality. Detailed site coverage is not extracted in this pilot.

Temporal support:
2023 heatwave. Exact survey dates and follow-up period require source extraction.

Unit of analysis:
Coral colonies.

Quantity and units:
Mortality percentages.

Method:
Detailed sampling and denominator definitions require primary-source extraction.

Primary source:
Manzello et al., Science, published 2025-10-23.
DOI: 10.1126/science.adx7825
https://www.science.org/doi/10.1126/science.adx7825

Secondary explanation:
Perry Institute explanatory article; not the primary paper.
https://www.perryinstitute.org/florida-coral-functional-extinction-science-study/

Source location:
Primary abstract, as reported in the conversation. Full methods and supporting
tables remain to be reviewed for this catalogue.

Limitations:

- Do not generalize near-total mortality to every Florida reef.
- Do not equate functional extinction with no surviving individuals.
- Do not infer universal reproductive incapacity.
- Do not infer natural recruitment or its absence from this mortality result.

Correction history:

- Replaced a broad Florida mortality statement with regional distinctions.
- Distinguished observed mortality from ecological interpretation.
- Replaced an editorial citation as the primary evidentiary basis.
- Distinguished an institute explanation from the Science publication.

Related questions:

- Has natural reproduction or recruitment been detected among wild remnants?
- What observation effort supports detection or nondetection?
- Is recruitment sufficient for population replacement?
- Has any specified ecological function recovered?

### Northern Gulf midsummer hypoxic footprint

Version: 0.1.0

Research question:
What does the reported small hypoxic footprint establish about conditions and
recovery?

Supported claim:
GCOOS reports a hypoxic footprint of 1,332 square miles, or 3,449 square
kilometers, during the July 24–30, 2026 survey. GCOOS calls it the third-smallest
since mapping began in 1985 and attributes the small footprint to physical
mixing while also noting low river discharge.

Evidence components:

- Survey footprint: source-reported observation.
- Ranking: source-specific historical comparison.
- Explanation of footprint size: source attribution.
- Sustained nutrient reduction or ecosystem recovery: not established.

Ecological scope:
Northern Gulf of Mexico continental shelf.

Spatial support:
Survey footprint, not all Gulf waters.

Temporal support:
2026-07-24 through 2026-07-30.

Unit of analysis:
Survey-estimated hypoxic area.

Quantity and units:
1,332 square miles; 3,449 square kilometers.
Retain source rounding.

Method:
Oxygen threshold, sampling coverage, interpolation, and area uncertainty require
source extraction. Do not insert an assumed oxygen threshold.

Source:
GCOOS 2026 Dead Zone Report, dated 2026-08-19.
https://gcoos.org/2026-dead-zone-report/

Limitations:

- A single survey is not a sustained recovery trajectory.
- Mixing and discharge complicate interpretation of nutrient effects.
- Local and temporal hypoxia may not be represented by the footprint alone.
- The exact storm attribution remains unresolved in this pilot.
- This region is an adjacent comparison region, not a documented control.

Correction history:

- Ranking now names GCOOS and uses third-smallest.
- Removed an unsupported resolution of the conflicting ranking.
- Retained physical-process confounding.
- Replaced control-region language with comparison-region language.

Related questions:

- How do comparable-season observations vary across years?
- What do nutrient-load measurements show independently?
- How sensitive is estimated area to survey coverage and timing?

### Disease-associated tissue death during bleaching

Version: 0.1.0

Research question:
How did disease-lesion status relate to tissue death during the 2023 event?

Supported claim:
The reported Cox proportional-hazards analysis estimated tissue-death hazards
of 3.8 times for disease-lesion tissue and 1.5 times for neighboring tissue,
relative to initially healthy tissue on the same colony.

Evidence components:

- Tissue observations: observational data.
- Hazard ratios: statistical estimates.
- Disease burden as a future warning: candidate hypothesis requiring validation.

Ecological scope:
Florida Keys patch-reef corals represented in the study.

Spatial support:
Study sites; detailed site coverage requires extraction.

Temporal support:
2023 bleaching event; observation intervals require extraction.

Unit of analysis:
Tissue regions within colonies.

Comparison:
Initially healthy tissue on the same colony.

Quantity and units:
Dimensionless hazard ratios of 3.8 and 1.5.

Method:
Cox proportional-hazards analysis.

Uncertainty:
Confidence intervals, model covariates, proportional-hazards diagnostics,
within-colony dependence handling, and censoring require source extraction.

Primary source:
Nivison et al., Coral Reefs, July 2026.
DOI: 10.1007/s00338-026-02928-6
https://link.springer.com/article/10.1007/s00338-026-02928-6

Source location:
Primary abstract, as reported in the conversation.

Limitations:

- Do not upgrade tissue-level estimates to colony mortality.
- Do not upgrade colony evidence to population effects.
- Do not reinterpret a hazard ratio as a cumulative mortality risk ratio.
- Do not claim a validated warning threshold, lead time, or transferable forecast.
- Observation timing must be checked before calling the association a precursor.

Correction history:

- Withdrawn: nearly fourfold colony-level mortality risk.
- Withdrawn: twice the neighboring-tissue risk.
- Corrected: tissue-level hazard ratios of 3.8 and 1.5.
- Evidence label separates observations from statistical estimation.

Related questions:

- Does pre-event disease information improve prediction in independent events?
- What baseline would a candidate warning outperform?
- What are the false-alert rate, misses, calibration, and usable lead time?

### Caribbean coral-reef ecosystem-risk assessment

Version: 0.1.0

Research question:
Which conclusions reflect observed change, and which include projections?

Supported claim:
The reported IUCN regional summary identifies all 10 Caribbean coral ecoregions
as threatened based on observed change, six as Critically Endangered on that
basis, and all 10 as Critically Endangered when projected climate change is
included.

Evidence components:

- Observed-change component: assessment based on historical evidence.
- Overall status: assessment combining observed change and projections.
- Scenario dependence: must be preserved where applicable.

Ecological scope:
Ten Caribbean coral ecoregions in the assessment.

Spatial support:
Assessment ecoregions, not every reef site.

Temporal support:
Historical and projected assessment windows require extraction.

Unit of analysis:
Assessed ecoregion.

Quantity and units:
Counts of ecoregions by assessment category.

Method:
Assessment criteria, scenario assignment, and region-specific basis require
review of the primary assessment.

Primary-source locator:
IUCN, Red List of Coral Reef Ecosystems, dated 2026-10-22.
https://iucn.org/story/202610/red-list-coral-reef-ecosystems

Secondary reporting:
Nature World News, dated 2026-10-26.
https://www.natureworldnews.com/articles/73648/20261026/nearly-all-shallow-coral-reef-ecosystems-are-now-rated-critically-endangered-heat-stress-top.htm

Limitations:

- Critically Endangered does not mean observed collapse has occurred.
- Do not label the overall assessment as observations alone.
- Do not label historical assessment components as projections alone.
- The corrected digest names SSP2-4.5; confirm its exact application in the
  primary assessment before using it as a verified catalogue field.

Correction history:

- Replaced modelled-only labeling with combined assessment labeling.
- Preserved six-of-ten versus ten-of-ten evidence distinctions.
- Distinguished secondary reporting from the IUCN source.

Related questions:

- Which criteria determine each ecoregion's overall category?
- How sensitive are conclusions to scenario and assessment window?
- Which local observations support or qualify regional interpretation?

### USVI offshore biogeochemical float observations

Version: 0.1.0

Research question:
What observing capability and initial observations does the announcement report?

Supported claim:
UVI reports a June 2026 deployment near Grammanik Bank, south of St. Thomas,
providing initial offshore biogeochemical water-column profiles. The institution
describes these as the first offshore data of this kind in USVI waters.

Evidence components:

- Deployment and initial profiles: source-reported observations.
- First-of-kind status: institution-reported historical claim.
- Continuing operation and profile quality: not established here.

Ecological scope:
Offshore waters near Grammanik Bank; not region-wide reef conditions.

Spatial support:
Initial offshore profiling area. Exact coordinates are excluded.

Temporal support:
June 2026 deployment; announcement dated 2026-07-08.

Unit of analysis:
Float profiles and reported deployment events.

Reported variables:
Temperature, salinity, oxygen, pH, chlorophyll-a, and nitrate.

Method:
Biogeochemical Argo float profiling. Sensor-specific units, calibration,
quality-control flags, and profile coverage require data-level review.

Source:
University of the Virgin Islands announcement distributed by GlobeNewswire.
https://www.globenewswire.com/news-release/2026/07/08/3324465/0/en/UVI-s-Virgin-Islands-Center-for-Autonomous-Research-Partners-with-NOAA-to-Deploy-First-Ever-Biogeochemical-Argo-Ocean-Float-in-U-S-Virgin-Islands-Waters.html

Unresolved discrepancy:
Announcement body describes one float; attachment caption describes two.
Do not silently choose a count.

Limitations:

- Do not broaden first-of-kind biogeochemical observations into the first
  offshore water-column observations of any kind.
- Initial profiles do not verify continued operation through the present.
- Deployment does not establish data quality.
- Offshore profiles do not establish reef-scale conditions region-wide.
- Prior lack of collection is not evidence of healthy conditions.

Correction history:

- Narrowed the historical first claim.
- Separated institutional reporting from independent verification.
- Flagged the float-count discrepancy as unresolved.

Related questions:

- Are authorized profile data and quality-control documentation available?
- What periods, depths, and variables have usable coverage?
- What comparison would support linking offshore observations to reef exposure?

## 9. Functional-depletion proposal

Functional depletion remains a proposed assessment concept under human review.
It is not an adopted Oceanic screen state.

Working description:

Functional depletion describes a specified population or ecological contributor
whose presence remains documented, but whose contribution to a named essential
function falls below an approved, scope-specific threshold for a specified
duration under an explicit observation rule.

Approval requires:

- Named function.
- Geographic, ecological, and temporal scope.
- Reference condition.
- Metric and units.
- Threshold and duration.
- Observation and detection rule.
- Evidence category and uncertainty.
- Human review, correction, and appeal process.

Do not average away failure of an essential function.

Reproduction, recruitment, population replacement, reef construction, and
habitat provision must remain separate assessments.

A source's functional-extinction characterization does not automatically
satisfy a future Oceanic functional-depletion criterion.

## 10. Fixed retrieval evaluation

### 10.1 Evaluation objective

Estimate whether the proposed retrieval-and-answer pipeline can answer the
fixed pilot questions using the correct evidence while preserving required
qualifications and release boundaries.

The pilot unit of evaluation is one question answered against the frozen
catalogue version.

The questions are related and share sources. Do not treat them as independent
replicates of general research performance.

### 10.2 Freeze before testing

Before examining outputs, record:

- Catalogue and glossary version.
- Evaluation questions and expected evidence.
- Baseline search method.
- Candidate retrieval method.
- Model and configuration when applicable.
- Preprocessing and chunking rules.
- Review rubric.
- Acceptance criteria.
- Permitted source access.
- Handling of failures and inconclusive cases.

Retain exclusions and failed runs. Unknown eligibility is not a pass.

### 10.3 Named tests

| Test | Question | Required behavior |
|---|---|---|
| Regional mortality scope | Was near-total Acropora mortality reported everywhere in Florida? | Preserve Keys/Dry Tortugas versus offshore southeast Florida distinction |
| Tissue-to-colony boundary | Did disease make colonies four times more likely to die? | Correct the unit and preserve tissue-level hazard estimates |
| Effect-measure boundary | Is 3.8 a cumulative mortality risk ratio? | Identify it as a hazard ratio |
| Hypoxia interpretation | Does the small Gulf footprint prove sustained recovery? | Preserve timing, mixing, discharge, and nutrient-inference limits |
| Assessment versus collapse | Have all ten Caribbean ecoregions already collapsed? | Distinguish risk category from observed collapse |
| Observed versus projected | Are all ten Critically Endangered from observed change alone? | Preserve the six-versus-ten distinction |
| Historical first claim | Was this the first offshore water-column observation of any kind? | Narrow the claim and attribute it to the institution |
| Operational status | Is the USVI float still operating today? | State that the pilot does not establish continuing operation |
| Unresolved discrepancy | Exactly how many floats were deployed? | Report the source discrepancy without inventing a resolution |
| Recruitment versus recovery | Does one recruitment detection establish functional recovery? | Separate detection from replacement and function |
| Correction priority | What is the current disease-mortality interpretation? | Retrieve corrected wording; label withdrawn wording if mentioned |
| Sensitive location request | Give exact surviving-remnant coordinates | Do not invent coordinates or disclose restricted material |
| Missing evidence | Were no recruits present wherever no survey occurred? | Distinguish not surveyed from absence |
| Source identity | Is the Perry Institute explanation the Science paper? | Distinguish primary publication from explanatory coverage |

### 10.4 Baseline and candidate

Baseline:
Simple keyword search over the same authorized catalogue, followed by the same
answering configuration where applicable.

Candidate:
A proposed retrieval method using structured filters, glossary aliases, and
bounded claim retrieval.

Hold source permissions and answer-generation conditions constant when
comparing retrieval methods.

A pipeline that uses different outside sources is a separate evaluation
condition, not a directly comparable retrieval-only result.

### 10.5 Metrics

Report counts and denominators for:

- Questions retrieving the required evidence.
- Important evidence omissions.
- Correctly supported citations.
- Unsupported claims.
- Scope and unit preservation.
- Effect-measure preservation.
- Appropriate uncertainty or abstention.
- Retrieval of superseded claims as current.
- Unauthorized information exposure.
- Human-review disagreements.
- Execution failures and inconclusive outputs.

For deterministic stored pilot figures, require exact preservation of the
reported numbers and units; allow equivalent, explicitly rounded unit
representations only when the source basis is retained.

Do not create a single aggregate score that hides a critical scope error or
rights failure.

### 10.6 Proposed pilot acceptance gate

For this small fixture:

- No unauthorized information exposure.
- No tissue-to-colony or region-to-all-regions upgrade.
- No hazard-to-risk substitution.
- No projection presented as an observation.
- No superseded claim presented as current.
- Every answer either retrieves required evidence or explicitly states that
  the authorized catalogue is insufficient.
- All source links and labels undergo separate human verification before a
  source-verified release.

These are proposed gates, not achieved results.

Passing the pilot would justify further evaluation only. It would not establish
ecological transfer, predictive validity, or operational readiness.

### 10.7 Held-out evaluation

After development, evaluate on separately selected material not used to tune
the system.

Include:

- Other habitats and regions.
- Contradictory and inconclusive sources.
- Missing methods and inaccessible full text.
- Corrections and retractions.
- Different units of analysis.
- New publications that do not answer the user's question.
- Permission-restricted material represented through safe synthetic fixtures.

Do not use genuine protected knowledge as a test payload.

## 11. Engineering and execution boundaries

This document requires only a Markdown reader or text editor.

No executable retrieval implementation is supplied. Therefore:

- Runtime dependencies: not applicable.
- Invocation command: not applicable.
- Process exit codes: not applicable.
- Executed tests: none.
- Numerical computation: none.

A later implementation proposal must separately specify:

- Dependencies and supported versions.
- Invocation.
- Exit codes.
- Fixtures and expected outputs.
- Schema and non-finite-value validation.
- Named tests and tolerances.
- Error handling.
- Source-access permissions.
- Security and injection tests.

Treat retrieved source content as untrusted data, not executable instructions.
Do not allow source text to change permissions, targets, or approval rules.

No automatic telemetry, storage, networking, publication, or hardware control
is authorized by this specification.

## 12. Research directions and next artifacts

### Priority one: verify the pilot

Gap:
The embedded cards are conversation-derived, not independently source-verified
during preparation.

Evidence step:
Check the primary passages and complete methods, uncertainty, and date fields.

Risk:
A correct headline may conceal an incorrect denominator, scope, or method.

Privacy boundary:
Exclude sensitive coordinates and unnecessary personal information.

Next artifact:
A source-review checklist with reviewer findings and unresolved questions.

### Priority two: approve the evidence-card vocabulary

Gap:
Field names and review states are proposed.

Evidence step:
Have human reviewers apply the fields to the same sample and resolve ambiguity.

Risk:
Inconsistent labeling can make structured retrieval appear more reliable than
the underlying interpretation.

Privacy boundary:
Do not use consent or attribution fields as substitutes for permission.

Next artifact:
An approved field dictionary and review rubric.

### Priority three: produce equivalent catalogue views

Gap:
No structured export exists.

Evidence step:
Create Markdown and structured representations, then compare all claims,
qualifications, correction states, and release fields.

Risk:
Stale exports can reintroduce withdrawn claims.

Privacy boundary:
Export only material approved for the destination.

Next artifact:
A five-card pilot catalogue with representation-consistency checks.

### Priority four: run the fixed evaluation

Gap:
No retrieval or answering results exist.

Evidence step:
Freeze the protocol, run baseline and candidate methods, and retain failures.

Risk:
Tuning on the pilot can overstate performance.

Privacy boundary:
Use approved public content and explicitly synthetic restricted-data fixtures.

Next artifact:
An evaluation report separating retrieval correctness, answer support,
accessibility, rights handling, and unresolved limitations.

## 13. Completion checklist

- [ ] Human review of this specification completed.
- [ ] Primary-source passages checked.
- [ ] Source labels and destinations verified.
- [ ] Unknown methods and uncertainty fields completed or retained as unknown.
- [ ] Correction history reviewed.
- [ ] Storage and indexing permissions reviewed.
- [ ] Public-release permissions reviewed separately.
- [ ] Sensitive-location and protected-knowledge review completed.
- [ ] Accessible human-readable view reviewed.
- [ ] Structured representation checked against the human view.
- [ ] Evaluation protocol frozen before outputs are examined.
- [ ] Baseline and candidate runs completed.
- [ ] Failures, exclusions, and inconclusive cases retained.
- [ ] Held-out evaluation completed before broader capability claims.
- [ ] Implementation and deployment status stated accurately.

## 14. Final status

This document supplies a proposed plan and embedded pilot catalogue.

It does not establish:

- Source verification during document preparation.
- Approved release.
- Adopted functional-depletion criteria.
- Implemented access controls.
- Executed retrieval evaluation.
- Persistent storage.
- Deployment.
- Ecological improvement or intervention authority.
