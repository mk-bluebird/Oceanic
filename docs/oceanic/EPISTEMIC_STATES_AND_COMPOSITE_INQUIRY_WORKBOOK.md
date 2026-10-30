<!-- SPDX-License-Identifier: MIT OR Apache-2.0 -->

# Epistemic States and Composite Inquiry Workbook

Document status: proposed research workbook  
Document version: 0.1.0  
Repository: mk-bluebird/Oceanic  
Scope: representations, question construction, and meaning preservation

## 1. Purpose

Develop representations that preserve distinctions among:
- Explicit declaration.
- Supplied content.
- Collection history.
- Knowledge status.
- Applicability.
- Permission.
- Scientific support.

Do not collapse these into a readiness score.

The objective is better ecological inquiry, not a larger audit.

Do not search within repositories. Investigate broad external literature and
worked ecological cases. Unavailable dependency contracts remain unresolved.

## 2. Contribution status

Label definitions, assumptions, derivations, hypotheses, proposals, source
reports, observations, and recommendations separately.

This workbook proposes representations and tests. It establishes no empirical
findings, legal determinations, authorizations, or verified predictions.

## 3. Declaration vocabulary

| Declaration | Meaning | Does not establish |
|---|---|---|
| supplied | Content is provided under the contract | Truth, relevance, adequacy |
| unknown | Answer or value is explicitly unresolved | Collection history or unknowability |
| not_collected | Specified information has not been collected | Nonexistence |
| withheld | Specified content is intentionally not provided | Whether it is known or collected |
| declared_not_applicable | Applicability is denied by declaration | Reviewed irrelevance |
| absent | No declaration exists | Awareness, competence, or knowledge |

These labels mix different kinds of information. Treat them as a candidate
submission vocabulary, not a proven independent state system.

Zero is a possible supplied numerical value. It is not a replacement for an
unresolved declaration.

## 4. Scoped declaration research

Before splitting the vocabulary into dimensions, investigate what each
declaration concerns.

Example:
"The location is withheld; recruitment measurements have not been collected."

The declarations concern different information and need not conflict.

For each proposed dimension, specify:
- Definition.
- Purpose.
- Tagged alternatives.
- Examples.
- Counterexamples.
- Compatibility constraints.
- What it does not establish.

Do not require reasons for withholding by default.

### Candidate representation

\[
r_f=(d_f,a_f,k_f,\ell_f).
\]

Where:
- \(d_f\): declaration status.
- \(a_f\): content availability.
- \(k_f\): knowledge or collection declaration.
- \(\ell_f\): applicability declaration.

Define admissible combinations:

\[
\mathcal R\subseteq D\times A\times K\times L.
\]

This is a constrained representation, not a claim of statistical independence.

Test pairwise and higher-order compatibility.

Permissions remain purpose-specific governance records, not a field-quality
dimension.

## 5. Operational declaration presence

Declaration presence is determined by an explicit recognized representation,
not by guessing what text means.

| Input | Proposed treatment |
|---|---|
| Field absent | No declaration |
| Recognized unknown tag | Explicit unresolved declaration |
| Recognized withheld tag without content | Explicit withholding |
| Supplied tag with acceptable content | Content supplied |
| Supplied tag with empty required text | Structural error |
| Null | Follow explicit format-specific null policy |
| Literal text "unknown" | Supplied text unless explicitly tagged |
| Placeholder-like wording | Do not infer intent without a declared rule |

Do not silently coerce malformed input into absence.

Any placeholder policy must be explicit, versioned, and limited to structural
screening.

## 6. Nominal comparison before ordering

Do not assume:
- supplied is better than withheld;
- withheld retains not_collected;
- unknown is a lower-quality contributor state;
- absence measures awareness.

A partial order requires a defined relation and its properties.

A bounded poset additionally requires least and greatest elements. Neither is
established by naming six declarations.

### Candidate assertion-preservation relation

