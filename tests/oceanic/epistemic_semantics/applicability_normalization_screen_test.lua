-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, M = pcall(require,
    "lua.oceanic.epistemic_semantics.applicability_normalization_screen")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local total, failures = 0, 0

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if rawget(a, key) == nil then return false end
    end
    return true
end

local function fixture()
    return {
        schema_version = 1,
        intents = {"compare", "describe"},
        fields = {
            {
                name = "spatial_scope",
                declaration = {tag = "declared_not_applicable"},
                review = {
                    schema_version = 1,
                    decision = "applicable",
                    policy_version = "synthetic-policy-1",
                    authority_reference = "Synthetic review reference",
                    question_scope = "Synthetic comparison"
                }
            },
            {
                name = "subject",
                declaration = {
                    tag = "supplied",
                    text = "  Synthetic lake  "
                }
            }
        }
    }
end

test("normalization_is_closed_and_idempotent", function()
    local a = M.normalize(fixture())
    assert(a.ok)
    local b = M.normalize(a.value)
    assert(b.ok and equal(a.value, b.value))
end)

test("normalization_preserves_text", function()
    local result = M.normalize(fixture())
    assert(result.ok)
    assert(result.value.fields[1].declaration.text
        == "  Synthetic lake  ")
end)

test("noncanonical_screen_input_is_rejected", function()
    local result = M.screen(fixture())
    assert(not result.ok)
    assert(result.error.code == "E_NOT_NORMALIZED")
end)

test("registered_denominator_does_not_shrink", function()
    local result = M.evaluate(fixture())
    assert(result.ok)
    assert(result.value.required_count == 3)
    assert(result.value.declared_count == 2)
    assert(result.value.supplied_count == 1)
end)

test("declaration_review_divergence_is_visible", function()
    local result = M.review_projection(fixture())
    assert(result.ok)
    assert(result.value.divergences[1].field == "spatial_scope")
    assert(not result.value.authority_verified)
end)

test("recorded_exclusion_does_not_authorize_denominator_change", function()
    local input = fixture()
    input.fields[1].review.decision = "not_applicable"
    local result = M.review_projection(input)
    assert(result.ok)
    assert(result.value.recorded_excluded_fields[1] == "spatial_scope")
    assert(not result.value.denominator_change_authorized)
    assert(M.evaluate(input).value.required_count == 3)
end)

test("normalization_output_is_detached", function()
    local input = fixture()
    local result = M.normalize(input)
    assert(result.ok)
    result.value.fields[1].declaration.text = "Changed"
    assert(input.fields[2].declaration.text == "  Synthetic lake  ")
end)

test("unknown_key_is_not_echoed", function()
    local marker = "SYNTHETIC_PRIVATE_KEY_8246"
    local input = fixture()
    input[marker] = true
    local result = M.evaluate(input)
    assert(not result.ok)
    assert(result.error.code == "E_UNKNOWN_FIELD")

    local function inspect(value)
        if type(value) == "string" then
            assert(not value:find(marker, 1, true))
        elseif type(value) == "table" then
            for key, item in pairs(value) do
                inspect(key)
                inspect(item)
            end
        end
    end

    inspect(result)
    assert(next(result.error.args) == nil)
end)

test("metatables_are_rejected", function()
    local result = M.evaluate(setmetatable({}, {}))
    assert(not result.ok and result.error.code == "E_RECORD")
end)

test("empty_draft_is_accepted_with_clarifications", function()
    local result = M.evaluate({
        schema_version = 1,
        intents = {"describe"},
        fields = {}
    })
    assert(result.ok)
    assert(result.value.outcome == "accepted_with_clarifications")
    assert(#result.value.clarifications == 3)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
