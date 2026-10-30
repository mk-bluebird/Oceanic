-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later. Standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- No identity, consent, authorization, or authority is established.
-- Handlers are caller-supplied code; their side effects are not controlled here.

local M = {VERSION = "1.0.0"}

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "structural_outcome_dispatch." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function exact_keys(value, allowed, maximum)
    local count = 0
    for key in next, value do
        count = count + 1
        if count > maximum or not allowed[key] then
            return false
        end
    end
    return true
end

local function valid_error(error)
    if not plain(error) then return false end
    if not exact_keys(error, {
        code = true, path = true,
        message_key = true, args = true
    }, 4) then
        return false
    end
    return type(error.code) == "string"
        and #error.code > 0
        and type(error.path) == "string"
        and type(error.message_key) == "string"
        and #error.message_key > 0
        and plain(error.args)
end

local function validate_envelope(result)
    if not plain(result) or type(result.ok) ~= "boolean" then
        return false
    end

    if result.ok then
        return exact_keys(result, {ok = true, value = true}, 2)
            and rawget(result, "value") ~= nil
    end

    return exact_keys(result, {ok = true, error = true}, 2)
        and valid_error(result.error)
end

function M.dispatch(result, handlers)
    if not validate_envelope(result) then
        return fail("E_RESULT_ENVELOPE", "result")
    end

    if not result.ok then
        return result
    end

    if not plain(result.value) then
        return fail("E_RESULT_VALUE", "result.value")
    end

    local outcome = rawget(result.value, "outcome")
    if outcome ~= "structurally_accepted"
        and outcome ~= "accepted_with_clarifications" then
        return fail("E_OUTCOME", "result.value.outcome")
    end

    if not plain(handlers) or not exact_keys(handlers, {
        structurally_accepted = true,
        accepted_with_clarifications = true
    }, 2) then
        return fail("E_HANDLERS", "handlers")
    end

    if type(handlers.structurally_accepted) ~= "function"
        or type(handlers.accepted_with_clarifications) ~= "function" then
        return fail("E_HANDLER_MISSING", "handlers")
    end

    local completed, returned = pcall(handlers[outcome], result.value)

    if not completed then
        return fail("E_HANDLER_EXCEPTION", "handler")
    end

    if not validate_envelope(returned) then
        return fail("E_HANDLER_RESULT", "handler.result")
    end

    return returned
end

return M
