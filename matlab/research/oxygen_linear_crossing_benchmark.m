function envelope = oxygen_linear_crossing_benchmark(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = oxygen_linear_crossing_benchmark(config)
%
% Exact required fields:
% ka_s_inv, Q_m3_s, V_m3,
% net_production_g_m3_s, saturation_g_m3,
% inflow_g_m3, initial_g_m3, threshold_g_m3
%
% ka is a first-order volumetric coefficient, not a transfer velocity.
% Net production is already volumetric; it is NOT divided by volume.
% Constant parameters, constant volume, well-mixed compartment assumed.
% No arguments runs synthetic self-tests.
%
% Outputs are analytical model results, not validated forecasts.
% No files, networking, persistence, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 1
        value = evaluate(varargin{1});
    else
        error('OxygenBenchmark:E_ARGUMENTS', ...
            'Supply one configuration, or no arguments for self-tests.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'OxygenBenchmark:';
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
            'message', message));
end
end

function result = evaluate(c)
fields = {'ka_s_inv', 'Q_m3_s', 'V_m3', ...
    'net_production_g_m3_s', 'saturation_g_m3', ...
    'inflow_g_m3', 'initial_g_m3', 'threshold_g_m3'};

if ~isstruct(c) || ~isscalar(c) || ...
        ~isequal(sort(fieldnames(c)), sort(fields(:)))
    error('OxygenBenchmark:E_CONFIG', ...
        'Supply exactly the documented configuration fields.');
end

for j = 1:numel(fields)
    x = c.(fields{j});
    if ~isa(x, 'double') || ~isreal(x) || ~isscalar(x) || ...
            isnan(x) || isinf(x)
        error('OxygenBenchmark:E_NUMBER', ...
            'Every field must be a finite real double scalar.');
    end
end

if c.ka_s_inv < 0 || c.Q_m3_s < 0 || c.V_m3 <= 0 || ...
        c.saturation_g_m3 < 0 || c.inflow_g_m3 < 0 || ...
        c.initial_g_m3 < 0 || c.threshold_g_m3 < 0
    error('OxygenBenchmark:E_DOMAIN', ...
        'Rates and concentrations must be nonnegative; volume positive.');
end

q = c.Q_m3_s / c.V_m3;
if isnan(q) || isinf(q) || (c.Q_m3_s > 0 && q == 0)
    error('OxygenBenchmark:E_EXCHANGE_RANGE', ...
        'The exchange-rate calculation exceeded supported range.');
end

lambda = c.ka_s_inv + q;
if isnan(lambda) || isinf(lambda)
    error('OxygenBenchmark:E_RATE_RANGE', ...
        'The combined response rate exceeded numerical range.');
end
if lambda == 0
    error('OxygenBenchmark:E_UNDEFINED_TIMESCALE', ...
        'Zero reaeration and exchange require a separate linear-drift model.');
end

tau = 1 / lambda;
equilibrium = c.net_production_g_m3_s / lambda + ...
    (c.ka_s_inv / lambda) * c.saturation_g_m3 + ...
    (q / lambda) * c.inflow_g_m3;

if isnan(tau) || isinf(tau) || tau == 0 || ...
        isnan(equilibrium) || isinf(equilibrium)
    error('OxygenBenchmark:E_DERIVED_RANGE', ...
        'A derived timescale or equilibrium is not representable.');
end

crossing = struct('state', 'no_finite_threshold_reaching', ...
    'time_seconds', NaN, 'time_defined', false);

if c.initial_g_m3 <= c.threshold_g_m3
    crossing.state = 'initially_at_or_below_threshold';
    crossing.time_seconds = 0;
    crossing.time_defined = true;
elseif equilibrium < c.threshold_g_m3
    gap = c.initial_g_m3 - c.threshold_g_m3;
    denominator = c.threshold_g_m3 - equilibrium;

    if isinf(gap) || isinf(denominator) || denominator <= 0
        error('OxygenBenchmark:E_CROSSING_RANGE', ...
            'Threshold-gap arithmetic exceeded numerical range.');
    end

    ratio = gap / denominator;
    if isinf(ratio)
        log_factor = log(gap) - log(denominator);
    else
        log_factor = log1p(ratio);
    end

    time = tau * log_factor;
    if isnan(time) || isinf(time) || time <= 0
        error('OxygenBenchmark:E_CROSSING_RANGE', ...
            'A positive finite crossing time was not representable.');
    end

    crossing.state = 'finite_threshold_reaching_predicted';
    crossing.time_seconds = time;
    crossing.time_defined = true;
elseif equilibrium == c.threshold_g_m3
    crossing.state = 'asymptotic_approach_to_threshold';
end

result = struct();
result.status = 'analytical_benchmark_only';
result.response_rate_s_inv = lambda;
result.exchange_rate_s_inv = q;
result.response_time_seconds = tau;
result.linear_equilibrium_g_m3 = equilibrium;
result.equilibrium_physically_nonnegative = equilibrium >= 0;
result.threshold_reaching = crossing;
result.assumptions_verified = false;
result.precursor_lead_time_validated = false;
result.DEWI_fitted = false;
result.critical_slowing_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_CONSTANT_FORCING', 'Parameters and forcing are constant.'), ...
    item('R_WELL_MIXED', 'Spatial concentration gradients are omitted.'), ...
    item('R_NEGATIVE_EQUILIBRIUM', ...
        'A negative equilibrium is mathematical extrapolation, not physical oxygen.'), ...
    item('R_NOT_WARNING', ...
        'Response time and threshold time do not establish detectable precursor lead.'), ...
    item('R_NO_UNCERTAINTY', ...
        'Parameter and model uncertainty are not propagated.'), ...
    item('R_NO_PERSISTENCE', ...
        'Reaching a threshold is not a duration-based depletion assessment.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
c = struct('ka_s_inv', 1, 'Q_m3_s', 0, 'V_m3', 1, ...
    'net_production_g_m3_s', -1, 'saturation_g_m3', 2, ...
    'inflow_g_m3', 0, 'initial_g_m3', 3, 'threshold_g_m3', 2);

before = c;
a = oxygen_linear_crossing_benchmark(c);
must(a.ok, 'baseline');
must(abs(a.value.response_time_seconds - 1) < 1e-12, 'timescale');
must(abs(a.value.linear_equilibrium_g_m3 - 1) < 1e-12, 'equilibrium');
must(abs(a.value.threshold_reaching.time_seconds - log(2)) < 1e-12, ...
    'analytic_crossing');
must(isequal(c, before), 'nonmutation');

b = oxygen_linear_crossing_benchmark(c);
must(isequaln(a, b), 'determinism');

no_crossing = c;
no_crossing.threshold_g_m3 = 0.5;
r = oxygen_linear_crossing_benchmark(no_crossing);
must(r.ok && ~r.value.threshold_reaching.time_defined, 'no_crossing');

asymptotic = c;
asymptotic.threshold_g_m3 = 1;
r = oxygen_linear_crossing_benchmark(asymptotic);
must(r.ok && strcmp(r.value.threshold_reaching.state, ...
    'asymptotic_approach_to_threshold'), 'asymptotic_case');

zero_rate = c;
zero_rate.ka_s_inv = 0;
r = oxygen_linear_crossing_benchmark(zero_rate);
must(~r.ok && strcmp(r.error.code, 'E_UNDEFINED_TIMESCALE'), ...
    'undefined_not_zero');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'timescale', 'equilibrium', 'crossing', ...
    'nonmutation', 'determinism', 'no_crossing', ...
    'asymptotic_case', 'zero_rate'}});
end

function must(condition, name)
if ~condition
    error('OxygenBenchmark:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
