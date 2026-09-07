local M = {}

local states = {
    clear = true,
    unmodeled_media = true,
    human_review_pending = true,
    human_review_complete = true,
    withhold = true
}

local function valid_transition(from, to, has_replacement_evidence, consent_rechecked, noninterference_rechecked)
    if not states[from] or not states[to] then
        return false
    end

    if from == "clear" then
        return to == "clear"
            or to == "unmodeled_media"
            or to == "human_review_pending"
            or to == "withhold"
    end

    if from == "unmodeled_media" then
        return to == "unmodeled_media"
            or to == "human_review_pending"
            or to == "withhold"
    end

    if from == "human_review_pending" then
        return to == "human_review_pending"
            or to == "human_review_complete"
            or to == "withhold"
    end

    if from == "human_review_complete" then
        if to == "clear" then
            return has_replacement_evidence
                and consent_rechecked
                and noninterference_rechecked
        end

        return to == "human_review_complete"
            or to == "unmodeled_media"
            or to == "human_review_pending"
            or to == "withhold"
    end

    if from == "withhold" then
        return to == "withhold"
            or to == "human_review_pending"
    end

    return false
end

local function unsafe(state, advisory_candidate)
    return state ~= "clear" and advisory_candidate == true
end

function M.check(initial_state, maximum_depth)
    if not states[initial_state] then
        return {
            status = "withheld",
            reason = "invalid initial state"
        }
    end

    if type(maximum_depth) ~= "number" or maximum_depth < 0 or maximum_depth % 1 ~= 0 then
        return {
            status = "withheld",
            reason = "maximum depth must be a non-negative integer"
        }
    end

    local queue = {
        {
            state = initial_state,
            depth = 0,
            advisory_candidate = initial_state == "clear",
            replacement_evidence = false,
            consent_rechecked = false,
            noninterference_rechecked = false
        }
    }

    local visited = {}

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local key = table.concat({
            current.state,
            tostring(current.depth),
            tostring(current.advisory_candidate),
            tostring(current.replacement_evidence),
            tostring(current.consent_rechecked),
            tostring(current.noninterference_rechecked)
        }, "|")

        if not visited[key] then
            visited[key] = true

            if unsafe(current.state, current.advisory_candidate) then
                return {
                    status = "unsafe_counterexample",
                    depth = current.depth,
                    state = current.state,
                    reason = "non-clear FOG state emitted advisory candidate"
                }
            end

            if current.depth < maximum_depth then
                for next_state, _ in pairs(states) do
                    for _, replacement_evidence in ipairs({ false, true }) do
                        for _, consent_rechecked in ipairs({ false, true }) do
                            for _, noninterference_rechecked in ipairs({ false, true }) do
                                if valid_transition(
                                    current.state,
                                    next_state,
                                    replacement_evidence,
                                    consent_rechecked,
                                    noninterference_rechecked
                                ) then
                                    table.insert(queue, {
                                        state = next_state,
                                        depth = current.depth + 1,
                                        advisory_candidate = next_state == "clear",
                                        replacement_evidence = replacement_evidence,
                                        consent_rechecked = consent_rechecked,
                                        noninterference_rechecked = noninterference_rechecked
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return {
        status = "no_unsafe_transition_found_within_bound",
        depth = maximum_depth,
        reason = "all reachable non-clear states withheld advisory candidate status"
    }
end

return M
