-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Local, non-actuating decision contract. No storage or networking.

local M = {
    version = "1.0.0",
    attribution = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
}

local stages = {
    evidence = true,
    hard = true,
    uncertainty_qualified = true
}

local statuses = { pass = true, fail = true, unknown = true }

local function failure(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            args = {}
        }
    }
end

local function text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function allowed_keys(value, allowed, path)
    for key in pairs(value) do
        if not allowed[key] then
            return failure("UNEXPECTED_FIELD", path)
        end
    end
end

local function array_length(value)
    if type(value) ~= "table" then return nil end
    local count, largest = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return nil
        end
        count = count + 1
        if key > largest then largest = key end
    end
    if count ~= largest then return nil end
    return count
end

function M.evaluate(input)
    if type(input) ~= "table" then
        return failure("EXPECTED_RECORD", "$")
    end

    local err = allowed_keys(input, {
        policy_version = true,
        findings = true,
        comparative_score = true
    }, "$")
    if err then return err end

    if not text(input.policy_version) then
        return failure("REQUIRED_TEXT", "$.policy_version")
    end

    local count = array_length(input.findings)
    if count == nil then
        return failure("EXPECTED_DENSE_ARRAY", "$.findings")
    end
    if count == 0 then
        return failure("EMPTY_GATE_SET", "$.findings")
    end

    local findings, names = {}, {}
    local totals = { pass = 0, fail = 0, unknown = 0 }
    local stage_totals = {
        evidence = { pass = 0, fail = 0, unknown = 0 },
        hard = { pass = 0, fail = 0, unknown = 0 },
        uncertainty_qualified = { pass = 0, fail = 0, unknown = 0 }
    }

    for index = 1, count do
        local item = input.findings[index]
        local path = "$.findings[" .. index .. "]"

        if type(item) ~= "table" then
            return failure("EXPECTED_RECORD", path)
        end

        err = allowed_keys(item, {
            name = true,
            stage = true,
            status = true,
            code = true,
            rationale = true
        }, path)
        if err then return err end

        for _, field in ipairs({ "name", "code", "rationale" }) do
            if not text(item[field]) then
                return failure("REQUIRED_TEXT", path .. "." .. field)
            end
        end

        if type(item.stage) ~= "string" or not stages[item.stage] then
            return failure("INVALID_STAGE", path .. ".stage")
        end
        if type(item.status) ~= "string" or not statuses[item.status] then
            return failure("INVALID_STATUS", path .. ".status")
        end
        if names[item.name] then
            return failure("DUPLICATE_FINDING_NAME", path .. ".name")
        end
        names[item.name] = true

        findings[index] = {
            name = item.name,
            stage = item.stage,
            status = item.status,
            code = item.code,
            rationale = item.rationale
        }
        totals[item.status] = totals[item.status] + 1
        local stage = stage_totals[item.stage]
        stage[item.status] = stage[item.status] + 1
    end

    for _, stage in ipairs({
        "evidence", "hard", "uncertainty_qualified"
    }) do
        local counts = stage_totals[stage]
        if counts.pass + counts.fail + counts.unknown == 0 then
            return failure("MISSING_REQUIRED_STAGE", "$.findings")
        end
    end

    local disposition
    if totals.fail > 0 then
        disposition = "blocked"
    elseif totals.unknown > 0 then
        disposition = "unresolved"
    else
        disposition = "eligible_for_comparison"
    end

    local score = { state = "not_supplied" }
    if input.comparative_score ~= nil then
        local supplied = input.comparative_score
        if type(supplied) ~= "table" then
            return failure("EXPECTED_RECORD", "$.comparative_score")
        end
        err = allowed_keys(supplied, {
            value = true,
            rubric_version = true
        }, "$.comparative_score")
        if err then return err end

        if not finite(supplied.value)
            or supplied.value < 0
            or supplied.value > 1 then
            return failure("INVALID_SCORE", "$.comparative_score.value")
        end
        if not text(supplied.rubric_version) then
            return failure(
                "REQUIRED_TEXT", "$.comparative_score.rubric_version"
            )
        end

        score = {
            state = disposition == "eligible_for_comparison"
                and "available_for_comparison" or "withheld_from_comparison",
            value = supplied.value,
            rubric_version = supplied.rubric_version
        }
    end

    return {
        ok = true,
        value = {
            contract_version = M.version,
            policy_version = input.policy_version,
            disposition = disposition,
            findings = findings,
            counts = totals,
            stage_counts = stage_totals,
            comparative_score = score,
            authority = "decision_support_only"
        }
    }
end

return M
