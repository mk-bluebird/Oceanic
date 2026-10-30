-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Dependency-free Lua 5.4 test runner (pcall only; no external framework).
-- All fixtures are clearly synthetic (invented names/values only).
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Run from the repository root:
--   lua tests/oceanic/question_frame_pipeline_test.lua
-- Exit codes: 0 all passed, 1 one or more failed.

local P = require("lua.oceanic.question_frame_pipeline")
local R = require("lua.oceanic.question_frame_registry")

local failures = 0

local function sanitize(s)
    s = tostring(s):gsub("[%z\1-\31\127]", " ")
    if #s > 500 then s = s:sub(1, 500) .. "...[truncated]" end
    return s
end

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t", sanitize(detail), "\n")
    end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local CORE = { "subject", "relationship", "response", "spatial_scope",
               "temporal_scope", "measurement_basis", "evidence_basis" }

local function sup(text) return { tag = "supplied", text = text } end

local function synth_complete_frame(extra)
    local f = {
        subject           = sup("Synthetic lake A"),
        relationship     = sup("Synthetic nutrient response relation"),
        response          = sup("Synthetic chlorophyll index"),
        spatial_scope     = sup("Synthetic basin 1"),
        temporal_scope    = sup("Synthetic season 2025"),
        measurement_basis = sup("Synthetic sensor grid units"),
        evidence_basis    = sup("Synthetic prior survey notes"),
    }
    if extra then for k, v in pairs(extra) do f[k] = v end end
    return f
end

local function deep_clone(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local o = {}
    seen[v] = o
    for k, val in pairs(v) do o[deep_clone(k, seen)] = deep_clone(val, seen) end
    return o
end

local function struct_equal(a, b, seen)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    seen = seen or {}
    local key = tostring(a) .. "|" .. tostring(b)
    if seen[key] then return true end
    seen[key] = true
    for k, v in pairs(a) do
        if not struct_equal(v, b[k], seen) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function assert_env(e)
    if type(e) ~= "table" or type(e.ok) ~= "boolean" then
        error("not a result envelope")
    end
end

local function err_of(e)
    assert_env(e)
    if e.ok then error("expected failure envelope, got ok=true") end
    local er = e.error
    if type(er) ~= "table" or type(er.code) ~= "string"
       or type(er.path) ~= "string" or type(er.message_key) ~= "string"
       or type(er.args) ~= "table" then
        error("error envelope missing stable fields")
    end
    return er
end

local TOL = 1e-12
local function near(x, y) return math.abs(x - y) <= TOL end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

test("empty_frame_returns_core_clarifications", function()
    local r = P.evaluate({ schema_version = 1, intents = { "describe" }, frame = {} })
    assert(r.ok, "evaluate failed")
    local v = r.value
    assert(#v.required_fields == 7, "expected 7 core required fields")
    assert(#v.clarifications == 7, "expected 7 clarifications")
    for i, c in ipairs(v.clarifications) do
        assert(c.field == CORE[i], "clarification order mismatch")
        assert(c.declaration_tag == "absent", "expected absent tag")
        assert(c.code == "REQ_CLARIFICATION_ABSENT", "expected absent code")
        assert(c.prompt_key == "clarify.absent", "expected absent prompt_key")
        assert(c.participation_required == false, "participation must be optional")
        assert(c.args.field == c.field, "args field role")
        assert(c.text == nil, "machine record must carry no rendered text")
    end
    assert(v.outcome == "accepted_with_clarifications", "outcome")
    assert(v.assessment_scope == "structural_only", "scope")
end)

test("unknown_is_declared_not_supplied", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "unknown" } },
    })
    assert(r.ok)
    local v = r.value
    assert(v.declaration_partition.unknown[1] == "subject", "unknown bucket")
    assert(v.coverage.declared_count == 1, "declared counts the declaration")
    assert(v.coverage.supplied_count == 0, "unknown is not supplied")
    local found = false
    for _, c in ipairs(v.clarifications) do
        if c.field == "subject" then
            found = true
            assert(c.declaration_tag == "unknown", "tag preserved")
            assert(c.code == "REQ_CLARIFICATION_UNKNOWN", "distinct code")
        end
    end
    assert(found, "subject clarification expected")
end)

