-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; separately versioned integration surface (not the earlier audit).
-- Does not require lua/oceanic/question_frame_audit.lua or any shared
-- validator. Local, synchronous, side-effect free: no networking, storage,
-- telemetry, publication, or hardware action. Scientific support and
-- authorization are outside this module's scope.
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Input contract: Lua tables only. No JSON parser is provided or required.
-- Lua nil represents absence in this interface; JSON null is outside this
-- interface.

local R = require("lua.oceanic.question_frame_registry")

local M = {}

M.VERSION = "1.0.0"
M.SCHEMA_VERSION = R.SCHEMA_VERSION

local fail = R._fail
local is_plain_table = R._is_plain_table

-- Documented upper bound per supplied text field, in bytes.
local TEXT_LIMIT_BYTES = 4000

local TAGS = {
    supplied = true,
    unknown = true,
    not_collected = true,
    withheld = true,
    declared_not_applicable = true,
}

local TAG_ORDER = {
    "supplied", "unknown", "not_collected", "withheld", "declared_not_applicable",
}

local TOP_KEYS = { schema_version = true, intents = true, frame = true }

local INTENT_RANK = {}
for i, name in ipairs(R.INTENT_ORDER) do INTENT_RANK[name] = i end

local FIELD_IN_CATALOGUE = {}
for _, f in ipairs(R.FIELD_ORDER) do FIELD_IN_CATALOGUE[f] = true end

-- Bounded guard before copying table contents from untrusted input.
local MAX_FRAME_KEYS = 64
local MAX_DECL_KEYS = 2

-- ---------------------------------------------------------------------------
-- UTF-8 validation (RFC 3629 forms; rejects overlongs, surrogates, >U+10FFFF).
-- Acceptance here is purely byte-form validation. It is NOT semantic review
-- and NOT accessibility validation.
-- ---------------------------------------------------------------------------

local function utf8_valid(s)
    local i, n = 1, #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then
            i = i + 1
        elseif b >= 0xC2 and b <= 0xDF then
            local b2 = s:byte(i + 1)
            if not b2 or b2 < 0x80 or b2 > 0xBF then return false end
            i = i + 2
        elseif b >= 0xE0 and b <= 0xEF then
            local b2 = s:byte(i + 1)
            local b3 = s:byte(i + 2)
            if not b2 or not b3 then return false end
            local lo, hi = 0x80, 0xBF
            if b == 0xE0 then lo = 0xA0 elseif b == 0xED then hi = 0x9F end
            if b2 < lo or b2 > hi then return false end
            if b3 < 0x80 or b3 > 0xBF then return false end
            i = i + 3
        elseif b >= 0xF0 and b <= 0xF4 then
            local b2 = s:byte(i + 1)
            local b3 = s:byte(i + 2)
            local b4 = s:byte(i + 3)
            if not b2 or not b3 or not b4 then return false end
            local lo, hi = 0x80, 0xBF
            if b == 0xF0 then lo = 0x90 elseif b == 0xF4 then hi = 0x8F end
            if b2 < lo or b2 > hi then return false end
            if b3 < 0x80 or b3 > 0xBF then return false end
            if b4 < 0x80 or b4 > 0xBF then return false end
            i = i + 4
        else
            return false
        end
    end
    return true
end

M._utf8_valid = utf8_valid

-- Stable, non-echoing hash for unknown key names (bounded FNV-1a output).
local function key_hash(s)
    local h = 2166136261
    for i = 1, #s do
        h = (h ~ s:byte(i)) * 16777619 & 0xFFFFFFFFFFFFFFFF
    end
    return string.format("%016x", h)
end

-- ---------------------------------------------------------------------------
-- Structural admission of raw input. Returns a validated deep copy or an
-- error envelope. Never mutates or executes input (no callbacks, no
-- input-provided metamethods: metatables are rejected outright).
-- ---------------------------------------------------------------------------

