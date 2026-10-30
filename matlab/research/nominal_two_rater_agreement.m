function envelope = nominal_two_rater_agreement(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = nominal_two_rater_agreement(ratings, category_names)
%
% ratings: real double n-by-2, n >= 1.
% Each finite rating is an integer from 1 through category count.
% NaN means no rating supplied by that reviewer.
%
% A substantive "unknown" category must have its own finite category code.
% NaN is not an ecological missingness category.
%
% category_names: cell vector of distinct nonempty character rows.
%
% Complete pairs only are used for kappa and the confusion matrix.
% Missing-rating coverage is reported separately.
% No arguments runs synthetic self-tests.
%
% No files, networking, storage, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 2
        value = evaluate(varargin{1}, varargin{2});
    else
        error('NominalAgreement:E_ARGUMENTS', ...
            'Supply ratings and category names, or no arguments for tests.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'NominalAgreement:';
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

function result = evaluate(ratings, names)
if ~isa(ratings, 'double') || ~isreal(ratings) || ...
        ~ismatrix(ratings) || size(ratings, 2) ~= 2 || ...
        size(ratings, 1) < 1 || any(isinf(ratings(:)))
    error('NominalAgreement:E_RATINGS', ...
        'Ratings must be real double n-by-2 with finite codes or NaN.');
end

if ~iscell(names) || ~isvector(names) || isempty(names)
    error('NominalAgreement:E_NAMES', ...
        'Supply a nonempty category-name cell vector.');
end

names = names(:)';
for j = 1:numel(names)
    if ~ischar(names{j}) || ~isrow(names{j}) || ...
            isempty(strtrim(names{j}))
        error('NominalAgreement:E_NAMES', ...
            'Category names must be nonempty character rows.');
    end
end
if numel(unique(names)) ~= numel(names)
    error('NominalAgreement:E_NAMES', ...
        'Category names must be distinct.');
end

k = numel(names);
available = ~isnan(ratings);
codes = ratings(available);
if any(codes ~= floor(codes)) || any(codes < 1 | codes > k)
    error('NominalAgreement:E_CODE', ...
        'Available ratings must be integer category codes from 1 through k.');
end

paired = all(available, 2);
n = sum(paired);
confusion = zeros(k, k);
if n > 0
    r = ratings(paired, :);
    confusion = accumarray(r, 1, [k, k]);
end

observed = metric('undefined_no_complete_pairs');
expected = metric('undefined_no_complete_pairs');
kappa = metric('undefined_no_complete_pairs');

row_counts = sum(confusion, 2);
column_counts = sum(confusion, 1)';
category_agreement = NaN(k, 1);
denominator = row_counts + column_counts;
has_category = denominator > 0;
category_agreement(has_category) = ...
    2 .* diag(confusion(has_category, has_category)) ./ ...
    denominator(has_category);

if n > 0
    po = sum(diag(confusion)) / n;
    pe = sum((row_counts/n) .* (column_counts/n));
    observed = metric('computed', po);
    expected = metric('computed', pe);

    if pe == 1
        kappa = metric('undefined_zero_chance_disagreement');
    else
        kappa = metric('computed', (po-pe)/(1-pe));
    end
end

result = struct();
result.status = 'descriptive_reliability_analysis';
result.category_names = names;
result.confusion_matrix = confusion;
result.confusion_layout = 'Rows: reviewer 1; columns: reviewer 2.';
result.total_claims = size(ratings, 1);
result.complete_pairs = n;
result.complete_pair_fraction = n / size(ratings, 1);
result.available_ratings_per_reviewer = sum(available, 1);
result.observed_agreement = observed;
result.expected_agreement = expected;
result.cohens_kappa = kappa;
result.category_specific_agreement = category_agreement;
result.category_specific_denominator = denominator;
result.category_specific_definition = ...
    '2*diagonal_count/(reviewer1_count+reviewer2_count)';
result.rater1_paired_category_counts = row_counts;
result.rater2_paired_category_counts = column_counts;
result.uncertainty_intervals = 'not_estimated';
result.missing_rating_mechanism_assessed = false;
result.multi_label_agreement_assessed = false;
result.scientific_validity_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_EXCLUSIVE_TASK', 'Exactly one nominal category per reviewer is assumed.'), ...
    item('R_COMPLETE_PAIRS', 'Agreement statistics exclude incomplete pairs.'), ...
    item('R_PREVALENCE', 'Kappa depends on marginal category frequencies.'), ...
    item('R_NO_VALIDITY', 'Agreement does not establish scientific correctness.'), ...
    item('R_UNDEFINED', 'NaN values require state-preserving JSON export.')];
end

function value = metric(state, number)
if nargin < 2
    number = NaN;
end
value = struct('state', state, 'value', number);
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
names = {'Observation', 'Interpretation'};
ratings = [1, 1; 1, 2; 2, 2; 2, 2; NaN, 1];
before = ratings;

a = nominal_two_rater_agreement(ratings, names);
must(a.ok, 'baseline');
must(a.value.complete_pairs == 4, 'complete_pairs');
must(abs(a.value.observed_agreement.value - 0.75) < 1e-12, ...
    'observed_agreement');
must(abs(a.value.cohens_kappa.value - 0.5) < 1e-12, 'kappa');
must(isequaln(ratings, before), 'nonmutation');

b = nominal_two_rater_agreement(ratings, names);
must(isequaln(a, b), 'determinism');

constant = nominal_two_rater_agreement([1, 1; 1, 1], names);
must(constant.ok && strcmp(constant.value.cohens_kappa.state, ...
    'undefined_zero_chance_disagreement'), 'constant_category');

missing = nominal_two_rater_agreement([NaN, 1; 2, NaN], names);
must(missing.ok && missing.value.complete_pairs == 0 && ...
    strcmp(missing.value.cohens_kappa.state, ...
    'undefined_no_complete_pairs'), 'no_pairs');

invalid = nominal_two_rater_agreement([0, 1], names);
must(~invalid.ok && strcmp(invalid.error.code, 'E_CODE'), 'invalid_code');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'agreement', 'kappa', 'missing_ratings', ...
    'constant_category', 'nonmutation', 'determinism', 'invalid_code'}});
end

function must(condition, name)
if ~condition
    error('NominalAgreement:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