test("withheld_requires_no_content", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { spatial_scope = { tag = "withheld" } },
    })
    assert(r.ok, "withholding needs no reason or content: " ..
        (r.error and r.error.code or "?"))
    local v = r.value
    assert(v.declaration_partition.withheld[1] == "spatial_scope", "bucket")
    -- Withheld wording must not ask for protected content.
    local rr = R.render_en("clarify.withheld",
        { field = "spatial_scope", declaration = "withheld" })
    assert(rr.ok)
    assert(rr.value:find("disclosure is not required", 1, true),
        "limitation-oriented wording expected")
    assert(not rr.value:find("please provide", 1, true)
        and not rr.value:find("share the", 1, true),
        "must not request protected content")
    -- No inference about collection status from withholding:
    local c
    for _, x in ipairs(v.clarifications) do if x.field == "spatial_scope" then c = x end end
    assert(c and c.code == "REQ_CLARIFICATION_WITHHELD", "distinct withheld code")
end)

test("declared_not_applicable_stays_in_denominator", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { relationship = { tag = "declared_not_applicable" } },
    })
    assert(r.ok)
    local v = r.value
    assert(v.coverage.required_count == 7, "denominator unchanged")
    assert(near(v.coverage.declaration_ratio, 1 / 7), "declaration ratio")
    assert(near(v.coverage.supplied_ratio, 0), "supplied ratio")
    assert(v.declaration_partition.declared_not_applicable[1] == "relationship",
        "bucket")
    local rr = R.render_en("clarify.declared_not_applicable",
        { field = "relationship", declaration = "declared_not_applicable" })
    assert(rr.ok)
    assert(rr.value:find("not a reviewed determination", 1, true),
        "declaration distinguished from reviewed applicability")
end)

test("literal_unknown_text_remains_supplied", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "supplied", text = "unknown" } },
    })
    assert(r.ok)
    assert(r.value.declaration_partition.supplied[1] == "subject",
        "literal text 'unknown' stays supplied")
    assert(r.value.normalized_frame.subject.text == "unknown", "text preserved")
    assert(r.value.coverage.supplied_count == 1, "counted as supplied")
end)

test("zero_text_is_not_missing", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { measurement_basis = { tag = "supplied", text = "0" } },
    })
    assert(r.ok, "numeric string '0' must be accepted as supplied text")
    assert(r.value.normalized_frame.measurement_basis.text == "0", "preserved")
    assert(r.value.coverage.supplied_count == 1, "supplied")
end)

test("unicode_text_is_accepted", function()
    local texts = { "Järvi‑synthétique — lac 合成湖 🌊", "Σῦνα → Ὕδωρ", "日本語の架空湖" }
    for _, t in ipairs(texts) do
        local r = P.evaluate({
            schema_version = 1, intents = { "describe" },
            frame = { subject = { tag = "supplied", text = t } },
        })
        assert(r.ok, "unicode rejected: " .. (r.error and r.error.code or "?"))
        assert(r.value.normalized_frame.subject.text == t, "exact preservation")
    end
end)

test("invalid_utf8_is_rejected", function()
    local bad = { "\xFF\xFE", "abc\xC0\x80def", "trail\xE2\x82", "\xED\xA0\x80" }
    for _, t in ipairs(bad) do
        local r = P.evaluate({
            schema_version = 1, intents = { "describe" },
            frame = { subject = { tag = "supplied", text = t } },
        })
        local e = err_of(r)
        assert(e.code == "E_TEXT_UTF8", "expected E_TEXT_UTF8, got " .. e.code)
    end
end)

test("empty_and_whitespace_text_are_rejected", function()
    for _, t in ipairs({ "", "   ", "\t \r\n" }) do
        local r = P.evaluate({
            schema_version = 1, intents = { "describe" },
            frame = { subject = { tag = "supplied", text = t } },
        })
        local e = err_of(r)
        assert(e.code == "E_TEXT_EMPTY", "expected E_TEXT_EMPTY, got " .. e.code)
    end
end)

test("oversized_text_is_rejected", function()
    local big = string.rep("a", 4001)
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "supplied", text = big } },
    })
    local e = err_of(r)
    assert(e.code == "E_TEXT_LIMIT", "expected E_TEXT_LIMIT, got " .. e.code)
    assert(e.args.limit_bytes == 4000, "documented bound")
    -- Exactly at the bound is accepted.
    local ok = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "supplied", text = string.rep("a", 4000) } },
    })
    assert(ok.ok, "4000-byte text must pass")
