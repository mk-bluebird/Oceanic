<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# Access, Language, and Data Governance Workbook

Document status: proposed research workbook  
Document version: 0.1.0  
Repository: mk-bluebird/Oceanic  
Scope: accessible ecological inquiry, meaning preservation, and governed use

## 1. Purpose

Investigate how ecological research assistance can preserve:

- Identity and autonomy.
- Communication variation.
- Meaning across languages.
- Accessible participation.
- Relevant Tribal and community-defined authority.
- Purpose-specific permissions.
- Correction, review, and appeal.
- The choice not to disclose or record information.

Accessibility and governance constrain the complete workflow. They are not
features added after scientific analysis or interface development.

This workbook establishes no:
- Accessibility certification.
- Community approval.
- Legal determination.
- Consent.
- Permission to collect or publish.
- Verified prediction.
- Intervention authority.

Do not search within repositories. Conduct broad external research and use
reviewed ecological cases. Treat unavailable implementation details as
unresolved rather than reconstructing them as facts.

## 2. Assessment boundaries

Keep three assessments separate.

### 2.1 Structural screening

Determines whether a representation satisfies a declared, versioned contract.

It may check:
- Recognized fields.
- Tagged declarations.
- Types.
- Bounds.
- Reference formats.
- Declared compatibility rules.

It does not establish:
- Truth.
- Scientific support.
- Appropriate interpretation.
- Authorization.

### 2.2 Scientific-support review

Evaluates evidence for a specified ecological claim, including:
- Measurement support.
- Observation processes.
- Estimands.
- Competing mechanisms.
- Model assumptions.
- Dependence.
- Uncertainty.
- Applicability.

Scientific support does not authorize use or disclosure.

### 2.3 Governance review

Documents relevant authority, permitted purposes, conditions, and restrictions.

Governance may apply before:
- Collection.
- Retrieval.
- Ingestion.
- Interpretation.
- Translation.
- Storage.
- Synchronization.
- Derivative creation.
- Publication.

A software policy check records or evaluates configured requirements. It does
not create authority or settle legal applicability.

## 3. Contribution labels

Label material statements as:
- Observation.
- Source report.
- Assumption.
- Definition.
- Derivation under stated assumptions.
- Hypothesis.
- Proposal.
- Recommendation.
- Reviewed interpretation.

Keep supplied wording separate from the interpretation assigned to it.

A declaration is not verification.

## 4. Research objectives

Investigate:

1. Which ecological terms admit materially different interpretations?
2. Which distinctions must survive translation?
3. Which interaction patterns create unnecessary participation burdens?
4. Which information can remain uncollected?
5. Which uses require separate permission?
6. How can withholding support a narrower, useful inference?
7. How can corrections propagate without exposing protected information?
8. Which accessibility claims are supported by user evaluation?
9. Which governance decisions remain outside software authority?
10. What would count as a meaningful community-defined benefit?

Preserve disagreement and inconclusive results.

## 5. Ecological terminology and contextual meaning

Terms requiring clarification may include:
- Recovery.
- Collapse.
- Health.
- Resilience.
- Restoration success.
- Persistence.
- Refugium.
- Habitat quality.
- Ecological function.

Do not impose a universal operational definition merely because it is easier
to calculate.

### 5.1 Proposed term record

Where recording is permitted, document:
- Original wording.
- Language, if relevant and supplied.
- Context.
- Intended meaning, if supplied.
- Alternative interpretations.
- Candidate operational endpoint.
- Reference condition.
- Spatial support.
- Temporal support.
- Unresolved questions.
- Review status.
- Permitted uses of the interpretation.

Do not require cultural explanations or protected terminology.

### 5.2 Interpretation relation

Let \(u\) be an utterance and \(c\) its context.

\[
I(u,c)\subseteq\mathcal M,
\]

where \(\mathcal M\) is a declared set of candidate meanings.

If:

\[
|I(u,c)|>1,
\]

a unique interpretation has not been established.

A supported clarification may reduce the set:

