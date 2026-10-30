function result = aquatic_regime_uncertainty(draws, boundary_margin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; no identity verification, consent, or authorization.
%
% Columns:
% [k_react_s_inv, Q_m3_s, u_m_s, L_m, K_m2_s, ...
%  N2_s_inv2, V_m3, shear_s_inv, optical_depth]
%
% Each row is one supplied joint uncertainty draw.
% No arguments: execute synthetic self-tests only.
%
% Proposed definitions:
% Da = k*L/u; Pe = u*L/K;
% Pi_tau = (V/Q)/(L/u); Ri = N2/shear^2.
%
% Synthetic model:
% dx/ds = x*(Da*exp(-optical_depth) - 1 - x), x >= 0.

if nargin == 0
    result = run_self_tests();
    return;
end

if nargin ~= 2
    error('AquaticRegime:Arguments', ...
        'Supply joint draws and a positive log-boundary margin.');
end

validateattributes(draws, {'double'}, ...
    {'real', 'finite', '2d', 'nonempty'}, mfilename, 'draws');

if size(draws, 2) ~= 9 || size(draws, 1) < 2
    error('AquaticRegime:Shape', ...
        'draws must have nine columns and at least two rows.');
end

validateattributes(boundary_margin, {'double'}, ...
    {'real', 'finite', 'scalar', 'positive'}, ...
    mfilename, 'boundary_margin');

positive_columns = [1, 2, 3, 4, 5, 7, 8];
if any(any(draws(:, positive_columns) <= 0))
    error('AquaticRegime:PositiveInputs', ...
        'k, Q, u, L, K, V, and shear must be strictly positive.');
end

if any(draws(:, 9) < 0)
    error('AquaticRegime:OpticalDepth', ...
        'Optical depth must be nonnegative.');
end

k = draws(:, 1);
Q = draws(:, 2);
u = draws(:, 3);
L = draws(:, 4);
K = draws(:, 5);
N2 = draws(:, 6);
V = draws(:, 7);
shear = draws(:, 8);
optical_depth = draws(:, 9);

log_Da = log(k) + log(L) - log(u);
log_Pe = log(u) + log(L) - log(K);
log_Pi = log(V) - log(Q) - log(L) + log(u);

Ri = zeros(size(N2));
nonzero = N2 ~= 0;
Ri(nonzero) = sign(N2(nonzero)) .* ...
    exp(log(abs(N2(nonzero))) - 2 .* log(shear(nonzero)));

groups = [exp(log_Da), exp(log_Pe), exp(log_Pi), Ri];
bad = isnan(groups) | isinf(groups);

if any(bad(:)) || any(any(groups(:, 1:3) <= 0)) || ...
        any(nonzero & Ri == 0)
    error('AquaticRegime:CoordinateRange', ...
        'A coordinate overflowed or underflowed; rescale or review inputs.');
end

group_covariance = cov(groups, 0);
if any(isnan(group_covariance(:)) | isinf(group_covariance(:)))
    error('AquaticRegime:CovarianceRange', ...
        'Coordinate covariance exceeded numerical range.');
end

h = log_Da - optical_depth;
if any(isnan(h) | isinf(h))
    error('AquaticRegime:BoundaryRange', ...
        'Boundary coordinate exceeded numerical range.');
end

r = expm1(h);
if any(isnan(r) | isinf(r))
    error('AquaticRegime:GrowthRange', ...
        'Synthetic growth coefficient exceeded numerical range.');
end

near_boundary = abs(h) <= boundary_margin;
zero_biomass_side = h < -boundary_margin;
positive_biomass_side = h > boundary_margin;

probabilities = [mean(zero_biomass_side), ...
                 mean(near_boundary), ...
                 mean(positive_biomass_side)];

assert(abs(sum(probabilities) - 1) < 1e-12, ...
    'AquaticRegime:Partition', 'Regime partition failed.');

equilibrium = max(r, 0);
local_return_rate = abs(r);
local_relaxation_time = inf(size(r));
noncritical = local_return_rate > 0;
local_relaxation_time(noncritical) = ...
    1 ./ local_return_rate(noncritical);

positive_bracket = exp(h) - 1 - equilibrium;
equilibrium_residual = equilibrium .* positive_bracket;
if any(isnan(equilibrium_residual) | isinf(equilibrium_residual))
    error('AquaticRegime:ResidualRange', ...
        'Synthetic equilibrium residual exceeded numerical range.');
end

result = struct();
result.status = 'research_only';
result.model = 'synthetic_attenuated_logistic_model';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.group_names = {'Da', 'Pe', 'Pi_tau', 'Ri'};
result.coordinate_draws = groups;
result.coordinate_covariance = group_covariance;
result.quantile_probabilities = [0.025, 0.5, 0.975];
result.coordinate_quantiles = empirical_quantiles( ...
    groups, result.quantile_probabilities);
result.log_boundary_coordinate = h;
result.log_boundary_margin = boundary_margin;
result.regime_names = { ...
    'zero_biomass_side', 'boundary_band', 'positive_biomass_side'};
result.regime_probabilities = probabilities;
result.synthetic_growth_coefficient = r;
result.synthetic_attracting_equilibrium = equilibrium;
result.synthetic_equilibrium_residual = equilibrium_residual;
result.local_relaxation_time_dimensionless = local_relaxation_time;
result.input_dependence = ...
    'Preserved from supplied joint rows; no prior distribution imposed.';
result.draw_count = size(draws, 1);
result.effective_sample_size = ...
    'Not estimated; rows may be dependent.';
result.external_actions = 'none';
result.limitations = { ...
    'Coordinate definitions are proposed conventions.', ...
    'Synthetic model is not calibrated to any water body.', ...
    'Boundary-band probability is not a confidence interval.', ...
    'No real-world regime equivalence is established.', ...
    'Inf relaxation time denotes a zero linear return rate.'};
end

function values = empirical_quantiles(samples, probabilities)
sorted = sort(samples, 1);
n = size(sorted, 1);
positions = 1 + (n - 1) .* probabilities(:);
lower = floor(positions);
upper = ceil(positions);
weights = positions - lower;
values = bsxfun(@times, 1 - weights, sorted(lower, :)) + ...
         bsxfun(@times, weights, sorted(upper, :));
end

function result = run_self_tests()
% Synthetic SI-valued fixtures, not observations.
base = [2, 1, 1, 1, 1, 1, 1, 1, 0];
comparison = base;
comparison(9) = log(4);
draws = [base; comparison];

out = aquatic_regime_uncertainty(draws, 1e-6);
assert(max(abs(out.coordinate_draws(1, :) - ...
    out.coordinate_draws(2, :))) < 1e-12);
assert(out.synthetic_attracting_equilibrium(1) > 0);
assert(out.synthetic_attracting_equilibrium(2) == 0);
assert(max(abs(out.regime_probabilities - [0.5, 0, 0.5])) < 1e-12);

critical = repmat(base, 2, 1);
critical(:, 9) = log(2);
boundary = aquatic_regime_uncertainty(critical, 1e-6);
assert(boundary.regime_probabilities(2) == 1);

signed = draws;
signed(:, 6) = [-1; 0];
signed_result = aquatic_regime_uncertainty(signed, 1e-6);
assert(signed_result.coordinate_draws(1, 4) < 0);
assert(signed_result.coordinate_draws(2, 4) == 0);

invalid = draws;
invalid(1, 2) = 0;
rejected_zero_exchange = false;
try
    aquatic_regime_uncertainty(invalid, 1e-6);
catch exception
    rejected_zero_exchange = ...
        strcmp(exception.identifier, 'AquaticRegime:PositiveInputs');
end
assert(rejected_zero_exchange);

invalid = draws;
invalid(1, 1) = NaN;
rejected_nonfinite = false;
try
    aquatic_regime_uncertainty(invalid, 1e-6);
catch
    rejected_nonfinite = true;
end
assert(rejected_nonfinite);

result = struct();
result.status = 'synthetic_self_tests_passed';
result.test_names = { ...
    'same_four_coordinates_different_equilibrium', ...
    'boundary_band_detection', ...
    'signed_buoyancy_preservation', ...
    'zero_exchange_rejection', ...
    'nonfinite_input_rejection'};
result.field_validation = 'not_performed';
end
