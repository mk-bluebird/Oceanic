function report = screen_cigarette_environment( ...
    consumedCigarettes, filteredFraction, litterFraction, ...
    dryButtMassGrams, packagingGramsPerPack, cigarettesPerPack, ...
    lifecycleWaterLitresPerCigarette, forestHaPerMillionCigarettes)
%SCREEN_CIGARETTE_ENVIRONMENT Offline scenario accounting.
% Interval arguments are [low high], finite and nonnegative.
% Fractions must also lie in [0,1].
% Forest intensity may be [NaN NaN] when evidence is unavailable.
%
% Litter fraction is the fraction of generated filtered butts littered.
% Water input is a declared lifecycle factor, not local pollution volume.
% Forest input must have a compatible source, year, and boundary.
% No global factors or observed data are embedded.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent, verification, or authority.

arguments
    consumedCigarettes {mustBeNonnegativeInterval}
    filteredFraction {mustBeFractionInterval}
    litterFraction {mustBeFractionInterval}
    dryButtMassGrams {mustBeNonnegativeInterval}
    packagingGramsPerPack {mustBeNonnegativeInterval}
    cigarettesPerPack {mustBePositiveScalarDouble}
    lifecycleWaterLitresPerCigarette {mustBeNonnegativeInterval}
    forestHaPerMillionCigarettes {mustBeOptionalForestInterval}
end

C = consumedCigarettes(:).';
F = filteredFraction(:).';
L = litterFraction(:).';
M = dryButtMassGrams(:).';
P = packagingGramsPerPack(:).';
W = lifecycleWaterLitresPerCigarette(:).';
A = forestHaPerMillionCigarettes(:).';

generatedButts = C.*F;
litteredButts = generatedButts.*L;
buttWasteKg = generatedButts.*M/1000;
litterWasteKg = litteredButts.*M/1000;
packagingWasteKg = (C/cigarettesPerPack).*P/1000;
waterLitres = C.*W;

forestAvailable = all(isfinite(A));
forestHa = [NaN NaN];
if forestAvailable
    forestHa = (C/1e6).*A;
end

values = [
    generatedButts
    litteredButts
    buttWasteKg
    litterWasteKg
    packagingWasteKg
    waterLitres
    waterLitres/1000
    forestHa
];

if any(isinf(values),"all")
    error("AugmentedHub:NumericalRange", ...
        "Scenario arithmetic exceeded finite double range.");
end

metric = [
    "generated_filtered_butts"
    "newly_littered_butts"
    "generated_dry_butt_waste"
    "newly_littered_dry_butt_waste"
    "packaging_waste"
    "lifecycle_water_screen"
    "lifecycle_water_screen"
    "supply_chain_forest_conversion_attribution"
];

unit = [
    "count"
    "count"
    "kg"
    "kg"
    "kg"
    "L"
    "m3"
    "ha"
];

report = struct();
report.mode = "offline-cigarette-environment-scenario-screen";
report.intervalMeaning = ...
    "Monotone low/high input scenario envelope; not a confidence interval";
report.consumedCigarettes = C;
report.forestAttributionAvailable = forestAvailable;
report.standingLitterStockEstimated = false;
report.waterPollutionVolumeEstimated = false;
report.scarcityWeightedWaterEstimated = false;
report.filterPlasticMassEstimated = false;
report.inputFactorsValidated = false;
report.sourceAndBoundaryCompatibilityVerified = false;
report.results = table( ...
    metric,unit,values(:,1),values(:,2), ...
    "VariableNames",["metric","unit","lowScenario","highScenario"]);
report.accountingNotes = [
    "Littered butt waste is a subset of generated butt waste"
    "Water rows in litres and cubic metres are the same quantity"
    "Butt mass is not automatically filter-plastic mass"
    "Forest attribution is not measured local forest loss"
    "Regional factors and uncertainty require separate evidence"
];
end

function mustBeNonnegativeInterval(value)
if ~isa(value,"double") || ~isreal(value) || ...
        ~isvector(value) || numel(value) ~= 2 || ...
        any(~isfinite(value),"all") || any(value < 0,"all") || ...
        value(1) > value(2)
    error("AugmentedHub:InputValue", ...
        "Require a finite nonnegative double interval [low high].");
end
end

function mustBeFractionInterval(value)
mustBeNonnegativeInterval(value);
if any(value > 1,"all")
    error("AugmentedHub:InputValue", "Fractions must lie in [0,1].");
end
end

function mustBePositiveScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0
    error("AugmentedHub:InputValue", ...
        "Require an actual positive finite scalar double.");
end
end

function mustBeOptionalForestInterval(value)
if isa(value,"double") && isreal(value) && isvector(value) && ...
        numel(value) == 2 && all(isnan(value),"all")
    return;
end
mustBeNonnegativeInterval(value);
end
