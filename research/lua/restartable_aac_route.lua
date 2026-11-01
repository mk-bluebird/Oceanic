-- Lua 5.4; version 0.3.0. Serialized lifecycle model, not an output adapter.
-- Preserve this attribution block in derivatives:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit/workstream metadata only; not consent, biological binding, identity verification,
-- authority, execution evidence, or a public status designation.
-- No persistent-memory or cryptographic-attestation claim.

local M = {
    VERSION = "0.3.0"
}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function positive(value, name)
    if not finite(value) or value <= 0 then
        error(name .. " must be positive and finite", 3)
    end
    return value
end

local function integer_limit(value, name)
    if math.type(value) ~= "integer" or value < 1 then
        error(name .. " must be a positive Lua integer", 3)
    end
    return value
end

local function option(value, fallback)
    if value == nil then
        return fallback
    end
    return value
end

function M.new(configuration_or_options)
    local legacy = type(configuration_or_options) == "string"
    local options

    if legacy then
        options = {
            expected_configuration = configuration_or_options
        }
    elseif type(configuration_or_options) == "table" then
        options = configuration_or_options
    else
        error("expected a configuration string or options table", 2)
    end

    local max_text_bytes = integer_limit(
        option(options.max_text_bytes, 4096), "max_text_bytes"
    )

    local generation_limit = integer_limit(
        option(options.generation_limit, math.maxinteger),
        "generation_limit"
    )

    local function valid_text(value)
        return type(value) == "string"
            and #value > 0
            and #value <= max_text_bytes
    end

    local expected_configuration = options.expected_configuration
    if not valid_text(expected_configuration) then
        error("expected_configuration must be a nonempty bounded label", 2)
    end

    local clock = options.clock
    local readiness_lifetime
    local candidate_lifetime
    local allowed_destinations = {}

    if not legacy then
        if type(clock) ~= "function" then
            error("options.clock must be a host-controlled clock function", 2)
        end

        readiness_lifetime = positive(
            options.readiness_lifetime, "readiness_lifetime"
        )
        candidate_lifetime = positive(
            options.candidate_lifetime, "candidate_lifetime"
        )

        local supplied = options.allowed_destinations
        if type(supplied) ~= "table"
            or getmetatable(supplied) ~= nil then
            error("allowed_destinations must be a plain dense sequence", 2)
        end

        local count = 0
        local highest = 0

        for key, value in pairs(supplied) do
            if math.type(key) ~= "integer" or key < 1
                or not valid_text(value)
                or allowed_destinations[value] then
                error("destination entries must be distinct bounded labels", 2)
            end

            allowed_destinations[value] = true
            count = count + 1
            highest = math.max(highest, key)
        end

        if count == 0 or count ~= highest then
            error("allowed_destinations must be a nonempty dense sequence", 2)
        end
    end

    local phase = "unavailable"
    local paused = true
    local generation = 0
    local validated_until = nil
    local selected_destination = nil
    local pending = nil
    local last_time = nil
    local permission_snapshot = nil
    local last_fault = nil
    local exhausted = false
    local clock_active = false
    local clock_reentry_detected = false
    local api = {}

    local function fail_closed(reason)
        pending = nil
        selected_destination = nil
        validated_until = nil
        permission_snapshot = nil
        phase = exhausted and "exhausted" or "needs_revalidation"
        last_fault = reason
    end

    local function assert_operable()
        if exhausted then
            error("generation limit exhausted; construct a new route instance", 3)
        end
        if clock_active then
            clock_reentry_detected = true
            error("route calls from the clock callback are prohibited", 3)
        end
    end

    local function read_time(explicit_time, require_explicit)
        assert_operable()

        local value

        if legacy then
            if require_explicit and explicit_time == nil then
                error("compatibility mode requires an explicit timestamp", 3)
            end
            value = explicit_time
            if value == nil then
                value = last_time or 0
            end
        else
            if explicit_time ~= nil then
                error("explicit timestamps are unavailable in host-clock mode", 3)
            end

            clock_active = true
            clock_reentry_detected = false
            local ok, result = pcall(clock)
            clock_active = false

            if not ok or clock_reentry_detected then
                fail_closed("clock_callback_failed_or_reentered")
                error("clock callback failed or attempted route reentry", 3)
            end

            value = result
        end

        if not finite(value) then
            fail_closed("invalid_clock_value")
            error("clock value must be finite and numeric", 3)
        end

        if last_time ~= nil and value < last_time then
            fail_closed("clock_moved_backwards")
            error("clock moved backwards", 3)
        end

        last_time = value
        return value
    end

    local function bump()
        pending = nil

        if generation >= generation_limit then
            exhausted = true
            fail_closed("generation_exhausted")
            error("generation limit exhausted", 3)
        end

        generation = generation + 1
    end

    local function expiry_after(t, lifetime)
        local expiry = t + lifetime
        if not finite(expiry) or expiry <= t then
            fail_closed("unrepresentable_expiry")
            error("expiry must be representable as a later finite time", 3)
        end
        return expiry
    end

    local function refresh(t)
        if validated_until ~= nil and t >= validated_until then
            bump()
            selected_destination = nil
            validated_until = nil
            permission_snapshot = nil
            phase = "needs_revalidation"
            last_fault = "readiness_expired"
        end
    end

    local function route_has_readiness()
        return phase == "awaiting_selection" or phase == "ready"
    end

    local function snapshot()
        return {
            version = M.VERSION,
            mode = legacy
                and "caller_timed_compatibility"
                or "host_clock_lifecycle",
            phase = phase,
            paused = paused,
            generation = generation,
            exhausted = exhausted,
            readiness_valid_until_exclusive = validated_until,
            readiness_freshness_enforced = not legacy,
            selected_destination = selected_destination,
            pending_count = pending ~= nil and 1 or 0,
            candidate_valid_until_exclusive =
                pending and pending.expires_at or nil,
            permission_snapshot_current = legacy
                and permission_snapshot == true or false,
            permission_snapshot_is_current_proof = false,
            destination_allowlist_enforced = not legacy,
            configuration_is_supplied_label = true,
            input_authenticity_verified = false,
            external_operation_available = false,
            last_observed_time = last_time,
            last_fault = last_fault
        }
    end

    function api.signal_lost()
        read_time()
        bump()
        phase = "unavailable"
        validated_until = nil
        selected_destination = nil
        permission_snapshot = nil
    end

    function api.signal_restored()
        read_time()
        bump()
        phase = "needs_revalidation"
        validated_until = nil
        selected_destination = nil
        permission_snapshot = nil
    end

    function api.revalidate(configuration, first_check, second_check)
        local t = read_time()

        if not valid_text(configuration)
            or type(first_check) ~= "boolean"
            or type(second_check) ~= "boolean" then
            error("revalidation requires a label and two booleans", 2)
        end

        if phase == "unavailable" then
            error("call signal_restored before revalidation", 2)
        end

        bump()
        selected_destination = nil
        validated_until = nil
        permission_snapshot = nil

        local accepted = configuration == expected_configuration
            and first_check
            and second_check

        if not accepted then
            phase = "needs_revalidation"
            last_fault = "revalidation_failed"
            return false, "revalidation_failed"
        end

        if legacy then
            permission_snapshot = second_check
        else
            validated_until = expiry_after(t, readiness_lifetime)
        end

        phase = "awaiting_selection"
        last_fault = nil
        return true, "readiness_observation_recorded"
    end

    function api.permission_changed()
        local t = read_time()
        refresh(t)
        local had_readiness = route_has_readiness()
        bump()
        selected_destination = nil
        permission_snapshot = nil

        if legacy then
            validated_until = nil
            phase = "needs_revalidation"
        elseif had_readiness then
            phase = "awaiting_selection"
        end
    end

    function api.user_pause()
        local t = read_time()
        refresh(t)
        bump()
        paused = true
    end

    function api.user_resume()
        local t = read_time()
        refresh(t)
        local had_readiness = route_has_readiness()
        bump()
        paused = false
        selected_destination = nil

        if had_readiness then
            phase = "awaiting_selection"
        end
    end

    function api.user_deselect_route()
        local t = read_time()
        refresh(t)
        local had_readiness = route_has_readiness()
        bump()
        selected_destination = nil

        if had_readiness then
            phase = "awaiting_selection"
        end
    end

    function api.cancel_pending()
        local t = read_time()
        refresh(t)
        bump()
        return true, "pending_candidates_invalidated"
    end

    function api.user_select_route(destination)
        local t = read_time()
        refresh(t)

        if not valid_text(destination) then
            error("use user_deselect_route for an unset destination", 2)
        end

        if not legacy and not allowed_destinations[destination] then
            return false, "destination_not_allowlisted"
        end

        if paused or not route_has_readiness()
            or (legacy and permission_snapshot ~= true) then
            return false, "route_not_selectable"
        end

        bump()
        selected_destination = destination
        phase = "ready"
        return true, "selected_locally"
    end

    function api.prepare_candidate(expires_at, explicit_time)
        local t = read_time(explicit_time, legacy)
        refresh(t)

        local expiry

        if legacy then
            if not finite(expires_at) or expires_at <= t then
                error("candidate expiry must be finite and later than now", 2)
            end
            expiry = expires_at
        else
            if expires_at ~= nil then
                error("candidate expiry is configured in host-clock mode", 2)
            end
            expiry = math.min(
                expiry_after(t, candidate_lifetime),
                validated_until or math.huge
            )
        end

        if phase ~= "ready" or paused
            or (legacy and permission_snapshot ~= true) then
            return nil, "route_not_ready"
        end

        if pending ~= nil and t >= pending.expires_at then
            pending = nil
        end

        if pending ~= nil then
            return nil, "pending_capacity_reached"
        end

        local handle = {}
        pending = {
            handle = handle,
            generation = generation,
            destination = selected_destination,
            expires_at = expiry
        }

        return handle, "candidate_prepared"
    end

    function api.consume_candidate(handle, explicit_time)
        local candidate = pending
        local t = read_time(explicit_time, legacy)
        refresh(t)

        local eligible = false
        local reason = "unknown_or_consumed_candidate"

        if candidate ~= nil and rawequal(handle, candidate.handle) then
            if pending == candidate then
                pending = nil
            end

            if candidate.generation ~= generation then
                reason = "stale_generation"
            elseif paused then
                reason = "paused"
            elseif phase ~= "ready" then
                reason = "route_not_ready"
            elseif candidate.destination ~= selected_destination then
                reason = "destination_changed"
            elseif legacy and permission_snapshot ~= true then
                reason = "cached_permission_unavailable"
            elseif t >= candidate.expires_at then
                reason = "candidate_expired"
            else
                eligible = true
                reason = "lifecycle_eligible_current_permission_still_required"
            end
        end

        return {
            model_eligible = eligible,
            permitted_by_model = eligible,
            reason = reason,
            destination = eligible and candidate.destination or nil,
            generation = generation,
            evaluated_at = t,
            candidate_valid_until_exclusive =
                candidate and candidate.expires_at or nil,
            current_permission_checked = false,
            physical_output_performed = false,
            external_action_performed_by_module = false,
            scope = "local_lifecycle_decision_only"
        }
    end

    api.commit_decision = api.consume_candidate

    function api.refresh()
        local t = read_time()
        refresh(t)
        return snapshot()
    end

    function api.status()
        if not exhausted then
            local t = read_time()
            refresh(t)
        end
        return snapshot()
    end

    function api.snapshot()
        return snapshot()
    end

    return api
end

return M
