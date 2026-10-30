function envelope = zero_record_interpretation(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = zero_record_interpretation(kind, parameter, support, unit)
%
% This function reviews an already reported numerical zero.
%
% kind:
%   'count_zero'
%       parameter must be 0.
%   'rounded_nonnegative_zero'
%       parameter is a positive nearest-rounding increment.
%   'nondetect_encoded_zero'
%       parameter is a positive caller-supplied reporting bound.
%   'placeholder_zero'
%       parameter must be 0.
%   'unqualified_zero'
%       parameter must be 0.
%
% support: descriptive observation-support text.
% unit: descriptive unit text.
%
% Rounded intervals are conservative closed reporting enclosures.
% Nondetect bounds are declared reporting enclosures, not guaranteed
% physical concentration bounds or confidence intervals.
%
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
        error('ZeroRecord:E_ARGUMENTS', ...
            'Supply kind, parameter, support, and unit.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'ZeroRecord:';
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

function result = evaluate(kind, parameter, support, unit)
choices = {'count_zero', 'rounded_nonnegative_zero', ...
    'nondetect_encoded_zero', 'placeholder_zero', 'unqualified_zero'};

if ~ischar(kind) || ~isrow(kind) || ~any(strcmp(kind, choices))
    error('ZeroRecord:E_KIND', 'Select a documented zero-record kind.');
end

if ~isa(parameter, 'double') || ~isreal(parameter) || ...
        ~isscalar(parameter) || isnan(parameter) || ...
        isinf(parameter) || parameter < 0
    error('ZeroRecord:E_PARAMETER', ...
        'Parameter must be a finite nonnegative real double scalar.');
end

check_text(support, 'E_SUPPORT');
check_text(unit, 'E_UNIT');

bounds = struct('state', 'not_available', ...
    'lower', NaN, 'upper', NaN, ...
    'meaning', 'No numerical enclosure established.');

if strcmp(kind, 'rounded_nonnegative_zero')
    if parameter <= 0
        error('ZeroRecord:E_RESOLUTION', ...
            'Rounding increment must be positive.');
    end
    upper = parameter / 2;
    if upper == 0
        error('ZeroRecord:E_NUMERIC_RANGE', ...
            'Positive half-increment underflowed to zero.');
    end
    bounds = struct('state', 'declared_reporting_enclosure', ...
        'lower', 0, 'upper', upper, ...
        'meaning', ...
        'Closed enclosure under nonnegative nearest-rounding assumptions.');
    interpretation = 'rounded_zero_not_exact_quantity';

elseif strcmp(kind, 'nondetect_encoded_zero')
    if parameter <= 0
        error('ZeroRecord:E_REPORTING_BOUND', ...
            'A positive declared reporting bound is required.');
    end
    bounds = struct('state', 'declared_reporting_enclosure', ...
        'lower', 0, 'upper', parameter, ...
        'meaning', ...
        'Caller-declared nondetect enclosure; method validity unverified.');
    interpretation = 'qualified_nondetection_not_measured_zero';

else
    if parameter ~= 0
        error('ZeroRecord:E_UNUSED_PARAMETER', ...
            'This record kind requires parameter equal to zero.');
    end

    if strcmp(kind, 'count_zero')
        bounds = struct('state', 'reported_count', ...
            'lower', 0, 'upper', 0, ...
            'meaning', 'Zero reported detections in the declared support.');
        interpretation = 'zero_count_not_established_absence';
    elseif strcmp(kind, 'placeholder_zero')
        interpretation = 'placeholder_not_numerical_evidence';
    else
        interpretation = 'zero_meaning_unresolved';
    end
end

result = struct();
result.status = 'record_semantics_review_only';
result.reported_value = 0;
result.zero_kind_declared = kind;
result.parameter = parameter;
result.support_declared = support;
result.unit_declared = unit;
result.interpretation = interpretation;
result.reporting_enclosure = bounds;
result.instrument_specifications_verified = false;
result.rounding_rule_verified = false;
result.detection_method_verified = false;
result.ecological_absence_established = false;
result.confidence_interval_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_DECLARATION', 'Record kind and metadata are caller-supplied.'), ...
    item('R_NONNEGATIVE', ...
        'Rounding and nondetect enclosures assume a nonnegative quantity.'), ...
    item('R_MEASUREMENT_MODEL', ...
        'Calibration, bias, blank correction, and clipping require separate review.'), ...
    item('R_NO_ABSENCE', ...
        'A zero count or nondetect does not establish ecological absence.'), ...
    item('R_NO_SUBSTITUTION', ...
        'No censored-data substitution or imputation is performed.')];
end

function check_text(value, code)
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error(['ZeroRecord:' code], ...
        'Support and unit must be nonempty character rows.');
end
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
a = zero_record_interpretation( ...
    'count_zero', 0, 'Synthetic survey occasion', 'detections');
must(a.ok && a.value.reporting_enclosure.upper == 0 && ...
    ~a.value.ecological_absence_established, 'count_not_absence');

b = zero_record_interpretation( ...
    'rounded_nonnegative_zero', 0.1, ...
    'Synthetic instrument display', 'synthetic_unit');
must(b.ok && abs(b.value.reporting_enclosure.upper-0.05) < 1e-12, ...
    'rounding_enclosure');

c = zero_record_interpretation( ...
    'nondetect_encoded_zero', 0.2, ...
    'Synthetic laboratory report', 'synthetic_unit');
must(c.ok && c.value.reporting_enclosure.upper == 0.2, ...
    'nondetect_enclosure');

p = zero_record_interpretation( ...
    'placeholder_zero', 0, 'Synthetic import record', 'synthetic_unit');
must(p.ok && strcmp(p.value.reporting_enclosure.state, ...
    'not_available'), 'placeholder_no_value');

bad = zero_record_interpretation( ...
    'rounded_nonnegative_zero', 0, 'Synthetic support', 'synthetic_unit');
must(~bad.ok && strcmp(bad.error.code, 'E_RESOLUTION'), ...
    'invalid_resolution');

again = zero_record_interpretation( ...
    'count_zero', 0, 'Synthetic survey occasion', 'detections');
must(isequaln(a, again), 'determinism');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'count', 'rounding', 'nondetect', ...
    'placeholder', 'invalid_resolution', 'determinism'}});
end

function must(condition, name)
if ~condition
    error('ZeroRecord:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
