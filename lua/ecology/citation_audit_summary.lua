-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local summary only; no fetching, archiving, logging, or publication.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}
local ACCESS={
    "reachable","not_found","gone",
    "blocked","transient_error","not_checked"
}
local CONTENT={"unchanged","changed","not_compared"}
local SUPPORT={"supports","qualifies","contradicts","unreviewed","not_applicable"}

local function zero_counts(values)
    local out={}
    for _,value in ipairs(values) do out[value]=0 end
    return out
end

function M.evaluate(x)
    local r=V.record(x,{"schema_version","scope","records"},{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    r=V.text(x.scope,500,"input.scope")
    if not r.ok then return r end
    r=V.sequence(x.records,10000,"input.records")
    if not r.ok then return r end
    local count=r.value

    local access_counts=zero_counts(ACCESS)
    local content_counts=zero_counts(CONTENT)
    local support_counts=zero_counts(SUPPORT)
    local reviews={}
    local technical_follow_up_count=0
    local semantic_review_count=0

    for i=1,count do
        local row,path=x.records[i],"input.records[" .. i .. "]"
        r=V.record(row,{"access","content","claim_support"},{},path)
        if not r.ok then return r end

        for _,spec in ipairs({
            {"access",ACCESS,"E_ACCESS"},
            {"content",CONTENT,"E_CONTENT"},
            {"claim_support",SUPPORT,"E_CLAIM_SUPPORT"}
        }) do
            r=V.enum(row[spec[1]],spec[2],spec[3],path .. "." .. spec[1])
            if not r.ok then return r end
        end

        access_counts[row.access]=access_counts[row.access]+1
        content_counts[row.content]=content_counts[row.content]+1
        support_counts[row.claim_support]=support_counts[row.claim_support]+1

        local technical=row.access~="reachable" and row.access~="not_checked"
        local semantic=row.claim_support=="qualifies"
            or row.claim_support=="contradicts"
            or (row.content=="changed" and row.claim_support=="unreviewed")

        if technical then technical_follow_up_count=technical_follow_up_count+1 end
        if semantic then semantic_review_count=semantic_review_count+1 end

        reviews[i]={
            access=row.access,
            content=row.content,
            claim_support=row.claim_support,
            technical_follow_up=technical,
            semantic_review_required=semantic,
            support_assessment_outstanding=row.claim_support=="unreviewed"
        }
    end

    local interpretable_access=access_counts.reachable
        +access_counts.not_found+access_counts.gone
    local out={
        module_version=M.VERSION,schema_version=1,
        status="screen_citation_audit_summary",
        scope=x.scope,record_count=count,
        access_counts=access_counts,
        content_counts=content_counts,
        claim_support_counts=support_counts,
        record_dispositions=reviews,
        technical_follow_up_count=technical_follow_up_count,
        semantic_review_count=semantic_review_count,
        interpretable_access_count=interpretable_access,
        access_fraction_scope="reachable_among_reachable_not_found_or_gone",
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            retrieval_states_verified=false,
            content_comparisons_verified=false,
            claim_reviews_verified=false,
            permanent_disappearance_established=false,
            longitudinal_change_rate_estimated=false,
            automatic_claim_replacement_authorized=false,
            archival_permission_verified=false,
            external_action_performed=false
        }
    }
    if interpretable_access>0 then
        out.reachable_fraction_among_interpretable_access=
            access_counts.reachable/interpretable_access
    end
    return V.ok(out)
end

return M
