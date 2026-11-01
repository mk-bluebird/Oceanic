function report = audit_flux_target_identifiability( ...
    H, observations, observationCovariance, targetContrast, relativeTolerance)
%AUDIT_FLUX_TARGET_IDENTIFIABILITY Linear target estimability audit.
% Model: y = H*x + error, with supplied positive-definite covariance.
% Target: targetContrast.'*x.
% Flux coordinates and observation units must be declared externally.
% Numerical rank uses the supplied tolerance.
% No nonnegativity constraints or field measurements are inferred.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not verification or authority.

arguments
    H {mustBeA(H,"double"), mustBeReal, mustBeFinite}
    observations {mustBeA(observations,"double"), mustBeReal, mustBeFinite}
    observationCovariance {mustBeA(observationCovariance,"double"), ...
        mustBeReal, mustBeFinite}
    targetContrast {mustBeA(targetContrast,"double"), ...
        mustBeReal, mustBeFinite}
    relativeTolerance {mustBeOpenUnitScalarDouble}
end

[m,n] = size(H);

if isempty(H) || ~ismatrix(H) || ...
        ~isvector(observations) || numel(observations) ~= m || ...
        ~isvector(targetContrast) || numel(targetContrast) ~= n
    error("AugmentedHub:InputShape", ...
        "Supply compatible nonempty observation and target dimensions.");
end

R = observationCovariance;
if ~isequal(size(R),[m,m]) || ~isequal(R,R.')
    error("AugmentedHub:InputValue", ...
        "Observation covariance must be exactly symmetric and compatible.");
end

[L,flag] = chol(R,"lower");
if flag ~= 0
    error("AugmentedHub:InputValue", ...
        "Observation covariance must be positive definite.");
end

y = observations(:);
a = targetContrast(:);
Hw = L\H;
yw = L\y;

if any(~isfinite(Hw),"all") || any(~isfinite(yw))
    error("AugmentedHub:NumericalRange", ...
        "Whitening exceeded finite arithmetic.");
end

[U,S,V] = svd(Hw,"econ");
s = diag(S);
dimension = min(m,n);
s = s(1:dimension);
U = U(:,1:dimension);
V = V(:,1:dimension);

largest = max(s);
cutoff = relativeTolerance*largest;
selected = s > cutoff;
rankH = sum(selected);

Vr = V(:,selected);
Ur = U(:,selected);
sr = s(selected);

projectedTarget = Vr*(Vr.'*a);
targetResidual = a-projectedTarget;
targetResidualNorm = norm(targetResidual);
targetTolerance = relativeTolerance*max(1,norm(a));
estimable = targetResidualNorm <= targetTolerance;

estimate = NaN;
variance = NaN;
measurementWeights = NaN(m,1);

if estimable
    if rankH == 0
        estimate = 0;
        variance = 0;
        measurementWeights = zeros(m,1);
    else
        coefficients = (Vr.'*a)./sr;
        weightsWhitened = Ur*coefficients;
        estimate = weightsWhitened.'*yw;
        variance = sum(coefficients.^2);
        measurementWeights = L.'\weightsWhitened;
    end
end

if any(isinf([estimate;variance;measurementWeights]))
    error("AugmentedHub:NumericalRange", ...
        "Target calculation exceeded finite arithmetic.");
end

report = struct();
report.mode = "offline-linear-target-identifiability";
report.observationRank = rankH;
report.fluxDimension = n;
report.fullFluxVectorIdentifiableAtTolerance = rankH == n;
report.targetIdentifiableAtTolerance = estimable;
report.targetRowSpaceResidualNorm = targetResidualNorm;
report.targetResidualTolerance = targetTolerance;
report.singularValueCutoff = cutoff;
report.singularValues = s;
report.targetEstimate = estimate;
report.modelBasedTargetVariance = variance;
report.measurementWeights = measurementWeights;
report.nonnegativityConstraintsUsed = false;
report.observationModelValidated = false;
report.covarianceValidated = false;
report.unitScalingValidated = false;
report.confidenceIntervalComputed = false;
end

function mustBeOpenUnitScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0 || value >= 1
    error("AugmentedHub:InputValue", ...
        "Require an actual finite scalar double strictly between zero and one.");
end
end