end)

test("disallowed_controls_are_rejected", function()
    for _, b in ipairs({ 0x00, 0x07, 0x0B, 0x1B }) do
        local r = P.evaluate({
            schema_version = 1, intents = { "describe" },
            frame = { subject = { tag = "supplied", text = "x" .. string.char(b) .. "y" } },
        })
        local e = err_of(r)
        assert(e.code == "E_TEXT_CONTROL", "expected E_TEXT_CONTROL, got " .. e.code)
    end
    -- Allowed controls: tab, CR, LF combined with real content.
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "supplied", text = "line1\tline2\r\nend" } },
    })
    assert(r.ok, "tab/CR/LF allowed inside nonblank text")
end)

test("metatables_are_rejected", function()
    local input = { schema_version = 1, intents = { "describe" }, frame = {} }
    setmetatable(input, {})
    local e = err_of(P.evaluate(input))
    assert(e.code == "E_METATABLE", "top-level metatable: " .. e.code)

    local frame = {}
    setmetatable(frame, {})
    local e2 = err_of(P.evaluate({
        schema_version = 1, intents = { "describe" }, frame = frame,
    }))
    assert(e2.code == "E_METATABLE", "frame metatable: " .. e2.code)

    local decl = { tag = "unknown" }
    setmetatable(decl, {})
    local e3 = err_of(P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = decl },
    }))
    assert(e3.code == "E_METATABLE", "declaration metatable: " .. e3.code)
end)

test("unknown_fields_are_rejected_without_echo", function()
    local secret = "SECRET_MARKER_do_not_echo_9f3k"
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" }, frame = {},
        [secret] = true,
    })
    local e = err_of(r)
    assert(e.code == "E_UNKNOWN_FIELD", "top-level unknown: " .. e.code)
    local serialized = sanitize(string.format("%s|%s|%s",
        e.code, e.path, table.concat((function()
            local o = {}
            for k, v in pairs(e.args) do o[#o + 1] = k .. "=" .. tostring(v) end
            return o
        end)(), ",")))
    assert(not serialized:find(secret, 1, true), "raw unknown key echoed!")

    local r2 = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { [secret] = { tag = "unknown" } },
    })
    local e2 = err_of(r2)
    assert(e2.code == "E_UNKNOWN_FIELD", "frame unknown: " .. e2.code)
    local s2 = sanitize(e2.path .. e2.message_key .. next(e2.args) .. tostring(e2.args[next(e2.args)]))
    assert(not s2:find(secret, 1, true), "raw frame key echoed!")

    local r3 = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = { subject = { tag = "unknown", reason = secret } },
    })
    local e3 = err_of(r3)
    assert(e3.code == "E_UNKNOWN_FIELD", "declaration unknown key: " .. e3.code)
    assert(not sanitize(e3.path):find(secret, 1, true), "decl key echoed!")
end)

test("sparse_intents_are_rejected", function()
    local sparse = { "describe", nil, "compare" }
    local e = err_of(P.evaluate({ schema_version = 1, intents = sparse, frame = {} }))
    assert(e.code == "E_INTENTS_ARRAY", "sparse: " .. e.code)
    local mixed = { "describe", extra = 1 }
    local e2 = err_of(P.evaluate({ schema_version = 1, intents = mixed, frame = {} }))
    assert(e2.code == "E_INTENTS_ARRAY", "hash part: " .. e2.code)
    local e3 = err_of(P.evaluate({ schema_version = 1, intents = {}, frame = {} }))
    assert(e3.code == "E_INTENTS_ARRAY", "empty: " .. e3.code)
    local e4 = err_of(P.evaluate({ schema_version = 1, intents = { "describe", "describe2" }, frame = {} }))
    assert(e4.code == "E_INTENT_VALUE", "unsupported: " .. e4.code)
    local e5 = err_of(P.evaluate({ schema_version = 1, intents = { 42 }, frame = {} }))
    assert(e5.code == "E_INTENT_VALUE", "non-string: " .. e5.code)
    local six = { "describe", "compare", "explain", "forecast", "design_monitoring", "describe" }
    local e6 = err_of(P.evaluate({ schema_version = 1, intents = six, frame = {} }))
    assert(e6.code == "E_INTENTS_ARRAY" or e6.code == "E_INTENT_DUPLICATE",
        ">five registered intents rejected: " .. e6.code)
end)

