local function number_in_range(value, label, minimum, maximum)
    local parsed = tonumber(value)
    if parsed == nil or parsed ~= parsed or parsed < minimum or parsed > maximum then
        error("invalid " .. label)
    end
    return parsed
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function classify(event)
    if event.fog_media_state == "unmodeled" or event.fog_media_state == "unknown" then
        return {
            containment_status = "human_review_required",
            operator_action = event.fog_fallback_route or "human_review"
        }
    end

    local surcharge_ratio = event.flow_lps / event.design_lps
    local hydraulic_score = surcharge_ratio + math.max(0.0, 0.50 - event.freeboard_m)
    local ecological_score =
        (event.bod_mg_l / 30.0) +
        (event.tss_mg_l / 100.0) +
        (math.max(0.0, 20.0 - event.cec_meq_100g) / 20.0)
    local blast_radius_m = event.downstream_m * clamp(hydraulic_score / 2.0, 0.10, 1.00)

    local containment_status = "contained"
    local operator_action = "continue normal monitored operation"

    if surcharge_ratio >= 1.30 or event.freeboard_m <= 0.20 or ecological_score >= 3.00 then
        containment_status = "critical"
        operator_action = "notify human operator; preserve safe flow and isolate only under approved local procedure"
    elseif surcharge_ratio >= 1.10 or ecological_score >= 1.75 then
        containment_status = "elevated"
        operator_action = "increase observation frequency; notify designated restoration operator"
    end

    return {
        surcharge_ratio = surcharge_ratio,
        hydraulic_score = hydraulic_score,
        ecological_score = ecological_score,
        blast_radius_m = blast_radius_m,
        containment_status = containment_status,
        operator_action = operator_action
    }
end

local event = {
    flow_lps = number_in_range(arg[1], "flow_lps", 0.0, 100000.0),
    design_lps = number_in_range(arg[2], "design_lps", 0.001, 100000.0),
    freeboard_m = number_in_range(arg[3], "freeboard_m", 0.0, 20.0),
    bod_mg_l = number_in_range(arg[4], "bod_mg_l", 0.0, 100000.0),
    tss_mg_l = number_in_range(arg[5], "tss_mg_l", 0.0, 100000.0),
    cec_meq_100g = number_in_range(arg[6], "cec_meq_100g", 0.0, 500.0),
    downstream_m = number_in_range(arg[7], "downstream_m", 0.001, 100000.0),
    fog_media_state = arg[8] or "unknown",
    fog_fallback_route = arg[9] or "human_review"
}

local result = classify(event)
for key, value in pairs(result) do
    print(key .. "=" .. value)
end
