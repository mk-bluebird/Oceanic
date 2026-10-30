-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.coral_coverage")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function close(actual, expected)
    assert(math.abs(actual - expected) < 1e-12)
end

local function fixture(counts)
    return {
        schema_version = 1,
        scope = "Synthetic estimator regression fixture",
        sampling_model = "multinomial_abundance",
        sampling_basis = "Declared synthetic abundance sampling",
        class_capacity = 100,
        counts = counts,
        extensions = {source_kind = "synthetic"}
    }
end

local function estimate(counts)
    local r = m.evaluate(fixture(counts))
    assert(r.ok, r.error and r.error.code or "unknown failure")
    return r.value
end

local function rejects(change, code, path)
    local x = fixture({1, 1, 2})
    change(x)
    local r = m.evaluate(x)
    assert(not r.ok and r.value == false)
    assert(r.error.code == code)
    assert(r.error.field_path == path)
    assert(type(r.error.args) == "table")
end

test("positive-doubleton branch", function()
    local r = estimate({1, 1, 2})
    close(r.sample_coverage, 0.625)
    close(r.richness_lower_bound_estimate, 4.5)
    assert(r.coverage_branch == "positive_doubletons")
end)

test("zero-doubleton branch", function()
    local r = estimate({1, 1, 3})
    close(r.sample_coverage, 11 / 15)
    close(r.richness_lower_bound_estimate, 3.8)
    assert(r.coverage_branch == "zero_doubletons")
end)

test("zero-doubleton singleton boundary", function()
    local r = estimate({1, 3})
    close(r.sample_coverage, 1)
    close(r.richness_lower_bound_estimate, 2)
    assert(not r.interpretation_limits.biological_recovery_established)
end)

test("no singletons and all singletons", function()
    close(estimate({2, 3}).sample_coverage, 1)
    close(estimate({1, 1}).sample_coverage, 0.5)
end)

test("sampling model gate", function()
    for _, model in ipairs({
        "curated_inventory", "clustered_unmodeled",
        "size_biased_unmodeled", "unknown"
    }) do
        rejects(function(x) x.sampling_model = model end,
            "E_SAMPLING_INCOMPATIBLE", "input.sampling_model")
    end
end)

test("missing and schema diagnostics", function()
    rejects(function(x) x.scope = nil end, "E_MISSING", "input.scope")
    rejects(function(x) x.schema_version = 2 end,
        "E_INTEGER", "input.schema_version")
    rejects(function(x) x.extra = true end, "E_UNKNOWN_FIELD", "input")
end)

test("sequence and capacity diagnostics", function()
    rejects(function(x) x.counts = {} end, "E_EMPTY", "input.counts")
    rejects(function(x) x.counts[2] = nil end,
        "E_SEQUENCE_GAP", "input.counts")
    rejects(function(x) x.counts[1.5] = 1 end,
        "E_INDEX_INTEGER", "input.counts")
    rejects(function(x) x.counts.extra = 1 end,
        "E_INDEX_TYPE", "input.counts")
    rejects(function(x) x.counts[0] = 1 end,
        "E_INDEX_POSITIVE", "input.counts")
    rejects(function(x) x.class_capacity = 1 end,
        "E_CAPACITY", "input.counts")
    rejects(function(x) x.class_capacity = 1.5 end,
        "E_INTEGER", "input.class_capacity")
end)

test("count and sample-size diagnostics", function()
    rejects(function(x) x.counts[1] = 0 / 0 end,
        "E_COUNT", "input.counts[1]")
    rejects(function(x) x.counts[1] = math.huge end,
        "E_COUNT", "input.counts[1]")
    rejects(function(x) x.counts = {1} end,
        "E_INSUFFICIENT_SAMPLE", "input.counts")
    rejects(function(x) x.counts = {1000000, 1} end,
        "E_TOTAL_LIMIT", "input.counts")
end)

test("text controls and bounded metadata", function()
    rejects(function(x) x.scope = "line\nbreak" end,
        "E_ASCII_TEXT", "input.scope")
    rejects(function(x) x.scope = string.rep("a", 241) end,
        "E_ASCII_TEXT", "input.scope")
    rejects(function(x) x.extensions.note = "\t" end,
        "E_EXTENSION_VALUE", "input.extensions")
end)

test("permutation invariance and copied inputs", function()
    local x = fixture({1, 1, 2, 3})
    local result = m.evaluate(x)
    assert(result.ok)
    local permuted = estimate({3, 2, 1, 1})
    close(result.value.sample_coverage, permuted.sample_coverage)
    close(result.value.richness_lower_bound_estimate,
        permuted.richness_lower_bound_estimate)
    result.value.counts[1] = 99
    result.value.extensions.source_kind = "changed"
    assert(x.counts[1] == 1)
    assert(x.extensions.source_kind == "synthetic")
end)

test("generated coverage bounds and richness floor", function()
    for a = 1, 6 do
        for b = 1, 6 do
            local r = estimate({a, b})
            assert(r.sample_coverage >= 0 and r.sample_coverage <= 1)
            assert(r.richness_lower_bound_estimate >= 2)
        end
    end
end)

os.exit(failures == 0 and 0 or 1)
