-- Private, local preference capability prototype.
-- No networking, filesystem access, telemetry, or device control.
--
-- Attribution:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit/workstream metadata only; not consent, verified identity,
-- execution evidence, diagnosis, ranking, eligibility, or authority.

local M = {}

local allowed_fields = {
    communication_method = true,
    presentation_preference = true,
    correction_preference = true,
    fallback_preference = true,
    privacy_boundary = true
}

local allowed_destinations = {
    private_person_view = true,
    local_accessibility_runtime = true
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function copy_preferences(input)
    if type(input) ~= "table" then
        error("preferences must be a table")
    end

    local output = {}
    for key, value in pairs(input) do
        if not allowed_fields[key] then
            error("unsupported preference field")
        end
        if type(value) ~= "string" or #value == 0 or #value > 4096 then
            error("preference values must be nonempty bounded strings")
        end
        output[key] = value
    end
    return output
end

function M.new(initial_preferences)
    local preferences = copy_preferences(initial_preferences)
    local capabilities = {}
    local accepted_reads = 0
    local denied_reads = 0

    local consumer = {}
    local owner = {}

    function owner.issue_local_read(destination, expires_at, now)
        if not allowed_destinations[destination] then
            error("destination is outside the local allowlist")
        end
        if not finite_number(now) or not finite_number(expires_at)
            or expires_at <= now then
            error("expiry must be finite and later than now")
        end

        local capability = {}
        capabilities[capability] = {
            destination = destination,
            expires_at = expires_at
        }
        return capability
    end

    function owner.revoke(capability)
        capabilities[capability] = nil
    end

    function owner.revoke_all()
        capabilities = {}
    end

    function owner.replace_preferences(updated)
        preferences = copy_preferences(updated)
        capabilities = {}
    end

    function consumer.read(capability, purpose, destination, now)
        local grant = capabilities[capability]

        if not grant
            or not finite_number(now)
            or now >= grant.expires_at
            or purpose ~= "accessibility_preferences"
            or destination ~= grant.destination
            or not allowed_destinations[destination] then

            denied_reads = denied_reads + 1
            return nil, "denied"
        end

        accepted_reads = accepted_reads + 1
        return copy_preferences(preferences), "permitted_local_read"
    end

    function owner.diagnostics()
        return {
            accepted_reads = accepted_reads,
            denied_reads = denied_reads,
            payloads_logged = false,
            public_export_api_available = false,
            automated_decision_api_available = false
        }
    end

    return consumer, owner
end

return M
