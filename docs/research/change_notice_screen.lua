-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; no identity verification, consent, or authorization.
-- Lua 5.4 standard library. No I/O, networking, storage, or actuation.
-- Validates a notice declaration, not its truth, authority, or graph context.
local M = {}
local VERSION = "0.1.0"
local fields = {"notice_version", "change_kind", "source_path", "source_version",
    "target_path", "target_version", "affected_fields", "replacement_scope",
    "reason", "review_state"}
local allowed = {}
for _, key in ipairs(fields) do allowed[key] = true end
local kinds = {
    transcription_correction = "replace_affected_fields_after_review",
    scientific_correction = "review_affected_conclusions_and_dependencies",
    clarification = "check_semantic_effect",
    evidence_revision = "preserve_historical_support",
    reinterpretation = "retain_competing_interpretations",
    criterion_revision = "separate_rule_change_from_ecological_change",
    withdrawal = "review_withdrawal_scope",
    source_status_update = "review_source_status_consequences"
}
local function envelope(ok, value, code, path)
    return {ok=ok, schema_version=VERSION, module_version=VERSION,
        value=value, error={present=not ok, code=code or "", path=path or "",
        message_key=code or ""}}
end
local function fail(code, path) return envelope(false, false, code, path) end
local function plain(x) return type(x)=="table" and getmetatable(x)==nil end
local function text(x, limit)
    return type(x)=="string" and #x>0 and #x<=limit and x:find("%S")~=nil
        and x:find("[%z\1-\31\127]")==nil
end
local function version(x)
    if not text(x, 40) then return false end
    local a,b,c=x:match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then return false end
    for _, part in ipairs({a,b,c}) do
        if #part>1 and part:sub(1,1)=="0" then return false end
    end
    return true
end
local function path(x)
    if not text(x, 512) or x:sub(1,1)=="/" or x:sub(-1)=="/"
        or x:find("\\",1,true) or x:find(":",1,true)
        or x:find("//",1,true) then return false end
    for segment in x:gmatch("[^/]+") do
        if segment=="." or segment==".." then return false end
    end
    return true
end
local function screen_impl(n)
    if not plain(n) then return fail("E_NOTICE", "notice") end
    for key in next,n do
        if not allowed[key] then return fail("E_FIELD", "notice") end
    end
    for _, key in ipairs(fields) do
        if rawget(n,key)==nil then return fail("E_REQUIRED", key) end
    end
    if n.notice_version~=VERSION then return fail("E_VERSION", "notice_version") end
    if type(n.change_kind)~="string" or not kinds[n.change_kind] then
        return fail("E_KIND", "change_kind") end
    for _, key in ipairs({"source_path", "target_path"}) do
        if not path(n[key]) then return fail("E_PATH", key) end
    end
    for _, key in ipairs({"source_version", "target_version"}) do
        if not version(n[key]) then return fail("E_RECORD_VERSION", key) end
    end
    if n.source_path==n.target_path and n.source_version==n.target_version then
        return fail("E_SELF_REPLACEMENT", "target_version") end
    if n.replacement_scope~="partial" and n.replacement_scope~="full" then
        return fail("E_SCOPE", "replacement_scope") end
    if n.review_state~="proposed" and n.review_state~="approved"
        and n.review_state~="rejected" then return fail("E_REVIEW", "review_state") end
    if not text(n.reason,4096) then return fail("E_REASON", "reason") end
    local affected=n.affected_fields
    if not plain(affected) then return fail("E_AFFECTED", "affected_fields") end
    local count=0
    for key in next,affected do
        if type(key)~="number" or key<1 or key>64 or key%1~=0 then
            return fail("E_AFFECTED", "affected_fields") end
        count=count+1
    end
    if count==0 then return fail("E_AFFECTED", "affected_fields") end
    local seen={}
    local copied={}
    for j=1,count do
        local value=rawget(affected,j)
        if not text(value,256) then return fail("E_AFFECTED", "affected_fields") end
        if seen[value] then return fail("E_DUPLICATE", "affected_fields") end
        seen[value]=true
        copied[j]=value
    end
    local routing="pending_review"
    if n.review_state=="approved" then routing="verify_review_and_applicability"
    elseif n.review_state=="rejected" then routing="no_supersession" end
    return envelope(true, {
        status="declaration_screen_only", change_kind=n.change_kind,
        affected_fields=copied, replacement_scope=n.replacement_scope,
        declared_review_state=n.review_state, review_routing=routing,
        proposed_policy=kinds[n.change_kind], graph_resolved=false,
        review_authority_verified=false, scientific_support_verified=false,
        retrieval_authorized=false, external_actions="none",
        attribution="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits={
            {code="R_NO_GRAPH",message="Cycles and competing branches are not checked."},
            {code="R_DECLARATION",message="Approval is declared, not authenticated."},
            {code="R_NO_ACTION",message="No index, file, or external record is changed."}
        }
    })
end
function M.screen(notice)
    local ok,result=pcall(screen_impl,notice)
    if not ok then return fail("E_INTERNAL", "") end
    return result
end
function M.self_test()
    local function fixture()
        return {notice_version=VERSION,change_kind="transcription_correction",
            source_path="research/cards/disease.md",source_version="0.1.0",
            target_path="research/cards/disease.md",target_version="0.2.0",
            affected_fields={"claim.effect_measure","claim.analysis_unit"},
            replacement_scope="partial",reason="Synthetic fixture correction.",
            review_state="proposed"}
    end
    local checks={
        {name="valid", mutate=function(_) end, code=false},
        {name="self_replacement", mutate=function(n) n.target_version=n.source_version end,
            code="E_SELF_REPLACEMENT"},
        {name="unknown_kind", mutate=function(n) n.change_kind="other" end,code="E_KIND"},
        {name="unsafe_path", mutate=function(n) n.target_path="../private.md" end,code="E_PATH"},
        {name="duplicates", mutate=function(n) n.affected_fields={"claim","claim"} end,
            code="E_DUPLICATE"},
        {name="version", mutate=function(n) n.notice_version="2.0.0" end,code="E_VERSION"}
    }
    for _,check in ipairs(checks) do
        local n=fixture(); check.mutate(n); local r=M.screen(n)
        if (check.code and (r.ok or r.error.code~=check.code))
            or (not check.code and not r.ok) then
            return fail("E_SELF_TEST",check.name)
        end
    end
    local n=fixture(); n.review_state="approved"
    local r=M.screen(n)
    if not r.ok or r.value.retrieval_authorized or r.value.review_authority_verified then
        return fail("E_SELF_TEST","approval_not_authority") end
    r.value.affected_fields[1]="changed_output"
    if n.affected_fields[1]~="claim.effect_measure" then
        return fail("E_SELF_TEST","output_aliasing") end
    return envelope(true,{status="synthetic_self_tests_passed",
        field_validation="not_performed",graph_tests_executed=false})
end
return M
