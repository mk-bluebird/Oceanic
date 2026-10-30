function envelope = reference_condition_sensitivity(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% envelope = reference_condition_sensitivity( ...
%     observed_bounds, reference_bounds, fraction, reference_names, unit)
%
% observed_bounds: finite nonnegative double 1-by-2 [lower upper].
% reference_bounds: finite strictly positive double r-by-2.
% fraction: finite double scalar, 0 < fraction <= 1.
% reference_names: cell vector of r nonempty character rows.
% unit: nonempty character row shared by observations and references.
%
% Higher indicator values are interpreted as better function support.
% Threshold = fraction * reference.
% Equality is non-deficit under the strict-below rule.
%
% No arguments runs synthetic self-tests.
% No files, networking, persistence, actuation, or ecological-state adoption.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 5
        value = evaluate(varargin{:});
    else
        error('ReferenceSensitivity:E_ARGUMENTS', ...
            'Supply the five documented inputs.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, ...
        'error', struct('code', '', 'path', '', 'message', ''));
catch exception
    prefix = 'ReferenceSensitivity:';
    if strncmp(exception.identifier, prefix, numel(prefix))
        code = exception.identifier(numel(prefix)+1:end);
        message = exception.message;
    else
        code = 'E_INTERNAL';
        message = 'Unexpected internal failure; inspect locally.';
    end
    envelope = struct('ok', false, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', [], ...
        'error', struct('code', code, 'path', '', 'message', message));
end
end

function result = evaluate(observed, references, fraction, names, unit)
if ~isa(observed, 'double') || ~isreal(observed) || ...
        ~isequal(size(observed), [1, 2]) || ...
        any(isnan(observed) | isinf(observed)) || ...
        any(observed < 0) || observed(1) > observed(2)
    error('ReferenceSensitivity:E_OBSERVATION', ...
        'Observation bounds must be finite, nonnegative, and ordered.');
end

if ~isa(references, 'double') || ~isreal(references) || ...
        ~ismatrix(references) || isempty(references) || ...
        size(references, 2) ~= 2 || ...
        any(isnan(references(:)) | isinf(references(:))) || ...
        any(references(:) <= 0) || ...
        any(references(:, 1) > references(:, 2))
    error('ReferenceSensitivity:E_REFERENCE', ...
        'Reference bounds must be finite, positive, ordered r-by-2 data.');
end

if ~isa(fraction, 'double') || ~isreal(fraction) || ...
        ~isscalar(fraction) || isnan(fraction) || isinf(fraction) || ...
        fraction <= 0 || fraction > 1
    error('ReferenceSensitivity:E_FRACTION', ...
        'The reference fraction must satisfy 0 < fraction <= 1.');
end

count = size(references, 1);
if ~iscell(names) || ~isvector(names) || numel(names) ~= count
    error('ReferenceSensitivity:E_NAMES', ...
        'Supply one descriptive name per reference.');
end
for j = 1:count
    check_text(names{j}, 'E_NAMES');
end
check_text(unit, 'E_UNIT');

thresholds = fraction .* references;
if any(thresholds(:) == 0) || ...
        any(isnan(thresholds(:)) | isinf(thresholds(:)))
    error('ReferenceSensitivity:E_NUMERIC_RANGE', ...
        'A positive threshold was not representable.');
end

template = struct('reference_name', '', ...
    'reference_bounds', [0, 0], ...
    'threshold_bounds', [0, 0], ...
    'comparison_state', '');
comparisons = repmat(template, 1, count);

deficit = false(count, 1);
nondeficit = false(count, 1);

for j = 1:count
    deficit(j) = observed(2) < thresholds(j, 1);
    nondeficit(j) = observed(1) >= thresholds(j, 2);

    state = 'unresolved';
    if deficit(j)
        state = 'definite_deficit';
    elseif nondeficit(j)
        state = 'definite_nondeficit';
    end

    comparisons(j).reference_name = names{j};
    comparisons(j).reference_bounds = references(j, :);
    comparisons(j).threshold_bounds = thresholds(j, :);
    comparisons(j).comparison_state = state;
end

sensitivity = 'unresolved_reference_sensitivity';
if all(deficit)
    sensitivity = 'deficit_across_tested_references';
elseif all(nondeficit)
    sensitivity = 'nondeficit_across_tested_references';
elseif any(deficit) && any(nondeficit)
    sensitivity = 'reference_sensitive';
end

result = struct();
result.status = 'research_only';
result.unit = unit;
result.observed_bounds = observed;
result.reference_fraction = fraction;
result.rule = 'strictly_below_fraction_of_reference';
result.comparisons = comparisons;
result.sensitivity_status = sensitivity;
result.reference_count = count;
result.definite_deficit_count = sum(deficit);
result.definite_nondeficit_count = sum(nondeficit);
result.unresolved_count = sum(~deficit & ~nondeficit);
result.reference_selection_verified = false;
result.unit_compatibility_verified = false;
result.persistence_duration_assessed = false;
result.functional_depletion_adopted = false;
result.recovery_assessed = false;
result.death_assessed = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = { ...
    'Results are conditional on the supplied reference set.', ...
    'Fraction-of-reference thresholds require independent justification.', ...
    'Bounds are not assumed to be confidence intervals.', ...
    'Complete reference inputs do not establish reference validity.', ...
    'No threshold duration or recovery pathway is evaluated.', ...
    'No ecological state, consent, or intervention authority is established.'};
end

function check_text(value, code)
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error(['ReferenceSensitivity:' code], ...
        'Names and units must be nonempty character rows.');
end
end

function result = self_tests()
observed = [4, 4];
references = [5, 5; 10, 10];
names = {'Synthetic reference A', 'Synthetic reference B'};
before = {observed, references, names};

a = reference_condition_sensitivity( ...
    observed, references, 0.5, names, 'synthetic_unit');
must(a.ok, 'baseline_envelope');
must(strcmp(a.value.sensitivity_status, 'reference_sensitive'), ...
    'reference_sensitive_case');
must(isequal(before, {observed, references, names}), 'nonmutation');

b = reference_condition_sensitivity( ...
    observed, references, 0.5, names, 'synthetic_unit');
must(isequaln(a, b), 'determinism');

equality = reference_condition_sensitivity( ...
    [5, 5], [10, 10], 0.5, {'Equality reference'}, 'synthetic_unit');
must(equality.ok && strcmp(equality.value.comparisons.comparison_state, ...
    'definite_nondeficit'), 'strict_threshold_equality');

uncertain = reference_condition_sensitivity( ...
    [4, 6], [10, 10], 0.5, {'Uncertain comparison'}, 'synthetic_unit');
must(uncertain.ok && strcmp(uncertain.value.sensitivity_status, ...
    'unresolved_reference_sensitivity'), 'uncertainty_preservation');

invalid = reference_condition_sensitivity( ...
    observed, [0, 1], 0.5, {'Invalid reference'}, 'synthetic_unit');
must(~invalid.ok && strcmp(invalid.error.code, 'E_REFERENCE'), ...
    'invalid_reference_error');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'envelopes', 'reference_sensitivity', ...
    'nonmutation', 'determinism', 'equality', ...
    'unresolved_bounds', 'invalid_reference'}});
end

function must(condition, name)
if ~condition
    error('ReferenceSensitivity:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