test("duplicate_intents_are_rejected", function()
    local e = err_of(P.evaluate({
        schema_version = 1, intents = { "compare", "forecast", "compare" },
        frame = {},
    }))
    assert(e.code == "E_INTENT_DUPLICATE", "expected duplicate code, got " .. e.code)
end)

test("intent_order_normalizes_identically", function()
    local a = P.normalize({ schema_version = 1,
        intents = { "forecast", "compare", "describe" }, frame = {} })
    local b = P.normalize({ schema_version = 1,
        intents = { "describe", "compare", "forecast" }, frame = {} })
    assert(a.ok and b.ok)
    assert(struct_equal(a.value, b.value), "canonicalization must converge")
    assert(a.value.intents[1] == "describe", "registry order describe first")
    assert(a.value.intents[2] == "compare", "registry order compare second")
    assert(a.value.intents[3] == "forecast", "registry order forecast third")
end)

test("compare_forecast_adds_alignment_requirement", function()
    local r = R.requirements({ "compare", "forecast" })
    assert(r.ok)
    local req = r.value.required_fields
    local has_align, align_idx = false, 0
    for i, f in ipairs(req) do
        if f == "forecast_alignment" then has_align = true; align_idx = i end
    end
    assert(has_align, "interaction field must be required")
    -- interaction record shape
    local rec = r.value.interaction_records[1]
    assert(rec.rule_code == "R_COMPARE_FORECAST_ALIGNMENT", "stable rule code")
    assert(rec.triggering_intents[1] == "compare"
        and rec.triggering_intents[2] == "forecast", "triggering intents")
    assert(rec.required_field == "forecast_alignment", "required field")
    -- Single-intent sets must NOT include it.
    local c1 = R.requirements({ "compare" })
    local c2 = R.requirements({ "forecast" })
    for _, cr in ipairs({ c1, c2 }) do
        for _, f in ipairs(cr.value.required_fields) do
            assert(f ~= "forecast_alignment", "no alignment without both intents")
        end
        assert(#cr.value.interaction_records == 0, "no records without both intents")
    end
    -- Presence of a declared alignment does not verify actual alignment:
    local ev = P.evaluate({
        schema_version = 1, intents = { "compare", "forecast" },
        frame = { forecast_alignment = sup("Synthetic same-window alignment note") },
    })
    assert(ev.ok)
    local v = ev.value
    assert(v.assessment_scope == "structural_only", "declared, not verified")
    assert(v.declaration_partition.supplied[1] == "forecast_alignment", "bucket")
end)

test("atomic_requirements_do_not_hide_interaction", function()
    local atomics = { "describe", "compare", "explain", "forecast", "design_monitoring" }
    -- The interaction field forecast_alignment is NOT present in any single
    -- atomic requirement set; only the compare+forecast composite reveals it.
    -- Atomic results therefore must not hide the interaction record.
    for _, it in ipairs(atomics) do
        local rr = R.requirements({ it })
        assert(rr.ok)
        assert(#rr.value.interaction_records == 0,
            "single-intent set must carry no interaction records")
        for _, f in ipairs(rr.value.required_fields) do
            assert(f ~= "forecast_alignment",
                "atomic set unexpectedly requires the interaction field")
        end
    end
    local cf = R.requirements({ "compare", "forecast" })
    assert(cf.ok and #cf.value.interaction_records == 1,
        "composite requirements must not hide the interaction record")
    local found_align = false
    for _, f in ipairs(cf.value.required_fields) do
        if f == "forecast_alignment" then found_align = true end
    end
    assert(found_align, "composite must add the interaction field")

    -- Every field of any composite set is registered: it either appears in
    -- the union of atomic requirements or is explicitly named by a returned
    -- interaction record (no unregistered fields leak into composites).
    local union = {}
    for _, it in ipairs(atomics) do
        local rr = R.requirements({ it })
        for _, f in ipairs(rr.value.required_fields) do union[f] = true end
    end
    local comp = R.requirements(atomics)
    assert(comp.ok)
    local interaction_fields = {}
    for _, rec in ipairs(comp.value.interaction_records) do
        interaction_fields[rec.required_field] = true
    end
    for i = 1, #atomics do
        for j = i + 1, #atomics do
            local pr = R.requirements({ atomics[i], atomics[j] })
            assert(pr.ok)
            for _, f in ipairs(pr.value.required_fields) do
                assert(union[f] or interaction_fields[f],
                    "composite field " .. f .. " has no registered source")
            end
        end
    end
    for _, f in ipairs(comp.value.required_fields) do
        assert(union[f] or interaction_fields[f],
            "composite field " .. f .. " has no registered source")
    end
    -- And every composite field appears exactly once (deduplication).
    local seen = {}
    for _, f in ipairs(comp.value.required_fields) do
        assert(not seen[f], "duplicate required field: " .. f)
        seen[f] = true
    end
end)

test("normalization_is_idempotent", function()
    local raw = {
        schema_version = 1,
        intents = { "forecast", "compare" },
        frame = {
            subject = sup("Synthetic lake Zäë"),
            evidence_basis = { tag = "not_collected" },
            spatial_scope = { tag = "withheld" },
        },
    }
    local n1 = P.normalize(raw)
    assert(n1.ok)
    local n2 = P.normalize(n1.value)
    assert(n2.ok, "normalize output must be admissible input")
    assert(struct_equal(n1.value, n2.value), "idempotence violated")
end)

test("complete_input_is_not_mutated", function()
    local raw = {
        schema_version = 1,
        intents = { "forecast", "compare" },
        frame = {
            subject = sup("Synthetic lake"),
            relationship = sup("Synthetic relation"),
            response = sup("Synthetic response"),
            spatial_scope = sup("Synthetic place"),
            temporal_scope = sup("Synthetic window"),
            measurement_basis = sup("Synthetic units"),
            evidence_basis = sup("Synthetic notes"),
            comparison_basis = sup("Synthetic pairing rule"),
            event_definition = sup("Synthetic bloom event"),
            issue_time = sup("Synthetic 2026-01-01"),
            forecast_horizon = sup("Synthetic 30 days"),
            evaluation_basis = sup("Synthetic scoring plan"),
            forecast_alignment = sup("Synthetic shared window"),
        },
    }
    local before = deep_clone(raw)
    local r = P.evaluate(raw)
    assert(r.ok, "complete compare+forecast must screen: "
        .. (r.error and r.error.code or "?"))
    assert(r.value.outcome == "structurally_accepted", "outcome")
    assert(struct_equal(before, raw), "input mutated during evaluation")
end)

test("output_changes_do_not_mutate_input_or_registry", function()
    local raw = {
        schema_version = 1, intents = { "describe" },
        frame = { subject = sup("Synthetic pond X") },
    }
    local before = deep_clone(raw)
    local r = P.evaluate(raw)
    assert(r.ok)
    -- Mutate every reachable output structure.
    local v = r.value
    v.outcome = "tampered"
    table.insert(v.required_fields, "bogus_field")
    table.insert(v.declaration_partition.supplied, "bogus")
    table.insert(v.clarifications, { field = "bogus" })
    table.insert(v.interaction_records, { rule_code = "BOGUS" })
    v.coverage.required_count = 999
    table.insert(v.additional_declared_fields, "bogus")
    v.normalized_frame.subject.text = "TAMPERED"
    local registry_before = deep_clone({
        order = R.FIELD_ORDER, intents = R.INTENT_ORDER, core = R.CORE_FIELDS,
    })
    -- Second evaluation must see pristine behavior.
    local r2 = P.evaluate(raw)
    assert(r2.ok)
    assert(struct_equal(before, raw), "input mutated")
    assert(r2.value.outcome == "accepted_with_clarifications", "outcome drift")
    assert(#r2.value.required_fields == 7, "required-field drift")
    assert(r2.value.normalized_frame.subject.text == "Synthetic pond X",
        "text drift (registry data mutated)")
    assert(struct_equal(registry_before.order, R.FIELD_ORDER)
        and struct_equal(registry_before.intents, R.INTENT_ORDER)
        and struct_equal(registry_before.core, R.CORE_FIELDS),
        "registry catalogues mutated")
    -- requirements() must hand back fresh tables each call.
    local q1 = R.requirements({ "compare" })
    local q2 = R.requirements({ "compare" })
    assert(q1.value.required_fields ~= q2.value.required_fields,
        "requirements returned a shared mutable reference")
    table.insert(q1.value.required_fields, "junk")
    assert(#q2.value.required_fields == 8, "freshness violated")
end)

test("required_partition_is_disjoint_and_exhaustive", function()
    local tags = { "supplied", "unknown", "not_collected", "withheld",
                   "declared_not_applicable", "absent" }
    local r = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = {
            subject = sup("Synthetic lake"),
            relationship = { tag = "unknown" },
            response = { tag = "not_collected" },
            spatial_scope = { tag = "withheld" },
            temporal_scope = { tag = "declared_not_applicable" },
        },
    })
    assert(r.ok)
    local p = r.value.declaration_partition
    local owner = {}
    local total = 0
    for _, tag in ipairs(tags) do
        assert(type(p[tag]) == "table", "missing bucket " .. tag)
        for _, f in ipairs(p[tag]) do
            assert(not owner[f], "field in two buckets: " .. f)
            owner[f] = tag
            total = total + 1
        end
    end
    assert(total == 7, "exhaustiveness: " .. total)
    for _, f in ipairs(CORE) do
        assert(owner[f], "required field unpartitioned: " .. f)
    end
    assert(owner.measurement_basis == "absent" and owner.evidence_basis == "absent",
        "absent bucket holds undeclared fields")
end)

test("coverage_counts_match_partition", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "explain" },
        frame = {
            subject = sup("Synthetic estuary"),
            relationship = sup("Synthetic link"),
            response = { tag = "unknown" },
            competing_explanations = sup("Synthetic hypotheses list"),
        },
    })
    assert(r.ok)
    local v = r.value
    local p = v.declaration_partition
    local cov = v.coverage
    assert(cov.required_count == 8, "core 7 + competing_explanations")
    local ps, pu, pn, pw, pd, pa =
        #p.supplied, #p.unknown, #p.not_collected, #p.withheld,
        #p.declared_not_applicable, #p.absent
    assert(cov.supplied_count == ps, "supplied count matches partition")
    assert(cov.declared_count == ps + pu + pn + pw + pd, "declared count")
    assert(ps + pu + pn + pw + pd + pa == cov.required_count, "sum")
    assert(near(cov.declaration_ratio, cov.declared_count / cov.required_count),
        "declaration_ratio")
    assert(near(cov.supplied_ratio, cov.supplied_count / cov.required_count),
        "supplied_ratio")
    assert(cov.denominator_scope == "registered_required_fields", "scope label")
    assert(v.outcome == "accepted_with_clarifications", "outcome")
