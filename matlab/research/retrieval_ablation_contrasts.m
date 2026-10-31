function envelope = retrieval_ablation_contrasts(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = retrieval_ablation_contrasts(scores, metric_name, direction)
%
% scores: real double n-by-4, n >= 1.
% Columns:
% A: keyword baseline, plain representation
% B: candidate method, plain representation
% C: keyword baseline, structured representation
% D: candidate method, structured representation
%
% NaN means an unavailable condition result, never zero performance.
% Inf is invalid.
%
% direction: 'higher_is_better' or 'lower_is_better'
% Contrasts use original units; direction is declared, not transformed.
%
% Rows are equally weighted within each available paired contrast.
% No standard errors, confidence intervals, or hypothesis tests.
% No arguments runs synthetic self-tests.
% No files, networking, persistence, indexing, or publication.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 3
        value = evaluate(varargin{:});
    else
        error('RetrievalAblation:E_ARGUMENTS', ...
            'Supply scores, metric name, and direction.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'RetrievalAblation:';
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

function result = evaluate(scores, metric_name, direction)
if ~isa(scores, 'double') || ~isreal(scores) || ...
        ~ismatrix(scores) || size(scores, 1) < 1 || ...
        size(scores, 2) ~= 4 || any(isinf(scores(:)))
    error('RetrievalAblation:E_SCORES', ...
        'Scores must be real double n-by-4 with finite values or NaN.');
end

if ~ischar(metric_name) || ~isrow(metric_name) || ...
        isempty(strtrim(metric_name))
    error('RetrievalAblation:E_METRIC', ...
        'Supply a nonempty metric name.');
end

if ~ischar(direction) || ~isrow(direction) || ...
        ~any(strcmp(direction, {'higher_is_better', 'lower_is_better'}))
    error('RetrievalAblation:E_DIRECTION', ...
        'Declare whether higher or lower metric values are preferable.');
end

C = [
    -1,  1,  0,  0;
     0,  0, -1,  1;
    -1,  0,  1,  0;
     0, -1,  0,  1;
     1, -1, -1,  1
];

names = {
    'method_difference_plain';
    'method_difference_structured';
    'structure_difference_baseline';
    'structure_difference_candidate';
    'method_by_structure_interaction'
};

n = size(scores, 1);
paired = NaN(n, 5);
template = struct('contrast_name', '', ...
    'available_row_count', 0, 'total_row_count', n, ...
    'coverage', 0, 'mean_difference', NaN, ...
    'state', 'unavailable');
summaries = repmat(template, 1, 5);

for j = 1:5
    needed = C(j, :) ~= 0;
    available = all(~isnan(scores(:, needed)), 2);

    values = scores(available, needed) * C(j, needed)';
    if any(isnan(values) | isinf(values))
        error('RetrievalAblation:E_NUMERIC_RANGE', ...
            'Contrast arithmetic exceeded numerical range.');
    end

    paired(available, j) = values;
    count = sum(available);

    summaries(j).contrast_name = names{j};
    summaries(j).available_row_count = count;
    summaries(j).coverage = count / n;

    if count > 0
        average = mean(values);
        if isnan(average) || isinf(average)
            error('RetrievalAblation:E_NUMERIC_RANGE', ...
                'Mean contrast exceeded numerical range.');
        end
        summaries(j).mean_difference = average;
        summaries(j).state = 'computed_on_available_pairs';
    end
end

result = struct();
result.status = 'descriptive_ablation_calculation';
result.metric_name = metric_name;
result.metric_direction = direction;
result.condition_order = {'A_plain_baseline', 'B_plain_candidate', ...
    'C_structured_baseline', 'D_structured_candidate'};
result.contrast_matrix = C;
result.per_row_contrasts = paired;
result.summaries = summaries;
result.all_four_conditions_available = all(~isnan(scores), 2);
result.row_weighting = 'equal_within_available_contrast';
result.independent_evaluation_units_verified = false;
result.common_information_access_verified = false;
result.heldout_integrity_verified = false;
result.statistical_uncertainty_estimated = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_DESCRIPTIVE', 'Differences do not establish statistical significance.'), ...
    item('R_SUPPORT', 'Contrasts may use different available-row sets.'), ...
    item('R_INTERACTION', 'Interaction uses rows with all four conditions.'), ...
    item('R_FAIRNESS', 'The function does not verify equal information or tuning budgets.'), ...
    item('R_SECURITY', 'No index separation or permission enforcement is implemented.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
scores = [0.4, 0.5, 0.6, 0.8; 0.5, 0.6, 0.7, 0.9];
before = scores;

a = retrieval_ablation_contrasts(scores, ...
    'Synthetic performance', 'higher_is_better');
must(a.ok, 'baseline');
expected = [0.1, 0.2, 0.2, 0.3, 0.1];
must(max(abs([a.value.summaries.mean_difference] - expected)) ...
    < 1e-12, 'known_contrasts');
must(isequal(scores, before), 'nonmutation');

b = retrieval_ablation_contrasts(scores, ...
    'Synthetic performance', 'higher_is_better');
must(isequaln(a, b), 'determinism');

missing = scores;
missing(2, 4) = NaN;
c = retrieval_ablation_contrasts(missing, ...
    'Synthetic performance', 'higher_is_better');
must(c.ok && c.value.summaries(1).available_row_count == 2 && ...
    c.value.summaries(5).available_row_count == 1, ...
    'paired_missingness');

invalid = retrieval_ablation_contrasts([1, 2, 3], ...
    'Synthetic performance', 'higher_is_better');
must(~invalid.ok && strcmp(invalid.error.code, 'E_SCORES'), ...
    'invalid_shape');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'known_contrasts', 'nonmutation', ...
    'determinism', 'paired_missingness', 'invalid_shape'}});
end

function must(condition, name)
if ~condition
    error('RetrievalAblation:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
