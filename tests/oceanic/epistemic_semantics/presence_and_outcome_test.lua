-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Synthetic fixtures only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local P = require("lua.oceanic.epistemic_semantics.declaration_presence")
local D = require("lua.oceanic.epistemic_semantics.structural_outcome_dispatch")

local total, failures = 0, 0

local function test(name, fn)
    total = total + 1
    local passed = pcall(fn)
    io.write(passed and "PASS\t" or "FAIL\t", name, "\n")
    if not passed then failures = failures + 1 end
end

local function supplied(text)
    return P.classify({
        present = true,
        value = {tag = "supplied", text = text}
    })
end

local function success(outcome)
    return {ok = true, value = {outcome = outcome}}
end

local function handlers()
    return {
        structurally_accepted = function()
            return {ok = true, value = "accepted_branch"}
        end,
        accepted_with_clarifications = function()
            return {ok = true, value = "clarification_branch"}
        end
    }
end

test("absent_is_not_null", function()
    local absent = P.classify({present = false})
    local null = P.classify({present = true, value = P.NULL})
    assert(absent.ok and not absent.value.declaration_present)
    assert(null.ok and null.value.declaration_present)
    assert(not null.value.content_supplied)
end)

test("present_without_value_is_error", function()
    local result = P.classify({present = true})
    assert(not result.ok)
    assert(result.error.code == "E_PRESENT_WITHOUT_VALUE")
end)

test("false_presence_cannot_carry_null", function()
    local result = P.classify({present = false, value = P.NULL})
    assert(not result.ok)
end)

test("empty_table_is_not_null", function()
    local result = P.classify({present = true, value = {}})
    assert(not result.ok)
    assert(result.error.code == "E_DECLARATION_TAG")
end)

test("primitive_string_is_not_tagged_declaration", function()
    local result = P.classify({present = true, value = "unknown"})
    assert(not result.ok)
end)

test("empty_and_ascii_whitespace_are_rejected", function()
    for _, text in ipairs({"", " ", "\t\r\n"}) do
        local result = supplied(text)
        assert(not result.ok and result.error.code == "E_TEXT_EMPTY")
    end
end)

test("literal_unknown_and_zero_remain_supplied", function()
    for _, text in ipairs({"unknown", "0"}) do
        local result = supplied(text)
        assert(result.ok and result.value.content_supplied)
        assert(#result.value.review_codes == 0)
    end
end)

test("placeholder_is_supplied_with_review", function()
    local result = supplied("TODO")
    assert(result.ok and result.value.content_supplied)
    assert(result.value.review_codes[1]
        == "R_REGISTERED_PLACEHOLDER_TEXT")
end)

test("placeholder_matching_is_exact", function()
    local result = supplied(" TODO ")
    assert(result.ok and #result.value.review_codes == 0)
end)

test("unresolved_tag_content_matrix", function()
    local tags = {
        "unknown", "not_collected", "withheld",
        "declared_not_applicable"
    }
    local variants = {false, "", "synthetic"}
    local checked = 0
    for _, tag in ipairs(tags) do
        local valid = P.classify({
            present = true, value = {tag = tag}
        })
        assert(valid.ok and valid.value.declaration_present)
        assert(not valid.value.content_supplied)

        for _, content in ipairs(variants) do
            local invalid = P.classify({
                present = true,
                value = {tag = tag, text = content}
            })
            assert(not invalid.ok)
            assert(invalid.error.code == "E_UNEXPECTED_CONTENT")
            checked = checked + 1
        end
    end
    assert(checked == 12)
end)

test("table_adapter_preserves_explicit_null", function()
    local result = P.from_table({field = P.NULL}, "field")
    assert(result.ok)
    assert(result.value.classification == "explicit_null")
end)

test("accepted_outcome_uses_accepted_handler", function()
    local result = D.dispatch(
        success("structurally_accepted"), handlers())
    assert(result.ok and result.value == "accepted_branch")
end)

test("clarification_outcome_uses_clarification_handler", function()
    local result = D.dispatch(
        success("accepted_with_clarifications"), handlers())
    assert(result.ok and result.value == "clarification_branch")
end)

test("both_handlers_are_required", function()
    local result = D.dispatch(success("structurally_accepted"), {
        structurally_accepted = function()
            return {ok = true, value = true}
        end
    })
    assert(not result.ok and result.error.code == "E_HANDLER_MISSING")
end)

test("unknown_outcome_is_rejected", function()
    local result = D.dispatch(success("scientifically_valid"), handlers())
    assert(not result.ok and result.error.code == "E_OUTCOME")
end)

test("success_with_error_member_is_rejected", function()
    local result = success("structurally_accepted")
    result.error = {}
    result = D.dispatch(result, handlers())
    assert(not result.ok and result.error.code == "E_RESULT_ENVELOPE")
end)

test("structural_error_is_propagated_unchanged", function()
    local original = {
        ok = false,
        error = {
            code = "E_SYNTHETIC",
            path = "input",
            message_key = "synthetic.error",
            args = {}
        }
    }
    assert(D.dispatch(original, {}) == original)
end)

test("handler_exception_is_sanitized", function()
    local h = handlers()
    h.structurally_accepted = function()
        error("synthetic private detail")
    end
    local result = D.dispatch(success("structurally_accepted"), h)
    assert(not result.ok)
    assert(result.error.code == "E_HANDLER_EXCEPTION")
    assert(next(result.error.args) == nil)
end)

test("handler_must_return_result_envelope", function()
    local h = handlers()
    h.structurally_accepted = function() return true end
    local result = D.dispatch(success("structurally_accepted"), h)
    assert(not result.ok and result.error.code == "E_HANDLER_RESULT")
end)

io.write("SUMMARY\ttotal\t", total, "\tfailures\t", failures, "\n")
os.exit(failures == 0 and 0 or 1)
