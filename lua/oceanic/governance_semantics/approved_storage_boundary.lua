-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Dependency-injection boundary only.
-- Injected callbacks may have side effects; they are not sandboxed.
-- No backend is supplied, discovered, or enabled by default.

local M = {VERSION = "1.0.0"}
local MAX_PAYLOAD_BYTES = 65536
local MAX_RETENTION_SECONDS = 31536000

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code)
    return {
        ok = false,
        error = {
            code = code,
            path = "storage",
            message_key = "approved_storage_boundary." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function exact(value, keys)
    if not plain(value) then return false end
    local allowed = {}
    for _, key in ipairs(keys) do
        allowed[key] = true
        if rawget(value, key) == nil then return false end
    end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 160
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
end

function M.create(policy, backend)
    if policy == nil and backend == nil then
        return ok({
            enabled = false,
            write = function() return fail("E_STORAGE_DISABLED") end,
            delete = function() return fail("E_STORAGE_DISABLED") end
        })
    end

    if not exact(policy, {
        "purpose", "retention_policy", "retention_seconds",
        "approval_declared"
    }) or not label(policy.purpose)
        or not label(policy.retention_policy)
        or type(policy.retention_seconds) ~= "number"
        or policy.retention_seconds % 1 ~= 0
        or policy.retention_seconds < 1
        or policy.retention_seconds > MAX_RETENTION_SECONDS
        or policy.approval_declared ~= true then
        return fail("E_STORAGE_POLICY")
    end

    if not exact(backend, {"write", "delete", "access_check"})
        or type(backend.write) ~= "function"
        or type(backend.delete) ~= "function"
        or type(backend.access_check) ~= "function" then
        return fail("E_STORAGE_BACKEND")
    end

    -- Capture scalar policy values and callback references.
    local purpose = policy.purpose
    local retention_policy = policy.retention_policy
    local retention_seconds = policy.retention_seconds
    local backend_write = backend.write
    local backend_delete = backend.delete
    local access_check = backend.access_check

    local function allowed(operation)
        local completed, result = pcall(access_check, operation, purpose)
        return completed and result == true
    end

    local adapter = {enabled = true}

    function adapter.write(payload, approval)
        if not exact(approval, {"purpose", "write_approved"})
            or approval.purpose ~= purpose
            or approval.write_approved ~= true then
            return fail("E_WRITE_APPROVAL")
        end

        if type(payload) ~= "string" or #payload > MAX_PAYLOAD_BYTES then
            return fail("E_PAYLOAD")
        end

        if not allowed("write") then return fail("E_ACCESS_NOT_CONFIRMED") end

        local completed, accepted = pcall(backend_write, payload, {
            purpose = purpose,
            retention_policy = retention_policy,
            retention_seconds = retention_seconds
        })

        if not completed or accepted ~= true then
            return fail("E_BACKEND_WRITE")
        end

        return ok({
            backend_acknowledged_write = true,
            durable_storage_verified = false,
            retention_enforcement_verified = false,
            authority_verified = false
        })
    end

    function adapter.delete(approval)
        if not exact(approval, {"purpose", "delete_approved"})
            or approval.purpose ~= purpose
            or approval.delete_approved ~= true then
            return fail("E_DELETE_APPROVAL")
        end

        if not allowed("delete") then return fail("E_ACCESS_NOT_CONFIRMED") end

        -- Deletion scope is the configured purpose, not an arbitrary record.
        local completed, acknowledged = pcall(backend_delete, purpose)
        if not completed or acknowledged ~= true then
            return fail("E_BACKEND_DELETE")
        end

        return ok({
            backend_acknowledged_delete = true,
            deletion_scope = "configured_purpose",
            all_copies_deleted_verified = false,
            authority_verified = false
        })
    end

    return ok(adapter)
end

return M
