function envelope = nondetection_effort_benchmark(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = nondetection_effort_benchmark( ...
%     effort, encounter_rate, prior_occupancy)
%
% effort: finite nonnegative double column vector.
% encounter_rate: same-sized finite nonnegative double column vector.
% Encounter-rate units must be reciprocal effort units.
% Empty double arrays represent no supplied survey occasions.
%
% All supplied occasions are assumed valid nondetections.
% Missing/invalid/unsurveyed occasions must not be encoded as nondetections.
%
% Model:
% p_j = 1-exp(-rate_j*effort_j)
% Conditional independence, closure, no false positives.
%
% No arguments runs synthetic self-tests.
% No files, networking, storage, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 3
        value = evaluate(varargin{:});
    else
        error('EffortNondetection:E_ARGUMENTS', ...
            'Supply effort, encounter rate, and prior occupancy.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'EffortNondetection:';
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

function result = evaluate(effort, rate, psi)
arrays = {effort, rate};
for j = 1:2
    x = arrays{j};
    valid_shape = isempty(x) || (ismatrix(x) && size(x, 2) == 1);
    if ~isa(x, 'double') || ~isreal(x) || ~valid_shape || ...
            any(isnan(x(:)) | isinf(x(:))) || any(x(:) < 0)
        error('EffortNondetection:E_INPUT', ...
            'Effort and rates must be finite nonnegative double columns.');
    end
end

if ~isequal(size(effort), size(rate))
    error('EffortNondetection:E_SHAPE', ...
        'Effort and encounter-rate arrays must have the same shape.');
end

if ~isa(psi, 'double') || ~isreal(psi) || ~isscalar(psi) || ...
        isnan(psi) || isinf(psi) || psi < 0 || psi > 1
    error('EffortNondetection:E_PRIOR', ...
        'Prior occupancy must be a finite double probability.');
end

hazard = effort .* rate;
if any(isnan(hazard) | isinf(hazard)) || ...
        any(effort > 0 & rate > 0 & hazard == 0)
    error('EffortNondetection:E_NUMERIC_RANGE', ...
        'An effort-rate product exceeded supported numerical range.');
end

total_hazard = sum(hazard);
if isnan(total_hazard) || isinf(total_hazard)
    error('EffortNondetection:E_NUMERIC_RANGE', ...
        'Cumulative encounter intensity exceeded numerical range.');
end

log_q = -total_hazard;

if psi == 0
    log_likelihood = 0;
    posterior = 0;
    log_posterior = -Inf;
elseif psi == 1
    log_likelihood = log_q;
    posterior = 1;
    log_posterior = 0;
else
    absent_term = log1p(-psi);
    occupied_term = log(psi) + log_q;
    largest = max(absent_term, occupied_term);
    log_likelihood = largest + ...
        log(exp(absent_term-largest) + exp(occupied_term-largest));
    log_posterior = occupied_term - log_likelihood;
    posterior = min(1, max(0, exp(log_posterior)));
end

posterior_state = 'computed';
if psi > 0 && psi < 1 && posterior == 0
    posterior = NaN;
    posterior_state = 'below_floating_point_probability_range';
end

q = exp(log_q);
q_state = 'computed';
if q == 0
    q = NaN;
    q_state = 'below_floating_point_probability_range';
end

result = struct();
result.status = 'conditional_analytical_benchmark';
result.supplied_nondetection_occasions = numel(effort);
result.zero_effort_occasions = sum(effort == 0);
result.cumulative_encounter_intensity = total_hazard;
result.log_nondetection_probability_if_occupied = log_q;
result.nondetection_probability_if_occupied = ...
    struct('state', q_state, 'value', q);
result.log_history_likelihood = log_likelihood;
result.prior_occupancy = psi;
result.posterior_occupancy = ...
    struct('state', posterior_state, 'value', posterior);
result.log_posterior_occupancy = log_posterior;
result.per_occasion_detection_probability = -expm1(-hazard);
result.encounter_rates_fitted = false;
result.assumptions_verified = false;
result.absence_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_EFFORT_MODEL', ...
        'Constant encounter-rate accumulation is a model assumption.'), ...
    item('R_CLOSURE', ...
        'Occupancy is assumed stable across the supplied occasions.'), ...
    item('R_DEPENDENCE', ...
        'Nondetections are conditionally independent under the model.'), ...
    item('R_FALSE_POSITIVES', ...
        'False-positive detections are excluded from the model.'), ...
    item('R_NO_UNCERTAINTY', ...
        'Input-rate, effort, and prior uncertainty are not propagated.'), ...
    item('R_UNAVAILABLE', ...
        'Missing effort or rates must not be replaced with zero.'), ...
    item('R_SERIALIZATION', ...
        'NaN and infinite log probabilities require explicit JSON states.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
effort = [1; 2];
rate = [log(2); log(2)];
before = {effort, rate};

a = nondetection_effort_benchmark(effort, rate, 0.5);
must(a.ok, 'baseline');
must(abs(a.value.nondetection_probability_if_occupied.value - 1/8) ...
    < 1e-12, 'conditional_nondetection');
must(abs(a.value.posterior_occupancy.value - 1/9) < 1e-12, ...
    'posterior');
must(isequal(before, {effort, rate}), 'nonmutation');

b = nondetection_effort_benchmark(effort, rate, 0.5);
must(isequaln(a, b), 'determinism');

none = nondetection_effort_benchmark([], [], 0.4);
must(none.ok && abs(none.value.posterior_occupancy.value - 0.4) ...
    < 1e-12, 'no_surveys_preserve_prior');

scaled = nondetection_effort_benchmark(effort*60, rate/60, 0.5);
must(scaled.ok && abs(scaled.value.posterior_occupancy.value - ...
    a.value.posterior_occupancy.value) < 1e-12, 'effort_unit_conversion');

certain = nondetection_effort_benchmark(effort, rate, 1);
must(certain.ok && certain.value.posterior_occupancy.value == 1, ...
    'dogmatic_prior');

invalid = nondetection_effort_benchmark([NaN; 2], rate, 0.5);
must(~invalid.ok && strcmp(invalid.error.code, 'E_INPUT'), ...
    'missing_effort_rejection');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'analytic_probability', 'posterior', 'nonmutation', ...
    'determinism', 'empty_history', 'unit_conversion', ...
    'prior_boundary', 'missing_effort'}});
end

function must(condition, name)
if ~condition
    error('EffortNondetection:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