local function check_supplied_text(decl, path)
    -- supplied requires exactly tag and text.
    local count = 0
    for _ in pairs(decl) do count = count + 1 end
    if count ~= 2 or decl.tag == nil or decl.text == nil then
        return fail("E_DECLARATION_TAG", path, { path = path })
    end
    if type(decl.text) ~= "string" then
        return fail("E_TEXT_TYPE", path .. ".text", { path = path .. ".text" })
    end
    local t = decl.text
    if #t > TEXT_LIMIT_BYTES then
        return fail("E_TEXT_LIMIT", path .. ".text",
            { path = path .. ".text", limit_bytes = TEXT_LIMIT_BYTES })
    end
    -- Reject ASCII control bytes except tab (09), CR (0D), LF (0A). DEL (7F)
    -- is treated as a disallowed control byte.
    if t:find("[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]") then
        return fail("E_TEXT_CONTROL", path .. ".text", { path = path .. ".text" })
    end
    if not utf8_valid(t) then
        return fail("E_TEXT_UTF8", path .. ".text", { path = path .. ".text" })
    end
    -- Empty / whitespace-only check after control scan so that control bytes
    -- yield their own stable code. Whitespace here: space, tab, CR, LF.
    if t:gsub("[ \t\r\n]", "") == "" then
        return fail("E_TEXT_EMPTY", path .. ".text", { path = path .. ".text" })
    end
    return { ok = true }
end

local function admit_declaration(decl, path)
    if type(decl) ~= "table" then
        return fail("E_DECLARATION_TYPE", path, { path = path })
    end
    if getmetatable(decl) ~= nil then
        return fail("E_METATABLE", path, { path = path })
    end
    -- Bound keys before copying; reject unknown declaration keys.
    local count = 0
    for k in pairs(decl) do
        count = count + 1
        if count > MAX_DECL_KEYS then
            return fail("E_UNKNOWN_FIELD", path,
                { path = path, key_hash = "over_bound" })
        end
        if type(k) ~= "string" or (k ~= "tag" and k ~= "text") then
            return fail("E_UNKNOWN_FIELD", path,
                { path = path, key_hash = (type(k) == "string") and key_hash(k) or "nondeterministic_key_type" })
        end
    end
    local tag = decl.tag
    if type(tag) ~= "string" or TAGS[tag] == nil then
        return fail("E_DECLARATION_TAG", path, { path = path })
    end
    if tag == "supplied" then
        return check_supplied_text(decl, path)
    end
    -- Other tags require exactly tag.
    if decl.text ~= nil or count ~= 1 then
        return fail("E_DECLARATION_TAG", path, { path = path })
    end
    return { ok = true }
end

local function admit_intents(intents, path)
    if type(intents) ~= "table" then
        return fail("E_INTENTS_ARRAY", path, { path = path, observed_length = -1 })
    end
    if getmetatable(intents) ~= nil then
        return fail("E_METATABLE", path, { path = path })
    end
    local n = 0
    for _ in pairs(intents) do n = n + 1 end
    local len = #intents
    if len == 0 or n ~= len then
        -- empty, non-array keys, or sparse (nil holes / hash-part entries)
        return fail("E_INTENTS_ARRAY", path, { path = path, observed_length = len })
    end
    if len > #R.INTENT_ORDER then
        return fail("E_INTENTS_ARRAY", path, { path = path, observed_length = len })
    end
    local seen = {}
    local out = {}
    for i = 1, len do
        local v = intents[i]
        if type(v) ~= "string" or INTENT_RANK[v] == nil then
            return fail("E_INTENT_VALUE", path .. "[" .. i .. "]",
                { path = path, index = i })
        end
        if seen[v] then
            return fail("E_INTENT_DUPLICATE", path .. "[" .. i .. "]",
                { path = path, index = i })
        end
        seen[v] = true
        out[i] = v
    end
    return { ok = true, value = out }
end