Let \(A(x)\) be explicit, scoped assertions in representation \(x\).

\[
x\preceq_A y
\iff
A(x)\subseteq A(y).
\]

This means assertion retention only.

It does not establish:
- Truth.
- Scientific superiority.
- Authorized disclosure.
- Better participation.

Define equivalence:

\[
x\sim_A y
\iff
A(x)=A(y).
\]

Conflicting additions require review rather than automatic dominance.

### Research deliverable

For every proposed order, provide:
- Intended meaning.
- Admissible transformations.
- Reflexivity argument.
- Antisymmetry argument.
- Transitivity argument.
- Comparable cases.
- Incomparable cases.
- Counterexamples to misleading use.

Do not build a ranking dashboard before this work.

## 7. Required fields and partitions

Let \(F\) be the frozen registered required field set.

For each category \(s\), define:

\[
F_s=\{f\in F:\sigma(f)=s\}.
\]

For acceptable declarations:

\[
F=\biguplus_sF_s,
\qquad
|F|=\sum_s|F_s|.
\]

Include:
- supplied
- unknown
- not_collected
- withheld
- declared_not_applicable
- absent

A declared non-applicability does not silently remove a required field.

Keep separately named sets for:
1. Recognized declared fields.
2. Registered required fields.
3. Reviewed applicable required fields, if established.

Each set needs its own definition and version.

## 8. Coverage coordinates

For \(n=|F|>0\):

\[
d(f)=\mathbf1[\text{recognized explicit declaration}],
\]

\[
c(f)=\mathbf1[\text{content supplied under the contract}].
\]

Then:

\[
\kappa_{\mathrm{decl}}
=
\frac{\sum_{f\in F}d(f)}{n},
\qquad
\kappa_{\mathrm{supp}}
=
\frac{\sum_{f\in F}c(f)}{n}.
\]

Because \(c(f)\leq d(f)\):

\[
0\leq\kappa_{\mathrm{supp}}
\leq\kappa_{\mathrm{decl}}
\leq1.
\]

These are dimensionless coverage statistics.

For \(n=0\), preserve undefined results.

Report:
- Counts.
- Denominator.
- Field-set version.
- Intent interpretation.
- Applicability status.

Coverage does not establish evidence quality or contributor worth.

## 9. Representation pipeline

Separate:
1. Parsing.
2. Structural admission.
3. Normalization.
4. Screening.
5. Rendering.

### Normalization

Specify a domain closed under normalization:

\[
N:\mathcal D\rightarrow\mathcal D.
\]

Require:

\[
N(N(x))=N(x).
\]

Normalization may canonicalize ordering. It must not:
- Invent declarations.
- Infer knowledge.
- Resolve applicability.
- Convert withholding to absence.
- Grant permission.

### Screening

\[
S:\mathcal N
\rightarrow
\operatorname{Ok}(\mathcal Y)
\cup
\operatorname{Err}(\mathcal E).
\]

Preserve the result convention:

{ok=true,value=...}
{ok=false,error=...}

Successful outcomes:
- structurally_accepted
- accepted_with_clarifications

Use StructurallyScreenedFrame, not ValidatedFrame.

### Error envelope

Require:
- Stable code.
- Input path.
- Message key.
- Bounded localization arguments.

Do not echo sensitive supplied content unnecessarily.

A constructor convention in Lua is not a security boundary.

## 10. Clarification records

A proposed clarification record contains:
- Stable clarification code.
- Affected field or requirement.
- Prompt key.
- Typed argument roles.
- Triggering rule.
- Rule version.
- Optionality.
- Interpretation limits.

Do not require rendered English in the core output.

Clarifications must not:
- Demand protected knowledge.
- Imply incompetence.
- Convert optional disclosure into participation eligibility.
- Claim optimal decision value.

## 11. Composite intents

### Separate operations

