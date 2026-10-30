-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; separately versioned integration surface (not the earlier audit).
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
-- Contract: every exposed function returns {ok=true,value=...} or
-- {ok=false,error=...}. No networking, storage, telemetry, publication,
-- or hardware action. Structural metadata only; no scientific judgment.

local M = {}

M.VERSION = "1.0.0"
M.SCHEMA_VERSION = 1
M.FIELD_SET_VERSION = "1.0.0"
M.MESSAGE_SET_VERSION = "1.0.0"

-- ---------------------------------------------------------------------------
-- Field catalogue. FIELD_ORDER is the exact canonical output order.
-- Ordering is explicit; nothing in this module relies on pairs() ordering.
-- ---------------------------------------------------------------------------

local FIELD_ORDER = {
    "subject",
    "relationship",
    "response",
    "spatial_scope",
    "temporal_scope",
    "measurement_basis",
    "evidence_basis",
    "comparison_basis",
    "competing_explanations",
    "event_definition",
    "issue_time",
    "forecast_horizon",
    "evaluation_basis",
    "sampling_basis",
    "forecast_alignment",
}

local FIELDS = {
    subject              = { prompt_key = "field.subject" },
    relationship         = { prompt_key = "field.relationship" },
    response             = { prompt_key = "field.response" },
    spatial_scope        = { prompt_key = "field.spatial_scope" },
    temporal_scope       = { prompt_key = "field.temporal_scope" },
    measurement_basis    = { prompt_key = "field.measurement_basis" },
    evidence_basis       = { prompt_key = "field.evidence_basis" },
    comparison_basis     = { prompt_key = "field.comparison_basis" },
    competing_explanations = { prompt_key = "field.competing_explanations" },
    event_definition     = { prompt_key = "field.event_definition" },
    issue_time           = { prompt_key = "field.issue_time" },
    forecast_horizon     = { prompt_key = "field.forecast_horizon" },
    evaluation_basis     = { prompt_key = "field.evaluation_basis" },
    sampling_basis       = { prompt_key = "field.sampling_basis" },
    forecast_alignment   = { prompt_key = "field.forecast_alignment" },
}

-- Core fields required for every admitted intent set, in output order.
local CORE_FIELDS = {
    "subject", "relationship", "response", "spatial_scope",
    "temporal_scope", "measurement_basis", "evidence_basis",
}

-- ---------------------------------------------------------------------------
-- Intents, in canonical order.
-- ---------------------------------------------------------------------------

local INTENT_ORDER = {
    "describe",
    "compare",
    "explain",
    "forecast",
    "design_monitoring",
}

local INTENTS = {
    describe          = {},
    compare           = { "comparison_basis" },
    explain           = { "competing_explanations" },
    forecast          = { "event_definition", "issue_time",
                          "forecast_horizon", "evaluation_basis" },
    design_monitoring = { "sampling_basis" },
}

-- ---------------------------------------------------------------------------
-- Composite interactions. Stable rule codes.
-- R_COMPARE_FORECAST_ALIGNMENT: when both compare and forecast are present,
-- an additional declared field forecast_alignment is required. The field is a
-- DECLARED description of how forecast comparisons align; its presence does
-- not verify actual alignment and carries no scientific guarantee.
-- ---------------------------------------------------------------------------

local INTERACTIONS = {
    {
        rule_code = "R_COMPARE_FORECAST_ALIGNMENT",
        triggering_intents = { "compare", "forecast" },
        required_field = "forecast_alignment",
    },
}

-- ---------------------------------------------------------------------------
-- English fallback templates. Display text is kept separate from machine
-- results; machine records never embed rendered English. These are fallbacks
-- only; rendering them is not a translation and claims no equivalence.
-- Declared argument roles per message key (only these roles are accepted).
-- ---------------------------------------------------------------------------

