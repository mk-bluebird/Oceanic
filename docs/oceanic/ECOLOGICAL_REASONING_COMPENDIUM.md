# Oceanic Ecological Reasoning Compendium

> A typed vocabulary, a grammar for qualified claims, a library of stronger questions, and a set of reusable reasoning engines for studying water bodies, species, habitats, and the people who steward them.

---

## 0. What this document is — and what it is not

This is a **reasoning artifact**, not a model, not a source of new empirical
claims, and not a memory store. It compiles the distinctions that prevent
one kind of evidence from being mistaken for another. Its purpose is to
expand what a conversational system can *ask* and *distinguish*, not to
change what it claims to know.

The central capability is **typed reasoning**: knowing what a statement
means before calculating with it.

---

## 1. The core distinctions (the type system)

These pairs must not collapse. Each collapse produces a specific,
predictable error.

| Distinction | What it unlocks | What collapses if ignored |
|---|---|---|
| Presence vs. ecological function | Whether an interaction actually operates | Co-occurrence reported as mutualism |
| Activity vs. outcome | Honest restoration evaluation | Planted counted as recovered |
| Observation vs. latent state | Detection-aware monitoring | Nondetection reported as absence |
| Threshold crossing vs. stability loss | Mechanism-specific early warning | Every crossing labeled a bifurcation |
| Spatial average vs. local exposure | Refugia, hotspots, vulnerable layers | Basin means hiding lethal depths |
| Structure vs. interaction strength | Better food-web interpretation | Centrality reported as influence |
| Gross import vs. retained benefit | Nutrient and material accounting | Import counted as system gain |
| Source lineage vs. independent evidence | Deduplication of summaries | Five summaries counted as five studies |
| Model calculation vs. validated prediction | Honest forecast claims | A screen reported as a forecast |
| Permission declaration vs. authorization | Privacy- and rights-preserving work | A field labeled "granted" treated as consent |
| Measurement vs. reference-relative score | Preserved absolute exposure | A "suitable" score hiding an unsuitable baseline |
| Declared process class vs. verified similarity | Conditional comparison | Matching dimensionless groups called identical dynamics |
| Conditional hypothesis vs. universal claim | Falsifiable research | One counterexample failing everything or nothing |

---

## 2. The universal language (dimensionless and reference-anchored)

A water body — from a desert puddle to the Antarctic Circumpolar Current —
can be placed at a **dimensionless position** so that different analysts
can compare like with like.

### 2.1 Primitives

Represent a water body as
\[
\mathcal{W} = (V, A, h, \tau, \mathcal{B}, \mathcal{C})
\]
where \(V\) is volume [m³], \(A\) is surface area [m²], \(h = V/A\) is mean
depth [m], \(\tau\) is a **declared** residence or flushing time [s],
\(\mathcal{B}\) is a boundary-type tag (closed basin, reach, estuary,
lagoon, shelf, canal, wash, reservoir), and \(\mathcal{C}\) is a
connectivity tag (isolated, episodic, continuous, tidal).

Do not use one scalar \(\tau = V/Q\) as if every system obeyed a single
idealization. Inflow, outflow, effective exchange, storage change,
parcel-residence distribution, and bulk flushing time are different
quantities.

### 2.2 State split

Separate **intensive** quantities (\(T, S, \mathrm{pH}, \mathrm{O_2},
\mathrm{Chl}, \mathrm{Turb}, N, P, \mathrm{Tox}\)) from **extensive**
ones (volume, area, biomass, flux). Averaging pH is not equivalent to
mixing pH. Basin averages can hide an anoxic hypolimnion.

### 2.3 Candidate dimensionless coordinates

\[
\mathrm{Da} = \frac{k_{\text{react}}V}{Q},\quad
\mathrm{Pe} = \frac{uL}{K},\quad
\Pi_\tau = \frac{\tau_{\text{res}}}{\tau_{\text{bio}}},\quad
\mathrm{Ri} = \frac{N^2}{(\partial u/\partial z)^2},\quad
\Pi_{\text{gas}} = k_a\tau.
\]

Matching selected groups is **necessary for similarity within a declared
functional family** and **not sufficient** across families. Two systems
with the same four groups can differ in gas exchange, geometry, forcing,
or biology. Label the set "candidate coordinates for comparing specified
process regimes," not "the complete universal state variables."

### 2.4 Functional depletion, defined operationally

Pick a **nonempty essential function set** \(\mathcal{F}_{\text{essential}}\)
and a **reference condition** \(\mathbf{x}^{\text{ref}}\). Depletion is
the event that the joint suitability of an essential function falls below
a declared threshold and remains there for a declared interval.

