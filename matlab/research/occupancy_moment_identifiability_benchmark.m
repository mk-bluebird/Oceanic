function envelope = occupancy_moment_identifiability_benchmark(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = occupancy_moment_identifiability_benchmark( ...
%     visits, psi, detection, availability, model)
%
% model:
%   'simple'
%       availability must equal 1.
%       Parameters analyzed: psi, detection.
%   'availability_detection'
%       Parameters analyzed: psi, availability, detection.
%       Availability is independently redrawn per visit under this benchmark.
%
% psi and detection must be strictly inside (0,1).
% availability must be inside (0,1) for availability_detection.
% visits is a positive integer double scalar.
%
% No arguments runs synthetic self-tests.
% No data fitting, files, networking, persistence, or actuation.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 5
        value = evaluate(varargin{:});
    else
        error('OccupancyMoment:E_ARGUMENTS', ...
            'Supply visits, psi, detection, availability, and model.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'OccupancyMoment:';
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

function result = evaluate(visits, psi, detection, availability, model)
values = {visits, psi, detection, availability};
for j = 1:numel(values)
    x = values{j};
    if ~isa(x, 'double') || ~isreal(x) || ~isscalar(x) || ...
            isnan(x) || isinf(x)
        error('OccupancyMoment:E_NUMBER', ...
            'All numerical inputs must be finite real double scalars.');
    end
end

if visits < 1 || visits ~= floor(visits) || visits > flintmax
    error('OccupancyMoment:E_VISITS', ...
        'Visits must be a supported positive integer.');
end
if psi <= 0 || psi >= 1 || detection <= 0 || detection >= 1
    error('OccupancyMoment:E_INTERIOR', ...
        'This benchmark requires interior occupancy and detection probabilities.');
end
if ~ischar(model) || ~isrow(model) || ...
        ~any(strcmp(model, {'simple', 'availability_detection'}))
    error('OccupancyMoment:E_MODEL', 'Select a documented model.');
end

if strcmp(model, 'simple')
    if availability ~= 1
        error('OccupancyMoment:E_AVAILABILITY', ...
            'The simple model requires availability equal to one.');
    end
    p = detection;
    parameters = {'psi', 'detection'};
    jacobian = [p, psi];
    moments = psi*p;
    if visits >= 2
        jacobian = [jacobian; p^2, 2*psi*p];
        moments = [moments; psi*p^2];
    end
    analytic_rank = min(visits, 2);
    structural_status = 'simple_model_single_visit_confounded';
    if visits >= 2
        structural_status = 'simple_model_interior_structurally_identified';
    end
else
    if availability <= 0 || availability >= 1
        error('OccupancyMoment:E_AVAILABILITY', ...
            'Availability must be strictly inside (0,1).');
    end
    a = availability;
    d = detection;
    p = a*d;
    parameters = {'psi', 'availability', 'detection'};
    jacobian = [p, psi*d, psi*a];
    moments = psi*p;
    if visits >= 2
        jacobian = [jacobian; p^2, 2*psi*a*d^2, 2*psi*a^2*d];
        moments = [moments; psi*p^2];
    end
    analytic_rank = min(visits, 2);
    structural_status = 'availability_detection_product_confounding';
end

if p == 0 || any(moments == 0) || ...
        any(isnan(jacobian(:)) | isinf(jacobian(:)))
    error('OccupancyMoment:E_NUMERIC_RANGE', ...
        'Moment arithmetic exceeded the supported numerical range.');
end

singular_values = svd(jacobian);
tolerance = max(size(jacobian))*eps(max(singular_values));
numerical_rank = sum(singular_values > tolerance);

result = struct();
result.status = 'restricted_model_benchmark';
result.model = model;
result.visits = visits;
result.parameter_names = parameters;
result.effective_detection = p;
result.observation_moments = moments;
result.moment_definition = ...
    'First-visit detection; additionally first-two-visit joint detection.';
result.moment_jacobian = jacobian;
result.analytic_interior_rank = analytic_rank;
result.numerical_rank = numerical_rank;
result.rank_tolerance = tolerance;
result.singular_values = singular_values;
result.parameter_count = numel(parameters);
result.structural_status = structural_status;
result.practical_identifiability_established = false;
result.survey_assumptions_verified = false;
result.model_fitted = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_RESTRICTED_MODEL', ...
        'Common probabilities, no false positives, and conditional independence assumed.'), ...
    item('R_NO_DATA', ...
        'No detection histories or sampling-frame information are analyzed.'), ...
    item('R_LOCAL_NUMERICS', ...
        'Numerical rank depends on precision and tolerance.'), ...
    item('R_NO_PRECISION', ...
        'Structural identification does not establish finite-sample precision.'), ...
    item('R_USE_MEANING', ...
        'The ecological meaning of occupancy or use requires a declared survey scope.')];
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
single = occupancy_moment_identifiability_benchmark( ...
    1, 0.6, 0.5, 1, 'simple');
must(single.ok && single.value.analytic_interior_rank == 1, ...
    'single_visit_confounding');

repeated = occupancy_moment_identifiability_benchmark( ...
    2, 0.6, 0.5, 1, 'simple');
must(repeated.ok && repeated.value.analytic_interior_rank == 2 && ...
    repeated.value.numerical_rank == 2, 'two_visit_simple_rank');

split = occupancy_moment_identifiability_benchmark( ...
    3, 0.6, 0.5, 0.8, 'availability_detection');
alternative = occupancy_moment_identifiability_benchmark( ...
    3, 0.6, 0.8, 0.5, 'availability_detection');
must(split.ok && alternative.ok && ...
    max(abs(split.value.observation_moments - ...
    alternative.value.observation_moments)) < 1e-12, ...
    'same_effective_detection');

must(split.value.analytic_interior_rank < split.value.parameter_count, ...
    'availability_detection_not_separated');

again = occupancy_moment_identifiability_benchmark( ...
    2, 0.6, 0.5, 1, 'simple');
must(isequaln(repeated, again), 'determinism');

bad = occupancy_moment_identifiability_benchmark( ...
    0, 0.6, 0.5, 1, 'simple');
must(~bad.ok && strcmp(bad.error.code, 'E_VISITS'), 'invalid_design');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'single_visit', 'repeated_visits', ...
    'product_confounding', 'determinism', 'invalid_visits'}});
end

function must(condition, name)
if ~condition
    error('OccupancyMoment:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
