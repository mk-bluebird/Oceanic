function envelope = function_deficit_duration_evidence(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = function_deficit_duration_evidence( ...
%   edges_seconds, lower, upper, valid, ...
%   threshold_lower, threshold_upper, duration_seconds, function_names)
%
% edges_seconds: finite double (n+1)-by-1, strictly increasing.
% lower, upper: real double n-by-f interval-supported indicator bounds.
% valid: logical n-by-f; false means unavailable interval evidence.
% threshold_lower, threshold_upper: finite double 1-by-f.
% duration_seconds: positive finite double 1-by-f.
% function_names: cell vector of f nonempty character rows.
%
% All indicators are oriented higher-is-better.
% Each function's indicator and thresholds must use compatible units.
% Bounds must apply throughout each interval, not just at sampled instants.
% Invalid cells are ignored; no zero or healthy state is inferred from them.
% No arguments runs synthetic self-tests.
%
% No networking, files, storage, hardware action, or threshold adoption.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 8
        value = evaluate(varargin{:});
    else
        error('FunctionEvidence:E_ARGUMENTS', ...
            'Supply the eight documented inputs.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, ...
        'error', struct('code', '', 'message', ''));
catch exception
    prefix = 'FunctionEvidence:';
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
        'error', struct('code', code, 'message', message));
end
end

function result = evaluate(edges, lower, upper, valid, tl, tu, duration, names)
if ~isa(lower, 'double') || ~isa(upper, 'double') || ...
        ~isreal(lower) || ~isreal(upper) || ~ismatrix(lower) || ...
        isempty(lower) || ~isequal(size(lower), size(upper))
    error('FunctionEvidence:E_BOUNDS', ...
        'Indicator bounds must be same-sized real double matrices.');
end

[n, f] = size(lower);

if ~islogical(valid) || ~isequal(size(valid), [n, f])
    error('FunctionEvidence:E_VALIDITY', ...
        'Validity must be a same-sized logical matrix.');
end

if ~isa(edges, 'double') || ~isreal(edges) || ...
        ~isequal(size(edges), [n+1, 1]) || ...
        any(isnan(edges) | isinf(edges))
    error('FunctionEvidence:E_TIME', ...
        'Time edges must be finite double (n+1)-by-1.');
end

dt = diff(edges);
total = edges(end) - edges(1);
if any(dt <= 0 | isnan(dt) | isinf(dt)) || ...
        ~isfinite_scalar(total) || total <= 0
    error('FunctionEvidence:E_TIME', ...
        'Intervals must have finite positive durations.');
end

vectors = {tl, tu, duration};
for j = 1:numel(vectors)
    x = vectors{j};
    if ~isa(x, 'double') || ~isreal(x) || ...
            ~isequal(size(x), [1, f]) || ...
            any(isnan(x) | isinf(x))
        error('FunctionEvidence:E_THRESHOLD', ...
            'Thresholds and durations must be finite double 1-by-f.');
    end
end

if any(tl > tu) || any(duration <= 0)
    error('FunctionEvidence:E_THRESHOLD', ...
        'Threshold bounds must be ordered; durations must be positive.');
end

if any(isnan(lower(valid)) | isinf(lower(valid))) || ...
        any(isnan(upper(valid)) | isinf(upper(valid))) || ...
        any(lower(valid) > upper(valid))
    error('FunctionEvidence:E_BOUNDS', ...
        'Valid intervals require finite ordered indicator bounds.');
end

if ~iscell(names) || ~isvector(names) || numel(names) ~= f
    error('FunctionEvidence:E_NAMES', ...
        'Provide one descriptive function name per column.');
end
for j = 1:f
    if ~ischar(names{j}) || ~isrow(names{j}) || ...
            isempty(strtrim(names{j}))
        error('FunctionEvidence:E_NAMES', ...
            'Function names must be nonempty character rows.');
    end
end

definite = valid & bsxfun(@lt, upper, tl);
nondeficit = valid & bsxfun(@ge, lower, tu);
possible = ~nondeficit;

template = struct('function_name', '', ...
    'criterion_status', '', ...
    'longest_definite_deficit_seconds', 0, ...
    'longest_possible_deficit_seconds', 0, ...
    'required_duration_seconds', 0, ...
    'observed_time_fraction', 0);
assessments = repmat(template, 1, f);