Four operational states, not to be conflated:

| State | Condition |
|---|---|
| **Degradation** | downward trend, still above threshold |
| **Depletion** | persistently below threshold, some biota remain |
| **Collapse** | obligate taxa locally absent under an observation model |
| **No recovery observed** | collapse with no observed recovery within the horizon |

"Do not conflate nondetection with absence, or absence of observed
recovery with irreversible death."

### 2.5 Reference-anchored thresholds

Every threshold \(\theta\) is stated relative to a declared reference
\(\mathbf{x}^{\text{ref}}\), with a version, date, evidence class
(literature / monitoring / physiological tolerance / policy), and
uncertainty. A reference without provenance is a preference.

### 2.6 Composition rules (declare the ecological proposition)

Two composition operators answer different questions:

- **Bottleneck (Liebig):** \(S_{\min} = \min_i S_i\).
- **Weighted-geometric:** \(S_{\text{geo}} = \prod_i S_i^{w_i}\).

Neither is universally correct. A weighted deficit \(D = 1 - \sum_i w_i S_i\)
can conceal a severe deficit in one essential function. Retain the full
vector and non-compensatory constraints alongside any summary.

---

## 3. Grammar for ecological statements

### 3.1 Structure

\[
\text{subject} + \text{relationship} + \text{recipient or response}
+ \text{place} + \text{time}
+ \text{measurement support} + \text{evidence} + \text{limits}.
\]

A template, not a finding:

> "Within the surveyed reach during the declared season, the observations
> support a change in the specified response associated with the proposed
> process; detection and causal attribution remain unresolved."

### 3.2 The five layers

1. **Entity** — taxa, habitats, compartments, processes.
2. **Relationship** — consumes, supports habitat, disperses seeds,
   transports nutrients, occupies, reproduces, transfers across boundary.
3. **Scope** — where, when, at what resolution, for which population.
4. **Epistemic** — observed, estimated, inferred, assumed, hypothesized,
   proposed, predicted, validated.
5. **Governance** — what processing or disclosure is permitted.

Keep layer 5 separate. A scientifically informative statement is not
automatically authorized for publication.

### 3.3 Verbs require different evidence

| Verb | Requires |
|---|---|
| observed | an observation record |
| estimated | a method and inputs |
| associated with | a defined comparison |
| caused | a defensible causal design and assumptions |
| predicted | a forecast made without future outcomes |
| validated | a specified target and independent evaluation |
| authorized | the relevant authority — not a confidence score |

A useful assistant detects when a sentence quietly changes verbs.

### 3.4 Claim categories

- empirical finding
- source report
- reproducibility result
- assumption
- hypothesis
- design proposal
- decision recommendation
- forecast
- operational status

Categories are **not** a single order. A reproducibility result is
stronger than a source report *for the reproduction*, but not equivalent
to an independent finding. A proposal is not a finding. A forecast is not
an observed outcome.

---

## 4. Vocabulary by reasoning function

### 4.1 Organisms and life cycles

- **Taxon** — record the resolution.
- **Cohort** — a shared origin or entry period.
- **Life stage** — a biologically defined phase.
- **Recruitment** — entry into a specified population or stage.
- **Establishment** — persistence to a declared early endpoint.
- **Reproductive contribution** — spawning, viable gametes, or recruits,
  as *measured*, not as inferred from size.
- **Genet / ramet** — genetic individual vs. clonal unit.
- **Provenance** — origin and production history.

Questions this unlocks:
- "Are we measuring original-cohort survival, replacement through new
  recruitment, or continued additions?"
- "Is a fragment count being reported as a population recovery?"

### 4.2 Habitat and spatial context

- **Range** — broad distribution.
- **Occurrence** — observation at a stated place and time.
- **Occupancy / site use** — a modeled latent state appropriate to the
  survey design.
- **Suitability** — a declared relationship between conditions and an
  endpoint.
- **Refugium** — candidate place of reduced exposure or improved
  persistence, with the mechanism specified.
- **Connectivity** — structural vs. functional.
- **Spatial support** — the area or volume a measurement represents.
- **Resolution** — granularity of observation or representation.

Questions this unlocks:
- "Does the map represent presence, suitability, or successful passage?"
- "Does a regional mean conceal a local exceedance?"

### 4.3 Processes and budgets

- **Stock, flux, loading, retention, export, production, respiration.**
- **Residence vs. flushing time** — related, not interchangeable.
- **Gross vs. net** — import vs. retained material.
- **Element budget** — mass conservation at a declared boundary.

