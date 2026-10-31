function envelope = digest_selection_composition_audit(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = digest_selection_composition_audit( ...
%     eligible_counts, selected_counts, category_names, frame_description)
%
% Counts: same-sized nonnegative integer double column vectors.
% Each selected count must not exceed its eligible count.
% Categories must be mutually exclusive under a declared coding rule.
%
% This is an audit of the supplied discovery frame, not ecological prevalence.
% No confidence intervals, causal attribution, or bias correction.
% No arguments runs synthetic self-tests.
% No files, networking, persistence, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 4
        value = evaluate(varargin{:});
    else
        error('DigestAudit:E_ARGUMENTS', ...
            'Supply eligible counts, selected counts, names, and frame description.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'DigestAudit:';
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

function result = evaluate(eligible, selected, names, frame)
vectors = {eligible, selected};
for j = 1:2
    x = vectors{j};
    if ~isa(x, 'double') || ~isreal(x) || ~ismatrix(x) || ...
            isempty(x) || size(x, 2) ~= 1 || ...
            any(isnan(x) | isinf(x)) || any(x < 0) || ...
            any(x ~= floor(x)) || any(x > flintmax)
        error('DigestAudit:E_COUNTS', ...
            'Counts must be nonnegative integer double column vectors.');
    end
end

if ~isequal(size(eligible), size(selected))
    error('DigestAudit:E_SHAPE', 'Count vectors must have matching shapes.');
end
if any(selected > eligible)
    error('DigestAudit:E_SUBSET', ...
        'Selected counts cannot exceed eligible counts.');
end

k = numel(eligible);
if ~iscell(names) || ~isvector(names) || numel(names) ~= k
    error('DigestAudit:E_NAMES', 'Supply one category name per count.');
end
names = names(:)';
for j = 1:k
    check_text(names{j}, 'E_NAMES');
end
if numel(unique(names)) ~= k
    error('DigestAudit:E_NAMES', 'Category names must be distinct.');
end
check_text(frame, 'E_FRAME');

eligible_total = safe_integer_sum(eligible);
selected_total = safe_integer_sum(selected);

rate = NaN(k, 1);
has_eligible = eligible > 0;
rate(has_eligible) = selected(has_eligible) ./ eligible(has_eligible);

eligible_share = NaN(k, 1);
selected_share = NaN(k, 1);
difference = NaN(k, 1);
tv = NaN;
comparison_state = 'unavailable';

if eligible_total > 0
    eligible_share = eligible / eligible_total;
end
if selected_total > 0
    selected_share = selected / selected_total;
end
if eligible_total > 0 && selected_total > 0
    difference = selected_share - eligible_share;
    tv = 0.5 * sum(abs(difference));
    comparison_state = 'descriptive_comparison_available';
end

template = struct('category_name', '', 'eligible_count', 0, ...
    'selected_count', 0, 'selection_rate', NaN, ...
    'selection_rate_defined', false, 'eligible_share', NaN, ...
    'selected_share', NaN, 'selected_minus_eligible_share', NaN);
categories = repmat(template, 1, k);

for j = 1:k
    categories(j).category_name = names{j};
    categories(j).eligible_count = eligible(j);
    categories(j).selected_count = selected(j);
    categories(j).selection_rate = rate(j);
    categories(j).selection_rate_defined = has_eligible(j);
    categories(j).eligible_share = eligible_share(j);
    categories(j).selected_share = selected_share(j);
    categories(j).selected_minus_eligible_share = difference(j);
end

result = struct();
result.status = 'descriptive_selection_audit';
result.frame_description = frame;
result.categories = categories;
result.eligible_total = eligible_total;
result.selected_total = selected_total;
result.composition_comparison_state = comparison_state;
result.total_variation_distance = tv;
result.frame_completeness_verified = false;
result.category_coding_verified = false;
result.duplicate_study_handling_verified = false;
result.alarmism_bias_established = false;
result.ecological_prevalence_estimated = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_FRAME', 'Results describe only the supplied eligible discovery frame.'), ...
    item('R_COMPOSITION', ...
        'Composition difference does not itself establish inappropriate selection.'), ...
    item('R_NO_PREVALENCE', ...
        'Published findings are not a probability sample of ecological conditions.'), ...
    item('R_NO_BALANCE_QUOTA', ...
        'No equal quota of adverse and favorable findings is justified.'), ...
    item('R_UNDEFINED', ...
        'Undefined values use NaN locally and require state-preserving export.')];
end

function total = safe_integer_sum(values)
total = 0;
for j = 1:numel(values)
    if values(j) > flintmax - total
        error('DigestAudit:E_COUNT_RANGE', ...
            'Count total exceeds supported exact-integer range.');
    end
    total = total + values(j);
end
end

function check_text(value, code)
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error(['DigestAudit:' code], ...
        'Names and frame description must be nonempty character rows.');
end
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
eligible = [10; 10];
selected = [8; 2];
names = {'Synthetic deterioration', 'Synthetic improvement'};
before = {eligible, selected, names};

a = digest_selection_composition_audit( ...
    eligible, selected, names, 'Synthetic eligible frame');
must(a.ok, 'baseline');
must(abs(a.value.total_variation_distance - 0.3) < 1e-12, ...
    'composition_distance');
must(abs(a.value.categories(1).selection_rate - 0.8) < 1e-12, ...
    'selection_rate');
must(isequal(before, {eligible, selected, names}), 'nonmutation');

b = digest_selection_composition_audit( ...
    eligible, selected, names, 'Synthetic eligible frame');
must(isequaln(a, b), 'determinism');

empty_selection = digest_selection_composition_audit( ...
    eligible, [0; 0], names, 'Synthetic empty selection');
must(empty_selection.ok && strcmp( ...
    empty_selection.value.composition_comparison_state, 'unavailable'), ...
    'empty_not_zero_distance');

invalid = digest_selection_composition_audit( ...
    [1; 1], [2; 0], names, 'Synthetic invalid subset');
must(~invalid.ok && strcmp(invalid.error.code, 'E_SUBSET'), ...
    'subset_validation');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'rates', 'composition', 'nonmutation', ...
    'determinism', 'empty_selection', 'invalid_subset'}});
end

function must(condition, name)
if ~condition
    error('DigestAudit:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
