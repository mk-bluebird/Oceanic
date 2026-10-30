function envelope = domain_equivalence_interval_screen(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = domain_equivalence_interval_screen( ...
%     intervals, margins, available, required, domain_names)
%
% intervals: real double d-by-2 [lower upper].
% margins: finite real double d-by-2 [lower upper], strictly ordered.
% available: logical d-by-1.
% required: logical d-by-1.
% domain_names: cell vector of d distinct nonempty character rows.
%
% Unavailable interval rows are ignored and remain unresolved.
% Available interval rows must be finite and ordered.
%
% Equivalence uses strict containment within open margins.
% Mismatch support requires an interval strictly beyond a margin.
% Equality with a margin remains unresolved.
%
% No arguments runs synthetic self-tests.
% No files, networking, persistence, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 5
        value = evaluate(varargin{:});
    else
        error('DomainEquivalence:E_ARGUMENTS', ...
            'Supply intervals, margins, availability, requirement flags, and names.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'DomainEquivalence:';
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

function result = evaluate(intervals, margins, available, required, names)
if ~isa(intervals, 'double') || ~isreal(intervals) || ...
        ~ismatrix(intervals) || isempty(intervals) || ...
        size(intervals, 2) ~= 2
    error('DomainEquivalence:E_INTERVAL_SHAPE', ...
        'Intervals must be a real double d-by-2 matrix.');
end

d = size(intervals, 1);

if ~isa(margins, 'double') || ~isreal(margins) || ...
        ~isequal(size(margins), [d, 2]) || ...
        any(isnan(margins(:)) | isinf(margins(:))) || ...
        any(margins(:, 1) >= margins(:, 2))
    error('DomainEquivalence:E_MARGINS', ...
        'Margins must be finite and strictly ordered d-by-2 bounds.');
end

if ~islogical(available) || ~isequal(size(available), [d, 1]) || ...
        ~islogical(required) || ~isequal(size(required), [d, 1])
    error('DomainEquivalence:E_FLAGS', ...
        'Availability and required flags must be logical d-by-1 vectors.');
end

observed = intervals(available, :);
if any(isnan(observed(:)) | isinf(observed(:))) || ...
        any(observed(:, 1) > observed(:, 2))
    error('DomainEquivalence:E_INTERVAL', ...
        'Available intervals must be finite and ordered.');
end

if ~iscell(names) || ~isvector(names) || numel(names) ~= d
    error('DomainEquivalence:E_NAMES', ...
        'Provide one domain name per row.');
end
names = names(:)';
for j = 1:d
    if ~ischar(names{j}) || ~isrow(names{j}) || ...
            isempty(strtrim(names{j}))
        error('DomainEquivalence:E_NAMES', ...
            'Domain names must be nonempty character rows.');
    end
end
if numel(unique(names)) ~= d
    error('DomainEquivalence:E_NAMES', 'Domain names must be distinct.');
end

equivalent = false(d, 1);
mismatch = false(d, 1);
template = struct('domain_name', '', 'required', false, ...
    'available', false, 'interval', [NaN, NaN], ...
    'margins', [NaN, NaN], 'state', '');
domains = repmat(template, 1, d);

for j = 1:d
    state = 'unresolved_unavailable';
    displayed_interval = [NaN, NaN];

    if available(j)
        displayed_interval = intervals(j, :);
        equivalent(j) = intervals(j, 1) > margins(j, 1) && ...
            intervals(j, 2) < margins(j, 2);
        mismatch(j) = intervals(j, 2) < margins(j, 1) || ...
            intervals(j, 1) > margins(j, 2);

        state = 'unresolved_margin_overlap';
        if equivalent(j)
            state = 'equivalence_condition_satisfied';
        elseif mismatch(j)
            state = 'mismatch_supported_by_supplied_interval';
        end
    end

    domains(j).domain_name = names{j};
    domains(j).required = required(j);
    domains(j).available = available(j);
    domains(j).interval = displayed_interval;
    domains(j).margins = margins(j, :);
    domains(j).state = state;
end

overall = 'unresolved_required_domains';
if ~any(required)
    overall = 'not_applicable_no_required_domains';
elseif any(mismatch(required))
    overall = 'required_domain_mismatch_supported';
elseif all(equivalent(required))
    overall = 'all_required_equivalence_conditions_satisfied';
end

result = struct();
result.status = 'interval_condition_screen_only';
result.domains = domains;
result.overall_required_domain_status = overall;
result.required_domain_count = sum(required);
result.required_equivalence_count = sum(required & equivalent);
result.required_mismatch_count = sum(required & mismatch);
result.required_unresolved_count = ...
    sum(required & ~equivalent & ~mismatch);
result.margins_approved = false;
result.interval_construction_verified = false;
result.spatial_temporal_comparability_verified = false;
result.statistical_error_control_verified = false;
result.ecological_interchangeability_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_INPUTS', 'Intervals and margins are supplied, not validated.'), ...
    item('R_NO_AVERAGE', 'No averaging compensates for a required-domain mismatch.'), ...
    item('R_UNRESOLVED', 'Failure to establish equivalence need not establish difference.'), ...
    item('R_STATISTICS', 'The interval check does not implement a statistical test.'), ...
    item('R_AUTHORITY', 'No restoration, management, or publication action is authorized.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
intervals = [-0.1, 0.1; 0.8, 1.0; NaN, NaN];
margins = [-0.2, 0.2; -0.2, 0.2; -0.2, 0.2];
available = logical([1; 1; 0]);
required = true(3, 1);
names = {'Oxygen support', 'Recruitment', 'Thermal refuge'};
before = {intervals, margins, available, required, names};

a = domain_equivalence_interval_screen( ...
    intervals, margins, available, required, names);
must(a.ok, 'baseline');
must(strcmp(a.value.overall_required_domain_status, ...
    'required_domain_mismatch_supported'), 'no_compensation');
must(a.value.required_unresolved_count == 1, 'unavailable_retained');
must(isequaln(before, {intervals, margins, available, required, names}), ...
    'nonmutation');

b = domain_equivalence_interval_screen( ...
    intervals, margins, available, required, names);
must(isequaln(a, b), 'determinism');

boundary = domain_equivalence_interval_screen( ...
    [-0.2, 0.1], [-0.2, 0.2], true, true, {'Boundary fixture'});
must(boundary.ok && strcmp(boundary.value.domains.state, ...
    'unresolved_margin_overlap'), 'boundary_not_equivalent');

none = domain_equivalence_interval_screen( ...
    [-0.1, 0.1], [-0.2, 0.2], true, false, {'Optional fixture'});
must(none.ok && strcmp(none.value.overall_required_domain_status, ...
    'not_applicable_no_required_domains'), 'no_vacuous_pass');

invalid = domain_equivalence_interval_screen( ...
    [0, 1], [1, 1], true, true, {'Invalid margin'});
must(~invalid.ok && strcmp(invalid.error.code, 'E_MARGINS'), ...
    'invalid_margin');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'no_compensation', 'unavailable', 'nonmutation', ...
    'determinism', 'boundary', 'no_required_domains', 'invalid_margin'}});
end

function must(condition, name)
if ~condition
    error('DomainEquivalence:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
