-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4.7 or later; standard library only.
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- No identity, consent, authorization, or authority is established.
-- Binary screening counts only; no raw records, I/O, or storage.

local M = {VERSION = "1.0.0"}
local LIMIT = 1000000000

local function fail(code)
    return {
        ok = false,
        error = {
            code = code,
            path = "input",
            message_key = "screening_miss_metrics." .. code,
            args = {}
        }
    }
end

local function ratio(numerator, denominator)
    if denominator == 0 then
        return {
            status = "undefined",
            numerator = numerator,
            denominator = denominator
        }
    end
    return {
        status = "defined",
        numerator = numerator,
        denominator = denominator,
        value = numerator / denominator
    }
end

function M.evaluate(input)
    if type(input) ~= "table" or getmetatable(input) ~= nil then
        return fail("E_INPUT_TYPE")
    end

    local allowed = {tp = true, fp = true, fn = true, tn = true}

    for key in next, input do
        if not allowed[key] then return fail("E_UNKNOWN_MEMBER") end
    end

    for _, key in ipairs({"tp", "fp", "fn", "tn"}) do
        local value = rawget(input, key)
        if value == nil then return fail("E_MISSING_COUNT") end
        if type(value) ~= "number" or value ~= value
            or value < 0 or value > LIMIT or value % 1 ~= 0 then
            return fail("E_COUNT_VALUE")
        end
    end

    local tp, fp, fn, tn = input.tp, input.fp, input.fn, input.tn
    local total = tp + fp + fn + tn

    return {
        ok = true,
        value = {
            module_version = M.VERSION,
            counts = {tp = tp, fp = fp, fn = fn, tn = tn},
            evaluated_record_count = total,
            reference_eligible_count = tp + fn,
            missed_eligible_count = fn,
            sensitivity = ratio(tp, tp + fn),
            missed_eligible_fraction = ratio(fn, tp + fn),
            specificity = ratio(tn, tn + fp),
            precision = ratio(tp, tp + fp),
            accuracy = ratio(tp + tn, total),
            reference_labels_verified = false,
            referral_handling = "not_represented",
            unresolved_reference_labels = "not_represented",
            confidence_intervals_computed = false,
            safe_exclusion_established = false,
            assessment_scope = "supplied_binary_confusion_counts"
        }
    }
end

return M
