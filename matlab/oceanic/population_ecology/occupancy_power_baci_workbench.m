function result=occupancy_power_baci_workbench(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit establishes no identity, consent, authorization, or authority.
% Base MATLAB; no Statistics and Machine Learning Toolbox required.
% Operations: occupancy_likelihood, occupancy_power, baci.
% Local calculations only; no I/O, persistence, or actuation.

if nargin~=2
    result=bad('E_ARGUMENTS','input'); return
end
op=textValue(varargin{1});
x=varargin{2};

switch op
    case 'occupancy_likelihood'
        result=occupancyLikelihood(x);
    case 'occupancy_power'
        result=occupancyPower(x);
    case 'baci'
        result=baciContrast(x);
    otherwise
        result=bad('E_OPERATION','operation');
end
end

function r=occupancyLikelihood(x)
if ~exact(x,{'detections','psi','p','false_positive'})
    r=bad('E_INPUT_SHAPE','input'); return
end
y=x.detections;
if ~isa(y,'double') || ~isreal(y) || issparse(y) || ...
        ndims(y)~=2 || isempty(y) || size(y,1)>10000 || ...
        size(y,2)>100 || any(~isfinite(y(:))) || ...
        any(y(:)~=0 & y(:)~=1)
    r=bad('E_DETECTION_MATRIX','input.detections'); return
end
if ~probability(x.psi) || ~probability(x.p) || ...
        ~probability(x.false_positive)
    r=bad('E_PROBABILITY','input'); return
end

n=size(y,1);
visits=size(y,2);
siteLog=zeros(n,1);
occupiedLog=zeros(n,1);
unoccupiedLog=zeros(n,1);

for s=1:n
    detected=sum(y(s,:));
    occupiedLog(s)=logWeight(x.psi)+ ...
        bernoulliSequenceLog(detected,visits,x.p);
    unoccupiedLog(s)=logWeight(1-x.psi)+ ...
        bernoulliSequenceLog(detected,visits,x.false_positive);
    siteLog(s)=logAdd(occupiedLog(s),unoccupiedLog(s));
end

v=struct();
v.schema_version=1;
v.site_count=n;
v.visits_per_site=visits;
v.site_log_likelihood=siteLog;
v.total_log_likelihood=sum(siteLog);
v.model_assigns_zero_to_some_observations=any(isinf(siteLog)&siteLog<0);
v.parameters_fitted=false;
v.identifiability_established=false;
v.false_positive_model='constant_probability_given_nonoccupancy';
v.visit_independence='conditional_on_occupancy_assumed';
v.closure_assessed=false;
r=good(v);
end

function r=occupancyPower(x)
keys={'psi_before','psi_after','p','false_positive','visits', ...
    'sites_per_period','replicates','significance_level','seed'};
if ~exact(x,keys)
    r=bad('E_INPUT_SHAPE','input'); return
end
if ~probability(x.psi_before) || ~probability(x.psi_after) || ...
        ~probability(x.p) || ~probability(x.false_positive)
    r=bad('E_PROBABILITY','input'); return
end
if x.psi_after>=x.psi_before
    r=bad('E_DECLINE_ESTIMAND','input.psi_after'); return
end
if x.p<=x.false_positive
    r=bad('E_OBSERVATION_SEPARATION','input'); return
end
if ~integerBound(x.visits,1,100) || ...
        ~integerBound(x.sites_per_period,2,1000) || ...
        ~integerBound(x.replicates,100,5000) || ...
        ~integerBound(x.seed,0,4294967295)
    r=bad('E_DESIGN_BOUND','input'); return
end
if ~number(x.significance_level) || ...
        x.significance_level<=0 || x.significance_level>=0.5
    r=bad('E_SIGNIFICANCE','input.significance_level'); return
end

d1=-expm1(x.visits*log1p(-x.p));
d0=-expm1(x.visits*log1p(-x.false_positive));
separation=d1-d0;
if separation<=sqrt(eps('double'))
    r=bad('E_COLLAPSED_SITE_DETECTION_SEPARATION','input'); return
end

qBefore=x.psi_before*d1+(1-x.psi_before)*d0;
qAfter=x.psi_after*d1+(1-x.psi_after)*d0;

stream=RandStream('mt19937ar','Seed',x.seed);
rejectAlt=0;
rejectNull=0;
n=x.sites_per_period;

for b=1:x.replicates
    before=sum(rand(stream,n,1)<qBefore);
    after=sum(rand(stream,n,1)<qAfter);
    nullBefore=sum(rand(stream,n,1)<qBefore);
    nullAfter=sum(rand(stream,n,1)<qBefore);

    rejectAlt=rejectAlt+rejectDecline(before,after,n,x.significance_level);
    rejectNull=rejectNull+rejectDecline( ...
        nullBefore,nullAfter,n,x.significance_level);
end

power=rejectAlt/x.replicates;
typeI=rejectNull/x.replicates;

v=struct();
v.schema_version=1;
v.estimand='occupancy_difference_independent_cross_sections';
v.target_difference=x.psi_after-x.psi_before;
v.observed_site_detection_before=qBefore;
v.observed_site_detection_after=qAfter;
v.simulated_power=power;
v.simulated_type_I_error=typeI;
v.power_monte_carlo_se=sqrt(power*(1-power)/x.replicates);
v.type_I_monte_carlo_se=sqrt(typeI*(1-typeI)/x.replicates);
v.monte_carlo_intervals_computed=false;
v.replicates=x.replicates;
v.seed=x.seed;
v.test='one_sided_pooled_normal_approximation_on_site_detections';
v.significance_level=x.significance_level;
v.p_and_false_positive_treated_as_known=true;
v.parameter_estimation_uncertainty_included=false;
v.paired_sites_supported=false;
v.spatial_dependence_included=false;
v.closure_assessed=false;
v.minimum_design_selected=false;
v.decision_authorized=false;
r=good(v);
end

function tf=rejectDecline(before,after,n,alpha)
pooled=(before+after)/(2*n);
variance=pooled*(1-pooled)*(2/n);
if variance==0
    pvalue=0.5;
else
    z=(before/n-after/n)/sqrt(variance);
    pvalue=0.5*erfc(z/sqrt(2));
end
tf=pvalue<alpha;
end

function r=baciContrast(x)
if ~exact(x,{'treated','control','response_unit','assumptions'})
    r=bad('E_INPUT_SHAPE','input'); return
end
if ~outcomes(x.treated) || ~outcomes(x.control)
    r=bad('E_OUTCOME_MATRIX','input'); return
end
if isempty(textValue(x.response_unit))
    r=bad('E_RESPONSE_UNIT','input.response_unit'); return
end

features={'counterfactual_trend','no_interference', ...
    'measurement_stability','assignment_review','replication_review'};
if ~exact(x.assumptions,features)
    r=bad('E_ASSUMPTION_RECORD','input.assumptions'); return
end

review=struct();
for i=1:numel(features)
    status=textValue(x.assumptions.(features{i}));
    if ~any(strcmp(status,{'supported','concern','unreviewed'}))
        r=bad('E_ASSUMPTION_STATUS','input.assumptions'); return
    end
    review.(features{i})=status;
end

treatedChange=x.treated(:,2)-x.treated(:,1);
controlChange=x.control(:,2)-x.control(:,1);
contrast=mean(treatedChange)-mean(controlChange);

if any(~isfinite(treatedChange)) || any(~isfinite(controlChange)) || ...
        ~isfinite(contrast)
    r=bad('E_NUMERIC_RANGE','input'); return
end

v=struct();
v.schema_version=1;
v.contrast=contrast;
v.response_unit=textValue(x.response_unit);
v.treated_unit_count=size(x.treated,1);
v.control_unit_count=size(x.control,1);
v.row_interpretation='declared_intervention_level_units';
v.mean_treated_change=mean(treatedChange);
v.mean_control_change=mean(controlChange);
v.assumption_review=review;
v.independence_verified=false;
v.causal_identification_established=false;
v.confidence_interval_computed=false;
v.assessment_scope='descriptive_baci_contrast';
r=good(v);
end

function tf=outcomes(x)
tf=isa(x,'double') && isreal(x) && ~issparse(x) && ...
    ndims(x)==2 && size(x,2)==2 && ...
    size(x,1)>=1 && size(x,1)<=10000 && all(isfinite(x(:)));
end

function value=bernoulliSequenceLog(d,k,p)
value=0;
if d>0, value=value+d*logWeight(p); end
if k-d>0, value=value+(k-d)*logWeight(1-p); end
end

function value=logWeight(p)
if p==0, value=-Inf; else, value=log(p); end
end

function value=logAdd(a,b)
m=max(a,b);
if isinf(m) && m<0
    value=-Inf;
else
    value=m+log(exp(a-m)+exp(b-m));
end
end

function tf=exact(x,keys)
tf=isstruct(x) && isscalar(x);
if ~tf, return; end
tf=numel(fieldnames(x))==numel(keys) && all(isfield(x,keys));
end

function tf=number(x)
tf=isa(x,'double') && isreal(x) && isscalar(x) && ...
    ~issparse(x) && isfinite(x);
end

function tf=probability(x)
tf=number(x) && x>=0 && x<=1;
end

function tf=integerBound(x,low,high)
tf=number(x) && x==fix(x) && x>=low && x<=high;
end

function t=textValue(x)
t='';
if ischar(x) && isrow(x) && ~isempty(x) && ...
        numel(x)<=160 && ~any(double(x)<32 | double(x)==127)
    t=x;
elseif isstring(x) && isscalar(x) && ~ismissing(x)
    t=textValue(char(x));
end
end

function r=good(value)
r=struct('ok',true,'value',value);
end

function r=bad(code,path)
e=struct('code',code,'path',path, ...
    'message_key',['occupancy_power_baci_workbench.' code], ...
    'args',struct());
r=struct('ok',false,'error',e);
end
