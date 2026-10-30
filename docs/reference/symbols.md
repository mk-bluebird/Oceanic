# MATLAB symbol catalogue

<!-- matlab-outline:generated -->
Generator: `matlab-outline/1.0.0` | Schema: `1.0.0` | Backend: `stdlib-lexical-fallback` | Precision: `syntactic_outline_only`

> **This is a generated syntactic snapshot, not GitHub's native symbol outline or a precise reference index.**

## Coverage

- Source roots: `matlab`
- Files scanned: 12
- Files with symbols: 12
- Symbols recorded: 98
- Skipped files: 0
- Diagnostics: 0

## Backend and limitations

Backend `stdlib-lexical-fallback` is an outline approximation. `end_line` and `parent_scope` are shown as `null` wherever the backend cannot establish them. No properties, variable references, or method bindings are extracted, and no references are inferred from calls.

- Syntactic outline only: no type inference, no scope resolution, no call-graph or reference index.
- Not GitHub's native symbol outline; generating these files does not enable GitHub's MATLAB code-navigation service.
- end&#95;line and parent&#95;scope are null whenever the selected backend cannot establish them; null means unknown, not absent.
- No properties, variable references, or method bindings are extracted in this milestone.
- Signatures are public-output candidates only after the selected roots and generated changes have been reviewed; source existence does not imply release permission.
- Do not pass .lua files to the MATLAB backend; Lua indexing requires a separate extractor.

## Symbols by source file

