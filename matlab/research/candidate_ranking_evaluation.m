function envelope = candidate_ranking_evaluation(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% envelope = candidate_ranking_evaluation(D, labels, eligible, k, config)
%
% D: finite nonnegative real double candidate-by-query matrix.
% labels: same-sized double; -1 unknown, 0 irrelevant, 1 relevant.
% eligible: same-sized logical; caller-supplied permission/compatibility result.
% k: positive integer double scalar.
%
% config fields, exactly:
% expected_schema_version: semantic version character row, e.g. '2.0.0'
% debug_local: logical scalar; keep false in production or shared outputs
% universe_type: 'curated_evaluation_sample' or 'declared_deployed_index'
% queries: struct vector, one entry per query, with exactly:
%   question_title, response_scope, source_document_path
%
% No arguments runs synthetic self-tests.
% Undefined numerical metric fields are NaN, never zero.
% NaN must be converted to null plus state before JSON export.
% No files, networking, persistence, or external actions.

schema_version = '2.0.0';
module_version = '2.0.0';
debug_local = false;

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 5
        config = varargin{5};
        validate_config(config, size(varargin{1}, 2), schema_version);
        debug_local = config.debug_local;
        value = evaluate(varargin{1}, varargin{2}, ...
            varargin{3}, varargin{4}, config);
    else
        error('Oceanic:CandidateRanking:E_ARGUMENTS', ...
            'Supply distances, labels, eligibility, k, and configuration.');
    end
    envelope = make_envelope(true, value, ...
        empty_error(), schema_version, module_version);
catch exception
    failure = map_exception(exception, debug_local);
    envelope = make_envelope(false, [], failure, ...
        schema_version, module_version);
end
end

function envelope = make_envelope(ok, value, failure, schema, module)
envelope = struct('ok', ok, 'schema_version', schema, ...
    'module_version', module, 'value', value, 'error', failure);
end

function failure = empty_error()
failure = struct('code', '', 'message', '', ...
    'debug', struct('enabled', false, 'identifier', '', 'message', ''));
end

function failure = map_exception(exception, debug_local)
failure = empty_error();
public_prefix = 'Oceanic:CandidateRanking:';
test_prefix = 'Oceanic:CandidateRankingSelfTest:';

if strncmp(exception.identifier, test_prefix, numel(test_prefix))
    failure.code = 'E_SELF_TEST';
    failure.message = exception.message;
elseif strncmp(exception.identifier, public_prefix, numel(public_prefix))
    failure.code = exception.identifier(numel(public_prefix) + 1:end);
    failure.message = exception.message;
else
    failure.code = 'E_INTERNAL';
    failure.message = 'Unexpected internal failure; inspect locally.';
end

if debug_local
    failure.debug.enabled = true;
    failure.debug.identifier = exception.identifier;
    failure.debug.message = exception.message;
end
end

function validate_config(config, query_count, current_schema)
fields = {'expected_schema_version', 'debug_local', ...
    'universe_type', 'queries'};
if ~isstruct(config) || ~isscalar(config) || ...
        ~isequal(sort(fieldnames(config)), sort(fields(:)))
    error('Oceanic:CandidateRanking:E_CONFIG', ...
        'Configuration must contain exactly the documented fields.');
end

version = config.expected_schema_version;
if ~ischar(version) || ~isrow(version) || ...
        isempty(regexp(version, ...
        '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$', 'once'))
    error('Oceanic:CandidateRanking:E_SCHEMA_VERSION', ...
        'Expected schema version must have numeric major.minor.patch form.');
end
expected_parts = strsplit(version, '.');
current_parts = strsplit(current_schema, '.');
if ~strcmp(expected_parts{1}, current_parts{1})
    error('Oceanic:CandidateRanking:E_SCHEMA_MISMATCH', ...
        'Expected and supplied schema major versions differ.');
end

if ~islogical(config.debug_local) || ~isscalar(config.debug_local)
    error('Oceanic:CandidateRanking:E_CONFIG', ...
        'debug_local must be a logical scalar.');
end

if ~ischar(config.universe_type) || ~isrow(config.universe_type) || ...
        ~any(strcmp(config.universe_type, ...
        {'curated_evaluation_sample', 'declared_deployed_index'}))
    error('Oceanic:CandidateRanking:E_UNIVERSE', ...
        'Declare the supplied candidate-universe type.');
end

query_fields = {'question_title', 'response_scope', 'source_document_path'};
queries = config.queries;
if ~isstruct(queries) || ~isvector(queries) || ...
        numel(queries) ~= query_count || ...
        ~isequal(sort(fieldnames(queries)), sort(query_fields(:)))
    error('Oceanic:CandidateRanking:E_QUERY_SCOPE', ...
        'Provide one documented query-scope structure per query.');
end

for j = 1:numel(queries)
    check_text(queries(j).question_title, false);
    check_text(queries(j).response_scope, false);
    check_text(queries(j).source_document_path, true);
end
end

function check_text(text, allow_empty)
if ~ischar(text) || ~(isrow(text) || isempty(text)) || ...
        (~allow_empty && isempty(strtrim(text)))
    error('Oceanic:CandidateRanking:E_QUERY_SCOPE', ...
        'Query metadata must use character rows with nonempty titles and scopes.');
end
end

function result = evaluate(D, labels, eligible, k, config)
if ~isa(D, 'double') || ~isreal(D) || ~ismatrix(D) || isempty(D) || ...
        any(isnan(D(:)) | isinf(D(:))) || any(D(:) < 0)
    error('Oceanic:CandidateRanking:E_DISTANCE', ...
        'Distances must be a finite nonnegative real double matrix.');
end
if ~isa(labels, 'double') || ~isreal(labels) || ...
        ~isequal(size(labels), size(D)) || ...
        any(~ismember(labels(:), [-1, 0, 1]))
    error('Oceanic:CandidateRanking:E_RELEVANCE', ...
        'Labels must match distances and contain only -1, 0, or 1.');
end
if ~islogical(eligible) || ~isequal(size(eligible), size(D))
    error('Oceanic:CandidateRanking:E_ELIGIBILITY', ...
        'Eligibility must be a same-sized logical matrix.');
end
if ~isa(k, 'double') || ~isreal(k) || ~isscalar(k) || ...
        isnan(k) || isinf(k) || k < 1 || k ~= floor(k)
    error('Oceanic:CandidateRanking:E_K', ...
        'k must be a finite positive integer double scalar.');
end

template = struct('question_title', '', 'response_scope', '', ...
    'source_document_path', '', 'returned_row_positions', zeros(0, 1), ...
    'requested_k', k, 'returned_count', 0, 'eligible_count', 0, ...
    'known_relevant_returned', 0, 'unknown_returned', 0, ...
    'known_relevant_ineligible', 0, ...
    'precision', metric('undefined_empty_return'), ...
    'judgment_coverage', metric('undefined_empty_return'), ...
    'recall_full_universe', metric('unresolved'), ...
    'recall_eligible_universe', metric('unresolved'));

queries = repmat(template, 1, size(D, 2));

for j = 1:size(D, 2)
    rows = find(eligible(:, j));
    sortable = [D(rows, j), rows];
    [~, order] = sortrows(sortable, [1, 2]);
    returned = rows(order(1:min(k, numel(order))));
    returned_labels = labels(returned, j);

    n = numel(returned);
    relevant = sum(returned_labels == 1);
    unknown = sum(returned_labels == -1);

    q = template;
    q.question_title = config.queries(j).question_title;
    q.response_scope = config.queries(j).response_scope;
    q.source_document_path = config.queries(j).source_document_path;
    q.returned_row_positions = returned;
    q.returned_count = n;
    q.eligible_count = numel(rows);
    q.known_relevant_returned = relevant;
    q.unknown_returned = unknown;
    q.known_relevant_ineligible = ...
        sum(labels(:, j) == 1 & ~eligible(:, j));

    q.precision.denominator = n;
    q.precision.numerator = relevant;
    q.precision.unknown_count = unknown;
    if n > 0
        q.precision.state = 'logical_bounds';
        q.precision.lower = relevant / n;
        q.precision.upper = (relevant + unknown) / n;
        q.precision.meaning = ...
            'Worst-case bounds; unknown labels independently in {0,1}.';
        if unknown == 0
            q.precision.state = 'computed';
            q.precision.value = relevant / n;
        end

        q.judgment_coverage.state = 'computed';
        q.judgment_coverage.value = (n - unknown) / n;
        q.judgment_coverage.lower = q.judgment_coverage.value;
        q.judgment_coverage.upper = q.judgment_coverage.value;
        q.judgment_coverage.numerator = n - unknown;
        q.judgment_coverage.denominator = n;
        q.judgment_coverage.unknown_count = unknown;
        q.judgment_coverage.meaning = 'Fraction of returned labels judged.';
    end

    q.recall_full_universe = recall_metric(labels(:, j), relevant);
    q.recall_eligible_universe = recall_metric(labels(rows, j), relevant);
    queries(j) = q;
end

result = struct();
result.status = 'research_only';
result.query_results = queries;
result.universe_type = config.universe_type;
result.candidate_universe_size = size(D, 1);
result.distance_provenance = 'supplied_by_caller';
result.distance_definition_verified = false;
result.eligibility_verified = false;
result.judgments_verified = false;
result.analogue_status = 'candidate_only';
result.verdict_basis = {'no_physical_scope_verification', ...
    'no_uncertainty_propagation', 'no_heldout_validation'};
result.tie_policy = 'distance_then_original_row_position';
result.undefined_numeric_representation = 'NaN; export as null with state';
result.unknown_label_assumption = ...
    'Independent binary completions; no aggregate contextual constraints.';
result.interpretation_limits = [ ...
    limit('R_SAMPLE_SCOPE', 'Metrics describe the supplied universe only.'), ...
    limit('R_NO_EQUIVALENCE', 'Ranking metrics do not establish ecological equivalence.'), ...
    limit('R_PERMISSIONS', 'Eligibility flags do not verify permission.'), ...
    limit('R_BOUNDS', 'Logical bounds are not confidence intervals.'), ...
    limit('R_DEBUG', 'Debug details may contain private data; local use only.')];
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.external_actions = 'none';
end

function m = metric(state)
m = struct('state', state, 'value', NaN, 'lower', NaN, 'upper', NaN, ...
    'numerator', NaN, 'denominator', NaN, 'known_relevant', NaN, ...
    'unknown_count', NaN, 'meaning', 'undefined');
end

function m = recall_metric(universe_labels, returned_relevant)
m = metric('not_reported_unknown_universe');
m.numerator = returned_relevant;
m.known_relevant = sum(universe_labels == 1);
m.unknown_count = sum(universe_labels == -1);
m.meaning = 'Relevant returned divided by relevant in this declared universe.';
if m.unknown_count > 0
    return;
end
m.denominator = m.known_relevant;
if m.denominator == 0
    m.state = 'undefined_no_relevant_candidates';
    return;
end
m.state = 'computed';
m.value = returned_relevant / m.denominator;
m.lower = m.value;
m.upper = m.value;
end

function value = limit(code, message)
value = struct('code', code, 'message', message);
end

function value = self_tests()
D = [0.1, 0.3; 0.2, 0.1; 0.3, 0.2];
labels = [1, 0; 0, 1; 1, -1];
eligible = true(3, 2);
k = 2;
query = struct('question_title', 'Synthetic ranking comparison', ...
    'response_scope', 'Synthetic response only', 'source_document_path', '');
config = struct('expected_schema_version', '2.0.0', ...
    'debug_local', false, 'universe_type', 'curated_evaluation_sample', ...
    'queries', repmat(query, 1, 2));

before = {D, labels, eligible, k, config};
a = candidate_ranking_evaluation(D, labels, eligible, k, config);
must(a.ok, 'baseline_success');
must(isequaln(before, {D, labels, eligible, k, config}), 'nonmutation');
b = candidate_ranking_evaluation(D, labels, eligible, k, config);
must(isequaln(a, b), 'determinism');

q = a.value.query_results;
must(abs(q(1).precision.value - 0.5) < 1e-12, 'precision');
must(abs(q(1).recall_full_universe.value - 0.5) < 1e-12, 'recall');
must(isnan(q(2).precision.value) && ...
    abs(q(2).precision.upper - 1) < 1e-12, 'unknown_bounds');
must(isstruct(q) && ~iscell(q), 'struct_array');
must(~isempty(a.value.interpretation_limits), 'interpretation_limits');

none = candidate_ranking_evaluation(D, labels, false(3, 2), 10, config);
must(none.ok && strcmp(none.value.query_results(1).precision.state, ...
    'undefined_empty_return'), 'empty_state');
must(isequal(fieldnames(q(1).precision), ...
    fieldnames(none.value.query_results(1).precision)), 'uniform_fields');

large = candidate_ranking_evaluation(D, labels, eligible, 10, config);
must(large.ok && large.value.query_results(1).returned_count == 3 && ...
    large.value.query_results(1).precision.denominator == 3, 'large_k');

filtered = eligible;
filtered(3, 1) = false;
c = candidate_ranking_evaluation(D, labels, filtered, k, config);
must(c.ok && abs(c.value.query_results(1).recall_full_universe.value - 0.5) ...
    < 1e-12 && abs(c.value.query_results(1).recall_eligible_universe.value ...
    - 1) < 1e-12, 'dual_recall');

partial = eligible;
partial(3, 2) = false;
d = candidate_ranking_evaluation(D, labels, partial, k, config);
must(d.ok && strcmp(d.value.query_results(2).recall_eligible_universe.state, ...
    'computed') && strcmp(d.value.query_results(2).recall_full_universe.state, ...
    'not_reported_unknown_universe'), 'unknown_ineligible');

bad_config = config;
bad_config.expected_schema_version = '3.0.0';
failure = candidate_ranking_evaluation(D, labels, eligible, k, bad_config);
must(~failure.ok && strcmp(failure.error.code, 'E_SCHEMA_MISMATCH'), ...
    'schema_mismatch');
must(strcmp(a.schema_version, '2.0.0') && ...
    strcmp(a.module_version, '2.0.0'), 'versions');

single_config = config;
single_config.queries = query;
tie = candidate_ranking_evaluation([0.2; 0.1; 0.1; 0.3], ...
    [0; 1; 1; 0], true(4, 1), 3, single_config);
must(tie.ok && isequal(tie.value.query_results.returned_row_positions, ...
    [2; 3; 1]), 'mixed_ties');

invalid = labels;
invalid(1, 1) = NaN;
failure = candidate_ranking_evaluation(D, invalid, eligible, k, config);
must(~failure.ok && strcmp(failure.error.code, 'E_RELEVANCE'), ...
    'negative_error_code');

caught = false;
try
    reshape(1, 2, 2);
catch exception
    caught = true;
    sanitized = map_exception(exception, false);
    local_debug = map_exception(exception, true);
    must(strcmp(sanitized.code, 'E_INTERNAL') && ...
        isempty(sanitized.debug.message), 'internal_sanitization');
    must(local_debug.debug.enabled && ...
        ~isempty(local_debug.debug.message), 'local_debug');
end
must(caught, 'builtin_failure_exercised');

value = struct('status', 'synthetic_self_tests_passed', ...
    'executed_when_called', true, 'field_validation', 'not_performed', ...
    'coverage', {{'uniform_fields', 'struct_array', 'nonmutation', ...
    'determinism', 'precision', 'dual_recall', 'unknown_labels', ...
    'empty_states', 'large_k', 'schema_gate', 'mixed_ties', ...
    'error_codes', 'internal_sanitization', 'debug', 'interpretation_limits'}});
end

function must(condition, name)
if ~condition
    error('Oceanic:CandidateRankingSelfTest:Failure', ...
        'Synthetic self-test failed: %s.', name);
end
end