Mass balance at a boundary:
\[
\Delta M = \text{inputs} - \text{outputs} + \text{declared internal transformations}.
\]
Internal transfers cancel at the whole-system level; do not double-count
carcasses, gametes, and original mass as three imports.

### 4.4 Evidence and uncertainty

- Observation process.
- Detection probability.
- Measurement error.
- Censoring, truncation.
- Missingness mechanism (not just "missing").
- Confounding, identifiability.
- Calibration, transferability.
- Sensitivity analysis, counterfactual.

Questions this unlocks:
- "Could the apparent change arise from how, where, or when we observed?"
- "Is an interval a measurement bound, a confidence interval, a credible
  interval, or a scenario range?"

### 4.5 Rights and governance

- **Consent declaration** — a recorded statement, not proof of authority.
- **Permission** — purpose-specific; not implied by sensitivity.
- **Disclosure tier** — restricted original, controlled analysis,
  generalized review, public release.
- **Custody** — community, Tribal, agency, landholder.
- **Rights basis** — copyright, license, community protocol, embargo,
  withheld.

Questions this unlocks:
- "For which purpose, with which authority, and under which permitted use?"
- "Does aggregation actually remove re-identification risk, or only
  reduce it?"

---

## 5. Reasoning engines

### Engine A — Measurement

Every numerical input carries
\((\text{quantity},\text{value},\text{unit},\text{space},\text{time},\text{method},\text{uncertainty})\).
Ask: consistent denominator? mixed wet/dry mass? legitimate unit
conversion? changed survey method? zero observation vs. missing-value
replacement?

### Engine B — Conservation accounting

For connected compartments: \(\Delta M = \text{inputs} - \text{outputs} + \text{transforms}\).
Ask: are carcasses, gametes, and original mass double-counted? Is sediment
storage omitted? Is a tissue isotope fraction being treated as a
watershed flux? Gross import or net retention?

### Engine C — Observation vs. state

Latent occupancy \(z_s \sim \mathrm{Bernoulli}(\psi_s)\), detection
\(y_{sk} \sim \mathrm{Bernoulli}(z_s p_{sk})\). Ask: repeat visits?
closure respected? could disappearance be movement or nondetection?
does detection vary with size, season, habitat complexity?

### Engine D — Mechanism and causality

Write the competing pathways explicitly (shared driver, mediator, direct
effect). Ask: which mediator was measured? what comparison approximates
the counterfactual? did conditioning on survivors remove the pathway?

### Engine E — Life cycle and function

Track transitions:
installed → surviving → reproductive → recruits → persistent population.
Each arrow is a question. Ask: are planted additions masking low natural
recruitment? does spawning habitat connect to juvenile habitat? are
compatible partners present at the right time?

### Engine F — Scale and applicability

Dimensionless comparison is conditional. Ask: are governing equations,
boundaries, and forcing comparable? is the system well-mixed or stratified?
does a regional average hide local exposure? is an undefined parameter
being treated as zero?

### Engine G — Forecast and warning

Separate: detection of a present condition, prediction of a future
condition, delivery of a warning, and a beneficial response.

Delivered lead time: \(L = t_{\text{onset}} - t_{\text{received}}\).
If onset is uncertain, report an interval — never select the latest
plausible onset. Ask: was future information used? does the model beat
seasonal or persistence baselines? were non-events included? is apparent
lead time actually reporting delay?

### Engine H — Evidence lineage

Separate a source, its production activity, and the responsible agent.
Distinct roots are not statistically independent evidence. Ask: do
several summaries reuse one dataset? do apparently separate studies share
controls or sites? was a model prediction copied as an observation? is
the source still applicable after revision?

### Engine I — Conditional universality

A hypothesis quantified over "every water body" is not falsified by a
system that fails its assumptions. Freeze before outcome inspection:

- process class,
- assumption checks (met / not met / unknown),
- event definition,
- precursor definition,
- observation adequacy,
- comparator,
- decision rule.

Unknown is not a pass. Retain excluded and inconclusive cases.
Distinguish "eligible counterexample to a strict claim" from "probabilistic
performance claim" and from "inconclusive test."

### Engine J — Rights and governance

Before using ecological knowledge, ask: who determines whether it may be
used, for which purpose, in which form, under which continuing
responsibilities? Is the source community-governed, Tribal-governed,
agency-custodied, private landholder? Is "public availability" being
mistaken for permission to reuse? Is a sensitivity declaration being
read as publication authority?

