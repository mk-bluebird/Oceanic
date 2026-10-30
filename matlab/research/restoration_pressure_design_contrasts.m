function envelope = restoration_pressure_design_contrasts(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% result = restoration_pressure_design_contrasts( ...
%     means, covariance, unit, scope)
%
% means: finite real double 2-by-2:
% rows:    design condition 0, design condition 1
% columns: pressure condition 0, pressure condition 1
%
% covariance: [] or finite real symmetric positive-semidefinite 4-by-4.
% Ordering follows means(:):
% [mu00; mu10; mu01; mu11].
%
% unit, scope: nonempty character rows.
%
% Contrasts:
% design at pressure 0; design at pressure 1;
% pressure at design 0; pressure at design 1;
% design-by-pressure interaction.
%
% No confidence intervals or causal conclusions are generated.
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
        error('RestorationContrasts:E_ARGUMENTS', ...
            'Supply means, covariance, unit, and scope.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, 'error', []);
catch exception
    prefix = 'RestorationContrasts:';
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

function result = evaluate(means, covariance, unit, scope)
if ~isa(means, 'double') || ~isreal(means) || ...
        ~isequal(size(means), [2, 2]) || ...
        any(isnan(means(:)) | isinf(means(:)))
    error('RestorationContrasts:E_MEANS', ...
        'Means must be a finite real double 2-by-2 matrix.');
end

check_text(unit, 'E_UNIT');
check_text(scope, 'E_SCOPE');

C = [
    -1,  1,  0,  0;
     0,  0, -1,  1;
    -1,  0,  1,  0;
     0, -1,  0,  1;
     1, -1, -1,  1
];

values = C * means(:);
if any(isnan(values) | isinf(values))
    error('RestorationContrasts:E_NUMERIC_RANGE', ...
        'Contrast arithmetic exceeded numerical range.');
end

standard_errors = NaN(5, 1);
contrast_covariance = NaN(5, 5);
uncertainty_state = 'not_supplied';
symmetrization_applied = false;
numeric_tolerance = NaN;

if ~isempty(covariance)
    if ~isa(covariance, 'double') || ~isreal(covariance) || ...
            ~isequal(size(covariance), [4, 4]) || ...
            any(isnan(covariance(:)) | isinf(covariance(:)))
        error('RestorationContrasts:E_COVARIANCE', ...
            'Covariance must be empty or finite real double 4-by-4.');
    end

    scale = max(abs(covariance(:)));
    numeric_tolerance = 1e-10 * max(scale, realmin);

    if any(any(abs(covariance-covariance') > numeric_tolerance))
        error('RestorationContrasts:E_COVARIANCE', ...
            'Covariance is not symmetric within the declared tolerance.');
    end

    symmetrization_applied = ~isequal(covariance, covariance');
    symmetric = covariance/2 + covariance'/2;
    eigenvalues = eig(symmetric);

    if any(eigenvalues < -numeric_tolerance)
        error('RestorationContrasts:E_COVARIANCE', ...
            'Covariance is not positive-semidefinite within tolerance.');
    end

    contrast_covariance = C * symmetric * C';
    diagonal = diag(contrast_covariance);
    output_tolerance = 16 * numeric_tolerance;

    if any(isnan(contrast_covariance(:)) | ...
            isinf(contrast_covariance(:))) || ...
            any(diagonal < -output_tolerance)
        error('RestorationContrasts:E_NUMERIC_RANGE', ...
            'Derived covariance failed numerical checks.');
    end

    standard_errors = sqrt(max(diagonal, 0));
    uncertainty_state = 'propagated_from_supplied_joint_covariance';
end

names = {
    'design_difference_at_pressure_0';
    'design_difference_at_pressure_1';
    'pressure_difference_at_design_0';
    'pressure_difference_at_design_1';
    'design_by_pressure_interaction'
};

result = struct();
result.status = 'descriptive_contrast_calculation';
result.cell_means = means;
result.cell_order = {'mu00', 'mu10', 'mu01', 'mu11'};
result.contrast_names = names;
result.contrast_matrix = C;
result.contrast_values = values;
result.standard_errors = standard_errors;
result.contrast_covariance = contrast_covariance;
result.uncertainty_state = uncertainty_state;
result.covariance_symmetrization_applied = symmetrization_applied;
result.covariance_numeric_tolerance = numeric_tolerance;
result.unit_declared = unit;
result.scope_declared = scope;
result.assignment_design_verified = false;
result.pressure_measurement_verified = false;
result.covariance_validity_verified = false;
result.causal_attribution_established = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = [ ...
    item('R_DESCRIPTIVE', 'Contrasts alone do not establish causal effects.'), ...
    item('R_COVARIANCE', ...
        'Matrix checks do not verify the supplied covariance model.'), ...
    item('R_NO_INTERVALS', ...
        'No confidence intervals or significance tests are calculated.'), ...
    item('R_DIRECTION', ...
        'The ecological meaning of positive outcomes must be declared separately.'), ...
    item('R_IMPLEMENTATION', ...
        'Intervention fidelity and continuing pressures require independent evidence.')];
end

function check_text(value, code)
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error(['RestorationContrasts:' code], ...
        'Unit and scope must be nonempty character rows.');
end
end

function value = item(code, message)
value = struct('code', code, 'message', message);
end

function result = self_tests()
means = [2, 1; 5, 2];
covariance = eye(4) * 0.1;
before = {means, covariance};

a = restoration_pressure_design_contrasts( ...
    means, covariance, 'synthetic_unit', 'Synthetic factorial fixture');
must(a.ok, 'baseline');
must(max(abs(a.value.contrast_values - [3; 1; -1; -3; -2])) ...
    < 1e-12, 'known_contrasts');
must(abs(a.value.standard_errors(1)-sqrt(0.2)) < 1e-12, ...
    'standard_error');
must(abs(a.value.standard_errors(5)-sqrt(0.4)) < 1e-12, ...
    'interaction_standard_error');
must(isequal(before, {means, covariance}), 'nonmutation');

b = restoration_pressure_design_contrasts( ...
    means, covariance, 'synthetic_unit', 'Synthetic factorial fixture');
must(isequaln(a, b), 'determinism');

missing = restoration_pressure_design_contrasts( ...
    means, [], 'synthetic_unit', 'No uncertainty supplied');
must(missing.ok && strcmp(missing.value.uncertainty_state, ...
    'not_supplied'), 'uncertainty_not_invented');

invalid = restoration_pressure_design_contrasts( ...
    means, -eye(4), 'synthetic_unit', 'Invalid covariance');
must(~invalid.ok && strcmp(invalid.error.code, 'E_COVARIANCE'), ...
    'invalid_covariance');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_validation', 'not_performed', ...
    'coverage', {{'contrasts', 'covariance_propagation', ...
    'nonmutation', 'determinism', 'missing_covariance', 'invalid_covariance'}});
end

function must(condition, name)
if ~condition
    error('RestorationContrasts:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
