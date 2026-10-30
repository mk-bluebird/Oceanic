-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4; module 1.0.0; schema 1.
-- Dependency: lua/ecology/validation.lua
-- Retain credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit grants no consent, verified identity, or authority.
-- Contract: {ok=true,value=...} or {ok=false,error=...}.
-- Descriptive factorial arithmetic; no inference, I/O, or action.

local V = require("lua.ecology.validation")
local M = {VERSION = "1.0.0"}
local CELLS = {"neither", "climate_only", "local_only", "both"}

function M.evaluate(x)
    local r = V.record(x, {
        "schema_version", "scope", "response", "units",
        "preferred_direction", "cells"
    }, {}, "input")
    if not r.ok then return r end

    if x.schema_version ~= 1 then
        return V.fail("E_SCHEMA_VERSION", "input.schema_version", {
            expected=1, actual=V.describe(x.schema_version)
        })
    end
    for _, key in ipairs({"scope", "response", "units"}) do
        r = V.text(x[key], 500, "input." .. key)
        if not r.ok then return r end
    end
    r = V.enum(x.preferred_direction,
        {"higher", "lower", "not_defined"},
        "E_PREFERRED_DIRECTION", "input.preferred_direction")
    if not r.ok then return r end
    r = V.record(x.cells, CELLS, {}, "input.cells")
    if not r.ok then return r end

    local copied, all_positive = {}, true
    for _, key in ipairs(CELLS) do
        if not V.finite(x.cells[key]) then
            return V.fail("E_FINITE", "input.cells." .. key)
        end
        copied[key] = x.cells[key]
        if x.cells[key] <= 0 then all_positive = false end
    end

    local y00, y10 = copied.neither, copied.climate_only
    local y01, y11 = copied.local_only, copied.both
    local expected_additive = (y10 - y00) + y01
    local interaction_additive = y11 - expected_additive

    if not V.finite(expected_additive) or not V.finite(interaction_additive) then
        return V.fail("E_NUMERIC_RANGE", "input.cells")
    end

    local out = {
        module_version=M.VERSION,
        schema_version=1,
        status="screen_descriptive_factorial_interaction",
        scope=x.scope, response=x.response, units=x.units,
        preferred_direction=x.preferred_direction,
        cells=copied,
        additive_expected_both=expected_additive,
        additive_interaction=interaction_additive,
        log_interaction_status=all_positive
            and "available" or "not_applicable_nonpositive_response",
        attribution={
            anchor="bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
            purpose="document_credit_and_configured_workstream_metadata_only",
            retention="copy_in_derivatives",
            establishes_consent=false,
            establishes_verified_identity=false,
            grants_authority=false
        },
        interpretation_limits={
            response_scale_validated=false,
            common_measurement_support_verified=false,
            randomization_verified=false,
            uncertainty_estimated=false,
            statistical_interaction_established=false,
            causal_interaction_established=false,
            ecological_harm_classified=false,
            external_action_performed=false
        }
    }

    if all_positive then
        local log_interaction =
            (math.log(y11) - math.log(y10))
            - (math.log(y01) - math.log(y00))
        if not V.finite(log_interaction) then
            return V.fail("E_NUMERIC_RANGE", "input.cells")
        end
        out.log_multiplicative_interaction=log_interaction
        out.log_interaction_units="dimensionless"
    end
    return V.ok(out)
end

return M
