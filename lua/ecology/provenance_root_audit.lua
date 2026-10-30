-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Local declared-derivation audit; no retrieval, I/O, or release.

local V=require("lua.ecology.validation")
local M={VERSION="1.0.0"}
local MAX_DOCUMENTS,MAX_EDGES,MAX_DEPTH=500,5000,256

local function path_check(path,field)
    local r=V.text(path,500,field)
    if not r.ok then return r end
    if path:sub(1,1)=="/" or path:sub(-1)=="/"
        or path:find("\\",1,true) or path:find("//",1,true) then
        return V.fail("E_RELATIVE_PATH",field)
    end
    for segment in path:gmatch("[^/]+") do
        if segment=="." or segment==".."
            or segment:find(":",1,true) then
            return V.fail("E_RELATIVE_PATH",field)
        end
    end
    return V.ok(true)
end

local function allow_empty_sequence(value,maximum,field)
    if type(value)=="table" and getmetatable(value)==nil
        and next(value)==nil then
        return V.ok(0)
    end
    return V.sequence(value,maximum,field)
end

function M.evaluate(x)
    local r=V.record(x,{"schema_version","documents","selected_paths"},{},"input")
    if not r.ok then return r end
    if x.schema_version~=1 then
        return V.fail("E_SCHEMA_VERSION","input.schema_version",
            {expected=1,actual=V.describe(x.schema_version)})
    end
    r=V.sequence(x.documents,MAX_DOCUMENTS,"input.documents")
    if not r.ok then return r end

    local nodes,order,edge_count={},{},0
    for i=1,r.value do
        local row=x.documents[i]
        local field="input.documents[" .. i .. "]"
        local rr=V.record(row,{
            "path","version","basis","upstream_paths"
        },{},field)
        if not rr.ok then return rr end
        rr=path_check(row.path,field .. ".path")
        if not rr.ok then return rr end
        rr=V.text(row.version,200,field .. ".version")
        if not rr.ok then return rr end
        rr=V.enum(row.basis,{"observation","synthetic","unresolved","derived"},
            "E_BASIS",field .. ".basis")
        if not rr.ok then return rr end
        if nodes[row.path] then return V.fail("E_DUPLICATE_PATH",field .. ".path") end

        rr=allow_empty_sequence(row.upstream_paths,MAX_DOCUMENTS,
            field .. ".upstream_paths")
        if not rr.ok then return rr end
        local upstream_count=rr.value
        if row.basis=="derived" and upstream_count==0 then
            return V.fail("E_DERIVATION_REQUIRED",field .. ".upstream_paths")
        elseif row.basis~="derived" and upstream_count~=0 then
            return V.fail("E_TERMINAL_WITH_UPSTREAM",field .. ".upstream_paths")
        end

        local upstream,seen={},{}
        for j=1,upstream_count do
            local p=row.upstream_paths[j]
            rr=path_check(p,field .. ".upstream_paths[" .. j .. "]")
            if not rr.ok then return rr end
            if seen[p] then return V.fail("E_DUPLICATE_UPSTREAM",field) end
            seen[p],upstream[j]=true,p
        end
        edge_count=edge_count+upstream_count
        if edge_count>MAX_EDGES then
            return V.fail("E_EDGE_CAPACITY","input.documents",{maximum=MAX_EDGES})
        end
        nodes[row.path]={basis=row.basis,version=row.version,upstream=upstream}
        order[#order+1]=row.path
    end

    for _,p in ipairs(order) do
        for _,u in ipairs(nodes[p].upstream) do
            if not nodes[u] then
                return V.fail("E_UNRESOLVED_REFERENCE","input.documents")
            end
        end
    end

    local state,cache={},{}
    local function visit(p,depth)
        if depth>MAX_DEPTH then
            return V.fail("E_DEPTH_CAPACITY","input.documents",{maximum=MAX_DEPTH})
        end
        if state[p]==1 then return V.fail("E_DERIVATION_CYCLE","input.documents") end
        if state[p]==2 then return V.ok(cache[p]) end
        state[p]=1
        local roots={}
        if nodes[p].basis~="derived" then
            roots[p]=true
        else
            for _,u in ipairs(nodes[p].upstream) do
                local result=visit(u,depth+1)
                if not result.ok then return result end
                for root in pairs(result.value) do roots[root]=true end
            end
        end
        state[p],cache[p]=2,roots
        return V.ok(roots)
    end

    -- Check the whole submitted derivation graph, not only selected sources.
    for _,p in ipairs(order) do
        local result=visit(p,1)
        if not result.ok then return result end
    end

    r=V.sequence(x.selected_paths,MAX_DOCUMENTS,"input.selected_paths")
    if not r.ok then return r end
    local roots,selected={},{}
    for i=1,r.value do
        local p=x.selected_paths[i]
        local rr=path_check(p,"input.selected_paths[" .. i .. "]")
        if not rr.ok then return rr end
        if not nodes[p] then return V.fail("E_UNKNOWN_SELECTION","input.selected_paths") end
        if selected[p] then return V.fail("E_DUPLICATE_SELECTION","input.selected_paths") end
        selected[p]=true
        for root in pairs(cache[p]) do roots[root]=true end
    end

    local result={observation={},synthetic={},unresolved={}}
    for p in pairs(roots) do
        local basis=nodes[p].basis
        result[basis][#result[basis]+1]={
            path=p,version=nodes[p].version
        }
    end
    for _,basis in ipairs({"observation","synthetic","unresolved"}) do
        table.sort(result[basis],function(a,b) return a.path<b.path end)
    end

    return V.ok({
        module_version=M.VERSION,schema_version=1,
        status="screen_declared_lineage_roots",
        roots=result,
        documented_observation_root_count=#result.observation,
        synthetic_root_count=#result.synthetic,
        unresolved_terminal_count=#result.unresolved,
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            upstream_content_verified=false,
            document_versions_authenticated=false,
            observation_root_declarations_verified=false,
            statistical_independence_established=false,
            effective_sample_size_estimated=false,
            source_correctness_established=false,
            permissions_verified=false,
            publication_authorized=false,
            external_action_performed=false
        }
    })
end

return M