\[
I(u,c,\text{clarification})\subseteq I(u,c).
\]

Do not reduce the set by silently selecting the interpretation most convenient
for the model.

### 5.3 Operational ecological endpoints

For a specified function \(j\), a proposed assessment record is:

\[
\mathcal R_j=(Y_j,B_j,A_j,D_j,O_j),
\]

where:
- \(Y_j\): response and units.
- \(B_j\): reference condition.
- \(A_j\): acceptable response region.
- \(D_j\): required duration.
- \(O_j\): observation rule.

This is not a universal definition of recovery.

Keep essential functions separate. Do not average away failure of a necessary
function.

## 6. Language and translation

### 6.1 Preserve relevant distinctions

Review whether wording preserves:
- Negation.
- Uncertainty.
- Observed versus estimated.
- Association versus causation.
- Present detection versus future prediction.
- Spatial scope.
- Time and duration.
- Agency.
- Permission versus recommendation.
- Optional request versus required disclosure.

Do not assume literal translation preserves meaning.

### 6.2 Separate two review activities

Registry conformance:
- Message purpose.
- Required argument roles.
- Argument types.
- Escaping.
- Fallback behavior.
- Registry version.

Semantic review:
- Evidential force.
- Negation.
- Uncertainty.
- Agency.
- Severity.
- Cultural appropriateness.
- Whether a request becomes a demand.

Mechanical checks do not prove semantic equivalence.

### 6.3 Proposed semantic feature record

\[
\phi(m)=
(\text{purpose},\text{polarity},\text{modality},
\text{evidential status},\text{agency},\text{scope}).
\]

For a specified use, reviewers may assess:

\[
\phi(m_{\ell_1})\simeq\phi(m_{\ell_2}).
\]

Here, \(\simeq\) denotes reviewed equivalence under explicit criteria. It is not
an automatically established property.

Equal placeholder counts are neither necessary nor sufficient for equivalent
meaning. Argument roles matter more than raw arity.

### 6.4 Unresolved translations

Allow:
- Retained original wording.
- Explanatory text.
- Multiple interpretations.
- A reviewed local term.
- An explicit unresolved translation.
- Human assistance.

Do not invent an authoritative equivalent.

Translation and distribution may themselves require permission.

## 7. Technical text contract

Before implementation, specify:
- Accepted encoding.
- Malformed-input behavior.
- Length units: bytes, code points, or another declared measure.
- Display-length considerations.
- Language metadata.
- Directionality.
- Normalization policy.
- Original-text preservation policy.
- Control-character handling.
- Escaping.
- Resource bounds.

Do not silently:
- Transliterate.
- Truncate.
- Replace wording.
- Change declaration tags based on natural-language guesses.
- Treat encoding acceptance as accessibility.

Keep stable machine keys separate from reviewed display text.

Any transformed text must be distinguishable from the original, where retaining
the original is permitted.

## 8. Accessible participation

### 8.1 Proposed participation options

Provide:
- Text-first interaction.
- Plain-language summaries.
- Optional technical detail.
- Offline materials.
- Short and extended responses.
- User-controlled pacing.
- Pause, skip, and return.
- Human review.
- Correction and appeal.
- Alternative response formats.

Do not make rapid response or mathematical fluency a participation condition.

### 8.2 Respect communication variation

Do not infer reduced competence from:
- Response latency.
- Unusual wording.
- Short or incomplete messages.
- Assistive technology use.
- Translation needs.
- Fatigue.
- Requests for repetition.

Respect augmented-citizen and cybernetic-host self-descriptions.

CyberRank remains private identity and project-governance vocabulary. It is not
public law, ecological evidence, verification, diagnosis, ranking, or eligibility.

Require no neural, biometric, medical, implant, or companion-system disclosure.

Do not claim access to or control of such systems.

### 8.3 Layered answer structure

1. Direct answer.
2. Plain-language explanation.
3. Optional mathematics.
4. Methods and assumptions.
5. Limits and alternative explanations.
6. Sources and next discriminating question.