1. Parse declarations.
2. Handle duplicates under the parser contract.
3. Canonicalize atomic intents.
4. Derive dependencies.
5. Add interaction requirements.
6. Detect conflicts.

For normalized intent sets:

\[
J\oplus J'=J\cup J'.
\]

Set union is commutative, associative, and idempotent.

Parser duplicate rejection is a separate operation.

### Requirement derivation

\[
R(J,x)
=
\operatorname{Cl}
\left(
\bigcup_{i\in J}F_i
\cup H(J,x)
\right).
\]

Where:
- \(F_i\): atomic-intent requirements.
- \(H(J,x)\): explicit interaction requirements.
- \(\operatorname{Cl}\): declared dependency closure.
- \(x\): contextual declarations.

Do not assume:

\[
R(J\cup J',x)=R(J,x)\cup R(J',x).
\]

### Interaction record

Record:
- Triggering intents.
- Introduced requirement.
- Affected fields or references.
- Rule and version.
- Satisfied, unresolved, or conflicting status.

Example:
Comparing forecasts may require common outcomes, aligned horizons, and
compatible evaluation rules beyond the separate atomic requirements.

### Analytical eligibility

If used:

\[
E(J,x)
=
\left(\bigwedge_{i\in J}E_i(x)\right)
\land E_{\mathrm{interaction}}(J,x).
\]

Define treatment of undetermined conditions.

Unknown is not a pass.

Analytical eligibility is not permission, participation eligibility, or
intervention authority.

## 12. Causal inquiry

Distinguish:
- Association.
- Predictive contribution.
- Intervention effect.
- Counterfactual claim.

### Structural model representation

\[
\mathcal M=(U,V,F,P(U)),
\]

\[
V_i=f_i(\operatorname{Pa}_i,U_i).
\]

The representation does not itself establish identifiability or empirical
correctness.

Declare:
- Variables and units.
- Time indexing.
- Confounders.
- Measurement processes.
- Selection.
- Interventions.
- Target estimand.

### Predictive contribution

Compare:

\[
P(Y_{t+1}\mid Y_{\leq t},Z_{\leq t},X_{\leq t})
\]

with:

\[
P(Y_{t+1}\mid Y_{\leq t},Z_{\leq t}).
\]

A predictive difference does not automatically establish an intervention
effect.

Feedback does not, by itself, imply future-to-past causation.

### Ecological exercise

For warming, oxygen, and organism condition:
- Draw competing pathways.
- Declare temporal and spatial support.
- Identify shared drivers.
- Specify observations that distinguish mechanisms.
- State which causal effects remain unidentified.

## 13. Vocabulary incompleteness

Distinguish:
1. A registered field missing from a submission.
2. A relevant concept missing from the vocabulary.

Let \(F^\ast(q)\) be concepts relevant to question \(q\).

\[
U(q)=F^\ast(q)\setminus F.
\]

Declaration coverage cannot establish:

\[
U(q)=\varnothing.
\]

No probability of unknown omissions follows without a probability model.

Use inquiry prompts:
- Which life stage is missing?
- Which boundary flux is omitted?
- Could detection explain the apparent change?
- Could an average conceal local exposure?
- Which alternative mechanism is unrepresented?

Do not infer awareness or competence from absence.

## 14. Migration and compatibility

Migration must report:
- Source and target versions.
- Rule version.
- Preserved declarations.
- New undeclared requirements.
- Losses.
- Ambiguities.
- Review needs.

A proposed migration relation is:

\[
M_{n\rightarrow m}(x)\subseteq\mathcal X_m.
\]

It may yield:
- One interpretation.
- Multiple interpretations requiring review.
- No admissible interpretation.

Exact semantic preservation is a claim to demonstrate:

