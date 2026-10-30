function envelope = csd_observation_noise_benchmark(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Required configuration fields:
% n_steps, n_replicates, lambda_per_s, process_sigma,
% observation_sd, dt_s, missing_probability, seed
%
% Latent model: dX = -lambda*X*dt + process_sigma*dW.
% State units are caller-defined.
% process_sigma units: state / sqrt(second).
% observation_sd units: state.
%
% Missing observations are independent of state and time.
% Lag estimates use only original adjacent observed pairs.
% A local RandStream avoids modifying MATLAB's global random stream.
%
% No arguments runs synthetic self-tests.
% No files, networking, persistence, publication, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 1
        value = evaluate(varargin{1});
    else
        error('CSDObservation:E_ARGUMENTS', ...
            'Supply one configuration or no arguments for self-tests.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'CSDObservation:';
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

function result = evaluate(c)
fields = {'n_steps', 'n_replicates', 'lambda_per_s', ...
    'process_sigma', 'observation_sd', 'dt_s', ...
    'missing_probability', 'seed'};

if ~isstruct(c) || ~isscalar(c) || ...
        ~isequal(sort(fieldnames(c)), sort(fields(:)))
    error('CSDObservation:E_CONFIG', ...
        'Supply exactly the documented configuration fields.');
end

for j = 1:numel(fields)
    x = c.(fields{j});
    if ~isa(x, 'double') || ~isreal(x) || ~isscalar(x) || ...
            isnan(x) || isinf(x)
        error('CSDObservation:E_NUMBER', ...
            'Every configuration field must be a finite real double scalar.');
    end
end

if c.n_steps < 4 || c.n_steps ~= floor(c.n_steps) || ...
        c.n_replicates < 1 || c.n_replicates ~= floor(c.n_replicates) || ...
        c.n_steps > 1e6 || c.n_replicates > 1e4 || ...
        c.n_steps > 1e7 / c.n_replicates
    error('CSDObservation:E_SIZE', ...
        'Use integer sizes within the declared ten-million-step budget.');
end

if c.lambda_per_s <= 0 || c.process_sigma <= 0 || c.dt_s <= 0 || ...
        c.observation_sd < 0 || c.missing_probability < 0 || ...
        c.missing_probability > 1
    error('CSDObservation:E_DOMAIN', ...
        'Require positive lambda, process sigma, and dt; valid noise and missingness.');
end

if c.seed < 0 || c.seed > 2^32-1 || c.seed ~= floor(c.seed)
    error('CSDObservation:E_SEED', ...
        'Seed must be an integer between zero and 2^32-1.');
end

eta = c.lambda_per_s * c.dt_s;
latent_variance = (c.process_sigma / sqrt(2*c.lambda_per_s))^2;
noise_variance = c.observation_sd^2;
observed_variance = latent_variance + noise_variance;
phi = exp(-eta);
innovation_sd = sqrt(latent_variance * (-expm1(-2*eta)));

derived = [eta, latent_variance, noise_variance, ...
    observed_variance, phi, innovation_sd];
if any(isnan(derived) | isinf(derived)) || ...
        latent_variance <= 0 || innovation_sd <= 0 || ...
        (c.observation_sd > 0 && noise_variance == 0)
    error('CSDObservation:E_DERIVED_RANGE', ...
        'Derived model parameters exceeded numerical range.');
end

expected_observed_acf = phi * (latent_variance / observed_variance);
stream = RandStream('mt19937ar', 'Seed', c.seed);

template = struct('observed_count', 0, 'adjacent_pair_count', 0, ...
    'variance', NaN, 'lag_pair_correlation', NaN, ...
    'gaussian_information_proxy', NaN, ...
    'variance_available', false, 'correlation_available', false);
replicates = repmat(template, 1, c.n_replicates);

for r = 1:c.n_replicates
    x = zeros(c.n_steps, 1);
    x(1) = sqrt(latent_variance) * randn(stream, 1, 1);
    innovations = randn(stream, c.n_steps-1, 1);

    for j = 2:c.n_steps
        x(j) = phi*x(j-1) + innovation_sd*innovations(j-1);
    end

    y = x + c.observation_sd * randn(stream, c.n_steps, 1);
    if any(isnan(y) | isinf(y))
        error('CSDObservation:E_SIMULATION_RANGE', ...
            'A simulated observation exceeded numerical range.');
    end

    keep = rand(stream, c.n_steps, 1) >= c.missing_probability;
    pairs = keep(1:end-1) & keep(2:end);
    replicates(r).observed_count = sum(keep);
    replicates(r).adjacent_pair_count = sum(pairs);

    if sum(keep) >= 3
        v = var(y(keep), 0);
        if isnan(v) || isinf(v)
            error('CSDObservation:E_SUMMARY_RANGE', ...
                'Variance calculation exceeded numerical range.');
        end
        replicates(r).variance = v;
        replicates(r).variance_available = true;
        if v > 0
            information = 1/v;
            if isinf(information)
                error('CSDObservation:E_SUMMARY_RANGE', ...
                    'Gaussian information proxy exceeded numerical range.');
            end
            replicates(r).gaussian_information_proxy = information;
        end
    end

    if sum(pairs) >= 3
        left = y(1:end-1);
        right = y(2:end);
        a = left(pairs);
        b = right(pairs);
        a = a - mean(a);
        b = b - mean(b);
        na = norm(a);
        nb = norm(b);
        if na > 0 && nb > 0 && ~isinf(na) && ~isinf(nb)
            correlation = sum((a/na).*(b/nb));
            replicates(r).lag_pair_correlation = ...
                min(1, max(-1, correlation));
            replicates(r).correlation_available = true;
        end
    end
end

result = struct();
result.status = 'synthetic_stationary_benchmark';
result.configuration = c;
result.latent_variance = latent_variance;
result.expected_observed_variance = observed_variance;
result.latent_lag_correlation = phi;
result.expected_observed_lag_correlation = expected_observed_acf;
result.sampling_interval_to_return_time_ratio = eta;
result.replicates = replicates;
result.random_generator = 'local_mt19937ar';
result.DEWI_fitted = false;
result.collapse_events_simulated = false;
result.nonparametric_information_estimated = false;
result.field_validation = 'not_performed';
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_STATIONARY', 'Lambda and noise properties are constant.'), ...
    item('R_MISSINGNESS', 'Missingness is independent, not informative.'), ...
    item('R_PAIR_ESTIMATOR', ...
        'Finite-sample pair correlation is not an unbiased ACF estimator.'), ...
    item('R_INFORMATION_PROXY', ...
        'Inverse sample variance is only a Gaussian information proxy.'), ...
    item('R_NO_WARNING', ...
        'No alarm discrimination or collapse prediction is evaluated.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
c = struct('n_steps', 20, 'n_replicates', 2, ...
    'lambda_per_s', 1, 'process_sigma', sqrt(2), ...
    'observation_sd', 1, 'dt_s', 1, ...
    'missing_probability', 0, 'seed', 17);

before_config = c;
before_rng = rng;
a = csd_observation_noise_benchmark(c);
must(a.ok, 'baseline');
must(abs(a.value.latent_variance-1) < 1e-12, 'latent_variance');
must(abs(a.value.expected_observed_lag_correlation-exp(-1)/2) ...
    < 1e-12, 'measurement_attenuation');
must(isequal(c, before_config), 'nonmutation');
must(isequal(rng, before_rng), 'global_rng_unchanged');

b = csd_observation_noise_benchmark(c);
must(isequaln(a, b), 'seeded_determinism');

missing = c;
missing.missing_probability = 1;
r = csd_observation_noise_benchmark(missing);
must(r.ok && all([r.value.replicates.observed_count] == 0), ...
    'all_missing');
must(all(~[r.value.replicates.variance_available]), ...
    'missing_not_zero_variance');

invalid = c;
invalid.lambda_per_s = 0;
r = csd_observation_noise_benchmark(invalid);
must(~r.ok && strcmp(r.error.code, 'E_DOMAIN'), 'invalid_lambda');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'analytic_variance', 'measurement_attenuation', ...
    'nonmutation', 'local_rng', 'determinism', ...
    'all_missing', 'invalid_domain'}});
end

function must(condition, name)
if ~condition
    error('CSDObservation:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