### [`matlab/oceanic/limnology/oxygen\_budget\_accounting\_v2.m`](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | oxygen\_budget\_accounting\_v2 | result = oxygen\_budget\_accounting\_v2 \(varargin\) | 1 | [L1](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L1) | partial |
| function | budget | r = budget \(x\) | 28 | [L28](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L28) | partial |
| function | partitionFluxes | r = partitionFluxes \(fluxes\) | 192 | [L192](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L192) | partial |
| function | termRegistry | r = termRegistry \(\) | 255 | [L255](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L255) | partial |
| function | quantifiedStates | s = quantifiedStates \(\) | 266 | [L266](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L266) | partial |
| function | checkShape | e = checkShape \(x,required,optional,path\) | 271 | [L271](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L271) | partial |
| function | number | tf = number \(x\) | 288 | [L288](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L288) | partial |
| function | asText | t = asText \(x\) | 293 | [L293](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L293) | partial |
| function | good | r = good \(v\) | 302 | [L302](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L302) | partial |
| function | bad | r = bad \(code,path\) | 306 | [L306](../matlab/oceanic/limnology/oxygen_budget_accounting_v2.m#L306) | partial |

### [`matlab/oceanic/limnology/oxygen\_inquiry\_workbench.m`](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | oxygen\_inquiry\_workbench | result = oxygen\_inquiry\_workbench \(operation, input\) | 1 | [L1](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L1) | partial |
| function | oxygenBudget | r = oxygenBudget \(x\) | 40 | [L40](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L40) | partial |
| function | reviewTranslation | r = reviewTranslation \(x\) | 167 | [L167](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L167) | partial |
| function | runTests | r = runTests \(\) | 204 | [L204](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L204) | partial |
| function | fixture | x = fixture \(\) | 285 | [L285](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L285) | partial |
| function | exactStruct | tf = exactStruct \(value, keys\) | 308 | [L308](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L308) | partial |
| function | scalarNumber | tf = scalarNumber \(value\) | 315 | [L315](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L315) | partial |
| function | textRow | tf = textRow \(value\) | 320 | [L320](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L320) | partial |
| function | strcmpExact | tf = strcmpExact \(value, expected\) | 324 | [L324](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L324) | partial |
| function | success | r = success \(value\) | 328 | [L328](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L328) | partial |
| function | failure | r = failure \(code, path\) | 332 | [L332](../matlab/oceanic/limnology/oxygen_inquiry_workbench.m#L332) | partial |

### [`matlab/oceanic/population\_ecology/occupancy\_power\_baci\_workbench.m`](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | occupancy\_power\_baci\_workbench | result = occupancy\_power\_baci\_workbench \(varargin\) | 1 | [L1](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L1) | partial |
| function | occupancyLikelihood | r = occupancyLikelihood \(x\) | 27 | [L27](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L27) | partial |
| function | occupancyPower | r = occupancyPower \(x\) | 73 | [L73](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L73) | partial |
| function | rejectDecline | tf = rejectDecline \(before,after,n,alpha\) | 154 | [L154](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L154) | partial |
| function | baciContrast | r = baciContrast \(x\) | 166 | [L166](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L166) | partial |
| function | outcomes | tf = outcomes \(x\) | 218 | [L218](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L218) | partial |
| function | bernoulliSequenceLog | value = bernoulliSequenceLog \(d,k,p\) | 224 | [L224](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L224) | partial |
| function | logWeight | value = logWeight \(p\) | 230 | [L230](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L230) | partial |
| function | logAdd | value = logAdd \(a,b\) | 234 | [L234](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L234) | partial |
| function | exact | tf = exact \(x,keys\) | 243 | [L243](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L243) | partial |
| function | number | tf = number \(x\) | 249 | [L249](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L249) | partial |
| function | probability | tf = probability \(x\) | 254 | [L254](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L254) | partial |
| function | integerBound | tf = integerBound \(x,low,high\) | 258 | [L258](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L258) | partial |
| function | textValue | t = textValue \(x\) | 262 | [L262](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L262) | partial |
| function | good | r = good \(value\) | 272 | [L272](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L272) | partial |
| function | bad | r = bad \(code,path\) | 276 | [L276](../matlab/oceanic/population_ecology/occupancy_power_baci_workbench.m#L276) | partial |

### [`matlab/research/aquatic\_regime\_uncertainty.m`](../matlab/research/aquatic_regime_uncertainty.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | aquatic\_regime\_uncertainty | result = aquatic\_regime\_uncertainty \(draws, boundary\_margin\) | 1 | [L1](../matlab/research/aquatic_regime_uncertainty.m#L1) | partial |
| function | empirical\_quantiles | values = empirical\_quantiles \(samples, probabilities\) | 158 | [L158](../matlab/research/aquatic_regime_uncertainty.m#L158) | partial |
| function | run\_self\_tests | result = run\_self\_tests \(\) | 169 | [L169](../matlab/research/aquatic_regime_uncertainty.m#L169) | partial |

### [`matlab/research/candidate\_ranking\_evaluation.m`](../matlab/research/candidate_ranking_evaluation.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | candidate\_ranking\_evaluation | envelope = candidate\_ranking\_evaluation \(varargin\) | 1 | [L1](../matlab/research/candidate_ranking_evaluation.m#L1) | partial |
| function | make\_envelope | envelope = make\_envelope \(ok, value, failure, schema, module\) | 52 | [L52](../matlab/research/candidate_ranking_evaluation.m#L52) | partial |
| function | empty\_error | failure = empty\_error \(\) | 57 | [L57](../matlab/research/candidate_ranking_evaluation.m#L57) | partial |
| function | map\_exception | failure = map\_exception \(exception, debug\_local\) | 62 | [L62](../matlab/research/candidate_ranking_evaluation.m#L62) | partial |
| function | validate\_config | validate\_config \(config, query\_count, current\_schema\) | 85 | [L85](../matlab/research/candidate_ranking_evaluation.m#L85) | partial |
| function | check\_text | check\_text \(text, allow\_empty\) | 136 | [L136](../matlab/research/candidate_ranking_evaluation.m#L136) | partial |
| function | evaluate | result = evaluate \(D, labels, eligible, k, config\) | 144 | [L144](../matlab/research/candidate_ranking_evaluation.m#L144) | partial |
| function | metric | m = metric \(state\) | 257 | [L257](../matlab/research/candidate_ranking_evaluation.m#L257) | partial |
| function | recall\_metric | m = recall\_metric \(universe\_labels, returned\_relevant\) | 263 | [L263](../matlab/research/candidate_ranking_evaluation.m#L263) | partial |
| function | limit | value = limit \(code, message\) | 283 | [L283](../matlab/research/candidate_ranking_evaluation.m#L283) | partial |
| function | self\_tests | value = self\_tests \(\) | 287 | [L287](../matlab/research/candidate_ranking_evaluation.m#L287) | partial |
| function | must | must \(condition, name\) | 380 | [L380](../matlab/research/candidate_ranking_evaluation.m#L380) | partial |

### [`matlab/research/dimensionless\_retrieval\_evaluation.m`](../matlab/research/dimensionless_retrieval_evaluation.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | dimensionless\_retrieval\_evaluation | envelope = dimensionless\_retrieval\_evaluation \(varargin\) | 1 | [L1](../matlab/research/dimensionless_retrieval_evaluation.m#L1) | partial |
| function | evaluate | result = evaluate \(distances, relevance, eligible, k\) | 57 | [L57](../matlab/research/dimensionless_retrieval_evaluation.m#L57) | partial |
| function | self\_tests | result = self\_tests \(\) | 163 | [L163](../matlab/research/dimensionless_retrieval_evaluation.m#L163) | partial |
| function | must | must \(condition, name\) | 222 | [L222](../matlab/research/dimensionless_retrieval_evaluation.m#L222) | partial |

### [`matlab/research/function\_deficit\_duration\_evidence.m`](../matlab/research/function_deficit_duration_evidence.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | function\_deficit\_duration\_evidence | envelope = function\_deficit\_duration\_evidence \(varargin\) | 1 | [L1](../matlab/research/function_deficit_duration_evidence.m#L1) | partial |
| function | evaluate | result = evaluate \(edges, lower, upper, valid, tl, tu, duration, names\) | 60 | [L60](../matlab/research/function_deficit_duration_evidence.m#L60) | partial |
| function | longest\_run | longest = longest\_run \(mask, dt\) | 196 | [L196](../matlab/research/function_deficit_duration_evidence.m#L196) | partial |
| function | isfinite\_scalar | yes = isfinite\_scalar \(x\) | 213 | [L213](../matlab/research/function_deficit_duration_evidence.m#L213) | partial |
| function | self\_tests | result = self\_tests \(\) | 217 | [L217](../matlab/research/function_deficit_duration_evidence.m#L217) | partial |
| function | must | must \(condition, name\) | 263 | [L263](../matlab/research/function_deficit_duration_evidence.m#L263) | partial |

### [`matlab/research/interval\_criterion\_comparison.m`](../matlab/research/interval_criterion_comparison.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | interval\_criterion\_comparison | envelope = interval\_criterion\_comparison \(varargin\) | 1 | [L1](../matlab/research/interval_criterion_comparison.m#L1) | partial |
| function | check\_version | check\_version \(expected, supplied\) | 75 | [L75](../matlab/research/interval_criterion_comparison.m#L75) | partial |
| function | evaluate | result = evaluate \(observed, criterion, rule\) | 90 | [L90](../matlab/research/interval_criterion_comparison.m#L90) | partial |
| function | check\_bounds | check\_bounds \(x, shape, code\) | 179 | [L179](../matlab/research/interval_criterion_comparison.m#L179) | partial |
| function | relation\_code | value = relation\_code \(a, b\) | 188 | [L188](../matlab/research/interval_criterion_comparison.m#L188) | partial |
| function | limit | value = limit \(code, message\) | 197 | [L197](../matlab/research/interval_criterion_comparison.m#L197) | partial |
| function | self\_tests | result = self\_tests \(\) | 201 | [L201](../matlab/research/interval_criterion_comparison.m#L201) | partial |
| function | must | must \(condition, name\) | 262 | [L262](../matlab/research/interval_criterion_comparison.m#L262) | partial |

### [`matlab/research/matlab\_session\_resource\_budget.m`](../matlab/research/matlab_session_resource_budget.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | matlab\_session\_resource\_budget | envelope = matlab\_session\_resource\_budget \(varargin\) | 1 | [L1](../matlab/research/matlab_session_resource_budget.m#L1) | partial |
| function | evaluate | result = evaluate \(config\) | 63 | [L63](../matlab/research/matlab_session_resource_budget.m#L63) | partial |
| function | units | value = units \(bytes\) | 169 | [L169](../matlab/research/matlab_session_resource_budget.m#L169) | partial |
| function | check\_number | check\_number \(value, label, strictly\_positive\) | 175 | [L175](../matlab/research/matlab_session_resource_budget.m#L175) | partial |
| function | check\_name | check\_name \(value\) | 184 | [L184](../matlab/research/matlab_session_resource_budget.m#L184) | partial |
| function | check\_struct\_vector | check\_struct\_vector \(value, fields, label\) | 191 | [L191](../matlab/research/matlab_session_resource_budget.m#L191) | partial |
| function | self\_tests | result = self\_tests \(\) | 200 | [L200](../matlab/research/matlab_session_resource_budget.m#L200) | partial |
| function | must | must \(condition, name\) | 246 | [L246](../matlab/research/matlab_session_resource_budget.m#L246) | partial |

### [`matlab/research/oxygen\_linear\_crossing\_benchmark.m`](../matlab/research/oxygen_linear_crossing_benchmark.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | oxygen\_linear\_crossing\_benchmark | envelope = oxygen\_linear\_crossing\_benchmark \(varargin\) | 1 | [L1](../matlab/research/oxygen_linear_crossing_benchmark.m#L1) | partial |
| function | evaluate | result = evaluate \(c\) | 56 | [L56](../matlab/research/oxygen_linear_crossing_benchmark.m#L56) | partial |
| function | item | value = item \(code, message\) | 174 | [L174](../matlab/research/oxygen_linear_crossing_benchmark.m#L174) | partial |
| function | self\_tests | result = self\_tests \(\) | 178 | [L178](../matlab/research/oxygen_linear_crossing_benchmark.m#L178) | partial |
| function | must | must \(condition, name\) | 219 | [L219](../matlab/research/oxygen_linear_crossing_benchmark.m#L219) | partial |

### [`matlab/research/reference\_condition\_sensitivity.m`](../matlab/research/reference_condition_sensitivity.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | reference\_condition\_sensitivity | envelope = reference\_condition\_sensitivity \(varargin\) | 1 | [L1](../matlab/research/reference_condition_sensitivity.m#L1) | partial |
| function | evaluate | result = evaluate \(observed, references, fraction, names, unit\) | 57 | [L57](../matlab/research/reference_condition_sensitivity.m#L57) | partial |
| function | check\_text | check\_text \(value, code\) | 165 | [L165](../matlab/research/reference_condition_sensitivity.m#L165) | partial |
| function | self\_tests | result = self\_tests \(\) | 172 | [L172](../matlab/research/reference_condition_sensitivity.m#L172) | partial |
| function | must | must \(condition, name\) | 211 | [L211](../matlab/research/reference_condition_sensitivity.m#L211) | partial |

### [`matlab/research/synthetic\_attenuated\_logistic\_uncertainty.m`](../matlab/research/synthetic_attenuated_logistic_uncertainty.m)

| Kind | Name | Signature | Line | Link | Confidence |
| --- | --- | --- | --- | --- | --- |
| function | synthetic\_attenuated\_logistic\_uncertainty | envelope = synthetic\_attenuated\_logistic\_uncertainty \(varargin\) | 1 | [L1](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L1) | partial |
| function | evaluate | result = evaluate \(draws, optical, options\) | 68 | [L68](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L68) | partial |
| function | checked\_exp | y = checked\_exp \(x, name\) | 302 | [L302](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L302) | partial |
| function | check\_choice | check\_choice \(value, choices, label\) | 314 | [L314](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L314) | partial |
| function | check\_margin | check\_margin \(value, label\) | 321 | [L321](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L321) | partial |
| function | item | value = item \(code, message\) | 329 | [L329](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L329) | partial |
| function | type7 | q = type7 \(x, probabilities\) | 333 | [L333](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L333) | partial |
| function | self\_tests | result = self\_tests \(\) | 343 | [L343](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L343) | partial |
| function | must | must \(condition, name\) | 446 | [L446](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L446) | partial |
| function | expect\_code | expect\_code \(envelope, code\) | 453 | [L453](../matlab/research/synthetic_attenuated_logistic_uncertainty.m#L453) | partial |

## Attribution

Configured attribution: `bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7`

Credit and configured workstream metadata only; it does not establish identity, verification, consent, authorization, execution evidence, or authority.