\[
\operatorname{sem}_n(x)
=
\operatorname{sem}_m(x').
\]

Never silently map:
- withheld to unknown;
- unknown to supplied;
- declared_not_applicable to reviewed irrelevance.

Unknown-key policy must be explicit by key or namespace, with a defined default.

Possible handling:
- reject;
- exclude from interpretation;
- require review;
- preserve as uninterpreted content when permitted.

Exclusion from interpretation does not authorize storage.

## 15. Localization and accessibility

Separate:
- Registry conformance.
- Human semantic review.

Mechanical checks examine:
- Message purpose.
- Argument roles and types.
- Escaping.
- Fallback.
- Registry versions.

Semantic review examines:
- Negation.
- Uncertainty.
- Evidential wording.
- Agency.
- Severity.
- Optional request versus demand.

Equal placeholder counts do not prove equivalent meaning.

Provide plain-language explanations, optional technical detail, text-first
participation, pacing, correction, and appeal.

Require no neural, biometric, medical, implant, or companion-system disclosure.

## 16. Competency questions

Use questions to test whether the representation supports meaningful inquiry.

Example progression:
1. Why has restoration not produced persistence?
2. Which life-cycle transition is unsupported?
3. Can observations distinguish recruitment failure from low detection?
4. Which estimand and design address that distinction?
5. Does the representation handle an unseen case?

Define:

\[
T(q,\mathcal K,A_q)
\in
\{
\text{answer supported},
\text{qualified partial answer},
\text{insufficient basis},
\text{representation failure}
\}.
\]

Where:
- \(q\): competency question.
- \(\mathcal K\): represented evidence and rules.
- \(A_q\): acceptance criteria.

A returned query value is not automatically a scientifically supported answer.

## 17. Test and evaluation plan

Named synthetic fixtures:
- absent_is_not_unknown
- withheld_does_not_imply_known
- empty_supplied_text_is_not_absence
- declared_not_applicable_remains_visible
- required_partition_is_disjoint_and_exhaustive
- zero_denominator_remains_undefined
- normalization_is_idempotent
- normalization_preserves_declarations
- screening_does_not_mutate_input
- canonical_intent_order_preserves_requirements
- composite_interaction_requirement_is_reported
- ambiguous_migration_requires_review
- unknown_key_does_not_grant_permission
- localization_fallback_preserves_message_purpose
- no_storage_by_default

Combine:
- Example-based tests.
- Frozen structural fixtures.
- Property-based tests.
- Model-based tests.
- Mutation tests.
- Reviewed held-out ecological cases.

Passing tests is evidence within the tested contract, not a proof that the
law set is sufficient.

Categorical fixtures use exact comparison. Any future numerical tolerance
requires a method-specific justification.

No executable implementation is supplied. Before execution, document
dependencies, invocation, exit codes, resource limits, and test scope.

## 18. Research completion criteria

The work should demonstrate:
- Which distinctions are necessary.
- Which representations lose meaning.
- Which counterexamples defeat proposed rules.
- Which questions become more answerable.
- Which uncertainty remains.
- Which information can stay uncollected.

Do not equate larger schemas, more terminology, or longer answers with better
ecological reasoning.

## 19. Selected external reading

- Epistemic logic:
  https://plato.stanford.edu/entries/logic-epistemic/
- Epistemic Logic of Likelihood and Belief:
  https://ijcai.org/proceedings/2022/360
- Structural causal model tutorial:
  https://ftp.cs.ucla.edu/pub/stat_ser/nips-dec2013-pearl-bareinboim-tutorial.pdf
- Restoration monitoring:
  https://www.nationalacademies.org/read/23476/chapter/6
- CARE Principles:
  https://datascience.codata.org/articles/10.5334/dsj-2020-043

These references motivate methods. They do not establish the correctness of
the proposed schema or its ecological transfer.

## 20. Attribution and limits

Retain:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Document credit and configured workstream metadata only.

No biological binding, verified identity, consent, authorization, execution
evidence, or authority is established.

No persistent memory, automatic telemetry, networking, publication, hardware
control, or durable storage is created by this document.
