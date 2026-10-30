function result=oxygen_budget_accounting_v2_test()
% SPDX-License-Identifier: MIT OR Apache-2.0
% Synthetic fixtures only.
% Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

tests={ ...
    'budget_closes',@testClosure; ...
    'negative_air_exchange',@testAir; ...
    'zero_is_measured',@testZero; ...
    'withheld_is_not_zero',@testWithheld; ...
    'negative_inventory_rejected',@testNegative; ...
    'interval_mismatch_rejected',@testInterval; ...
    'declared_overlap_rejected',@testOverlap; ...
    'residual_inference_not_independent',@testResidual; ...
    'actual_partition_enumeration',@testPartition; ...
    'wrong_arity_returns_envelope',@testArity; ...
    'unknown_member_safe_error',@testUnknown; ...
    'input_preserved',@testMutation};

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
        details{i}=message(1:min(300,numel(message)));
    end
end
result=struct('ok',true,'value',struct( ...
    'test_names',{tests(:,1)},'passed',passed, ...
    'failure_details',{details}, ...
    'passed_count',sum(passed),'failed_count',sum(~passed), ...
    'fixtures','synthetic','executed_properties_not_formal_proofs',true));
end

function x=fixture()
x=struct('schema_version',2,'volume_m3',1000, ...
    'start_day',0,'end_day',2,'initial_mg_L',8,'final_mg_L',6, ...
    'concentration_support','volume_weighted_mean', ...
    'boundary_model','constant_volume_control_volume', ...
    'sink_partition','declared_disjoint','fluxes',struct());
x.fluxes.inflow=q(0,'measured');
x.fluxes.outflow=q(0,'measured');
x.fluxes.air_exchange=q(0.5,'measured');
x.fluxes.production=q(1,'measured');
x.fluxes.water_column_respiration=q(1,'measured');
x.fluxes.sediment_demand=q(1.5,'measured');
x.fluxes.other_demand=q(0,'assumed_negligible');
end

function f=q(value,state)
f=struct('state',state,'value',value,'unit','kg_O2_per_day', ...
    'time_support','interval_mean','start_day',0,'end_day',2);
end

function testClosure()
r=oxygen_budget_accounting_v2("budget",fixture());
assert(r.ok && r.value.schema_version==2);
assert(abs(r.value.inventory_residual_kg_O2)<=1e-10);
assert(strcmp(r.value.budget_status,'all_registered_fluxes_quantified'));
end

function testAir()
x=fixture(); x.fluxes.air_exchange.value=-0.5; x.final_mg_L=4;
r=oxygen_budget_accounting_v2('budget',x);
assert(r.ok && abs(r.value.inventory_residual_kg_O2)<=1e-10);
end

function testZero()
r=oxygen_budget_accounting_v2('partition',fixture().fluxes);
assert(r.ok && any(strcmp(r.value.partition.measured,'inflow')));
end

function testWithheld()
x=fixture(); x.fluxes.sediment_demand=struct('state','withheld');
r=oxygen_budget_accounting_v2('budget',x);
assert(r.ok && ~isfield(r.value,'predicted_final_mg_L'));
end

function testNegative()
x=fixture(); x.fluxes.sediment_demand.value=100;
r=oxygen_budget_accounting_v2('budget',x);
assert(~r.ok && strcmp(r.error.code,'E_NEGATIVE_PREDICTED_INVENTORY'));
end

function testInterval()
x=fixture(); x.fluxes.inflow.end_day=1;
r=oxygen_budget_accounting_v2('budget',x);
assert(~r.ok && strcmp(r.error.code,'E_FLUX_TIME_SUPPORT_MISMATCH'));
end

function testOverlap()
x=fixture(); x.sink_partition='overlap_declared';
r=oxygen_budget_accounting_v2('budget',x);
assert(~r.ok && strcmp(r.error.code,'E_DOUBLE_COUNTED_SINK'));
end

function testResidual()
x=fixture(); x.fluxes.sediment_demand.state='inferred_by_residual';
r=oxygen_budget_accounting_v2('budget',x);
assert(r.ok && ~r.value.independent_closure_assessed);
end

function testPartition()
states={'measured','estimated_from_measurements','inferred_by_residual', ...
    'assumed_negligible','unknown','not_collected','withheld'};
selected={'inflow','outflow','production'};
cases=0;
for a=1:7
    for b=1:7
        for c=1:7
            x=fixture();
            choices=[a b c];
            for k=1:3
                state=states{choices(k)};
                if choices(k)<=4
                    x.fluxes.(selected{k})=q(0,state);
                else
                    x.fluxes.(selected{k})=struct('state',state);
                end
            end
            r=oxygen_budget_accounting_v2('partition',x.fluxes);
            assert(r.ok);
            seen={};
            for s=1:7
                seen=[seen r.value.partition.(states{s})]; %#ok<AGROW>
            end
            assert(numel(seen)==7 && numel(unique(seen))==7);
            for k=1:3
                assert(any(strcmp( ...
                    r.value.partition.(states{choices(k)}),selected{k})));
            end
            cases=cases+1;
        end
    end
end
assert(cases==343);
end

function testArity()
r=oxygen_budget_accounting_v2('budget');
assert(~r.ok && strcmp(r.error.code,'E_ARGUMENTS'));
r=oxygen_budget_accounting_v2('budget',fixture(),true);
assert(~r.ok && strcmp(r.error.code,'E_ARGUMENTS'));
end

function testUnknown()
x=fixture(); x.SYNTHETIC_PRIVATE_FIELD=true;
r=oxygen_budget_accounting_v2('budget',x);
assert(~r.ok && strcmp(r.error.code,'E_UNKNOWN_MEMBER'));
assert(strcmp(r.error.path,'input'));
assert(isempty(fieldnames(r.error.args)));
end

function testMutation()
x=fixture(); before=x;
r=oxygen_budget_accounting_v2('budget',x);
assert(r.ok && isequaln(x,before));
end