local function admit_raw(raw)
    if type(raw) ~= "table" then
        return fail("E_INPUT_TYPE", "input",
            { path = "input", actual_type = type(raw) })
    end
    if getmetatable(raw) ~= nil then
        return fail("E_METATABLE", "input", { path = "input" })
    end
    -- Top-level keys: bounded, then copied.
    local count = 0
    for k in pairs(raw) do
        count = count + 1
        if count > MAX_FRAME_KEYS then
            return fail("E_UNKNOWN_FIELD", "input",
                { path = "input", key_hash = "over_bound" })
        end
        if type(k) ~= "string" or not TOP_KEYS[k] then
            return fail("E_UNKNOWN_FIELD", "input",
                { path = "input",
                  key_hash = (type(k) == "string") and key_hash(tostring(k)) or "nondeterministic_key_type" })
        end
    end

    if raw.schema_version ~= R.SCHEMA_VERSION then
        return fail("E_SCHEMA_VERSION", "input.schema_version",
            { path = "input.schema_version", expected = R.SCHEMA_VERSION,
              actual_type = type(raw.schema_version) })
    end

    local r = admit_intents(raw.intents, "input.intents")
    if not r.ok then return r end
    local admitted_intents = r.value

    local frame_in = {}
    if raw.frame ~= nil then
        if type(raw.frame) ~= "table" then
            return fail("E_DECLARATION_TYPE", "input.frame", { path = "input.frame" })
        end
        if getmetatable(raw.frame) ~= nil then
            return fail("E_METATABLE", "input.frame", { path = "input.frame" })
        end
        local fc = 0
        for k in pairs(raw.frame) do
            fc = fc + 1
            if fc > MAX_FRAME_KEYS then
                return fail("E_UNKNOWN_FIELD", "input.frame",
                    { path = "input.frame", key_hash = "over_bound" })
            end
            if type(k) ~= "string" or not FIELD_IN_CATALOGUE[k] then
                return fail("E_UNKNOWN_FIELD", "input.frame",
                    { path = "input.frame",
                      key_hash = (type(k) == "string") and key_hash(k) or "nondeterministic_key_type" })
            end
        end
        for _, field in ipairs(R.FIELD_ORDER) do
            local decl = raw.frame[field]
            if decl ~= nil then
                local dr = admit_declaration(decl, "input.frame." .. field)
                if not dr.ok then return dr end
                -- Copy: preserve text exactly (no trim, no transliteration).
                local c = { tag = decl.tag }
                if decl.tag == "supplied" then c.text = decl.text end
                frame_in[field] = c
            end
        end
    end

    return { ok = true, value = { intents = admitted_intents, frame = frame_in } }
end

-- ---------------------------------------------------------------------------
-- normalize(raw): validate the raw representation, then return a NEW canonical
-- table with intents in registry order. Preserves text and declaration tags;
-- does not invent missing declarations; does not mutate the input. The output
-- uses the same admissible input shape, so normalize(normalize(raw).value) is
-- valid and structurally equal to the first result (idempotent). This is a
-- plain data shape, not a private type or a security boundary.
-- ---------------------------------------------------------------------------

function M.normalize(raw)
    local a = admit_raw(raw)
    if not a.ok then return a end

    local sorted = {}
    for i, v in ipairs(a.value.intents) do sorted[i] = v end
    table.sort(sorted, function(x, y)
        return INTENT_RANK[x] < INTENT_RANK[y]
    end)

    local frame = {}
    for field, decl in pairs(a.value.frame) do
        local c = { tag = decl.tag }
        if decl.text ~= nil then c.text = decl.text end
        frame[field] = c
    end

    return {
        ok = true,
        value = {
            schema_version = R.SCHEMA_VERSION,
            intents = sorted,
            frame = frame,
        },
    }
end

-- ---------------------------------------------------------------------------
-- screen(normalized): defensively validates its argument. Structurally valid
-- but noncanonical intent order yields E_NOT_NORMALIZED. Derives requirements
-- from the registry. No rendering, no side effects.
--
-- Output note: normalized_frame contains supplied content. Callers must not
-- automatically log or publish it.
-- ---------------------------------------------------------------------------

local CLARIFY_CODE = {
    absent                     = "REQ_CLARIFICATION_ABSENT",
    unknown                    = "REQ_CLARIFICATION_UNKNOWN",
    not_collected              = "REQ_CLARIFICATION_NOT_COLLECTED",
    withheld                   = "REQ_CLARIFICATION_WITHHELD",
    declared_not_applicable    = "REQ_CLARIFICATION_DECLARED_NOT_APPLICABLE",
}

local CLARIFY_MESSAGE_KEY = {
    absent                     = "clarify.absent",
    unknown                    = "clarify.unknown",
    not_collected              = "clarify.not_collected",
    withheld                   = "clarify.withheld",
    declared_not_applicable    = "clarify.declared_not_applicable",
}

