-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit establishes no identity, consent, authorization, or authority.
--
-- Local supplied-record processing only.
-- No I/O, persistence, networking, automatic disclosure, or actuation.
-- Restricted trace outputs require an external access-control process.

local M = {
    VERSION = "1.0.0",
    POLICY_VERSION = "1.0.0"
}

local OPERATIONS = {
    analysis = true, storage = true, translation = true,
    publication = true, derivative_creation = true
}

local AUDIENCES = {
    restricted_review = true,
    approved_summary = true,
    public = true
}

local DERIVATIVES = {
    none = true,
    summary = true,
    translated_summary = true,
    derived_analysis = true
}

local DETERMINATIONS = {
    permitted = true,
    not_permitted = true,
    undetermined = true
}

local REQUIREMENTS = {
    exact_location = true,
    coarse_location = true,
    observation_period = true,
    response_measurements = true,
    comparison_basis = true,
    detection_basis = true
}

local MAX = 32
local MAX_TIME = 9007199254740991

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "scoped_permission_limitation." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, keys)
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

local function length(value)
    if not plain(value) then return nil end
    local count, highest = 0, 0
    for key in next, value do
        count = count + 1
        if count > MAX or type(key) ~= "number"
            or key % 1 ~= 0 or key < 1 or key > MAX then
            return nil
        end
        if key > highest then highest = key end
    end
    if count ~= highest then return nil end
    return count
end

local function label(value)
    return type(value) == "string"
        and #value > 0 and #value <= 160
        and not value:find("[%z\1-\31\127]")
        and not value:match("^ *$")
end

local function registered(value, values)
    return type(value) == "string" and values[value] == true
end

local function time_value(value)
    return type(value) == "number"
        and value == value and value >= 0
        and value <= MAX_TIME and value % 1 == 0
end

local function valid_use(value)
    return shape(value, {
        "operation", "purpose", "audience", "scope",
        "start_second", "end_second", "derivative"
    })
        and registered(value.operation, OPERATIONS)
        and label(value.purpose)
        and registered(value.audience, AUDIENCES)
        and label(value.scope)
        and time_value(value.start_second)
        and time_value(value.end_second)
        and value.end_second > value.start_second
        and registered(value.derivative, DERIVATIVES)
end

local function matches(request, recorded)
    return request.operation == recorded.operation
        and request.purpose == recorded.purpose
        and request.audience == recorded.audience
        and request.scope == recorded.scope
        and request.derivative == recorded.derivative
        and request.start_second >= recorded.start_second
        and request.end_second <= recorded.end_second
end

function M.match_permission(input)
    if not shape(input, {"policy_version", "request", "records"}) then
        return fail("E_INPUT_SHAPE", "input")
    end
    if input.policy_version ~= M.POLICY_VERSION then
        return fail("E_POLICY_VERSION", "input.policy_version")
    end
    if not valid_use(input.request) then
        return fail("E_USE_RECORD", "input.request")
    end

    local count = length(input.records)
    if count == nil then return fail("E_RECORDS", "input.records") end

    local statuses, matching = {}, 0

    for _, record in ipairs(input.records) do
        if not shape(record, {"use", "determination"})
            or not valid_use(record.use)
            or not registered(record.determination, DETERMINATIONS) then
            return fail("E_PERMISSION_RECORD", "input.records")
        end

        if matches(input.request, record.use) then
            matching = matching + 1
            statuses[record.determination] = true
        end
    end

    local status, reason = "undetermined", "no_matching_determination"

    if matching > 0 then
        if statuses.undetermined
            or (statuses.permitted and statuses.not_permitted) then
            reason = "unresolved_or_conflicting_determinations"
        elseif statuses.not_permitted then
            status, reason = "not_permitted", "matching_record"
        else
            status, reason = "permitted", "matching_record"
        end
    end

    return ok({
        policy_version = M.POLICY_VERSION,
        recorded_permission_status = status,
        reason = reason,
        matching_record_count = matching,
        time_convention = "caller_shared_origin_integer_seconds_half_open",
        authority_verified = false,
        record_currentness_verified = false,
        conditions_verified = false,
        action_authorized_here = false,
        assessment_scope = "supplied_record_match_only"
    })
end

local function requirement_set(values)
    if length(values) == nil then return nil end
    local set = {}
    for _, value in ipairs(values) do
        if not registered(value, REQUIREMENTS) or set[value] then
            return nil
        end
        set[value] = true
    end
    return set
end

function M.trace_limitations(input)
    if not shape(input, {"withheld", "steps"}) then
        return fail("E_INPUT_SHAPE", "input")
    end

    local withheld = requirement_set(input.withheld)
    if not withheld then return fail("E_REQUIREMENTS", "input.withheld") end

    if length(input.steps) == nil then
        return fail("E_STEPS", "input.steps")
    end

    local results = {}
    for position, step in ipairs(input.steps) do
        if not shape(step, {"requirements"}) then
            return fail("E_STEP_SHAPE", "input.steps")
        end
        if not requirement_set(step.requirements) then
            return fail("E_REQUIREMENTS", "input.steps")
        end

        local overlap = {}
        for _, requirement in ipairs(step.requirements) do
            if withheld[requirement] then
                overlap[#overlap + 1] = requirement
            end
        end
        table.sort(overlap)

        results[position] = {
            step_position = position,
            status = #overlap > 0
                and "potentially_limited"
                or "not_blocked_by_declared_withholding",
            unavailable_requirements = overlap
        }
    end

    return ok({
        step_results = results,
        audience_class = "restricted_review",
        dependency_inventory_verified = false,
        scientific_adequacy_assessed = false,
        permission_assessed = false,
        participation_assessed = false,
        disclosure_requested = false,
        publication_authorized = false
    })
end

function M.summary_notice(selection)
    if selection ~= "scope_limited" and selection ~= "review_pending" then
        return fail("E_SUMMARY_SELECTION", "selection")
    end

    local templates = {
        scope_limited =
            "The analysis is limited to the stated scope; no additional disclosure is required.",
        review_pending =
            "Interpretation remains under review; no conclusion is established."
    }

    return ok({
        audience_class = "approved_summary",
        template_version = "1.0.0",
        text = templates[selection],
        selection_source = "caller_supplied",
        release_approval_verified = false,
        publication_authorized = false
    })
end

function M.public_notice()
    return ok({
        audience_class = "public",
        template_version = "1.0.0",
        text =
            "This report addresses only its stated question and evidence. It makes no claim about information outside that scope.",
        trace_consumed = false,
        release_approval_verified = false,
        publication_authorized = false
    })
end

return M
