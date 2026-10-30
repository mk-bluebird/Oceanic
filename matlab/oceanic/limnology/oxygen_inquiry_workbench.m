function result = oxygen_inquiry_workbench(operation, input)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit establishes no identity, consent, authorization, or authority.
% Local research calculations only. No I/O, storage, or actuation.
%
% Operations:
%   review_translation : record supplied fidelity judgments
%   budget             : constant-volume interval oxygen accounting
%   self_test          : run synthetic tests
%
% No toolboxes are required. Text uses MATLAB character row vectors.

if nargin ~= 2
    result = failure('E_ARGUMENTS', 'input');
    return
end

if ~ischar(operation) || ~isrow(operation)
    result = failure('E_OPERATION', 'operation');
    return
end

switch operation
    case 'review_translation'
        result = reviewTranslation(input);
    case 'budget'
        result = oxygenBudget(input);
    case 'self_test'
        if ~isstruct(input) || ~isscalar(input) || ~isempty(fieldnames(input))
            result = failure('E_TEST_INPUT', 'input');
            return
        end
        result = runTests();
    otherwise
        result = failure('E_OPERATION', 'operation');
end
end

function r = oxygenBudget(x)
required = {'volume_m3','duration_days','initial_mg_L','final_mg_L', ...
    'concentration_support','boundary_model','fluxes'};

if ~exactStruct(x, required)
    r = failure('E_INPUT_SHAPE', 'input');
    return
end

if ~scalarNumber(x.volume_m3) || x.volume_m3 <= 0 || ...
        ~scalarNumber(x.duration_days) || x.duration_days <= 0 || ...
        ~scalarNumber(x.initial_mg_L) || x.initial_mg_L < 0 || ...
        ~scalarNumber(x.final_mg_L) || x.final_mg_L < 0
    r = failure('E_QUANTITY', 'input');
    return
end

if ~strcmpExact(x.concentration_support, 'volume_weighted_mean') || ...
        ~strcmpExact(x.boundary_model, 'constant_volume_control_volume')
    r = failure('E_SCOPE_MODEL', 'input');
    return
end

names = {'inflow','outflow','air_exchange','production', ...
    'water_column_respiration','sediment_demand','other_demand'};
signs = [1 -1 1 1 -1 -1 -1];

if ~exactStruct(x.fluxes, names)
    r = failure('E_FLUX_SET', 'input.fluxes');
    return
end

knownNet = 0;
unresolved = {};
measured = {};
inferred = {};

for i = 1:numel(names)
    f = x.fluxes.(names{i});
    if ~isstruct(f) || ~isscalar(f) || ~isfield(f, 'state') || ...
            ~textRow(f.state)
        r = failure('E_FLUX_RECORD', 'input.fluxes');
        return
    end

    if any(strcmp(f.state, {'measured','inferred'}))
        if ~exactStruct(f, {'state','value','unit','time_support'}) || ...
                ~scalarNumber(f.value) || ...
                ~strcmpExact(f.unit, 'kg_O2_per_day') || ...
                ~strcmpExact(f.time_support, 'interval_mean')
            r = failure('E_FLUX_VALUE_OR_UNIT', 'input.fluxes');
            return
        end

        if ~strcmp(names{i}, 'air_exchange') && f.value < 0
            r = failure('E_FLUX_SIGN', 'input.fluxes');
            return
        end

        knownNet = knownNet + signs(i) * f.value;
        if strcmp(f.state, 'measured')
            measured{end+1} = names{i}; %#ok<AGROW>
        else
            inferred{end+1} = names{i}; %#ok<AGROW>
        end

    elseif any(strcmp(f.state, {'unknown','not_collected','withheld'}))
        if ~exactStruct(f, {'state'})
            r = failure('E_UNRESOLVED_WITH_VALUE', 'input.fluxes');
            return
        end
        unresolved{end+1} = names{i}; %#ok<AGROW>
    else
        r = failure('E_FLUX_STATE', 'input.fluxes');
        return
    end
end

initialMass = 0.001 * x.initial_mg_L * x.volume_m3;
finalMass = 0.001 * x.final_mg_L * x.volume_m3;
observedChange = finalMass - initialMass;

if any(~isfinite([knownNet initialMass finalMass observedChange]))
    r = failure('E_NUMERIC_RANGE', 'input');
    return
end

v = struct();
v.initial_inventory_kg_O2 = initialMass;
v.final_inventory_kg_O2 = finalMass;
v.observed_inventory_change_kg_O2 = observedChange;
v.known_net_flux_kg_O2_per_day = knownNet;
v.measured_terms = measured;
v.inferred_terms = inferred;
v.unresolved_terms = unresolved;
v.complete_flux_inventory_declared = isempty(unresolved);
v.omitted_processes_assessed = false;
v.measurement_uncertainty_propagated = false;
v.causal_attribution_established = false;
v.ecological_safety_assessed = false;

if isempty(unresolved)
    change = x.duration_days * knownNet;
    predictedMass = initialMass + change;
    residual = observedChange - change;
    predictedConcentration = predictedMass / (0.001 * x.volume_m3);

    if any(~isfinite([change predictedMass residual predictedConcentration]))
        r = failure('E_NUMERIC_RANGE', 'input');
        return
    end

    v.budget_status = 'complete_declared_terms';
    v.predicted_change_kg_O2 = change;
    v.predicted_final_inventory_kg_O2 = predictedMass;
    v.predicted_final_mg_L = predictedConcentration;
    v.inventory_residual_kg_O2 = residual;
    v.negative_predicted_inventory = predictedMass < 0;
    v.physical_feasibility_verified = false;