end)

test("additional_fields_do_not_change_denominator", function()
    local base = P.evaluate({ schema_version = 1, intents = { "describe" }, frame = {} })
    assert(base.ok)
    local with_extra = P.evaluate({
        schema_version = 1, intents = { "describe" },
        frame = {
            subject = sup("Synthetic lake"),
            comparison_basis = { tag = "unknown" },      -- recognized, not required
            sampling_basis = sup("Synthetic transect plan"),
        },
    })
    assert(with_extra.ok)
    local v = with_extra.value
    assert(v.coverage.required_count == base.value.coverage.required_count,
        "denominator unchanged by additional declarations")
    assert(v.coverage.declared_count == 1, "only required fields counted")
    assert(v.coverage.supplied_count == 1, "only required fields counted")
    local seen = {}
    for _, f in ipairs(v.additional_declared_fields) do
        assert(not seen[f], "dup additional")
        seen[f] = true
        assert(f ~= "subject", "required field leaked into additional")
    end
    assert(seen.comparison_basis and seen.sampling_basis, "both listed")
    assert(near(v.coverage.declaration_ratio, 1 / 7), "ratio uses 7 denominator")
end)

test("screen_rejects_noncanonical_intent_order", function()
    local e = err_of(P.screen({
        schema_version = 1, intents = { "forecast", "compare" }, frame = {},
    }))
    assert(e.code == "E_NOT_NORMALIZED", "expected E_NOT_NORMALIZED, got " .. e.code)
    -- Canonical order passes.
    local ok = P.screen({
        schema_version = 1, intents = { "compare", "forecast" }, frame = {},
    })
    assert(ok.ok, "canonical order must screen")
    -- Garbage arguments still get structural errors, not crashes.
    assert(err_of(P.screen(nil)).code == "E_INPUT_TYPE", "nil arg")
    assert(err_of(P.screen("x")).code == "E_INPUT_TYPE", "string arg")
end)

