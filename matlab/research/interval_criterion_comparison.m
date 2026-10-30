function envelope = interval_criterion_comparison(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = interval_criterion_comparison( ...
%     observed_bounds, criterion_bounds, rule, expected_schema_version)
%
% First three arguments are required.
% expected_schema_version is optional; default '1.0.0'.
%
% observed_bounds: finite real double 1-by-2 [lower upper].
%
% rule:
%   'minimum_support' : adverse when y < threshold
%   'maximum_tolerable': adverse when y > threshold
%   'acceptable_band' : adverse outside the band
%
% criterion_bounds:
%   One-sided: 1-by-2 [threshold_lower threshold_upper].
%   Band: 2-by-2; row 1 lower-limit bounds, row 2 upper-limit bounds.
%         Requires criterion_bounds(1,2) <= criterion_bounds(2,1).
%
% Equality is non-adverse.
% No arguments runs synthetic self-tests.
% No files, networking, persistence, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    else
        if nargin < 3
            error('IntervalCriterion:E_ARGUMENTS_MIN', ...
                'At least three arguments are required.');
        elseif nargin > 4
            error('IntervalCriterion:E_ARGUMENTS_MAX', ...
                'At most four arguments are accepted.');
        end

        expected = schema_version;
        if nargin == 4
            expected = varargin{4};
        end
        check_version(expected, schema_version);
        value = evaluate(varargin{1}, varargin{2}, varargin{3});
    end

    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'IntervalCriterion:';
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
        'error', struct('code', code, 'path', '', ...
            'message', message, 'debug_message', ''));
end
end

function check_version(expected, supplied)
if ~ischar(expected) || ~isrow(expected) || ...
        isempty(regexp(expected, ...
        '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$', 'once'))
    error('IntervalCriterion:E_SCHEMA_VERSION', ...
        'Expected schema version must use major.minor.patch.');
end
a = strsplit(expected, '.');
b = strsplit(supplied, '.');
if ~strcmp(a{1}, b{1})
    error('IntervalCriterion:E_SCHEMA_MAJOR_MISMATCH', ...
        'Expected and supplied schema major versions differ.');
end
end

function result = evaluate(observed, criterion, rule)
check_bounds(observed, [1, 2], 'E_OBSERVATION');

if ~ischar(rule) || ~isrow(rule) || ...
        ~any(strcmp(rule, ...
        {'minimum_support', 'maximum_tolerable', 'acceptable_band'}))
    error('IntervalCriterion:E_RULE', ...
        'Select a documented criterion rule.');
end

if strcmp(rule, 'acceptable_band')
    check_bounds(criterion, [2, 2], 'E_CRITERION');
    if criterion(1, 2) > criterion(2, 1)
        error('IntervalCriterion:E_BAND_ORDER', ...
            'Every allowed lower limit must not exceed every upper limit.');
    end
else
    check_bounds(criterion, [1, 2], 'E_CRITERION');
end

yL = observed(1);
yU = observed(2);

if strcmp(rule, 'minimum_support')
    deficit = yU < criterion(1);
    nondeficit = yL >= criterion(2);
elseif strcmp(rule, 'maximum_tolerable')
    deficit = yL > criterion(2);
    nondeficit = yU <= criterion(1);
else
    deficit = yU < criterion(1, 1) || yL > criterion(2, 2);
    nondeficit = yL >= criterion(1, 2) && yU <= criterion(2, 1);
end

if deficit && nondeficit
    error('IntervalCriterion:E_INVARIANT', ...
        'Deficit and non-deficit predicates must be exclusive.');
end

state = 'unresolved';
if deficit
    state = 'definite_deficit';
elseif nondeficit
    state = 'definite_nondeficit';
end

endpoint_relations = zeros(2, numel(criterion));
endpoints = criterion(:);
for j = 1:numel(endpoints)
    endpoint_relations(1, j) = relation_code(yL, endpoints(j));
    endpoint_relations(2, j) = relation_code(yU, endpoints(j));
end

result = struct();
result.status = 'research_only';
result.comparison_state = state;
result.rule_used = rule;
result.observed_bounds = observed;
result.criterion_bounds = criterion;
result.observation_width = observed(2) - observed(1);
result.observation_width_representable = ...
    ~isinf(result.observation_width);
result.endpoint_relations = endpoint_relations;
result.endpoint_relation_encoding = struct( ...
    'less', -1, 'equal', 0, 'greater', 1);