else
    v.budget_status = 'incomplete_declared_terms';
    v.prediction_status = 'not_computed';
end

r = success(v);
end

function r = reviewTranslation(x)
features = {'response','boundary','time_support','units', ...
    'assumptions','alternative_explanations'};

if ~exactStruct(x, features)
    r = failure('E_REVIEW_SHAPE', 'input');
    return
end

concerns = {};
unreviewed = {};
for i = 1:numel(features)
    status = x.(features{i});
    if ~textRow(status) || ...
            ~any(strcmp(status, {'preserved','concern','unreviewed'}))
        r = failure('E_REVIEW_STATUS', 'input');
        return
    end
    if strcmp(status, 'concern')
        concerns{end+1} = features{i}; %#ok<AGROW>
    elseif strcmp(status, 'unreviewed')
        unreviewed{end+1} = features{i}; %#ok<AGROW>
    end
end

v = struct();
v.review_record = x;
v.concerns = concerns;
v.unreviewed_features = unreviewed;
v.no_recorded_concerns = isempty(concerns);
v.all_features_reviewed = isempty(unreviewed);
v.translation_fidelity_verified = false;
v.empirical_premises_verified = false;
v.proof_checker_executed = false;
r = success(v);
end

function r = runTests()
names = { ...
    'synthetic_budget_closes', ...
    'unresolved_flux_is_not_zero', ...
    'incompatible_unit_is_rejected', ...
    'fidelity_concern_is_separate', ...
    'input_is_not_mutated', ...
    'finite_partition_enumeration'};

passed = false(1, numel(names));
for k = 1:numel(names)
    try
        switch k
            case 1
                x = fixture();
                y = oxygenBudget(x);
                assert(y.ok);
                assert(abs(y.value.inventory_residual_kg_O2) <= 1e-10);
            case 2
                x = fixture();
                x.fluxes.sediment_demand = struct('state','withheld');
                y = oxygenBudget(x);
                assert(y.ok);
                assert(strcmp(y.value.budget_status, ...
                    'incomplete_declared_terms'));
                assert(~isfield(y.value, 'predicted_change_kg_O2'));
            case 3
                x = fixture();
                x.fluxes.inflow.unit = 'mg_per_L';
                y = oxygenBudget(x);
                assert(~y.ok);
                assert(strcmp(y.error.code, 'E_FLUX_VALUE_OR_UNIT'));
            case 4
                q = struct('response','concern','boundary','preserved', ...
                    'time_support','preserved','units','preserved', ...
                    'assumptions','unreviewed', ...
                    'alternative_explanations','preserved');
                y = reviewTranslation(q);
                assert(y.ok && numel(y.value.concerns) == 1);
                assert(~y.value.translation_fidelity_verified);
            case 5
                x = fixture();
                before = x;
                y = oxygenBudget(x);
                assert(y.ok && isequaln(x, before));
            case 6
                states = {'supplied','unknown','not_collected', ...
                    'withheld','declared_not_applicable','absent'};
                cases = 0;
                for a = 1:6
                    for b = 1:6
                        for c = 1:6
                            assignment = {states{a}, states{b}, states{c}};
                            membership = false(6,3);
                            for s = 1:6
                                membership(s,:) = strcmp(assignment, states{s});
                            end
                            assert(all(sum(membership,1) == 1));
                            assert(sum(membership(:)) == 3);
                            cases = cases + 1;
                        end
                    end
                end
                assert(cases == 216);
        end
        passed(k) = true;
    catch
        passed(k) = false;
    end
end

v = struct();
v.test_names = names;
v.passed = passed;
v.passed_count = sum(passed);
v.failed_count = sum(~passed);
v.fixtures = 'synthetic';
v.formal_proof_established = false;
r = success(v);
end

function x = fixture()
x = struct();
x.volume_m3 = 1000;
x.duration_days = 2;
x.initial_mg_L = 8;
x.final_mg_L = 6;
x.concentration_support = 'volume_weighted_mean';
x.boundary_model = 'constant_volume_control_volume';

names = {'inflow','outflow','air_exchange','production', ...
    'water_column_respiration','sediment_demand','other_demand'};
values = [0 0 0.5 1 1 1.5 0];

x.fluxes = struct();
for i = 1:numel(names)
    x.fluxes.(names{i}) = struct( ...
        'state','measured', ...
        'value',values(i), ...
        'unit','kg_O2_per_day', ...
        'time_support','interval_mean');
end
end

function tf = exactStruct(value, keys)
tf = isstruct(value) && isscalar(value);
if ~tf, return; end
actual = fieldnames(value);
tf = numel(actual) == numel(keys) && all(ismember(keys, actual));
end

function tf = scalarNumber(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) ...
    && ~issparse(value) && isfinite(value);
end

function tf = textRow(value)
tf = ischar(value) && isrow(value) && ~isempty(value);
end

function tf = strcmpExact(value, expected)
tf = textRow(value) && strcmp(value, expected);
end

function r = success(value)
r = struct('ok',true,'value',value);
end

function r = failure(code, path)
e = struct();
e.code = code;
e.path = path;
e.message_key = ['oxygen_inquiry_workbench.' code];
e.args = struct();
r = struct('ok',false,'error',e);
end