Layering should preserve complexity without imposing unnecessary burden.

## 9. Accessibility research and evaluation

Co-develop evaluation tasks with participants where engagement is invited.

Do not collect diagnoses or protected details merely to explain interaction
differences.

Candidate outcomes:
- Task completion.
- Interpretation errors.
- Unwanted disclosure.
- Ability to correct.
- Ability to decline.
- Assistance requested.
- Abandonment.
- Participant-reported burden, if voluntarily provided.

For a specified task:

\[
p_{\mathrm{completion}}
=
\frac{\text{completed tasks}}
{\text{attempted tasks}}.
\]

Report the denominator and task definition.

Completion time alone is not competence. Fast completion with an unwanted
disclosure is not a successful outcome.

Aggregate results may conceal barriers. Review meaningful differences only
where collection and reporting are appropriate and permitted.

Do not claim accessibility certification from a small usability exercise.

## 10. Indigenous and community-defined authority

Respect Indigenous Peoples' rights and relevant community-defined governance.

Do not treat Indigenous Peoples and local communities as interchangeable
political or rights categories.

Do not presume:
- One participant can authorize collective knowledge.
- A researcher can select legitimate representatives.
- Public availability authorizes reuse.
- Individual consent resolves every collective concern.
- Attribution substitutes for permission.

Where engagement is invited, co-develop:
- Purpose.
- Access.
- Interpretation.
- Attribution.
- Retention.
- Benefits.
- Derivatives.
- Publication.
- Correction.
- Remedy.

Not collecting or recording knowledge is a valid outcome.

## 11. CARE and FAIR

Use CARE as a governance framework:
- Collective Benefit.
- Authority to Control.
- Responsibility.
- Ethics.

Do not reduce CARE to a compliance checkbox or a numerical score.

FAIR practices alone do not establish:
- Authorization.
- Appropriate purpose.
- Collective benefit.
- Ethical reuse.

Investigate how technical discoverability and interoperability can coexist
with community-defined restrictions.

Do not assume community benefit. Ask how benefit is defined and by whom.

## 12. Purpose-specific permission

Represent a proposed use as:

\[
u=
(\text{operation},\text{purpose},\text{information scope},
\text{audience},\text{duration},\text{derivatives}).
\]

A documented determination is:

\[
P(u)\in
\{
\text{permitted},
\text{not permitted},
\text{undetermined}
\}.
\]

Permission does not automatically transfer:

\[
P(u_1)=\text{permitted}
\not\Rightarrow
P(u_2)=\text{permitted}.
\]

A change in audience, purpose, derivative, or distribution may require review.

An undetermined permission is not a pass.

The system must not generate a legal determination or authorization token from
scientific confidence.

## 13. Participation and consent processes

Distinguish:
- Participation in discussion.
- Permission to record.
- Permission to analyze.
- Permission to store.
- Permission to translate.
- Permission to create derivatives.
- Permission to publish.

Do not bundle these into one irreversible acceptance.

Where consent or another authorization process applies, record only the
minimum necessary information about its scope and conditions.

Allow meaningful refusal and correction.

Do not describe consent as obtained unless the relevant process actually
occurred.

Do not infer permission from:
- Silence.
- Continued conversation.
- A supplied source.
- An attribution anchor.
- A declaration that data are low sensitivity.
- Schema acceptance.

## 14. Withheld information

Withholding is a legitimate declaration.

It does not establish:
- Whether content is known.
- Whether measurements exist.
- Whether the contributor lacks competence.
- Whether participation is invalid.

### 14.1 Inferential dependency

Let:
- \(W\): information unavailable because it is withheld.
- \(\operatorname{Req}(h)\): information required by analysis \(h\).

Then:

\[
W\cap\operatorname{Req}(h)\neq\varnothing
\]

identifies a potential limitation.

