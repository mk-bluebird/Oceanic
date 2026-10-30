-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- One element, one interval, kg throughout; local arithmetic only.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}

function M.evaluate(x)
    local r=V.record(x,{
        "schema_version","element","interval_basis","tolerance_kg",
        "compartments","transfers"
    },{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    r=V.enum(x.element,{"nitrogen","phosphorus","carbon"},
        "E_ELEMENT","input.element")
    if not r.ok then return r end
    r=V.text(x.interval_basis,500,"input.interval_basis")
    if not r.ok then return r end
    if not V.finite(x.tolerance_kg) or x.tolerance_kg<0 then
        return V.fail("E_TOLERANCE","input.tolerance_kg")
    end

    r=V.sequence(x.compartments,100,"input.compartments")
    if not r.ok then return r end
    local n=r.value
    r=V.sequence(x.transfers,10000,"input.transfers")
    if not r.ok then return r end
    local transfer_count=r.value

    local lookup,names,stocks,net={},{},{},{}
    local stock_fields={
        "initial_kg","final_kg","external_in_kg","external_out_kg"
    }

    for i=1,n do
        local row=x.compartments[i]
        local path="input.compartments[" .. i .. "]"
        r=V.record(row,{
            "name","initial_kg","final_kg","external_in_kg","external_out_kg"
        },{},path)
        if not r.ok then return r end
        r=V.text(row.name,200,path .. ".name")
        if not r.ok then return r end
        if lookup[row.name] then return V.fail("E_DUPLICATE_COMPARTMENT",path) end
        lookup[row.name]=i
        names[i]=row.name
        stocks[i]={}
        for _,key in ipairs(stock_fields) do
            if not V.finite(row[key]) or row[key]<0 then
                return V.fail("E_NONNEGATIVE_FINITE",path .. "." .. key)
            end
            stocks[i][key]=row[key]
        end
        net[i]=0
    end

    for i=1,transfer_count do
        local row=x.transfers[i]
        local path="input.transfers[" .. i .. "]"
        r=V.record(row,{"source","target","mass_kg"},{},path)
        if not r.ok then return r end
        for _,key in ipairs({"source","target"}) do
            r=V.text(row[key],200,path .. "." .. key)
            if not r.ok then return r end
            if not lookup[row[key]] then
                return V.fail("E_UNKNOWN_COMPARTMENT",path .. "." .. key)
            end
        end
        if row.source==row.target then
            return V.fail("E_SELF_TRANSFER",path)
        end
        if not V.finite(row.mass_kg) or row.mass_kg<0 then
            return V.fail("E_NONNEGATIVE_FINITE",path .. ".mass_kg")
        end
        local source,target=lookup[row.source],lookup[row.target]
        net[source]=net[source]-row.mass_kg
        net[target]=net[target]+row.mass_kg
        if not V.finite(net[source]) or not V.finite(net[target]) then
            return V.fail("E_NUMERIC_RANGE",path)
        end
    end

    local results,all_within,system_residual={},true,0
    for i=1,n do
        local row=stocks[i]
        local observed=row.final_kg-row.initial_kg
        local expected=net[i]+row.external_in_kg-row.external_out_kg
        local residual=observed-expected
        if not V.finite(observed) or not V.finite(expected)
            or not V.finite(residual) then
            return V.fail("E_NUMERIC_RANGE","input.compartments")
        end
        local within=math.abs(residual)<=x.tolerance_kg
        if not within then all_within=false end
        system_residual=system_residual+residual
        if not V.finite(system_residual) then
            return V.fail("E_NUMERIC_RANGE","input.compartments")
        end
        results[i]={
            name=names[i],
            observed_stock_change_kg=observed,
            expected_stock_change_kg=expected,
            internal_net_transfer_kg=net[i],
            residual_kg=residual,
            within_declared_tolerance=within
        }
    end

    return V.ok({
        module_version=M.VERSION,schema_version=1,
        status=all_within and "screen_compartment_residuals_within_tolerance"
            or "screen_compartment_residual_review_required",
        element=x.element,units="kg_of_declared_element",
        interval_basis=x.interval_basis,tolerance_kg=x.tolerance_kg,
        compartments=results,system_residual_kg=system_residual,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            measurement_accuracy_verified=false,
            boundary_completeness_verified=false,
            transfers_independently_verified=false,
            statistical_uncertainty_propagated=false,
            habitat_adequacy_established=false,
            cultural_documentation_authorized=false,
            publication_authorized=false,
            external_action_performed=false
        }
    })
end

return M