function M.screen(normalized)
    -- Defensive re-admission: screen accepts only what normalize would accept.
    local a = admit_raw(normalized)
    if not a.ok then return a end

    -- Require canonical intent order (registry order, strictly increasing).
    local ints = a.value.intents
    for i = 2, #ints do
        if INTENT_RANK[ints[i - 1]] >= INTENT_RANK[ints[i]] then
            return fail("E_NOT_NORMALIZED", "input.intents",
                { path = "input.intents" })
        end
    end

    local req_r = R.requirements(ints)
    if not req_r.ok then
        if req_r.error.code == "E_REGISTRY_CONTRACT" then return req_r end
        return fail("E_REGISTRY_CONTRACT", "registry.requirements",
            { path = "registry.requirements", reason_id = "R_REQUIREMENTS_FAILED" })
    end
    local required = req_r.value.required_fields
    local interaction_records = req_r.value.interaction_records

    -- Registry invariant guard: required set is never empty.
    if #required == 0 then
        return fail("E_REGISTRY_CONTRACT", "registry.requirements",
            { path = "registry.requirements", reason_id = "R_EMPTY_REQUIRED_SET" })
    end

    local frame = (normalized and normalized.frame) or {}
    local required_set = {}
    for _, f in ipairs(required) do required_set[f] = true end

    -- Partition: every required field occurs in exactly one array, in
    -- required-field order within each bucket.
    local partition = {
        supplied = {}, unknown = {}, not_collected = {}, withheld = {},
        declared_not_applicable = {}, absent = {},
    }
    local clarifications = {}
    local supplied_count = 0
    local declared_count = 0
    for _, field in ipairs(required) do
        local decl = frame[field]
        local tag = decl and decl.tag or "absent"
        partition[tag][#partition[tag] + 1] = field
        if tag == "absent" then
            -- no declaration
        else
            declared_count = declared_count + 1
            if tag == "supplied" then supplied_count = supplied_count + 1 end
        end
        if tag ~= "supplied" then
            -- Machine record: no rendered English, no supplied text copied.
            clarifications[#clarifications + 1] = {
                field = field,
                declaration_tag = tag,
                code = CLARIFY_CODE[tag],
                prompt_key = CLARIFY_MESSAGE_KEY[tag],
                args = { field = field, declaration = tag },
                participation_required = false,
            }
        end
    end

    local required_count = #required
    local additional_declared_fields = {}
    for _, field in ipairs(R.FIELD_ORDER) do
        if frame[field] ~= nil and not required_set[field] then
            additional_declared_fields[#additional_declared_fields + 1] = field
        end
    end

    local outcome
    if supplied_count == required_count then
        outcome = "structurally_accepted"
    else
        outcome = "accepted_with_clarifications"
    end
    -- Interpretation limits (stated narrowly):
    --  * structurally_accepted means every required field carries a supplied
    --    declaration. It does NOT mean scientifically supported.
    --  * accepted_with_clarifications does NOT reject participation.
    --  * supplied_ratio is NOT scientific readiness.

    return {
        ok = true,
        value = {
            outcome = outcome,
            normalized_frame = frame,
            required_fields = required,
            declaration_partition = partition,
            clarifications = clarifications,
            interaction_records = interaction_records,
            coverage = {
                required_count = required_count,
                declared_count = declared_count,
                supplied_count = supplied_count,
                declaration_ratio = declared_count / required_count,
                supplied_ratio = supplied_count / required_count,
                denominator_scope = "registered_required_fields",
            },
            additional_declared_fields = additional_declared_fields,
            versions = {
                pipeline_version = M.VERSION,
                registry_version = R.VERSION,
                schema_version = R.SCHEMA_VERSION,
                field_set_version = req_r.value.field_set_version,
                message_set_version = R.MESSAGE_SET_VERSION,
            },
            assessment_scope = "structural_only",
        },
    }
end

-- ---------------------------------------------------------------------------
-- evaluate(raw): normalize, then screen. Returns the first error unchanged.
-- Renders no messages and performs no side effects.
-- ---------------------------------------------------------------------------

function M.evaluate(raw)
    local n = M.normalize(raw)
    if not n.ok then return n end
    local s = M.screen(n.value)
    if not s.ok then return s end
    return s
end

-- Re-export registry surfaces for convenience of callers of this layer.
M.registry = R

M.TEXT_LIMIT_BYTES = TEXT_LIMIT_BYTES
M.TAG_ORDER = TAG_ORDER

return M
