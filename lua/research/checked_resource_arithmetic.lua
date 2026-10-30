-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4, integer range sufficient for 2^53 - 1, binary64-compatible float.
-- No filesystem, networking, installation, persistence, or telemetry.
--
-- Public API:
--   evaluate({
--       operation = "integer_add" | "integer_multiply" |
--                   "real_add" | "real_multiply" | "byte_units",
--       a = number,
--       b = number
--   })
--
-- byte_units requires b == 0.
-- ok is the sole success discriminator.
-- Failure value is false; error.present is true.
-- No debug data is exposed.
--
-- The limit is an interoperability policy, not Lua's native integer maximum.

local M = {}
local LIMIT_FLOAT = 2.0 ^ 53 - 1.0
local SCHEMA_VERSION = "1.0.0"
local MODULE_VERSION = "1.0.0"

local function response(ok, value, code, field, message)
    return {
        ok = ok,
        schema_version = SCHEMA_VERSION,
        module_version = MODULE_VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            field = field or "",
            message = message or ""
        }
    }
end

local function fail(code, field, message)
    return response(false, false, code, field, message)
end

local function supported_platform()
    return type(math.tointeger) == "function"
        and type(math.maxinteger) == "number"
        and math.maxinteger >= LIMIT_FLOAT
        and (2.0 ^ 53 + 1.0 == 2.0 ^ 53)
        and (2.0 ^ 52 + 1.0 ~= 2.0 ^ 52)
end

local function validate_number(x, field, integer_required)
    if type(x) ~= "number" then
        return nil, fail("E_TYPE", field, "Expected a number.")
    end
    if x ~= x or x == math.huge or x == -math.huge then
        return nil, fail("E_FINITE", field, "Expected a finite number.")
    end
    if x < 0 or x > LIMIT_FLOAT then
        return nil, fail("E_RANGE", field,
            "Expected a nonnegative number within the supported limit.")
    end
    if integer_required then
        local converted = math.tointeger(x)
        if converted == nil then
            return nil, fail("E_INTEGER", field,
                "Expected an integer-valued number.")
        end
        return converted, nil
    end
    return x + 0.0, nil
end

local function field_token(key)
    if type(key) ~= "string" then
        return "non_string_key"
    end
    local token = key:sub(1, 40):gsub("[^A-Za-z0-9_]", "_")
    return token ~= "" and token or "empty_key"
end

