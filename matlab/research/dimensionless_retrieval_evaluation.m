function envelope = dimensionless_retrieval_evaluation(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Normal call:
% envelope = dimensionless_retrieval_evaluation( ...
%     distances, relevance, eligible, k)
%
% Matrices are candidate-by-query:
% distances: finite nonnegative real double ranking distances.
% relevance: double values -1 unknown, 0 irrelevant, 1 relevant.
% eligible: logical; permission and compatibility checks occur upstream.
% k: positive integer double scalar.
%
% No arguments runs synthetic self-tests.
% No files, networking, random sampling, storage, or external actions.
%
% Precision denominator: actual number returned, not requested k.
% Recall denominator: relevant candidates in the entire supplied universe.
% Recall is withheld if any relevance label in that query is unknown.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 4
        value = evaluate(varargin{1}, varargin{2}, ...
            varargin{3}, varargin{4});
    else
        error('RetrievalEvaluation:E_ARGUMENTS', ...
            'Supply distances, relevance, eligible, and k.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'RetrievalEvaluation:';
    if strncmp(exception.identifier, prefix, numel(prefix))
        code = exception.identifier(numel(prefix) + 1:end);
        message = exception.message;
    else
        code = 'E_INTERNAL';
        message = 'Unexpected internal failure; review locally.';
    end
    envelope = struct('ok', false, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', [], ...
        'error', struct('code', code, 'message', message));
end
end

function result = evaluate(distances, relevance, eligible, k)
if ~isa(distances, 'double') || ~isreal(distances) || ...
        ~ismatrix(distances) || isempty(distances) || ...
        any(isnan(distances(:)) | isinf(distances(:))) || ...
        any(distances(:) < 0)
    error('RetrievalEvaluation:E_DISTANCE', ...
        'Distances must be a finite nonnegative real double matrix.');
end

if ~isa(relevance, 'double') || ~isreal(relevance) || ...
        ~isequal(size(relevance), size(distances)) || ...
        any(~ismember(relevance(:), [-1, 0, 1]))
    error('RetrievalEvaluation:E_RELEVANCE', ...
        'Relevance must match distances and contain only -1, 0, or 1.');
end

if ~islogical(eligible) || ...
        ~isequal(size(eligible), size(distances))
    error('RetrievalEvaluation:E_ELIGIBILITY', ...
        'Eligibility must be a same-sized logical matrix.');
end

if ~isa(k, 'double') || ~isreal(k) || ~isscalar(k) || ...
        isnan(k) || isinf(k) || k < 1 || k ~= floor(k)
    error('RetrievalEvaluation:E_K', ...
        'k must be a finite positive integer double scalar.');
end

query_results = cell(1, size(distances, 2));

for query = 1:size(distances, 2)
    candidates = find(eligible(:, query));
    sortable = [distances(candidates, query), candidates];
    [~, order] = sortrows(sortable, [1, 2]);
    returned = candidates(order(1:min(k, numel(order))));
    labels = relevance(returned, query);

    count = numel(returned);
    known_relevant = sum(labels == 1);
    unknown_returned = sum(labels == -1);
    judged_returned = sum(labels ~= -1);

    precision = struct('state', 'undefined_empty_return');
    coverage = struct('state', 'undefined_empty_return');

    if count > 0
        precision = struct('state', 'bounds_from_judgments', ...
            'lower', known_relevant / count, ...
            'upper', (known_relevant + unknown_returned) / count, ...
            'denominator', count, ...
            'meaning', 'Identification bounds, not confidence bounds');
        coverage = struct('state', 'computed', ...
            'fraction', judged_returned / count);
    end

    universe_labels = relevance(:, query);
    recall = struct('state', 'not_reported_unknown_universe');

    if all(universe_labels ~= -1)
        relevant_total = sum(universe_labels == 1);
        if relevant_total == 0
            recall = struct('state', 'undefined_no_relevant_candidates');
        else
            recall = struct('state', 'computed', ...
                'value', known_relevant / relevant_total, ...
                'denominator', relevant_total);
        end
    end

    query_results{query} = struct( ...
        'returned_row_positions', returned, ...
        'requested_k', k, ...
        'returned_count', count, ...
        'eligible_count', numel(candidates), ...
        'known_relevant_returned', known_relevant, ...
        'unknown_returned', unknown_returned, ...
        'precision', precision, ...
        'judgment_coverage', coverage, ...
        'recall', recall, ...
        'known_relevant_ineligible', ...
            sum(universe_labels == 1 & ~eligible(:, query)));
end

result = struct();
result.status = 'research_only';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.query_results = query_results;
result.candidate_universe_size = size(distances, 1);
result.query_count = size(distances, 2);
result.tie_policy = 'distance_then_original_row_position';
result.eligibility_verified = false;
result.judgments_verified = false;
result.analogue_status = 'candidate_only';
result.uncertainty_intervals = 'not_estimated';
result.cross_validation = 'not_performed';
result.external_actions = 'none';
result.interpretation_limits = { ...
    'Rank evaluation does not establish ecological equivalence.', ...
    'Eligibility is supplied, not verified.', ...
    'Unknown judgments are not treated as irrelevant.', ...
    'Recall uses the entire supplied candidate universe.', ...
    'Input row positions are local matrix locators, not public identifiers.', ...
    'No automatic permission, storage, or release approval is granted.'};
end

function result = self_tests()
distances = [0.1, 0.3; 0.2, 0.1; 0.3, 0.2];
relevance = [1, 0; 0, 1; 1, -1];
eligible = true(3, 2);

before = distances;
a = dimensionless_retrieval_evaluation( ...
    distances, relevance, eligible, 2);
must(a.ok, 'baseline_envelope');
must(isequal(distances, before), 'input_nonmutation');

b = dimensionless_retrieval_evaluation( ...
    distances, relevance, eligible, 2);
must(isequaln(a, b), 'determinism');

q = a.value.query_results{1};
must(q.precision.lower == 0.5 && q.precision.upper == 0.5, ...
    'fully_judged_precision');
must(q.recall.value == 0.5, 'full_universe_recall');

q = a.value.query_results{2};
must(q.precision.lower == 0.5 && q.precision.upper == 1, ...
    'unknown_precision_bounds');
must(strcmp(q.recall.state, 'not_reported_unknown_universe'), ...
    'unknown_recall_withheld');

none = dimensionless_retrieval_evaluation( ...
    distances, relevance, false(3, 2), 2);
must(none.ok && none.value.query_results{1}.returned_count == 0, ...
    'empty_return');

filtered = eligible;
filtered(1, 1) = false;
c = dimensionless_retrieval_evaluation( ...
    distances, relevance, filtered, 2);
must(c.ok && c.value.query_results{1}.known_relevant_ineligible == 1, ...
    'ineligible_relevant_recorded');

invalid = relevance;
invalid(1, 1) = NaN;
failure = dimensionless_retrieval_evaluation( ...
    distances, invalid, eligible, 2);
must(~failure.ok && strcmp(failure.error.code, 'E_RELEVANCE'), ...
    'invalid_judgment_error_code');

tied = zeros(3, 1);
tie_result = dimensionless_retrieval_evaluation( ...
    tied, [1; 0; 1], true(3, 1), 2);
must(tie_result.ok && isequal( ...
    tie_result.value.query_results{1}.returned_row_positions, [1; 2]), ...
    'deterministic_tie_order');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'test_coverage', {{'envelopes', 'nonmutation', 'determinism', ...
    'precision', 'recall', 'unknown_judgments', 'empty_returns', ...
    'eligibility_exclusions', 'negative_error_codes', 'ties'}});
end

function must(condition, name)
if ~condition
    error('RetrievalEvaluation:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