local MESSAGES = {
    ["field.subject"] = {
        template = "What organism, population, habitat, or process is the subject? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.relationship"] = {
        template = "What relationship between entities or processes is being asked about? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.response"] = {
        template = "What outcome or response variable should the answer address? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.spatial_scope"] = {
        template = "What spatial scope does the question concern? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.temporal_scope"] = {
        template = "What temporal scope does the question concern? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.measurement_basis"] = {
        template = "What measurement basis (units, methods) is intended? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.evidence_basis"] = {
        template = "What evidence basis is declared for this question? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.comparison_basis"] = {
        template = "On what basis are the compared items selected? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.competing_explanations"] = {
        template = "Which competing explanations are being considered? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.event_definition"] = {
        template = "What event is being forecast? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.issue_time"] = {
        template = "At what issue time is the forecast made? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.forecast_horizon"] = {
        template = "Over what horizon does the forecast extend? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.evaluation_basis"] = {
        template = "On what basis will the forecast be evaluated? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.sampling_basis"] = {
        template = "What sampling basis would the monitoring design use? (declared: {declaration})",
        args = { "declaration" },
    },
    ["field.forecast_alignment"] = {
        template = "How do the forecast comparisons align? This asks for a declared description; declaring it does not verify alignment. (declared: {declaration})",
        args = { "declaration" },
    },

    -- Clarification codes (distinct per declaration state).
    ["clarify.absent"] = {
        template = "Field '{field}' has no declaration yet (status: {declaration}). Supplying one or declaring a status is optional for participation.",
        args = { "field", "declaration" },
    },
    ["clarify.unknown"] = {
        template = "Field '{field}' is declared unknown. Unknown is a valid declaration; supplied content is not required.",
        args = { "field", "declaration" },
    },
    ["clarify.not_collected"] = {
        template = "Field '{field}' is declared as data not collected. This limits what structural screening can reflect.",
        args = { "field", "declaration" },
    },
    -- Withheld wording must not ask for the protected content.
    ["clarify.withheld"] = {
        template = "Field '{field}' is withheld. This analysis may need a narrower scope; disclosure is not required.",
        args = { "field", "declaration" },
    },
    -- Declared-not-applicable wording distinguishes a declaration from
    -- reviewed applicability.
    ["clarify.declared_not_applicable"] = {
        template = "Field '{field}' is declared not applicable by the contributor. This is a declaration, not a reviewed determination of applicability.",
        args = { "field", "declaration" },
    },

    -- Structural error messages (args are code/path/numbers only; never raw
    -- supplied text or raw unknown key names).
    ["error.E_INPUT_TYPE"] = {
        template = "Input type is not admissible: expected a plain table at {path}, received {actual_type}.",
        args = { "path", "actual_type" },
    },
    ["error.E_METATABLE"] = {
        template = "A metatable was found at {path}; inputs with metatables are rejected.",
        args = { "path" },
    },
    ["error.E_UNKNOWN_FIELD"] = {
        template = "An unrecognized key was found at {path} (key hash {key_hash}). The key name is not echoed.",
        args = { "path", "key_hash" },
    },
    ["error.E_SCHEMA_VERSION"] = {
        template = "Unsupported schema_version at {path}: expected {expected}, received {actual_type}.",
        args = { "path", "expected", "actual_type" },
    },
    ["error.E_INTENTS_ARRAY"] = {
        template = "intents at {path} must be a nonempty contiguous array of strings (observed length {observed_length}).",
        args = { "path", "observed_length" },
    },
    ["error.E_INTENT_VALUE"] = {
        template = "The intent entry at {path} (position {index}) is not a registered intent value.",
        args = { "path", "index" },
    },
    ["error.E_INTENT_DUPLICATE"] = {
        template = "The intent entry at {path} (position {index}) duplicates an earlier intent.",
        args = { "path", "index" },
    },
    ["error.E_DECLARATION_TYPE"] = {
        template = "The declaration at {path} must be a plain table without a metatable.",
        args = { "path" },
    },
    ["error.E_DECLARATION_TAG"] = {
        template = "The declaration at {path} has an invalid tag or invalid companion keys for its tag.",
        args = { "path" },
    },
    ["error.E_TEXT_TYPE"] = {
        template = "supplied.text at {path} must be a string.",
        args = { "path" },
    },
    ["error.E_TEXT_EMPTY"] = {
        template = "supplied.text at {path} is empty or whitespace-only.",
        args = { "path" },
    },
    ["error.E_TEXT_LIMIT"] = {
        template = "supplied.text at {path} exceeds the {limit_bytes}-byte bound.",
        args = { "path", "limit_bytes" },
    },
    ["error.E_TEXT_UTF8"] = {
        template = "supplied.text at {path} is not valid UTF-8.",
        args = { "path" },
    },
    ["error.E_TEXT_CONTROL"] = {
        template = "supplied.text at {path} contains a disallowed ASCII control byte.",
        args = { "path" },
    },
    ["error.E_NOT_NORMALIZED"] = {
        template = "screen() input at {path} is structurally valid but not in canonical normalized form.",
        args = { "path" },
    },
    ["error.E_REGISTRY_CONTRACT"] = {
        template = "Registry contract violated at {path}: {reason_id}.",
        args = { "path", "reason_id" },
    },
    ["error.E_MESSAGE_KEY"] = {
        template = "The message key at {path} is not registered.",
        args = { "path" },
    },
    ["error.E_MESSAGE_ARGS"] = {
        template = "The arguments for message key at {path} do not match the declared roles.",
        args = { "path" },
    },
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function fail(code, path, args)
    return {
        ok = false,
        error = { code = code, path = path, message_key = "error." .. code, args = args or {} },
    }
end

M._fail = fail -- shared with the pipeline (stable envelope constructor)

local function is_plain_table(v)
    return type(v) == "table" and getmetatable(v) == nil
end

M._is_plain_table = is_plain_table

local function copy_list(t)
    local o = {}
    for i = 1, #t do o[i] = t[i] end
    return o
end

M._copy_list = copy_list

-- ---------------------------------------------------------------------------
-- requirements(intents): ordered required fields for an intent list.
-- Returns fresh tables; callers may mutate results without affecting the
-- registry. Result: {required_fields=..., interaction_records=...,
-- field_set_version=...}
-- ---------------------------------------------------------------------------

function M.requirements(intents)
    if not is_plain_table(intents) then
        return fail("E_INPUT_TYPE", "registry.intents",
            { path = "registry.intents", actual_type = type(intents) })
    end
    local n = #intents
    for i = 1, n do
        if type(intents[i]) ~= "string" then
            return fail("E_INTENT_VALUE", "registry.intents[" .. i .. "]",
                { path = "registry.intents", index = i })
        end
        if INTENTS[intents[i]] == nil then
            return fail("E_INTENT_VALUE", "registry.intents[" .. i .. "]",
                { path = "registry.intents", index = i })
        end
    end

    local present = {}
    for i = 1, n do present[intents[i]] = true end

    -- Build membership lookup over core + intent-specific fields.
    local member = {}
    for _, f in ipairs(CORE_FIELDS) do member[f] = true end
    for _, f in ipairs(FIELD_ORDER) do member[f] = member[f] or FIELDS[f] ~= nil end

    local req = {}
    local seen = {}
    local function add(f)
        if not seen[f] then seen[f] = true; req[#req + 1] = f end
    end
    for _, f in ipairs(CORE_FIELDS) do add(f) end
    -- Intent-specific fields in canonical FIELD_ORDER grouping: iterate
    -- FIELD_ORDER and include fields owned by any present intent.
    local owned = {}
    for intent in pairs(present) do
        for _, f in ipairs(INTENTS[intent]) do owned[f] = true end
    end
    -- Composite interactions contribute their required field when all
    -- triggering intents are present, so every composite requirement is
    -- derivable from the registered atomic/intent ownership plus declared
    -- interaction rules (the interaction RECORD itself is reported
    -- separately and is never hidden by atomic sets).
    for _, inter in ipairs(INTERACTIONS) do
        local triggered = true
        for _, intent in ipairs(inter.triggering_intents) do
            if not present[intent] then triggered = false break end
        end
        if triggered then owned[inter.required_field] = true end
    end
    -- Intent-owned fields are looked up via the field catalogue (not the
    -- CORE_FIELDS list), so composite/intent-specific requirements appear.
    for _, f in ipairs(FIELD_ORDER) do
        if FIELDS[f] and owned[f] then add(f) end
    end

    local records = {}
    for _, inter in ipairs(INTERACTIONS) do
        local triggered = true
        for _, intent in ipairs(inter.triggering_intents) do
            if not present[intent] then triggered = false break end
        end
        if triggered then
            records[#records + 1] = {
                rule_code = inter.rule_code,
                triggering_intents = copy_list(inter.triggering_intents),
                required_field = inter.required_field,
            }
        end
    end

    -- Registry invariant: core requirements always exist. If violated, this
    -- is a stable registry-contract error (no zero-denominator fallback).
    if #req == 0 then
        return fail("E_REGISTRY_CONTRACT", "registry.requirements",
            { path = "registry.requirements", reason_id = "R_EMPTY_REQUIRED_SET" })
    end

    return {
        ok = true,
        value = {
            required_fields = req,
            interaction_records = records,
            field_set_version = M.FIELD_SET_VERSION,
        },
    }
end

-- ---------------------------------------------------------------------------
-- message_contract(message_key): fresh copy of {template, arg_roles}.
-- ---------------------------------------------------------------------------

function M.message_contract(message_key)
    if type(message_key) ~= "string" then
        return fail("E_MESSAGE_KEY", "registry.message_key",
            { path = "registry.message_key" })
    end
    local m = MESSAGES[message_key]
    if m == nil then
        return fail("E_MESSAGE_KEY", "registry.message_key",
            { path = "registry.message_key" })
    end
    return {
        ok = true,
        value = {
            template = m.template,
            arg_roles = copy_list(m.args),
        },
    }
end

-- ---------------------------------------------------------------------------
-- render_en(message_key, args): English fallback rendering.
-- Resolves only registered keys; accepts only declared argument roles;
-- substitutes via function-based replacement (never format expansion that
-- could execute or misinterpret input). Returns an error envelope for
-- unknown keys or invalid/mismatched args. Claims no translation
-- equivalence.
-- ---------------------------------------------------------------------------

local MAX_ARG_BYTES = 256

function M.render_en(message_key, args)
    if type(message_key) ~= "string" or MESSAGES[message_key] == nil then
        return fail("E_MESSAGE_KEY", "registry.render_en.message_key",
            { path = "registry.render_en.message_key" })
    end
    local m = MESSAGES[message_key]
    if not is_plain_table(args) then
        return fail("E_MESSAGE_ARGS", "registry.render_en.args",
            { path = "registry.render_en.args" })
    end
    local allowed = {}
    for _, role in ipairs(m.args) do allowed[role] = true end

    -- Reject undeclared roles and oversized values.
    for k, v in pairs(args) do
        if type(k) ~= "string" or not allowed[k] then
            return fail("E_MESSAGE_ARGS", "registry.render_en.args",
                { path = "registry.render_en.args" })
        end
        local sv
        if type(v) == "number" or type(v) == "integer" then
            sv = tostring(v)
        elseif type(v) == "string" then
            sv = v
        else
            return fail("E_MESSAGE_ARGS", "registry.render_en.args",
                { path = "registry.render_en.args" })
        end
        if #sv > MAX_ARG_BYTES then
            return fail("E_MESSAGE_ARGS", "registry.render_en.args",
                { path = "registry.render_en.args" })
        end
    end
    -- Require every declared role to be present.
    for _, role in ipairs(m.args) do
        if args[role] == nil then
            return fail("E_MESSAGE_ARGS", "registry.render_en.args",
                { path = "registry.render_en.args" })
        end
    end

    local missing_sub = false
    -- Function-based replacement: the substitution value is returned as data
    -- from the function; it is never re-interpreted as a pattern/format.
    local out = (m.template:gsub("{(%a[%w_]*)}", function(role)
        local v = args[role]
        if v == nil then missing_sub = true; return "" end
        return tostring(v)
    end))
    if missing_sub then
        return fail("E_MESSAGE_ARGS", "registry.render_en.args",
            { path = "registry.render_en.args" })
    end
    return { ok = true, value = out }
end

-- Read-only catalogues exposed for introspection (do not mutate).
M.FIELD_ORDER = FIELD_ORDER
M.INTENT_ORDER = INTENT_ORDER
M.CORE_FIELDS = CORE_FIELDS

return M