for j = 1:f
    definite_run = longest_run(definite(:, j), dt);
    possible_run = longest_run(possible(:, j), dt);

    state = 'indeterminate';
    if definite_run >= duration(j)
        state = 'criterion_met';
    elseif possible_run < duration(j)
        state = 'criterion_not_met';
    end

    assessments(j).function_name = names{j};
    assessments(j).criterion_status = state;
    assessments(j).longest_definite_deficit_seconds = definite_run;
    assessments(j).longest_possible_deficit_seconds = possible_run;
    assessments(j).required_duration_seconds = duration(j);
    assessments(j).observed_time_fraction = sum(dt(valid(:, j))) / total;
end

joint_lower = zeros(f);
joint_upper = zeros(f);
for a = 1:f
    for b = a:f
        lo = sum(dt(definite(:, a) & definite(:, b))) / total;
        hi = sum(dt(possible(:, a) & possible(:, b))) / total;
        joint_lower(a, b) = lo;
        joint_lower(b, a) = lo;
        joint_upper(a, b) = hi;
        joint_upper(b, a) = hi;
    end
end

result = struct();
result.status = 'research_only';
result.assessments = assessments;
result.definite_interval_deficit = definite;
result.possible_interval_deficit = possible;
result.joint_deficit_time_fraction_lower = joint_lower;
result.joint_deficit_time_fraction_upper = joint_upper;
result.observation_window_seconds = total;
result.threshold_rule = 'strictly_below';
result.threshold_approval_verified = false;
result.interval_support_verified = false;
result.functional_depletion_adopted = false;
result.collapse_assessed = false;
result.death_assessed = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = { ...
    'Criterion results are not adopted ecological states.', ...
    'Bounds must support every instant in each interval.', ...
    'Missing intervals remain possible deficits, not confirmed deficits.', ...
    'Joint fractions describe simultaneous interval deficits, not correlation.', ...
    'Joint fractions do not impose the persistence-duration rule.', ...
    'Logical bounds are not confidence intervals.', ...
    'No extrapolation beyond the supplied window is performed.'};
end

function longest = longest_run(mask, dt)
current = 0;
longest = 0;
for j = 1:numel(dt)
    if mask(j)
        current = current + dt(j);
        if ~isfinite_scalar(current)
            error('FunctionEvidence:E_NUMERIC_RANGE', ...
                'Duration accumulation exceeded numerical range.');
        end
        longest = max(longest, current);
    else
        current = 0;
    end
end
end

function yes = isfinite_scalar(x)
yes = isscalar(x) && ~isnan(x) && ~isinf(x);
end

function result = self_tests()
edges = [0; 1; 2; 3];
lower = [0.1, 0.1; 0.1, 0; 0.9, 0.9];
upper = [0.2, 0.2; 0.2, 0; 1.0, 1.0];
valid = logical([1, 1; 1, 0; 1, 1]);
names = {'Synthetic function A', 'Synthetic function B'};
before = {edges, lower, upper, valid};

a = function_deficit_duration_evidence( ...
    edges, lower, upper, valid, [0.5, 0.5], [0.5, 0.5], [2, 2], names);
must(a.ok, 'baseline');
must(strcmp(a.value.assessments(1).criterion_status, ...
    'criterion_met'), 'definite_duration');
must(strcmp(a.value.assessments(2).criterion_status, ...
    'indeterminate'), 'missing_interval_uncertainty');
must(abs(a.value.joint_deficit_time_fraction_lower(1, 2) - 1/3) ...
    < 1e-12, 'joint_lower');
must(abs(a.value.joint_deficit_time_fraction_upper(1, 2) - 2/3) ...
    < 1e-12, 'joint_upper');
must(isequal(before, {edges, lower, upper, valid}), 'nonmutation');

b = function_deficit_duration_evidence( ...
    edges, lower, upper, valid, [0.5, 0.5], [0.5, 0.5], [2, 2], names);
must(isequaln(a, b), 'determinism');

bad_edges = [0; 1; 1; 3];
failure = function_deficit_duration_evidence( ...
    bad_edges, lower, upper, valid, [0.5, 0.5], ...
    [0.5, 0.5], [2, 2], names);
must(~failure.ok && strcmp(failure.error.code, 'E_TIME'), 'invalid_time');

equal_lower = ones(3, 1) * 0.5;
equal_upper = equal_lower;
equal_case = function_deficit_duration_evidence( ...
    edges, equal_lower, equal_upper, true(3, 1), ...
    0.5, 0.5, 1, {'Equality fixture'});
must(equal_case.ok && strcmp( ...
    equal_case.value.assessments.criterion_status, ...
    'criterion_not_met'), 'strict_threshold_equality');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'duration', 'missingness', 'cooccurrence_bounds', ...
    'nonmutation', 'determinism', 'invalid_time', 'threshold_equality'}});
end

function must(condition, name)
if ~condition
    error('FunctionEvidence:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
