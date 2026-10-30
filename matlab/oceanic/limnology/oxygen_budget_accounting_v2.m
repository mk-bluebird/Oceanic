function result = oxygen_budget_accounting_v2(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% No identity, consent, authorization, or authority is established.
% Local accounting only; no I/O, storage, networking, or actuation.
% Operations: budget, partition.
% Built-in double quantities; char rows or scalar strings for text.

if nargin ~= 2
    result = bad('E_ARGUMENTS','input'); return
end
op = asText(varargin{1});
x = varargin{2};
if isempty(op)
    result = bad('E_OPERATION','operation'); return
end

switch op
    case 'budget'
        result = budget(x);
    case 'partition'
        result = partitionFluxes(x);
    otherwise
        result = bad('E_OPERATION','operation');
end
end

function r = budget(x)
required = {'schema_version','volume_m3','start_day','end_day', ...
    'initial_mg_L','final_mg_L','concentration_support', ...
    'boundary_model','sink_partition','fluxes'};
e = checkShape(x,required,{'translation_review'},'input');
if ~isempty(e), r=e; return; end
if ~isequal(x.schema_version,2)
    r=bad('E_SCHEMA_VERSION','input'); return
end
if ~number(x.volume_m3) || x.volume_m3<=0
    r=bad('E_VOLUME','input.volume_m3'); return
end
if ~number(x.start_day) || ~number(x.end_day) || x.end_day<=x.start_day
    r=bad('E_DURATION','input'); return
end
if ~number(x.initial_mg_L) || x.initial_mg_L<0
    r=bad('E_CONCENTRATION_INITIAL','input.initial_mg_L'); return
end
if ~number(x.final_mg_L) || x.final_mg_L<0
    r=bad('E_CONCENTRATION_FINAL','input.final_mg_L'); return
end
if ~strcmp(asText(x.concentration_support),'volume_weighted_mean')
    r=bad('E_CONCENTRATION_SUPPORT','input.concentration_support'); return
end
if ~strcmp(asText(x.boundary_model),'constant_volume_control_volume')
    r=bad('E_BOUNDARY_MODEL','input.boundary_model'); return
end

sinkPolicy=asText(x.sink_partition);
if strcmp(sinkPolicy,'overlap_declared')
    r=bad('E_DOUBLE_COUNTED_SINK','input.sink_partition'); return
elseif ~strcmp(sinkPolicy,'declared_disjoint')
    r=bad('E_SINK_PARTITION','input.sink_partition'); return
end

reviewPresent=isfield(x,'translation_review');
review=struct();
if reviewPresent
    features={'response','boundary','time_support','units', ...
        'assumptions','alternative_explanations'};
    e=checkShape(x.translation_review,features,{},'input.translation_review');
    if ~isempty(e), r=e; return; end
    for i=1:numel(features)
        value=asText(x.translation_review.(features{i}));
        if ~any(strcmp(value,{'preserved','concern','unreviewed'}))
            r=bad('E_REVIEW_STATUS','input.translation_review'); return
        end
        review.(features{i})=value;
    end
end

p=partitionFluxes(x.fluxes);
if ~p.ok, r=p; return; end
registry=termRegistry();
knownNet=0;
absoluteFlux=0;
residualUsed=false;

for i=1:numel(registry)
    name=registry(i).name;
    f=x.fluxes.(name);
    state=asText(f.state);
    if any(strcmp(state,quantifiedStates()))
        if f.start_day~=x.start_day || f.end_day~=x.end_day
            r=bad('E_FLUX_TIME_SUPPORT_MISMATCH','input.fluxes'); return
        end
        knownNet=knownNet+registry(i).sign*f.value;
        absoluteFlux=absoluteFlux+abs(f.value);
        if ~isfinite(knownNet) || ~isfinite(absoluteFlux)
            r=bad('E_FLUX_ACCUMULATION_RANGE','input.fluxes'); return
        end
        residualUsed=residualUsed || strcmp(state,'inferred_by_residual');
    end
end

conversion=0.001;
volumeFactor=conversion*x.volume_m3;
duration=x.end_day-x.start_day;
initialMass=volumeFactor*x.initial_mg_L;
finalMass=volumeFactor*x.final_mg_L;
observedChange=finalMass-initialMass;
if volumeFactor==0 || any(~isfinite( ...
        [volumeFactor duration initialMass finalMass observedChange]))
    r=bad('E_NUMERIC_RANGE','input'); return
end

v=struct();
v.schema_version=2;
v.registered_term_set_version='1.0.0';
v.scope_registry_version='1.0.0';
v.scope_declaration=struct( ...
    'concentration_support','volume_weighted_mean', ...
    'boundary_model','constant_volume_control_volume', ...
    'start_day',x.start_day,'end_day',x.end_day);
v.air_exchange_sign_convention='positive_into_water_negative_out_of_water';
v.conversion_kg_per_m3_per_mg_L=conversion;
v.temperature_or_salinity_correction_applied=false;
v.sink_partition_declaration=sinkPolicy;
v.sink_disjointness_verified=false;
v.flux_partition=p.value.partition;
v.all_registered_terms_present=true;
v.all_registered_terms_quantified=p.value.unresolved_count==0;
v.scope_completeness_assessed=false;
v.initial_inventory_kg_O2=initialMass;
v.final_inventory_kg_O2=finalMass;
v.observed_change_kg_O2=observedChange;
v.known_net_flux_kg_O2_per_day=knownNet;
v.translation_review_present=reviewPresent;
v.translation_review_record=review;
v.translation_review_binding_verified=false;
v.translation_fidelity_verified=false;
v.independent_closure_assessed=~residualUsed;
v.uncertainty_propagated=false;
v.numeric_error_bound=struct('status','not_established');
v.ecological_safety_assessed=false;

if p.value.unresolved_count>0
    v.budget_status='registered_fluxes_unresolved';
    v.prediction_status='not_computed';
    r=good(v); return
end

change=duration*knownNet;
predictedMass=initialMass+change;
residual=observedChange-change;
predictedC=predictedMass/volumeFactor;

if any(~isfinite([change predictedMass residual predictedC]))
    r=bad('E_BUDGET_ARITHMETIC_RANGE','input.fluxes'); return
end
if predictedMass<0
    r=bad('E_NEGATIVE_PREDICTED_INVENTORY','input.fluxes'); return
end

scale=max(abs(observedChange),abs(change));
if scale==0
    relativeResidual=struct('status','undefined','reason','zero_change_scale');
    smallResidual=false;
else
    ratio=abs(residual)/scale;
    relativeResidual=struct('status','defined','value',ratio);
    smallResidual=ratio<=sqrt(eps('double'));
end

inventoryScale=max(abs(initialMass),abs(finalMass));
smallObservedDifference=inventoryScale>0 && ...
    abs(observedChange)<=sqrt(eps('double'))*inventoryScale;
fluxCancellation=absoluteFlux>0 && ...
    abs(knownNet)<=sqrt(eps('double'))*absoluteFlux;

v.budget_status='all_registered_fluxes_quantified';
v.predicted_change_kg_O2=change;
v.predicted_final_inventory_kg_O2=predictedMass;
v.predicted_final_mg_L=predictedC;
v.inventory_residual_kg_O2=residual;
v.residual_relative_to_change=relativeResidual;
v.numerical_diagnostics=struct( ...
    'small_residual_relative_to_change',smallResidual, ...
    'small_endpoint_difference',smallObservedDifference, ...
    'flux_cancellation_possible',fluxCancellation, ...
    'diagnostics_are_error_bounds',false);
r=good(v);
end

function r=partitionFluxes(fluxes)
registry=termRegistry();
names={registry.name};
e=checkShape(fluxes,names,{},'input.fluxes');
if ~isempty(e), r=e; return; end

states=[quantifiedStates(),{'unknown','not_collected','withheld'}];
partition=struct();
for i=1:numel(states), partition.(states{i})={}; end
unresolved=0;

for i=1:numel(registry)
    name=registry(i).name;
    path=['input.fluxes.' name];
    f=fluxes.(name);

    if ~isstruct(f)
        r=bad('E_FLUX_NOT_STRUCT',path); return
    elseif ~isscalar(f)
        r=bad('E_FLUX_NOT_SCALAR',path); return
    elseif ~isfield(f,'state')
        r=bad('E_FLUX_STATE_MISSING',path); return
    end

    state=asText(f.state);
    if isempty(state)
        r=bad('E_FLUX_STATE_TYPE',path); return
    elseif ~any(strcmp(state,states))
        r=bad('E_FLUX_STATE',path); return
    end

    if any(strcmp(state,quantifiedStates()))
        e=checkShape(f,{'state','value','unit','time_support', ...
            'start_day','end_day'},{},path);
        if ~isempty(e), r=e; return; end
        if ~number(f.value)
            r=bad('E_FLUX_VALUE_TYPE',path); return
        elseif ~strcmp(asText(f.unit),'kg_O2_per_day')
            r=bad('E_FLUX_UNIT',path); return
        elseif ~strcmp(asText(f.time_support),'interval_mean')
            r=bad('E_FLUX_TIME_SUPPORT',path); return
        elseif ~number(f.start_day) || ~number(f.end_day) || ...
                f.end_day<=f.start_day
            r=bad('E_FLUX_INTERVAL',path); return
        elseif ~registry(i).signed && f.value<0
            r=bad('E_FLUX_SIGN',path); return
        elseif strcmp(state,'assumed_negligible') && f.value~=0
            r=bad('E_NEGLIGIBLE_NONZERO',path); return
        end
    else
        e=checkShape(f,{'state'},{},path);
        if ~isempty(e)
            r=bad('E_UNRESOLVED_EXTRA_MEMBER',path); return
        end
        unresolved=unresolved+1;
    end
    partition.(state){end+1}=name;
end

r=good(struct('partition',partition,'unresolved_count',unresolved, ...
    'registered_term_set_version','1.0.0'));
end

function r=termRegistry()
r=struct('name',{},'sign',{},'signed',{});
r(end+1)=struct('name','inflow','sign',1,'signed',false);
r(end+1)=struct('name','outflow','sign',-1,'signed',false);
r(end+1)=struct('name','air_exchange','sign',1,'signed',true);
r(end+1)=struct('name','production','sign',1,'signed',false);
r(end+1)=struct('name','water_column_respiration','sign',-1,'signed',false);
r(end+1)=struct('name','sediment_demand','sign',-1,'signed',false);
r(end+1)=struct('name','other_demand','sign',-1,'signed',false);
end

function s=quantifiedStates()
s={'measured','estimated_from_measurements', ...
    'inferred_by_residual','assumed_negligible'};
end

function e=checkShape(x,required,optional,path)
e=[];
if ~isstruct(x) || ~isscalar(x)
    e=bad('E_RECORD',path); return
end
if numel(unique(required))~=numel(required) || ...
        numel(unique([required optional]))~=numel([required optional])
    e=bad('E_INTERNAL_KEY_REGISTRY',path); return
end
if ~all(isfield(x,required))
    e=bad('E_MISSING_MEMBER',path); return
end
if any(~ismember(fieldnames(x),[required optional]))
    e=bad('E_UNKNOWN_MEMBER',path);
end
end

function tf=number(x)
tf=isa(x,'double') && isreal(x) && isscalar(x) && ...
    ~issparse(x) && isfinite(x);
end

function t=asText(x)
t='';
if ischar(x) && isrow(x) && ~isempty(x)
    t=x;
elseif isstring(x) && isscalar(x) && ~ismissing(x) && strlength(x)>0
    t=char(x);
end
end

function r=good(v)
r=struct('ok',true,'value',v);
end

function r=bad(code,path)
e=struct('code',code,'path',path, ...
    'message_key',['oxygen_budget_accounting_v2.' code], ...
    'args',struct());
r=struct('ok',false,'error',e);
end
