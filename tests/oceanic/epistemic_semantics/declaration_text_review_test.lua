-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local loaded, R = pcall(require,
    "lua.oceanic.epistemic_semantics.declaration_text_review")

if not loaded then
    io.stderr:write("ENV_MODULE_LOAD_FAILED\n")
    os.exit(2)
end

local total, failures = 0, 0

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if rawget(a, key) == nil then return false end
    end
    return true
end

local function contains(list, expected)
    for _, item in ipairs(list) do
        if item == expected then return true end
    end
    return false
end

local function inspect(text)
    local result = R.inspect(text)
    assert(result.ok)
    return result.value
end

local function test(name, contract, fn)
    total = total + 1
    local passed = pcall(function()
        local described = R.describe()
        assert(described.ok)
        assert(described.value.contract_version == contract)
        fn()
    end)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

test("empty_text_has_explicit_decision", "1.0.0", function()
    assert(inspect("").policy_decision == "reject_empty")
end)

test("ascii_whitespace_is_rejected", "1.0.0", function()
    assert(inspect(" \t\r\n").policy_decision
        == "reject_ascii_whitespace_only")
end)

test("nonbreaking_space_is_retained_with_review", "1.0.0", function()
    local value = inspect(utf8.char(0x00A0))
    assert(value.policy_decision == "accept")
    assert(contains(value.review_codes, "R_UNICODE_WHITESPACE_ONLY"))
end)

test("mixed_whitespace_is_reviewed", "1.0.0", function()
    local value = inspect(" \t" .. utf8.char(0x3000))
    assert(value.whitespace_only)
    assert(value.policy_decision == "accept")
end)

test("c1_controls_have_explicit_policy", "1.0.0", function()
    local value = inspect(utf8.char(0x0080))
    assert(value.policy_decision == "accept")
    assert(contains(value.review_codes, "R_C1_CONTROL_PRESENT"))
end)

test("next_line_has_both_reviews", "1.0.0", function()
    local value = inspect(utf8.char(0x0085))
    assert(contains(value.review_codes, "R_C1_CONTROL_PRESENT"))
    assert(contains(value.review_codes, "R_UNICODE_WHITESPACE_ONLY"))
end)

test("zero_width_space_is_not_assumed_whitespace", "1.0.0", function()
    local value = inspect(utf8.char(0x200B))
    assert(not value.whitespace_only)
end)

test("placeholder_registry_is_queryable", "1.0.0", function()
    local yes = R.contains_placeholder("TODO")
    local no = R.contains_placeholder(" TODO ")
    assert(yes.ok and yes.value.registered)
    assert(no.ok and not no.value.registered)
end)

test("registry_results_are_detached", "1.0.0", function()
    local first = R.list_placeholders()
    assert(first.ok)
    first.value.items[1] = "changed"
    local second = R.list_placeholders()
    assert(second.ok and second.value.items[1] == "TODO")
end)

test("classification_results_do_not_alias", "1.0.0", function()
    local first, second = inspect("TODO"), inspect("TODO")
    assert(first ~= second and same(first, second))
    assert(first.review_codes ~= second.review_codes)
    first.review_codes[1] = "changed"
    assert(second.review_codes[1] == "R_REGISTERED_PLACEHOLDER_TEXT")
end)

test("multibyte_boundary_uses_bytes", "1.0.0", function()
    local unit = utf8.char(0x00E9)
    local accepted = R.inspect(unit:rep(2000))
    local rejected = R.inspect(unit:rep(2000) .. "x")
    assert(accepted.ok and accepted.value.byte_count == 4000)
    assert(not rejected.ok and rejected.error.code == "E_TEXT_LIMIT")
end)

test("invalid_utf8_sequences_are_rejected", "1.0.0", function()
    local samples = {
        "\192\175",
        "\237\160\128",
        "\244\144\128\128",
        "\226\130"
    }
    for _, text in ipairs(samples) do
        local result = R.inspect(text)
        assert(not result.ok and result.error.code == "E_TEXT_UTF8")
    end
end)

test("ascii_delete_is_rejected", "1.0.0", function()
    assert(inspect("x\127").policy_decision == "reject_ascii_control")
end)

test("text_is_not_returned", "1.0.0", function()
    local marker = "SYNTHETIC_PRIVATE_MARKER_6821"
    local result = R.inspect(marker)
    assert(result.ok)

    local function scan(value)
        if type(value) == "string" then
            assert(not value:find(marker, 1, true))
        elseif type(value) == "table" then
            for key, item in pairs(value) do
                scan(key)
                scan(item)
            end
        end
    end

    scan(result)
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