test("complete_frame_has_structural_only_status", function()
    local r = P.evaluate({
        schema_version = 1, intents = { "design_monitoring" },
        frame = synth_complete_frame({ sampling_basis = sup("Synthetic random design") }),
    })
    assert(r.ok)
    local v = r.value
    assert(v.outcome == "structurally_accepted", "outcome")
    assert(v.assessment_scope == "structural_only", "status")
    assert(near(v.coverage.supplied_ratio, 1), "full supplied ratio")
    assert(#v.clarifications == 0, "no clarifications when complete")
    -- structurally_accepted does NOT mean scientifically supported;
    -- scientific support and authorization remain out of scope:
    assert(v.scientific_support == nil and v.authorization == nil,
        "no out-of-scope verdicts emitted")
end)

test("fallback_rendering_uses_registered_argument_roles", function()
    local rr = R.render_en("clarify.unknown", { field = "subject", declaration = "unknown" })
    assert(rr.ok, "render failed")
    assert(type(rr.value) == "string", "rendered string")
    assert(rr.value:find("subject", 1, true), "declared role substituted")
    -- message_contract exposes roles freshly.
    local mc = R.message_contract("clarify.unknown")
    assert(mc.ok)
    local roles = mc.value.arg_roles
    assert(type(roles) == "table" and #roles >= 1, "arg roles exposed")
    -- Unknown extra role rejected.
    assert(err_of(R.render_en("clarify.unknown",
        { field = "subject", declaration = "unknown", injected = "%s" })).code
        == "E_MESSAGE_ARGS", "undeclared role must be rejected")
    -- Missing declared role rejected.
    assert(err_of(R.render_en("clarify.unknown",
        { field = "subject" })).code
        == "E_MESSAGE_ARGS", "missing role must be rejected")
    -- Substitution is data-safe: an args value containing pattern markers is
    -- inserted literally, never re-expanded.
    local tricky = R.render_en("clarify.absent",
        { field = "%d{9}", declaration = "absent" })
    assert(tricky.ok)
    assert(tricky.value:find("%d{9}", 1, true), "literal insertion, no format expansion")
    -- Clarification machine records contain no rendered English but their
    -- prompt keys resolve through the registry.
    local ev = P.evaluate({ schema_version = 1, intents = { "describe" }, frame = {} })
    assert(ev.ok)
    local c = ev.value.clarifications[1]
    assert(c.en == nil and c.text == nil and c.rendered == nil, "no embedded rendering")
    local resolved = R.render_en(c.prompt_key, c.args)
    assert(resolved.ok, "record prompt_key must resolve with record args")
end)

test("unknown_message_key_returns_error", function()
    local e = err_of(R.render_en("not.a.registered.key", {}))
    assert(e.code == "E_MESSAGE_KEY", "expected E_MESSAGE_KEY, got " .. e.code)
    assert(e.path ~= nil and e.message_key == "error.E_MESSAGE_KEY", "envelope fields")
    assert(err_of(R.message_contract("nope")).code == "E_MESSAGE_KEY", "contract path")
    assert(err_of(R.message_contract(nil)).code == "E_MESSAGE_KEY", "nonstring key")
end)

test("errors_do_not_echo_supplied_text", function()
    local marker = "PRIVATE_TEXT_MARKER_ΔΩ7"
    local cases = {
        { schema_version = 2, intents = { "describe" }, frame = {} },          -- schema
        { schema_version = 1, intents = "describe", frame = {} },             -- intents
        { schema_version = 1, intents = { "nope" }, frame = {} },             -- intent value
        { schema_version = 1, intents = { "describe", "describe" }, frame = {} }, -- dup
        { schema_version = 1, intents = { "describe" }, frame = 5 },          -- decl type
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "supplied" } } },                        -- tag/text
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "supplied", text = 7 } } },              -- text type
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "maybe", text = marker } } },            -- bad tag
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "supplied", text = marker .. "\x00" } } }, -- control
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "supplied", text = marker .. "\xFF" } } }, -- utf8
        { schema_version = 1, intents = { "describe" },
          frame = { subject = { tag = "supplied", text = marker .. string.rep("q", 4000) } } }, -- limit
    }
    for _, inp in ipairs(cases) do
        -- embed marker also in a valid field where possible
        if type(inp.frame) == "table" and inp.frame.other_marker == nil then
            inp.frame.relationship = { tag = "supplied", text = marker }
        end
        local res = P.evaluate(inp)
        if not res.ok then
            local e = res.error
            local dump = sanitize(table.concat({ e.code, e.path, e.message_key }, "|"))
            for k, v in pairs(e.args) do
                dump = dump .. "|" .. sanitize(k) .. "=" .. sanitize(v)
            end
            assert(not dump:find(marker, 1, true),
                "error echoed supplied text for case " .. e.code)
        end
    end
    -- Sanity: at least the schema-version case errored.
    assert(err_of(P.evaluate(cases[1])).code == "E_SCHEMA_VERSION", "schema error")