Investigate an alternative analysis \(h'\) that may answer a narrower question:

\[
W\cap\operatorname{Req}(h')=\varnothing.
\]

Do not infer or reconstruct withheld content.

### 14.2 Audience-sensitive limitation reporting

A public explanation need not identify every withheld field.

The fact that information exists, a location was withheld, or a community
holds particular knowledge may itself be sensitive.

Separate:
- Restricted analytical explanation.
- Approved public summary.
- Information that should not be recorded.

A limitation notice must not become a disclosure channel.

## 15. Data minimization and retention

No automatic:
- Telemetry.
- Storage.
- Logs.
- Clarification histories.
- Event ledgers.
- Synchronization.
- Publication.

If persistence is later required, define:
- Purpose.
- Minimum content.
- Access.
- Retention.
- Correction.
- Deletion.
- Backups.
- Derivatives.
- Review authority.

Do not claim encryption, secure synchronization, durable storage, or deletion
without implementation evidence.

Minimization applies to:
- Raw observations.
- Metadata.
- Error arguments.
- Prompts.
- Model inputs.
- Review notes.
- Exported reports.

Aggregation is not guaranteed anonymity.

Review repeated releases and combined datasets for exposure risks.

## 16. Corrections, withdrawal, and remedy

Provide a process to:
- Contest an interpretation.
- Correct a source linkage.
- Revise a declaration.
- Report an unwanted disclosure.
- Request review of a permitted use.
- Explain downstream limitations.

Do not promise complete recall or deletion of distributed material unless
that capability is implemented and demonstrated.

Distinguish:
- Correcting the active record.
- Updating derivatives.
- Restricting future use.
- Deleting retained copies.
- Addressing external copies.

Record unresolved remedy limits plainly.

## 17. Ecological cases

### 17.1 Oxygen decline

Language work:
- Distinguish concentration, inventory, saturation, exposure, and trend.
- Explain local versus basin-average conditions.
- Preserve uncertainty in onset and duration.

Governance work:
- Protect sensitive sampling locations and community-use information.
- Review whether a public summary reveals more than intended.

Next question:
Can a permitted summary support the intended inference without exposing
unnecessary location detail?

### 17.2 Restoration

Language work:
- Clarify structure, survival, function, reproduction, recruitment, persistence,
  and community-defined goals.
- Do not substitute a technical endpoint for a valued relationship.

Governance work:
- Allow priorities to be stated without requiring protected explanations.
- Review attribution and publication separately.

Next question:
Which outcome matters for this purpose, and who determines whether the
description is appropriate?

### 17.3 Species detection

Language work:
- Distinguish nondetection, local absence, redistribution, and decline.
- Explain detection uncertainty without implying confirmed absence.

Governance work:
- Protect locations and relevant knowledge.
- Review risks from repeated releases.
- Do not request protected locations merely to complete a frame.

Next question:
What permitted evidence can distinguish ecological change from observation
change?

## 18. Proposed review records

Use descriptive names and scoped references. Do not require object identifiers.

### 18.1 Semantic review record

Include:
- Message key.
- Registry version.
- Source wording.
- Reviewed wording.
- Language.
- Intended use.
- Argument roles.
- Preserved distinctions.
- Unresolved interpretation.
- Review status.

Retain reviewer attribution only where permitted and necessary.

### 18.2 Governance review record

Include:
- Proposed use.
- Relevant authority or unresolved authority.
- Documented determination.
- Conditions.
- Review period, if applicable.
- Derivative restrictions.
- Publication restrictions.
- Correction and remedy route.

Do not place protected supporting detail in general summaries.

### 18.3 Accessibility review record

Include:
- Task.
- Participation mode.
- Barrier observed or reported.
- Proposed adjustment.
- Whether the adjustment was evaluated.
- Remaining limitations.

Do not infer a diagnosis.

## 19. Synthetic fixtures and named tests

Fixtures are synthetic unless explicitly documented otherwise.

### Declaration and participation

- withheld_does_not_require_content
- withheld_does_not_imply_known
- absent_does_not_imply_unaware
- disclosure_is_not_participation_score
- optional_question_can_be_skipped
- no_sensitive_explanation_required

### Language

- observed_not_rewritten_as_estimated
- association_not_rewritten_as_causation
- negation_preserved
- uncertainty_not_silently_strengthened
- optional_request_not_rendered_as_demand
- missing_translation_reports_fallback
- argument_roles_preserved
- semantic_review_not_claimed_by_registry_check

### Governance

- permission_is_purpose_specific
- publication_not_implied_by_analysis_permission
- translation_not_implied_by_storage_permission
- unknown_permission_is_not_pass
- attribution_does_not_grant_authority
- public_source_does_not_auto_authorize_reuse
- limitation_notice_does_not_expose_protected_detail

### Data handling

- no_storage_by_default
- no_networking_by_default
- error_arguments_do_not_echo_sensitive_content
- repeated_release_requires_review
- deletion_not_claimed_without_evidence

### Accessibility

- short_and_extended_explanations_available
- correction_path_is_visible
- pause_does_not_infer_incompetence
- no_medical_or_neural_disclosure_required
- alternate_participation_path_preserved

## 20. Engineering acceptance requirements

No executable implementation is supplied here.

Before engineering execution, document:
- Dependencies and versions.
- Input and output contracts.
- Invocation.
- Exit codes.
- Fixtures.
- Resource limits.
- Failure modes.
- Tolerances where numerical methods exist.
- Properties tested.
- Human-review boundaries.

Use:
{ok=true,value=...}
or
{ok=false,error=...}.

Errors require:
- Stable code.
- Safe path.
- Message key.
- Bounded localization arguments.

Categorical fixtures use exact comparison. No numerical tolerance is implied.

Passing tests establishes only the tested behavior within the declared scope.
It does not establish universal accessibility, semantic equivalence, legal
compliance, community approval, or operational readiness.

## 21. Research-agent answer structure

For extended ecological answers:

1. Answer directly to the extent evidence permits.
2. Clarify consequential ambiguity.
3. Define the response and scope.
4. Describe evidence and observation support.
5. Compare mechanisms.
6. Present applicable mathematics.
7. State assumptions and counterexamples.
8. Identify a next discriminating observation or question.
9. State governance and disclosure limits.
10. Offer an accessible interpretation without removing necessary qualifications.

Do not force every answer to contain every formalism.

## 22. Completion criteria

The research should demonstrate:
- Which language differences change an inference.
- Which interface choices create or reduce barriers.
- Which information can remain uncollected.
- Which narrower analyses remain useful.
- Which permissions require separate review.
- Which limitations cannot be resolved by software.

Preserve disagreements and unresolved questions.

Do not equate longer documents, more metadata, or more disclosure with better
ecological reasoning.

## 23. External reading for review

These sources motivate inquiry. They do not certify this workbook.

- CARE Principles for Indigenous Data Governance:
  https://datascience.codata.org/articles/10.5334/dsj-2020-043

- CBD Article 8(j):
  https://www.cbd.int/traditionalknowledge

- UNDRIP explanatory material:
  https://legal.un.org/avl/pdf/ha/ga_61-295/ga_61-295_e.pdf

- W3C guidance on usable content:
  https://www.w3.org/TR/coga-usable/

- W3C clear-content objective:
  https://www.w3.org/WAI/WCAG2/supplemental/objectives/o3-clear-content/

- W3C usability testing guidance:
  https://www.w3.org/TR/coga-usable/usability_testing.html

- Cross-linguistic semantic-alignment preprint:
  https://arxiv.org/abs/2503.04792

Review source status, context, limitations, and applicability before reuse.

UNDRIP Article 18 addresses participation. Articles 19 and 32(2) expressly
address obtaining free, prior and informed consent in their respective
contexts. Do not collapse these provisions into an unqualified legal claim.

## 24. Attribution and limits

Retain:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Document credit and configured workstream metadata only.

No biological binding, verified identity, consent, authorization, execution
evidence, or authority is established.

This document does not change model weights, create persistent memory,
perform consultation, establish community approval, or authorize data use.

No repository modification, field intervention, deployment, storage, or
publication occurred through producing this snippet.
