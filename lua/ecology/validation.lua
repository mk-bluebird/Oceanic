-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; validation 1.0.0.
-- Retain credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, identity verification, or authority.
-- Public contract: {ok=true,value=...} or {ok=false,error=...}.
-- Machine metadata profile: bounded printable ASCII.

local V = {VERSION = "1.0.0"}
local LIMITS = {assumption_checks = 100}

function V.ok(value)
    return {ok = true, value = value}
end

function V.fail(code, path, args)
    return {ok = false, error = {
        code = code, field_path = path,
        message_key = "ecology." .. code,
        args = args or {}, category = "validation"
    }}
end

function V.finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function V.describe(value)
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    return "<" .. type(value) .. ">"
end

function V.limit(name)
    return LIMITS[name]
end

function V.text(value, maximum, path)
    if type(value) ~= "string" then
        return V.fail("E_TEXT_TYPE", path, {actual_type = type(value)})
    end
    if #value < 1 or #value > maximum or not value:match("%S") then
        return V.fail("E_TEXT_LENGTH", path, {
            minimum_bytes = 1, maximum_bytes = maximum, actual_bytes = #value
        })
    end
    for i = 1, #value do
        local byte = value:byte(i)
        if byte < 32 or byte > 126 then
            return V.fail("E_TEXT_PROFILE", path, {
                profile = "printable_ascii", byte_position = i
            })
        end
    end
    return V.ok(value)
end

local function field_list(fields)
    if type(fields) ~= "table" or getmetatable(fields) ~= nil then return false end
    local count, highest, seen = 0, 0, {}
    for key, value in pairs(fields) do
        if not V.finite(key) or key % 1 ~= 0 or key < 1
            or key > 1000 or type(value) ~= "string" or seen[value] then
            return false
        end
        seen[value] = true
        count, highest = count + 1, math.max(highest, key)
    end
    return count == highest
end

function V.record(value, required, optional, path)
    if not field_list(required) or not field_list(optional) then
        return V.fail("E_VALIDATOR_SCHEMA", path)
    end
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return V.fail("E_RECORD", path, {expected_type = "plain_table"})
    end
    local allowed = {}
    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return V.fail("E_MISSING", path .. "." .. key, {field = key})
        end
    end
    for _, key in ipairs(optional) do allowed[key] = true end

    local unknown, nonstring = {}, false
    for key in pairs(value) do
        if type(key) ~= "string" then nonstring = true
        elseif not allowed[key] then unknown[#unknown + 1] = key end
    end
    if nonstring then return V.fail("E_FIELD_KEY_TYPE", path) end
    table.sort(unknown)
    if #unknown > 0 then
        local key = unknown[1]
        if key:match("^[A-Za-z][A-Za-z0-9_]*$") and #key <= 80 then
            return V.fail("E_UNKNOWN_FIELD", path .. "[" .. key .. "]",
                {field = key})
        end
        return V.fail("E_UNKNOWN_FIELD", path, {key_bytes = #key})
    end
    return V.ok(true)
end

function V.enum(value, allowed, prefix, path)
    if type(value) ~= "string" then
        return V.fail(prefix .. "_TYPE", path, {actual_type = type(value)})
    end
    for _, option in ipairs(allowed) do
        if value == option then return V.ok(value) end
    end
    return V.fail(prefix .. "_VALUE", path, {
        actual_type = "string", actual_bytes = #value
    })
end

function V.sequence(value, maximum, path)
    if not V.finite(maximum) or maximum % 1 ~= 0 or maximum < 1 then
        return V.fail("E_VALIDATOR_LIMIT", path)
    end
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return V.fail("E_SEQUENCE", path)
    end
    local count, highest = 0, 0
    local wrong_type, fractional, nonpositive, overflow
    for key in pairs(value) do
        if type(key) ~= "number" then wrong_type = true
        elseif not V.finite(key) or key % 1 ~= 0 then fractional = true
        elseif key < 1 then
            nonpositive = math.min(nonpositive or key, key)
        elseif key > maximum then
            overflow = math.min(overflow or key, key)
        else
            count, highest = count + 1, math.max(highest, key)
        end
    end
    if wrong_type then return V.fail("E_INDEX_TYPE", path) end
    if fractional then return V.fail("E_INDEX_INTEGER", path) end
    if nonpositive then
        return V.fail("E_INDEX_POSITIVE", path, {actual = nonpositive, minimum = 1})
    end
    if overflow then
        return V.fail("E_CAPACITY", path, {actual = overflow, maximum = maximum})
    end
    if count == 0 then return V.fail("E_EMPTY", path) end
    if count ~= highest then
        local gap = 1
        while rawget(value, gap) ~= nil do gap = gap + 1 end
        return V.fail("E_SEQUENCE_GAP", path, {
            gap_position = gap, highest_index = highest
        })
    end
    return V.ok(count)
end

return V