end)

test("all_declaration_combinations_preserve_partition", function()
    -- Enumerate all six declaration possibilities across two selected core
    -- fields (subject, response); remaining core fields stay absent.
    -- This exercises partition/coverage invariants over these combinations;
    -- it is not exhaustive testing of the whole implementation.
    local states = {
        { kind = "absent" },
        { kind = "supplied", decl = sup("Synthetic filler text") },
        { kind = "unknown", decl = { tag = "unknown" } },
        { kind = "not_collected", decl = { tag = "not_collected" } },
        { kind = "withheld", decl = { tag = "withheld" } },
        { kind = "declared_not_applicable", decl = { tag = "declared_not_applicable" } },
    }
    local combos = 0
    for _, s1 in ipairs(states) do
        for _, s2 in ipairs(states) do
            combos = combos + 1
            local frame = {}
            if s1.kind ~= "absent" then frame.subject = s1.decl end
            if s2.kind ~= "absent" then frame.response = s2.decl end
            local r = P.evaluate({
                schema_version = 1, intents = { "describe" }, frame = frame,
            })
            assert(r.ok, "combination rejected: "
                .. (r.error and r.error.code or "?"))
            local v = r.value
            local p = v.declaration_partition
            local cov = v.coverage
            -- Disjoint and exhaustive over the 7 required fields.
            local owner, total = {}, 0
            for _, tag in ipairs({ "supplied", "unknown", "not_collected",
                                   "withheld", "declared_not_applicable", "absent" }) do
                for _, f in ipairs(p[tag]) do
                    assert(not owner[f], "double bucket " .. f)
                    owner[f] = tag
                    total = total + 1
                end
            end
            assert(total == 7, "partition size " .. total)
            for _, f in ipairs(CORE) do assert(owner[f], "unowned " .. f) end
            assert(owner.subject == s1.kind, "subject bucket")
            assert(owner.response == s2.kind, "response bucket")
            -- Coverage consistency.
            local supplied_n = (s1.kind == "supplied" and 1 or 0)
                             + (s2.kind == "supplied" and 1 or 0)
            local declared_n = ((s1.kind ~= "absent") and 1 or 0)
                             + ((s2.kind ~= "absent") and 1 or 0)
            assert(cov.required_count == 7, "denominator")
            assert(cov.supplied_count == supplied_n, "supplied count")
            assert(cov.declared_count == declared_n, "declared count")
            assert(near(cov.declaration_ratio, declared_n / 7), "decl ratio")
            assert(near(cov.supplied_ratio, supplied_n / 7), "supp ratio")
            -- Outcome policy.
            if supplied_n == 7 then
                assert(v.outcome == "structurally_accepted", "outcome accept")
            else
                assert(v.outcome == "accepted_with_clarifications", "outcome clarify")
            end
            -- One clarification per non-supplied required field.
            assert(#v.clarifications == 7 - supplied_n, "clarification count")
        end
    end
    assert(combos == 36, "expected 36 combinations, got " .. combos)
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

io.write("SUMMARY\tfailures\t" .. failures .. "\n")
os.exit(failures == 0 and 0 or 1)