local function evaluate_impl(config)
    if not supported_platform() then
        return fail("E_PLATFORM", "",
            "Unsupported integer or floating-point configuration.")
    end

    if type(config) ~= "table" or getmetatable(config) ~= nil then
        return fail("E_CONFIG", "", "Expected a plain data table.")
    end

    local unknown = {}
    for key in next, config do
        if key ~= "operation" and key ~= "a" and key ~= "b" then
            unknown[#unknown + 1] = field_token(key)
        end
    end
    if #unknown > 0 then
        table.sort(unknown)
        return fail("E_CONFIG_FIELD", unknown[1],
            "Unexpected configuration field.")
    end

    local operation = rawget(config, "operation")
    local operations = {
        integer_add = true,
        integer_multiply = true,
        real_add = true,
        real_multiply = true,
        byte_units = true
    }
    if type(operation) ~= "string" or not operations[operation] then
        return fail("E_OPERATION", "operation", "Unsupported operation.")
    end

    local integer_required =
        operation == "integer_add"
        or operation == "integer_multiply"
        or operation == "byte_units"

    local a, failure = validate_number(rawget(config, "a"), "a",
        integer_required)
    if failure then
        return failure
    end
    local b
    b, failure = validate_number(rawget(config, "b"), "b",
        integer_required)
    if failure then
        return failure
    end

    local limit = math.tointeger(LIMIT_FLOAT)
    local value

    if operation == "integer_add" then
        if a > limit - b then
            return fail("E_ADD_RANGE", "",
                "Addition would exceed the supported integer limit.")
        end
        value = a + b

    elseif operation == "integer_multiply" then
        if b ~= 0 and a > limit // b then
            return fail("E_MULTIPLY_RANGE", "",
                "Multiplication would exceed the supported integer limit.")
        end
        value = a * b

    elseif operation == "real_add" then
        if a > LIMIT_FLOAT - b then
            return fail("E_ADD_RANGE", "",
                "Addition would exceed the supported real-value limit.")
        end
        value = a + b

    elseif operation == "real_multiply" then
        if b > 1.0 and a > LIMIT_FLOAT / b then
            return fail("E_MULTIPLY_RANGE", "",
                "Multiplication would exceed the supported real-value limit.")
        end
        value = a * b
        if a > 0.0 and b > 0.0 and value == 0.0 then
            return fail("E_UNDERFLOW", "",
                "A positive product underflowed to zero.")
        end

    else
        if b ~= 0 then
            return fail("E_UNUSED_OPERAND", "b",
                "byte_units requires b equal to zero.")
        end
        return response(true, {
            bytes = a,
            GB_decimal = a / 1000000000.0,
            GiB_binary = a / 1073741824.0,
            GiB_is_whole = a % 1073741824 == 0,
            decimal_display = "Presentation rounding is not specified."
        })
    end

    if value ~= value or value == math.huge or value > LIMIT_FLOAT then
        return fail("E_ARITHMETIC_RANGE", "",
            "Arithmetic result failed the postcondition.")
    end

    return response(true, {
        result = value,
        operation = operation,
        integer_exactness_contract = integer_required,
        real_arithmetic_contract =
            "Floating-point rounding applies to real operations.",
        external_actions = "none"
    })
end

function M.evaluate(config)
    local ok, result = pcall(evaluate_impl, config)
    if not ok then
        return fail("E_INTERNAL", "",
            "Unexpected internal failure; inspect locally.")
    end
    return result
end

function M.self_test()
    if not supported_platform() then
        return fail("E_PLATFORM", "",
            "Self-tests require the supported numeric configuration.")
    end

    local function call(operation, a, b)
        return M.evaluate({operation = operation, a = a, b = b})
    end

    local function require_test(condition, name)
        if not condition then
            error({test_name = name}, 0)
        end
    end

    local ok, problem = pcall(function()
        local max = math.tointeger(LIMIT_FLOAT)

        local add = call("integer_add", max - 1, 1)
        require_test(add.ok and add.value.result == max, "maximum_sum")

        local overflow = call("integer_multiply", max, max)
        require_test(not overflow.ok
            and overflow.error.code == "E_MULTIPLY_RANGE",
            "pre_multiplication_rejection")

        local add_overflow = call("integer_add", max, 1)
        require_test(not add_overflow.ok
            and add_overflow.error.code == "E_ADD_RANGE",
            "pre_addition_rejection")

        local zero = call("integer_multiply", max, 0)
        require_test(zero.ok and zero.value.result == 0, "zero_product")

        local fractional = call("integer_add", 2.5, 1)
        require_test(not fractional.ok
            and fractional.error.code == "E_INTEGER",
            "fractional_integer_rejection")

        local invalid_type = call("integer_add", "two", 1)
        require_test(not invalid_type.ok
            and invalid_type.error.code == "E_TYPE", "type_error")

        local nonfinite = call("real_add", math.huge, 1)
        require_test(not nonfinite.ok
            and nonfinite.error.code == "E_FINITE", "finite_error")

        local metatable = M.evaluate(setmetatable({
            operation = "integer_add", a = 1, b = 2
        }, {}))
        require_test(not metatable.ok
            and metatable.error.code == "E_CONFIG", "metatable_rejection")

        local units = call("byte_units", 536870912, 0)
        require_test(units.ok and units.value.GiB_binary == 0.5
            and units.value.GiB_is_whole == false, "fractional_GiB")

        local source = {operation = "integer_add", a = 2, b = 3}
        local first = M.evaluate(source)
        local second = M.evaluate(source)
        require_test(first.ok and second.ok
            and first.value.result == second.value.result
            and source.a == 2 and source.b == 3, "determinism_nonmutation")
    end)

    if not ok then
        local name = type(problem) == "table"
            and rawget(problem, "test_name") or nil
        return fail("E_SELF_TEST", field_token(name),
            "Synthetic arithmetic self-test failed.")
    end

    return response(true, {
        status = "synthetic_self_tests_passed",
        field_validation = "not_performed",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        external_actions = "none"
    })
end

return M
