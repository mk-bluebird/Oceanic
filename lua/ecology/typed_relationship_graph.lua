-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Retain attribution in derivative distributions:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; no consent, identity verification, or operational authority.
-- Local validation and structural counts; no I/O or external actions.

local M = {VERSION = "1.0.0", SCHEMA_VERSION = 1}
local MAX_NODES, MAX_EDGES = 500, 5000

local RELATIONS = {
    consumes = {
        source = {taxon = true},
        target = {taxon = true, compartment = true}
    },
    habitat_support = {
        source = {habitat = true, taxon = true},
        target = {taxon = true}
    },
    pollinates = {
        source = {taxon = true}, target = {taxon = true}
    },
    disperses_seeds = {
        source = {taxon = true}, target = {taxon = true}
    },
    transfers_nutrients = {
        source = {compartment = true}, target = {compartment = true}
    }
}

local ORDER = {
    "consumes", "habitat_support", "pollinates",
    "disperses_seeds", "transfers_nutrients"
}

local function good(value)
    return {ok = true, value = value, error = false}
end

local function bad(code, path)
    return {ok = false, value = false, error = {
        code = code, field_path = path,
        message_key = "relationship_graph." .. code,
        args = {}, category = "validation"
    }}
end

local function text(value)
    if type(value) ~= "string" or #value < 1 or #value > 500
        or not value:match("%S") then return false end
    for i = 1, #value do
        local b = value:byte(i)
        if b < 32 or b > 126 then return false end
    end
    return true
end

local function record(value, fields, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return bad("E_RECORD", path)
    end
    local allowed = {}
    for _, key in ipairs(fields) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return bad("E_MISSING", path .. "." .. key)
        end
    end
    local unknown = false
    for key in pairs(value) do
        if not allowed[key] then unknown = true end
    end
    if unknown then return bad("E_UNKNOWN_FIELD", path) end
    return good(true)
end

local function sequence(value, limit, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return bad("E_SEQUENCE", path)
    end
    local n, highest, invalid = 0, 0, false
    for key in pairs(value) do
        if type(key) ~= "number" or key ~= key
            or key < 1 or key > limit or key % 1 ~= 0 then
            invalid = true
        else
            n, highest = n + 1, math.max(highest, key)
        end
    end
    if invalid then return bad("E_SEQUENCE_INDEX", path) end
    if n ~= highest then return bad("E_SEQUENCE_GAP", path) end
    return good(n)
end

function M.evaluate(input)
    local r = record(input, {
        "schema_version", "scope", "nodes", "edges"
    }, "input")
    if not r.ok then return r end
    if input.schema_version ~= M.SCHEMA_VERSION then
        return bad("E_SCHEMA_VERSION", "input.schema_version")
    end
    if not text(input.scope) then return bad("E_TEXT", "input.scope") end

    local nr = sequence(input.nodes, MAX_NODES, "input.nodes")
    if not nr.ok then return nr end
    if nr.value == 0 then return bad("E_EMPTY_NODES", "input.nodes") end
    local er = sequence(input.edges, MAX_EDGES, "input.edges")
    if not er.ok then return er end

    local classes, names, layers, copied_edges = {}, {}, {}, {}
    for _, relation in ipairs(ORDER) do layers[relation] = {} end

    for i = 1, nr.value do
        local node, path = input.nodes[i], "input.nodes[" .. i .. "]"
        r = record(node, {"name", "class"}, path)
        if not r.ok then return r end
        if not text(node.name) then return bad("E_TEXT", path .. ".name") end
        if node.class ~= "taxon" and node.class ~= "habitat"
            and node.class ~= "compartment" then
            return bad("E_NODE_CLASS", path .. ".class")
        end
        if classes[node.name] then return bad("E_DUPLICATE_NODE", path) end
        classes[node.name] = node.class
        names[i] = node.name
        for _, relation in ipairs(ORDER) do
            layers[relation][node.name] = {incoming = 0, outgoing = 0}
        end
    end

    local evidence = {
        observation = true, experiment = true,
        model = true, hypothesis = true
    }
    local review = {unreviewed = true, reviewed = true}
    local seen = {}
    local evidence_counts = {
        observation = 0, experiment = 0, model = 0, hypothesis = 0
    }
    local unreviewed = 0

    for i = 1, er.value do
        local edge, path = input.edges[i], "input.edges[" .. i .. "]"
        local fields = {
            "source", "target", "relation",
            "evidence_kind", "evidence_reference", "review_status"
        }
        r = record(edge, fields, path)
        if not r.ok then return r end
        for _, key in ipairs(fields) do
            if not text(edge[key]) then return bad("E_TEXT", path .. "." .. key) end
        end

        local rule = RELATIONS[edge.relation]
        if not rule then return bad("E_RELATION", path .. ".relation") end
        if not classes[edge.source] then
            return bad("E_UNKNOWN_SOURCE", path .. ".source")
        end
        if not classes[edge.target] then
            return bad("E_UNKNOWN_TARGET", path .. ".target")
        end
        if edge.source == edge.target then
            return bad("E_SELF_EDGE_UNSUPPORTED", path)
        end
        if not rule.source[classes[edge.source]]
            or not rule.target[classes[edge.target]] then
            return bad("E_ENDPOINT_CLASS", path)
        end
        if not evidence[edge.evidence_kind] then
            return bad("E_EVIDENCE_KIND", path .. ".evidence_kind")
        end
        if not review[edge.review_status] then
            return bad("E_REVIEW_STATUS", path .. ".review_status")
        end

        seen[edge.source] = seen[edge.source] or {}
        seen[edge.source][edge.relation] =
            seen[edge.source][edge.relation] or {}
        local targets = seen[edge.source][edge.relation]
        if targets[edge.target] then return bad("E_DUPLICATE_EDGE", path) end
        targets[edge.target] = true

        local copy = {}
        for _, key in ipairs(fields) do copy[key] = edge[key] end
        copied_edges[i] = copy
        evidence_counts[edge.evidence_kind] =
            evidence_counts[edge.evidence_kind] + 1
        if edge.review_status == "unreviewed" then
            unreviewed = unreviewed + 1
        end
        local layer = layers[edge.relation]
        layer[edge.source].outgoing = layer[edge.source].outgoing + 1
        layer[edge.target].incoming = layer[edge.target].incoming + 1
    end

    local nodes = {}
    for i, name in ipairs(names) do
        nodes[i] = {name = name, class = classes[name]}
    end
    local relation_order = {}
    for i, relation in ipairs(ORDER) do relation_order[i] = relation end

    return good({
        schema_version = M.SCHEMA_VERSION,
        module_version = M.VERSION,
        status = "screen_typed_graph_structure",
        scope = input.scope,
        nodes = nodes, edges = copied_edges,
        relation_order = relation_order,
        degree_by_layer = layers,
        evidence_counts = evidence_counts,
        unreviewed_edge_count = unreviewed,
        attribution = {
            anchor = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose = "document_credit_and_configured_workstream_metadata_only",
            establishes_consent = false,
            establishes_verified_identity = false,
            grants_authority = false
        },
        interpretation_limits = {
            all_evidence_kinds_included_in_degree = true,
            biological_relationships_verified = false,
            interaction_strength_estimated = false,
            trophic_cascade_established = false,
            keystone_status_established = false,
            conservation_priority_established = false,
            external_action_authorized = false
        }
    })
end

return M
