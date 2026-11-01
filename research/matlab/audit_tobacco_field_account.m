function report = audit_tobacco_field_account( ...
    stock, areaM2, durationDays, runoff, eventCategory, provenance)
%AUDIT_TOBACCO_FIELD_ACCOUNT Local stock balance and one-contaminant load.
% stock fields, all in the same declared stockUnit:
% start, observedEnd, deposited, transportedIn,
% collected, transportedOut, categoryLoss, stockUnit
%
% stockUnit: "count" or "kg_dry_total".
% All fluxes are totals over durationDays, not rates.
% categoryLoss means leaving the counting/mass category, not harmless decay.
%
% runoff table:
% timeSeconds, flowLitresPerSecond, concentrationMgPerL,
% backgroundMgPerL. Samples must span the declared sampled event.
%
% provenance fields:
% sourceCitation, boundaryDescription, observationDate, stockCategory,
% contaminantName, samplingAndInterpolationDescription.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not verification or authority.

arguments
    stock {mustBeA(stock,"struct")}
    areaM2 {mustBePositiveScalarDouble}
    durationDays {mustBePositiveScalarDouble}
    runoff {mustBeA(runoff,"table")}
    eventCategory {mustBeA(eventCategory,"string")}
    provenance {mustBeA(provenance,"struct")}
end

stockFields = ["start","observedEnd","deposited","transportedIn", ...
    "collected","transportedOut","categoryLoss","stockUnit"];
sourceFields = ["sourceCitation","boundaryDescription","observationDate", ...
    "stockCategory","contaminantName","samplingAndInterpolationDescription"];
runoffFields = ["timeSeconds","flowLitresPerSecond", ...
    "concentrationMgPerL","backgroundMgPerL"];

if ~isscalar(stock) || ~all(isfield(stock,cellstr(stockFields))) || ...
        ~isscalar(provenance) || ...
        ~all(isfield(provenance,cellstr(sourceFields)))
    error("AugmentedHub:InputConsistency", ...
        "Required stock or provenance fields are missing.");
end

mustBeTextScalar(stock.stockUnit);
if ~any(stock.stockUnit == ["count","kg_dry_total"])
    error("AugmentedHub:InputValue", "Unsupported stock-unit convention.");
end

for name = stockFields(1:end-1)
    value = stock.(char(name));
    mustBeNonnegativeScalarDouble(value);
    if stock.stockUnit == "count" && value ~= fix(value)
        error("AugmentedHub:InputValue", ...
            "Count-based stocks and flows must be integer-valued.");
    end
end

for name = sourceFields
    mustBeTextScalar(provenance.(char(name)));
end

mustBeTextScalar(eventCategory);
if ~any(eventCategory == ["dry_weather","wet_weather","mixed"])
    error("AugmentedHub:InputValue", "Unsupported event category.");
end

if height(runoff) < 2 || ...
        ~all(ismember(runoffFields,string(runoff.Properties.VariableNames)))
    error("AugmentedHub:InputShape", ...
        "Supply at least two runoff samples and all required columns.");
end

for name = runoffFields
    column = runoff.(char(name));
    if ~isa(column,"double") || ~isreal(column) || ...
            size(column,2) ~= 1 || any(~isfinite(column))
        error("AugmentedHub:InputType", ...
            "Runoff columns must be finite real double columns.");
    end
end

t = runoff.timeSeconds;
q = runoff.flowLitresPerSecond;
c = runoff.concentrationMgPerL;
background = runoff.backgroundMgPerL;

if any(diff(t) <= 0) || any(q < 0) || any(c < 0) || any(background < 0)
    error("AugmentedHub:InputValue", ...
        "Times must increase and flow/concentrations must be nonnegative.");
end

sampledDurationSeconds = t(end)-t(1);
if sampledDurationSeconds > durationDays*86400
    error("AugmentedHub:InputConsistency", ...
        "Sampled event duration exceeds the declared accounting period.");
end

predictedEnd = stock.start + stock.deposited + stock.transportedIn ...
    - stock.collected - stock.transportedOut - stock.categoryLoss;

observedResidual = stock.observedEnd-predictedEnd;
loadRate = q.*c;
backgroundRate = q.*background;

volumeLitres = trapz(t,q);
measuredLoadGrams = trapz(t,loadRate)/1000;
backgroundEquivalentLoadGrams = trapz(t,backgroundRate)/1000;
incrementalLoadGrams = trapz(t,loadRate-backgroundRate)/1000;

computed = [predictedEnd,observedResidual,volumeLitres, ...
    measuredLoadGrams,backgroundEquivalentLoadGrams,incrementalLoadGrams];

if any(~isfinite(computed))
    error("AugmentedHub:NumericalRange", ...
        "Accounting or integration exceeded finite arithmetic.");
end

report = struct();
report.documentVersion = "0.1.0";
report.mode = "offline-local-stock-and-runoff-account";
report.provenance = provenance;
report.stockUnit = stock.stockUnit;
report.predictedEndStock = predictedEnd;
report.predictedStockNonnegative = predictedEnd >= 0;
report.observedEndStock = stock.observedEnd;
report.observedMinusPredictedStock = observedResidual;
report.startDensityPerM2 = stock.start/areaM2;
report.endDensityPerM2 = stock.observedEnd/areaM2;
report.netObservedStockChangePerM2PerDay = ...
    (stock.observedEnd-stock.start)/(areaM2*durationDays);
report.sampledEventDurationSeconds = sampledDurationSeconds;
report.eventCategory = eventCategory;
report.runoffVolumeLitres = volumeLitres;
report.measuredContaminantLoadGrams = measuredLoadGrams;
report.backgroundEquivalentLoadGrams = backgroundEquivalentLoadGrams;
report.signedIncrementalLoadGrams = incrementalLoadGrams;
report.integrationConvention = ...
    "Trapezoidal integration of sampled flow and load-rate products";
report.stockBalanceToleranceSpecified = false;
report.sourceAttributionEstablished = false;
report.wholePeriodRunoffCoverageEstablished = false;
report.toxicityOrDamagedWaterVolumeEstimated = false;
report.inputAuthenticityVerified = false;
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value < 0
    error("AugmentedHub:InputValue", ...
        "Require an actual finite nonnegative scalar double.");
end
end

function mustBePositiveScalarDouble(value)
mustBeNonnegativeScalarDouble(value);
if value == 0
    error("AugmentedHub:InputValue", ...
        "Require a strictly positive scalar double.");
end
end

function mustBeTextScalar(value)
if ~isa(value,"string") || ~isscalar(value) || ...
        ismissing(value) || strlength(value) == 0
    error("AugmentedHub:InputValue", ...
        "Require a nonempty nonmissing string scalar.");
end
end
