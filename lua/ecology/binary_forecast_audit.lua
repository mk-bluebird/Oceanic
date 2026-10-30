-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local evaluation only; no model fitting, I/O, or external action.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}
local MAX_ROWS=100000

local function probability(v)
    return V.finite(v) and v>=0 and v<=1
end

function M.evaluate(x)
    local r=V.record(x,{
        "schema_version","scope","evaluation_basis","bin_count","records"
    },{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    r=V.text(x.scope,500,"input.scope")
    if not r.ok then return r end
    r=V.enum(x.evaluation_basis,{
        "temporal_holdout","spatial_holdout","external_dataset","synthetic"
    },"E_EVALUATION_BASIS","input.evaluation_basis")
    if not r.ok then return r end
    if not V.finite(x.bin_count) or x.bin_count%1~=0
        or x.bin_count<2 or x.bin_count>20 then
        return V.fail("E_BIN_COUNT","input.bin_count",{minimum=2,maximum=20})
    end
    r=V.sequence(x.records,MAX_ROWS,"input.records")
    if not r.ok then return r end
    local n=r.value

    local bins={}
    for i=1,x.bin_count do
        bins[i]={count=0,probability_sum=0,event_sum=0}
    end
    local model_sum,baseline_sum,probability_sum,event_sum=0,0,0,0

    for i=1,n do
        local row,path=x.records[i],"input.records[" .. i .. "]"
        r=V.record(row,{"probability","baseline_probability","outcome"},{},path)
        if not r.ok then return r end
        for _,key in ipairs({"probability","baseline_probability"}) do
            if not probability(row[key]) then
                return V.fail("E_PROBABILITY",path .. "." .. key,
                    {minimum=0,maximum=1})
            end
        end
        if type(row.outcome)~="number"
            or (row.outcome~=0 and row.outcome~=1) then
            return V.fail("E_BINARY",path .. ".outcome")
        end

        local p,b,y=row.probability,row.baseline_probability,row.outcome
        model_sum=model_sum+(p-y)^2
        baseline_sum=baseline_sum+(b-y)^2
        probability_sum=probability_sum+p
        event_sum=event_sum+y

        local index=math.min(x.bin_count,math.floor(p*x.bin_count)+1)
        local bin=bins[index]
        bin.count=bin.count+1
        bin.probability_sum=bin.probability_sum+p
        bin.event_sum=bin.event_sum+y
    end

    local calibration_bins,weighted_gap={},0
    for i,bin in ipairs(bins) do
        local out={
            lower_probability=(i-1)/x.bin_count,
            upper_probability=i/x.bin_count,
            upper_endpoint_inclusive=i==x.bin_count,
            count=bin.count
        }
        if bin.count>0 then
            out.mean_probability=bin.probability_sum/bin.count
            out.event_fraction=bin.event_sum/bin.count
            weighted_gap=weighted_gap+(bin.count/n)
                *math.abs(out.mean_probability-out.event_fraction)
        end
        calibration_bins[i]=out
    end

    local model_bs,baseline_bs=model_sum/n,baseline_sum/n
    local out={
        module_version=M.VERSION,schema_version=1,
        status="screen_binary_forecast_evaluation",
        scope=x.scope,evaluation_basis=x.evaluation_basis,
        record_count=n,event_count=event_sum,
        mean_probability=probability_sum/n,
        observed_event_fraction=event_sum/n,
        brier_score=model_bs,
        baseline_brier_score=baseline_bs,
        brier_skill_available=baseline_bs>0,
        bin_count=x.bin_count,
        calibration_bins=calibration_bins,
        bin_weighted_absolute_calibration_gap=weighted_gap,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            holdout_design_verified=false,
            outcome_adjudication_verified=false,
            temporal_or_spatial_dependence_adjusted=false,
            calibration_certified=false,
            statistical_uncertainty_estimated=false,
            decision_readiness_established=false,
            floating_point_underflow_excluded=false,
            external_action_performed=false
        }
    }
    if baseline_bs>0 then
        local skill=1-model_bs/baseline_bs
        if not V.finite(skill) then
            return V.fail("E_NUMERIC_RANGE","input.records")
        end
        out.brier_skill_score=skill
    end
    return V.ok(out)
end

return M
