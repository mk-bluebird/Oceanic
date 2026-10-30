function envelope = synthetic_attenuated_logistic_uncertainty(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not identity verification, consent, or authorization.
%
% No arguments: run synthetic self-tests and return the same envelope shape.
%
% Normal call:
%   envelope = synthetic_attenuated_logistic_uncertainty( ...
%       measurement_draws, optical_depth, options)
%
% measurement_draws: finite real double n-by-8, n >= 2:
% [k_s_inv, Q_m3_s, u_m_s, L_m, K_m2_s, N2_s_inv2, V_m3, S_s_inv]
%
% optical_depth: finite nonnegative real double scalar or n-by-1.
%
% Required options:
% joint_draws_declared: logical scalar
% sampling_dependence: 'iid', 'dependent', or 'unspecified'
% optical_mode: 'fixed' or 'paired'
% optical_uncertainty_kind:
%   'fixed', 'measurement_parameter', or 'scenario_parameter'
% boundary_margin: positive dimensionless log-coordinate margin
% ri_reference_margin: positive dimensionless Ri-coordinate margin
% include_input_draws: logical scalar
%
% Numeric policy: nonzero coordinate log magnitudes must be within +/-300.
% No networking, file access, hardware actions, or persistent storage.
%
% Success: ok=true, value=struct, error=[]
% Failure: ok=false, value=[], error=struct(code,message)
% MATLAB batch exits nonzero only if the caller asserts envelope.ok.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 3
        value = evaluate(varargin{1}, varargin{2}, varargin{3});
    else
        error('SyntheticLogistic:E_ARGUMENTS', ...
            'Supply measurement draws, optical depth, and options.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'SyntheticLogistic:';
    if strncmp(exception.identifier, prefix, numel(prefix))
        code = exception.identifier(numel(prefix) + 1:end);
        message = exception.message;
    else
        code = 'E_INTERNAL';
        message = ['Unexpected internal failure; no result approved. ' ...
            'Review locally without exporting private inputs.'];
    end
    envelope = struct('ok', false, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', [], ...
        'error', struct('code', code, 'message', message));
end
end

function result = evaluate(draws, optical, options)
if ~isa(draws, 'double') || ~isreal(draws) || ...
        ~ismatrix(draws) || size(draws, 2) ~= 8 || size(draws, 1) < 2
    error('SyntheticLogistic:E_DRAW_SHAPE', ...
        'Measurement draws must be a real double n-by-8 matrix, n >= 2.');
end

names = {'k', 'Q', 'u', 'L', 'K', 'N2', 'V', 'shear'};
for column = 1:8
    if any(isnan(draws(:, column)) | isinf(draws(:, column)))
        error('SyntheticLogistic:E_NONFINITE_INPUT', ...
            'Non-finite measurement input in column %s.', names{column});
    end
end

if any(any(draws(:, [1:5, 7:8]) <= 0))
    error('SyntheticLogistic:E_POSITIVE_INPUT', ...
        ['k, Q, u, L, K, V, and shear must be positive. ' ...
         'N2 may be negative or zero; optical depth must be nonnegative.']);
end

required = {'joint_draws_declared', 'sampling_dependence', ...
    'optical_mode', 'optical_uncertainty_kind', 'boundary_margin', ...
    'ri_reference_margin', 'include_input_draws'};

if ~isstruct(options) || ~isscalar(options) || ...
        ~isequal(sort(fieldnames(options)), sort(required(:)))
    error('SyntheticLogistic:E_OPTIONS', ...
        'Options must contain exactly the documented required fields.');
end

if ~islogical(options.joint_draws_declared) || ...
        ~isscalar(options.joint_draws_declared) || ...
        ~islogical(options.include_input_draws) || ...
        ~isscalar(options.include_input_draws)
    error('SyntheticLogistic:E_OPTIONS', ...
        'Declaration and input-retention options must be logical scalars.');
end

check_choice(options.sampling_dependence, ...
    {'iid', 'dependent', 'unspecified'}, 'sampling_dependence');
check_choice(options.optical_mode, {'fixed', 'paired'}, 'optical_mode');
check_choice(options.optical_uncertainty_kind, ...
    {'fixed', 'measurement_parameter', 'scenario_parameter'}, ...
    'optical_uncertainty_kind');

check_margin(options.boundary_margin, 'boundary_margin');
check_margin(options.ri_reference_margin, 'ri_reference_margin');

n = size(draws, 1);
if ~isa(optical, 'double') || ~isreal(optical) || ...
        any(isnan(optical(:)) | isinf(optical(:))) || ...
        any(optical(:) < 0)
    error('SyntheticLogistic:E_OPTICAL_INPUT', ...
        'Optical depth must be finite, real, nonnegative double data.');
end

if strcmp(options.optical_mode, 'fixed')
    if ~isscalar(optical) || ...
            ~strcmp(options.optical_uncertainty_kind, 'fixed')
        error('SyntheticLogistic:E_OPTICAL_MODE', ...
            'Fixed mode requires one scalar and uncertainty kind fixed.');
    end
    lambda = repmat(optical, n, 1);
else
    if ~isequal(size(optical), [n, 1]) || ...
            strcmp(options.optical_uncertainty_kind, 'fixed')
        error('SyntheticLogistic:E_OPTICAL_MODE', ...
            'Paired mode requires n-by-1 data and a non-fixed kind.');
    end
    lambda = optical;
end

log_da = log(draws(:, 1)) + log(draws(:, 4)) - log(draws(:, 3));
log_pe = log(draws(:, 3)) + log(draws(:, 4)) - log(draws(:, 5));
log_pi = log(draws(:, 7)) - log(draws(:, 2)) ...
    - log(draws(:, 4)) + log(draws(:, 3));

da = checked_exp(log_da, 'DA');
pe = checked_exp(log_pe, 'PE');
pi_tau = checked_exp(log_pi, 'PI_TAU');

ri = zeros(n, 1);
nonzero = draws(:, 6) ~= 0;
log_abs_ri = log(abs(draws(nonzero, 6))) ...
    - 2 .* log(draws(nonzero, 8));
ri(nonzero) = sign(draws(nonzero, 6)) .* ...
    checked_exp(log_abs_ri, 'RI');

coordinates = [da, pe, pi_tau, ri];
h = log_da - lambda;
if any(isnan(h) | isinf(h))
    error('SyntheticLogistic:E_BOUNDARY_RANGE', ...
        'Boundary-coordinate arithmetic exceeded numerical range.');
end

r = expm1(h);
equilibrium = max(r, 0);
positive_branch = r > 0;

below = h < -options.boundary_margin;
within = abs(h) <= options.boundary_margin;
above = h > options.boundary_margin;
fractions = [mean(below), mean(within), mean(above)];

if abs(sum(fractions) - 1) > 1e-12
    error('SyntheticLogistic:E_PARTITION', ...
        'Boundary-band partition failed.');
end

if n < 3
    covariance = struct('state', 'not_reported', ...
        'reason', 'Reporting policy withholds covariance for fewer than three rows.');
else
    covariance = struct('state', 'computed', ...
        'value', cov(coordinates, 0), ...
        'normalization', 'n_minus_one', ...
        'method', 'sample_covariance_of_transformed_rows', ...
        'rank', rank(bsxfun(@minus, coordinates, mean(coordinates, 1))), ...
        'adequacy_established', false);
end

probability = struct('state', 'not_reported', ...
    'reason', 'Joint iid sampling is not declared.');
if options.joint_draws_declared && ...
        strcmp(options.sampling_dependence, 'iid')
    probability = struct('state', 'conditional_estimate', ...
        'value', fractions, ...
        'assumptions_verified', false, ...
        'monte_carlo_error', 'not_estimated');
end

positive_residual = zeros(n, 1);
positive_residual(positive_branch) = equilibrium(positive_branch) .* ...
    (r(positive_branch) - equilibrium(positive_branch));

linear_time = zeros(n, 1);
time_defined = r ~= 0;
linear_time(time_defined) = 1 ./ abs(r(time_defined));
if any(isinf(linear_time) | isnan(linear_time))
    error('SyntheticLogistic:E_RELAXATION_RANGE', ...
        'Finite noncritical relaxation-time arithmetic failed.');
end

ri_margin = options.ri_reference_margin;
ri_fractions = [mean(ri < 0.25 - ri_margin), ...
    mean(abs(ri - 0.25) <= ri_margin), mean(ri > 0.25 + ri_margin)];

result = struct();
result.status = 'research_only';
result.model_family = 'synthetic_attenuated_logistic';
result.analogue_status = 'candidate_only';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.coordinate_convention = struct( ...
    'Da', 'k*L/u; advective_timescale', ...
    'Pe', 'u*L/K; same_L_as_Da', ...
    'Pi_tau', '(V/Q)/(L/u); nominal_hydraulic_to_advective', ...
    'Ri', 'N2/shear^2; gradient_interpretation_requires_local_inputs');
result.group_names = {'Da_advective', 'Pe_shared_length', ...
    'Pi_hydraulic_advective', 'Ri_gradient_candidate'};
result.coordinate_draws = coordinates;
result.coordinate_covariance = covariance;
result.quantile_convention = 'Hyndman_Fan_type_7';
result.quantile_probabilities = [0.025, 0.5, 0.975];
result.coordinate_quantiles = type7(coordinates, result.quantile_probabilities);
result.numeric_policy = struct('max_abs_log_coordinate', 300, ...
    'meaning', 'implementation_bound_not_physical_threshold');
result.input_dependence = struct( ...
    'joint_draws_declared', options.joint_draws_declared, ...
    'sampling_dependence_declared', options.sampling_dependence, ...
    'distribution_verified', false, ...
    'rows_reordered_or_resampled', false, ...
    'optical_mode', options.optical_mode, ...
    'optical_uncertainty_kind', options.optical_uncertainty_kind);
result.effective_sample_size = struct('state', 'not_estimated', ...
    'reason', 'No chain-specific dependence estimator is implemented.');
result.proximity_names = {'below_band', 'within_band', 'above_band'};
result.proximity_fractions = fractions;
result.proximity_probability_estimate = probability;
result.band_definition = struct('coordinate', 'log(Da_advective)-Lambda', ...
    'margin', options.boundary_margin, ...
    'units', 'log_dimensionless', ...
    'within_rule', 'absolute_coordinate_less_than_or_equal_to_margin');
result.log_boundary_coordinate = h;
result.synthetic_growth_coefficient = r;
result.limit_for_strictly_positive_initial_biomass = equilibrium;
result.zero_initial_condition = 'remains_zero_for_all_parameters';
result.positive_branch_residual = struct( ...
    'values', positive_residual, 'applicable', positive_branch, ...
    'outside_mask', 'not_applicable; numeric placeholders are not residuals');
result.linear_relaxation_time = struct( ...
    'values', linear_time, 'applicable', time_defined, ...
    'units', 'dimensionless_time', ...
    'outside_mask', 'undefined exponential time at criticality', ...
    'critical_behavior', 'x(s)=x0/(1+x0*s) for positive x0', ...
    'physical_validation', 'none');
result.ri_reference_diagnostic = struct( ...
    'reference', 0.25, 'margin', ri_margin, ...
    'names', {{'below_reference_band', 'within_reference_band', ...
               'above_reference_band'}}, ...
    'row_fractions', ri_fractions, ...
    'classifier', false, ...
    'profile_coverage_verified', false, ...
    'theorem_assumptions_verified', false);
result.retained_processes = { ...
    'attenuated_growth', 'linear_loss', 'density_dependent_loss'};
result.omitted_processes = [ ...
    item('P_SPATIAL', 'No spatial advection-diffusion equation.'), ...
    item('P_EXCHANGE', 'Hydraulic exchange is not evolved.'), ...
    item('P_SHEAR', 'No stratified shear dynamics or stability solver.'), ...
    item('P_SEDIMENT', 'No sediment or resuspension states.'), ...
    item('P_TROPHIC', 'No trophic interactions.'), ...
    item('P_FORCING', 'No time-dependent forcing.'), ...
    item('P_STRUCTURE', 'No alternative model structures sampled.')];
result.interpretation_limits = [ ...
    item('R_SYNTHETIC_MODEL', 'Not calibrated to a water body.'), ...
    item('R_COORDINATE_CONVENTION', 'Coordinate formulas are explicit conventions.'), ...
    item('R_NO_EMPIRICAL_VALIDATION', 'No ecological transfer validation.'), ...
    item('R_RI_NOT_CLASSIFIER', 'Ri reference does not establish a mixing regime.'), ...
    item('R_INPUT_DECLARATION', 'Sampling declarations are not verified.'), ...
    item('R_BRANCH_RESIDUAL', 'Constructed residual is not independent validation.')];
result.provenance = struct('alignment', ...
    'coordinate row corresponds to the same supplied measurement row', ...
    'invertible', false, 'input_draws_returned', options.include_input_draws);
if options.include_input_draws
    result.input_draws = struct('measurement', draws, ...
        'optical_argument', optical);
end
result.draw_count = n;
result.external_actions = 'none';
result.release = 'No storage, indexing, synchronization, or publication authorized.';
end

function y = checked_exp(x, name)
if any(isnan(x) | isinf(x) | abs(x) > 300)
    error(['SyntheticLogistic:E_' name '_LOG_MAGNITUDE'], ...
        '%s exceeds the declared +/-300 log-magnitude policy.', name);
end
y = exp(x);
if any(isnan(y) | isinf(y) | y <= 0)
    error(['SyntheticLogistic:E_' name '_EXP_RANGE'], ...
        '%s exponentiation failed.', name);
end
end

function check_choice(value, choices, label)
if ~ischar(value) || ~isrow(value) || ~any(strcmp(value, choices))
    error('SyntheticLogistic:E_OPTIONS', ...
        'Invalid declared option: %s.', label);
end
end

function check_margin(value, label)
if ~isa(value, 'double') || ~isreal(value) || ~isscalar(value) || ...
        isnan(value) || isinf(value) || value <= 0
    error('SyntheticLogistic:E_MARGIN', ...
        '%s must be a finite positive dimensionless double scalar.', label);
end
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function q = type7(x, probabilities)
x = sort(x, 1);
position = 1 + (size(x, 1) - 1) .* probabilities(:);
lo = floor(position);
hi = ceil(position);
weight = position - lo;
q = bsxfun(@times, 1 - weight, x(lo, :)) + ...
    bsxfun(@times, weight, x(hi, :));
end

function result = self_tests()
options = struct('joint_draws_declared', false, ...
    'sampling_dependence', 'unspecified', 'optical_mode', 'fixed', ...
    'optical_uncertainty_kind', 'fixed', 'boundary_margin', 1e-6, ...
    'ri_reference_margin', 0.01, 'include_input_draws', false);

draws = repmat([2, 1, 1, 1, 1, 1, 1, 1], 3, 1);
before = draws;
a = synthetic_attenuated_logistic_uncertainty(draws, 0, options);
must(a.ok, 'baseline_envelope');
must(isequal(draws, before), 'input_nonmutation');
b = synthetic_attenuated_logistic_uncertainty(draws, 0, options);
must(isequaln(a, b), 'determinism');
must(all(a.value.limit_for_strictly_positive_initial_biomass == 1), ...
    'positive_branch');

paired = options;
paired.optical_mode = 'paired';
paired.optical_uncertainty_kind = 'scenario_parameter';
c = synthetic_attenuated_logistic_uncertainty( ...
    draws, [0; log(4); log(2)], paired);
must(c.ok, 'paired_input');
must(isequal(c.value.proximity_fractions, [1/3, 1/3, 1/3]), ...
    'three_way_partition');
must(~c.value.positive_branch_residual.applicable(2), ...
    'zero_side_residual_not_applicable');
must(~c.value.linear_relaxation_time.applicable(3), ...
    'critical_exponential_time_not_applicable');

changed = draws;
changed(:, 1) = 0.5;
d = synthetic_attenuated_logistic_uncertainty(changed, 0, options);
must(d.ok && d.value.proximity_fractions(1) == 1, ...
    'Da_change_at_fixed_optical_depth');

two = synthetic_attenuated_logistic_uncertainty(draws(1:2, :), 0, options);
must(two.ok && strcmp(two.value.coordinate_covariance.state, ...
    'not_reported'), 'two_row_covariance_policy');

invalid = draws;
invalid(1, 6) = NaN;
expect_code(synthetic_attenuated_logistic_uncertainty( ...
    invalid, 0, options), 'E_NONFINITE_INPUT');

extreme = draws;
extreme(1, 6) = realmin;
extreme(1, 8) = realmax;
expect_code(synthetic_attenuated_logistic_uncertainty( ...
    extreme, 0, options), 'E_RI_LOG_MAGNITUDE');

invalid = draws;
invalid(1, 2) = 0;
expect_code(synthetic_attenuated_logistic_uncertainty( ...
    invalid, 0, options), 'E_POSITIVE_INPUT');

signed = draws;
signed(:, 6) = [-1; 0; 1];
e = synthetic_attenuated_logistic_uncertainty(signed, 0, options);
must(e.ok && isequal(e.value.coordinate_draws(:, 4), [-1; 0; 1]), ...
    'signed_Ri');

q = type7([0; 10], [0.025, 0.5, 0.975]);
must(max(abs(q - [0.25; 5; 9.75])) < 1e-12, 'type7_known_values');
must(all(all(diff(c.value.coordinate_quantiles, 1, 1) >= 0)), ...
    'quantile_order');

dependent = options;
dependent.joint_draws_declared = true;
dependent.sampling_dependence = 'dependent';
f = synthetic_attenuated_logistic_uncertainty(draws, 0, dependent);
must(f.ok && strcmp(f.value.proximity_probability_estimate.state, ...
    'not_reported'), 'dependent_probability_withheld');

iid_options = dependent;
iid_options.sampling_dependence = 'iid';
g = synthetic_attenuated_logistic_uncertainty(draws, 0, iid_options);
must(g.ok && strcmp(g.value.proximity_probability_estimate.state, ...
    'conditional_estimate'), 'declared_iid_probability');

opt_in = options;
opt_in.include_input_draws = true;
h = synthetic_attenuated_logistic_uncertainty(draws, 0, opt_in);
must(h.ok && isequal(h.value.input_draws.measurement, draws), ...
    'traceability_opt_in');
must(~isfield(a.value, 'input_draws'), 'default_input_minimization');

ri_draws = draws;
ri_draws(:, 6) = [0.1; 0.25; 0.4];
j = synthetic_attenuated_logistic_uncertainty(ri_draws, 0, options);
must(j.ok && isequal(j.value.ri_reference_diagnostic.row_fractions, ...
    [1/3, 1/3, 1/3]) && ~j.value.ri_reference_diagnostic.classifier, ...
    'Ri_reference_not_classifier');

result = struct('status', 'synthetic_self_tests_passed', ...
    'coverage', {{'envelopes', 'nonmutation', 'determinism', ...
    'same_inputs_same_outputs', 'omitted_optical_parameter', ...
    'Da_response', 'covariance_policy', 'N2_nonfinite', ...
    'Ri_extreme_ratio', 'zero_exchange', 'signed_Ri', ...
    'type7_quantiles', 'dependence_declarations', ...
    'input_retention', 'Ri_reference_diagnostic'}}, ...
    'field_validation', 'not_performed');
end

function must(condition, name)
if ~condition
    error('SyntheticLogistic:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end

function expect_code(envelope, code)
must(~envelope.ok && strcmp(envelope.error.code, code), ...
    ['expected_' code]);
must(isfield(envelope, 'schema_version') && ...
    isfield(envelope, 'module_version'), 'failure_versions');
end
