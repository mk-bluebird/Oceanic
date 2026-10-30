function result=occupancy_power_baci_workbench_test()
% SPDX-License-Identifier: MIT OR Apache-2.0
% Synthetic fixtures only.
% Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

tests={ ...
    'false_positive_changes_likelihood',@falsePositive; ...
    'known_site_sequence_probability',@sequenceProbability; ...
    'impossible_observation_is_explicit',@impossibleObservation; ...
    'power_is_seed_reproducible',@powerReproducible; ...
    'power_reports_type_I_error',@powerNullReport; ...
    'baci_is_descriptive',@baciDescription; ...
    'wrong_arity_returns_error',@wrongArity};

passed=false(size(tests,1),1);
details=cell(size(passed));
for i=1:size(tests,1)
    try
        fn=tests{i,2};
        fn();
        passed(i)=true;
        details{i}='';
    catch ex
        message=regexprep(ex.message,'[\x00-\x1F\x7F]',' ');
        details{i}=message(1:min(numel(message),300));
    end
end
value=struct('test_names',{tests(:,1)},'passed',passed, ...
    'failure_details',{details},'passed_count',sum(passed), ...
    'failed_count',sum(~passed),'fixtures','synthetic');
result=struct('ok',true,'value',value);
end

function falsePositive()
x=struct('detections',[1 0],'psi',0,'p',0.8,'false_positive',0.1);
r=occupancy_power_baci_workbench('occupancy_likelihood',x);
assert(r.ok);
assert(abs(exp(r.value.total_log_likelihood)-0.09)<=1e-12);
end

function sequenceProbability()
x=struct('detections',[1 0],'psi',0.5,'p',0.8,'false_positive',0.1);
r=occupancy_power_baci_workbench('occupancy_likelihood',x);
assert(r.ok);
assert(abs(exp(r.value.total_log_likelihood)-0.125)<=1e-12);
assert(~r.value.identifiability_established);
end

function impossibleObservation()
x=struct('detections',[1 0],'psi',0,'p',0.8,'false_positive',0);
r=occupancy_power_baci_workbench('occupancy_likelihood',x);
assert(r.ok && r.value.model_assigns_zero_to_some_observations);
assert(r.value.total_log_likelihood==-Inf);
end

function x=powerInput()
x=struct('psi_before',0.7,'psi_after',0.4,'p',0.6, ...
    'false_positive',0.02,'visits',3,'sites_per_period',50, ...
    'replicates',100,'significance_level',0.05,'seed',17);
end

function powerReproducible()
x=powerInput();
a=occupancy_power_baci_workbench('occupancy_power',x);
b=occupancy_power_baci_workbench('occupancy_power',x);
assert(a.ok && b.ok && isequaln(a.value,b.value));
end

function powerNullReport()
r=occupancy_power_baci_workbench('occupancy_power',powerInput());
assert(r.ok);
assert(r.value.simulated_power>=0 && r.value.simulated_power<=1);
assert(r.value.simulated_type_I_error>=0 && ...
    r.value.simulated_type_I_error<=1);
assert(~r.value.minimum_design_selected);
end

function baciDescription()
assumptions=struct('counterfactual_trend','unreviewed', ...
    'no_interference','unreviewed','measurement_stability','supported', ...
    'assignment_review','unreviewed','replication_review','unreviewed');
x=struct('treated',[10 15;12 17],'control',[8 10;9 11], ...
    'response_unit','synthetic response units','assumptions',assumptions);
r=occupancy_power_baci_workbench('baci',x);
assert(r.ok && abs(r.value.contrast-3)<=1e-12);
assert(~r.value.causal_identification_established);
end

function wrongArity()
r=occupancy_power_baci_workbench('baci');
assert(~r.ok && strcmp(r.error.code,'E_ARGUMENTS'));
end
