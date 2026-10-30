-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local question-structure audit; no model fitting, retrieval, or action.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}

local FIELDS={
    "subject","response","spatial_scope","temporal_scope",
    "measurement_basis","evidence_basis"
}
local PROMPTS={
    subject="What organism, habitat, process, or population is being studied?",
    response="What quantity or outcome should the answer describe?",
    spatial_scope="What place and spatial support does the question concern?",
    temporal_scope="What observation period or forecast horizon is intended?",
    measurement_basis="What measurements, units, or observation method are available?",
    evidence_basis="What evidence is available, and what remains an assumption?"
}

function M.evaluate(x)
    local r=V.record(x,{"schema_version","question_type","frame"},{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    r=V.enum(x.question_type,{
        "describe","compare","explain","forecast","design_monitoring"
    },"E_QUESTION_TYPE","input.question_type")
    if not r.ok then return r end
    r=V.record(x.frame,{},FIELDS,"input.frame")
    if not r.ok then return r end

    local supplied,missing,next_questions={}, {}, {}
    for _,field in ipairs(FIELDS) do
        local value=x.frame[field]
        if value==nil then
            missing[#missing+1]=field
            next_questions[#next_questions+1]={
                field=field,question=PROMPTS[field]
            }
        else
            r=V.text(value,500,"input.frame." .. field)
            if not r.ok then return r end
            supplied[#supplied+1]=field
        end
    end

    local further_checks={
        "Distinguish ecological state from observation and detection.",
        "Check units, denominators, missingness, and scope compatibility.",
        "Keep evidence support separate from permission to use or disclose."
    }
    if x.question_type=="forecast" then
        further_checks[#further_checks+1]=
            "Define event onset, available-at-issue-time inputs, baseline, and held-out validation."
    elseif x.question_type=="compare" then
        further_checks[#further_checks+1]=
            "Define the common estimand, comparison conditions, and dependence structure."
    elseif x.question_type=="explain" then
        further_checks[#further_checks+1]=
            "List competing mechanisms and the observations that distinguish them."
    elseif x.question_type=="design_monitoring" then
        further_checks[#further_checks+1]=
            "Separate sampling frequency, spatial placement, duration, and detection requirements."
    end

    return V.ok({
        module_version=M.VERSION,schema_version=1,
        status=#missing==0 and "screen_question_fields_supplied"
            or "screen_question_frame_incomplete",
        question_type=x.question_type,
        supplied_fields=supplied,
        missing_fields=missing,
        suggested_clarifications=next_questions,
        further_checks=further_checks,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            scientific_content_verified=false,
            question_answered=false,
            model_applicability_established=false,
            evidence_retrieved=false,
            permission_verified=false,
            persistent_memory_created=false,
            external_action_performed=false
        }
    })
end

return M