result.endpoint_relation_layout = ...
    'Rows: observed lower/upper; columns: criterion(:) in MATLAB order.';
result.input_provenance = 'caller_supplied_not_verified';
result.unit_compatibility_verified = false;
result.temporal_support_verified = false;
result.persistence_assessed = false;
result.recovery_assessed = false;
result.ecological_state_adopted = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    limit('R_CRITERION_VALIDITY', ...
        'Numerical comparison does not validate the ecological criterion.'), ...
    limit('R_INTERVAL_SUPPORT', ...
        'Bounds must represent compatible scientific support.'), ...
    limit('R_NO_REMEDY_INFERENCE', ...
        'Overlap geometry does not identify the best next measurement.'), ...
    limit('R_NO_PROBABILITY', ...
        'Interval classifications are not event probabilities.'), ...
    limit('R_NO_RECOVERY', ...
        'No recovery horizon or functional-extinction mapping is evaluated.')];
end

function check_bounds(x, shape, code)
if ~isa(x, 'double') || ~isreal(x) || ...
        ~isequal(size(x), shape) || ...
        any(isnan(x(:)) | isinf(x(:))) || any(x(:, 1) > x(:, 2))
    error(['IntervalCriterion:' code], ...
        'Supply finite ordered real double bounds of the documented shape.');
end
end

function value = relation_code(a, b)
value = 0;
if a < b
    value = -1;
elseif a > b
    value = 1;
end
end

function value = limit(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
cases = {
    [4, 4], [5, 5], 'minimum_support', 'definite_deficit';
    [4, 4], [3, 3], 'maximum_tolerable', 'definite_deficit';
    [4, 6], [5, 5], 'minimum_support', 'unresolved';
    [5, 5], [5, 5], 'minimum_support', 'definite_nondeficit';
    [-2, -1], [0, 0], 'minimum_support', 'definite_deficit';
    [4, 6], [2, 3; 7, 8], 'acceptable_band', 'definite_nondeficit';
    [0, 1], [2, 3; 7, 8], 'acceptable_band', 'definite_deficit';
    [2, 4], [2, 3; 7, 8], 'acceptable_band', 'unresolved'
};

for j = 1:size(cases, 1)
    before = cases(j, 1:3);
    a = interval_criterion_comparison(cases{j, 1:3});
    must(a.ok && isempty(a.error), 'success_envelope');
    must(strcmp(a.value.comparison_state, cases{j, 4}), ...
        'criterion_case');
    b = interval_criterion_comparison(cases{j, 1:3});
    must(isequaln(a, b), 'determinism');
    must(isequaln(before, cases(j, 1:3)), 'nonmutation');
end

threshold = 1.0;
below = interval_criterion_comparison( ...
    [threshold-eps(threshold), threshold-eps(threshold)], ...
    [threshold, threshold], 'minimum_support');
must(below.ok && strcmp(below.value.comparison_state, ...
    'definite_deficit'), 'representable_below_boundary');

tiny = realmin / 2;
subnormal = interval_criterion_comparison( ...
    [0, 0], [tiny, tiny], 'minimum_support');
must(subnormal.ok && strcmp(subnormal.value.comparison_state, ...
    'definite_deficit'), 'subnormal_threshold');

negative = {
    [2, 1], [1, 1], 'minimum_support', 'E_OBSERVATION';
    [1, 1], [2, 1], 'minimum_support', 'E_CRITERION';
    [1, 1], [1, 1], 'unknown_rule', 'E_RULE';
    [1, 1], [1, 4; 3, 5], 'acceptable_band', 'E_BAND_ORDER'
};

for j = 1:size(negative, 1)
    failure = interval_criterion_comparison(negative{j, 1:3});
    must(~failure.ok && strcmp(failure.error.code, negative{j, 4}), ...
        'negative_error_code');
end

version = interval_criterion_comparison( ...
    [1, 1], [1, 1], 'minimum_support', '2.0.0');
must(~version.ok && strcmp(version.error.code, ...
    'E_SCHEMA_MAJOR_MISMATCH'), 'version_gate');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'directions', 'bands', 'signed_values', 'zero_threshold', ...
    'equality', 'subnormal', 'determinism', 'nonmutation', ...
    'error_codes', 'schema_gate', 'success_error_empty'}});
end

function must(condition, name)
if ~condition
    error('IntervalCriterion:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