---

## 6. Stronger question patterns

| Pattern | Capability unlocked |
|---|---|
| "What exactly is the response and denominator?" | Measurement clarification |
| "What observation would distinguish these explanations?" | Study design |
| "Which assumptions are necessary for this calculation?" | Applicability assessment |
| "Where could this conclusion fail?" | Boundary-case reasoning |
| "What is unmeasured rather than zero?" | Missingness reasoning |
| "Which stage connects the intervention to the claimed outcome?" | Mechanistic decomposition |
| "What changes when spatial or temporal resolution changes?" | Scale sensitivity |
| "What would a useful baseline predict?" | Forecast evaluation |
| "Which sources share underlying observations?" | Evidence deduplication |
| "What would count as a counterexample?" | Falsifiable research |
| "What information can remain uncollected?" | Data minimization |
| "Who determines whether this knowledge may be used?" | Governance-aware reasoning |
| "Is the pathway drift, bifurcation, or forcing?" | Mechanism-specific warning |
| "Is the dimensionless similarity conditional or claimed universal?" | Process-class reasoning |
| "Is this a declaration or an authorization?" | Rights-preserving reasoning |

### Expansions of common short questions

- "Which seed source is best?" → "For which recipient environment, survival
  horizon, reproductive endpoint, genetic representation, and permitted
  transfer conditions?"
- "Did restoration work?" → "Was implementation completed, did the
  specified ecological response occur, and did that response persist
  through the observed conditions?"
- "Is a lake approaching collapse?" → "Which function is threatened, what
  exposure was measured, what model applies, and what out-of-sample
  evidence supports the forecast?"
- "Is this a reliable source?" → "Reliable for which claim, in which
  context, with what lineage, methods, review, and uncertainty?"

---

## 7. Knowledge development chain

\[
\text{question} \rightarrow \text{typed problem}
\rightarrow \text{evidence requirements}
\rightarrow \text{applicable calculation}
\rightarrow \text{qualified result}
\rightarrow \text{next discriminating question}.
\]

The last step matters. Better questions reduce uncertainty or distinguish
mechanisms — not merely generate more terminology.

Prioritize, in order:
1. A coherent quantity and endpoint.
2. A compatible observation design.
3. Explicit uncertainty and missingness.
4. Appropriate scope.
5. Independent validation.
6. Permitted use.

A proposal, a functioning module, a passing test suite, a fitted model, a
validated model, and a deployed warning system are different achievements.
Do not slide between them.

---

## 8. Human relationships

Include people, stewardship, access, food relationships, livelihoods,
and community priorities without reducing them to extraction rates or a
universal utility score. CBD guidance recognizes management objectives as
societal choices.

Appropriate documentation may be a public description, a restricted
record, or **no recording of protected details**. Absence of public
cultural information is not evidence that a relationship does not exist.

Respect augmented-citizen and cybernetic-host self-descriptions and
communication needs without requiring proof or technical inventory.
Communication variation is not a competence signal. Participant-chosen
pacing, assistive entry, and correction pathways are design requirements,
not concessions.

---

## 9. Recommended Oceanic architecture

Maintain small, linked components:

- **Vocabulary** — definitions, units, scope, inverse relationships.
- **Question frames** — what is asked, what is missing.
- **Evidence records** — source, production, lineage, applicability.
- **Measurement records** — values with explicit non-observed states.
- **Models** — assumptions, parameters, diagnostics, validation.
- **Reports** — accessible conclusions with interpretation limits.
- **Governance** — permitted processing and disclosure.

Keep protected or unnecessary data out of the reasoning context. Each
component's interpretation limits should be machine-readable, not buried
in prose.

---

## 10. Companion code

The supplied `lua/oceanic/question_frame_audit.lua` module (schema 1) and
its named test file remain valid. The module implements only the
completeness-checking portion of section 9's question-frame component. It
does not answer the question, retrieve evidence, select a model, or verify
scientific content.

A future companion that scores vocabulary conformance or detects claim
verb drift — a validator that recognizes when a draft has silently moved
from "associated with" to "caused," or from "modelled" to "observed" — is
a natural next artifact and is not yet implemented.

---

## 11. What this compilation enables next

The most valuable next step is a **reviewed vocabulary-and-question
corpus**: for each term or pattern, a precise definition, common
confusions, a well-formed claim, an overextended claim, questions that
resolve the difference, and relevant mathematical or observational tests.

That corpus should preserve disagreements and unresolved knowledge rather
than forcing every ecological question into a completed answer.
