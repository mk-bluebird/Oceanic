-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not identity verification, consent, or authorization.
--
-- Lua 5.4 module. No filesystem, networking, telemetry, or installation.
-- API:
--   local m = require("toolchain_session_accounting")
--   local result = m.evaluate(config)
--   local tests = m.self_test()
--
-- All inputs are caller-supplied planning values.
-- Currency fields use one caller-declared currency.
-- Byte inputs and computed byte totals are nonnegative integers
-- bounded by 2^53 - 1 for conservative cross-language interoperability.

local M = {}
local SCHEMA_VERSION = "1.0.0"
local MODULE_VERSION = "1.0.0"
local MAX_EXACT = 9007199254740991

local required = {
    toolchain_name = "text",
    currency = "text",
    installed_bytes = "integer",
    download_bytes = "integer",
    staging_bytes = "integer",
    scratch_bytes_per_session = "integer",
    total_sessions = "positive_integer",
    concurrent_sessions = "positive_integer",
    cold_installs = "integer",
    shared_installation = "boolean",
    restart_each_cycle = "boolean",
    cycles_per_session = "positive_integer",
    process_start_seconds = "number",
    kernel_seconds_per_cycle = "number",
    install_seconds_per_cold_install = "number",
    annual_license_cost = "number",
    annual_session_count = "positive_integer",
    engineering_hours_for_run = "number",
    engineering_cost_per_hour = "number"
}

local function envelope(ok, value, code, message)
    return {
        ok = ok,
        schema_version = SCHEMA_VERSION,
        module_version = MODULE_VERSION,
        value = value or false,
        error = {
            code = code or "",
            message = message or ""
        }
    }
end

local function fail(code, message)
    return envelope(false, false, code, message)
end

local function finite_number(x)
    return type(x) == "number"
        and x == x
        and x ~= math.huge
        and x ~= -math.huge
end

local function valid_number(x, kind)
    if not finite_number(x) or x < 0 or x > MAX_EXACT then
        return false
    end
    if kind == "integer" or kind == "positive_integer" then
        if x % 1 ~= 0 then
            return false
        end
    end
    return kind ~= "positive_integer" or x > 0
end

local function units(bytes)
    return {
        bytes = bytes,
        GB_decimal = bytes / 1000000000,
        GiB_binary = bytes / 1073741824
    }
end

local function checked(x, integer_required)
    if not finite_number(x) or x < 0 or x > MAX_EXACT then
        return false
    end
    return not integer_required or x % 1 == 0
end

local function evaluate_impl(config)
    if type(config) ~= "table" or getmetatable(config) ~= nil then
        return fail("E_CONFIG", "Supply a plain configuration table.")
    end

    for key in pairs(config) do
        if required[key] == nil then
            return fail("E_CONFIG_FIELD", "Unexpected configuration field.")
        end
    end

    for key, kind in pairs(required) do
        local value = rawget(config, key)
        if kind == "text" then
            if type(value) ~= "string" or not value:find("%S") then
                return fail("E_TEXT", "Invalid text field: " .. key)
            end
        elseif kind == "boolean" then
            if type(value) ~= "boolean" then
                return fail("E_BOOLEAN", "Invalid boolean field: " .. key)
            end
        elseif not valid_number(value, kind) then
            return fail("E_NUMBER", "Invalid numeric field: " .. key)
        end
    end

    if config.concurrent_sessions > config.total_sessions then
        return fail("E_CONCURRENCY",
            "Concurrent sessions cannot exceed total sessions.")
    end

    if config.cold_installs > config.total_sessions then
        return fail("E_INSTALL_COUNT",
            "This model permits at most one cold install per session.")
    end

    if config.shared_installation and config.cold_installs > 1 then
        return fail("E_SHARED_INSTALL_MODEL",
            "Shared-installation scenario permits at most one cold install.")
    end

    local starts_per_session = config.restart_each_cycle
        and config.cycles_per_session or 1
    local process_starts = config.total_sessions * starts_per_session
    local cycle_count = config.total_sessions * config.cycles_per_session

    if not checked(process_starts, true)
        or not checked(cycle_count, true) then
        return fail("E_COUNT_RANGE", "Process or cycle count exceeded range.")
    end

    local installation_peak
    if config.shared_installation then
        installation_peak = config.installed_bytes
            + config.download_bytes
            + config.staging_bytes
            + config.concurrent_sessions * config.scratch_bytes_per_session
    else
        installation_peak = config.concurrent_sessions * (
            config.installed_bytes
            + config.download_bytes
            + config.staging_bytes
            + config.scratch_bytes_per_session
        )
    end

    local download_total = config.cold_installs * config.download_bytes

    if not checked(installation_peak, true)
        or not checked(download_total, true) then
        return fail("E_BYTE_RANGE", "Computed byte budget exceeded range.")
    end

    local startup_seconds =
        process_starts * config.process_start_seconds
    local kernel_seconds =
        cycle_count * config.kernel_seconds_per_cycle
    local installation_seconds =
        config.cold_installs * config.install_seconds_per_cold_install
    local license_allocation = config.annual_license_cost
        * (config.total_sessions / config.annual_session_count)
    local engineering_cost = config.engineering_hours_for_run
        * config.engineering_cost_per_hour
    local known_cost = license_allocation + engineering_cost

    local totals = {
        startup_seconds, kernel_seconds, installation_seconds,
        startup_seconds + kernel_seconds,
        license_allocation, engineering_cost, known_cost
    }

    for _, value in ipairs(totals) do
        if not checked(value, false) then
            return fail("E_TOTAL_RANGE",
                "Computed time or cost exceeded supported range.")
        end
    end

    return envelope(true, {
        status = "planning_only",
        toolchain_name = config.toolchain_name,
        currency = config.currency,
        disk_peak_same_volume_conservative = units(installation_peak),
        cumulative_download = units(download_total),
        process_starts = process_starts,
        cycle_count = cycle_count,
        aggregate_startup_seconds = startup_seconds,
        aggregate_kernel_seconds = kernel_seconds,
        aggregate_process_work_seconds = startup_seconds + kernel_seconds,
        aggregate_installation_seconds = installation_seconds,
        allocated_license_cost = license_allocation,
        engineering_cost = engineering_cost,
        partial_accounted_cost = known_cost,
        full_total_cost_of_ownership_established = false,
        inputs_measured_by_module = false,
        elapsed_wall_time_established = false,
        input_provenance = "caller_supplied_not_verified",
        external_actions = "none",
        attribution = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_PEAK_SCENARIO",
                message = "Disk peak assumes stated components coexist."
            },
            {
                code = "R_NO_LAYER_SHARING",
                message = "No container-layer, cache, or deduplication model."
            },
            {
                code = "R_PARTIAL_COST",
                message = "Compute, transfer charges, storage duration, and taxes excluded."
            },
            {
                code = "R_AGGREGATE_TIME",
                message = "Aggregate work seconds are not concurrent elapsed time."
            },
            {
                code = "R_LICENSE_ALLOCATION",
                message = "License cost is allocated, not a marginal purchase determination."
            },
            {
                code = "R_NO_BENCHMARK",
                message = "Timing inputs are supplied; no benchmark was run."
            }
        }
    })
end

function M.evaluate(config)
    local ok, result = pcall(evaluate_impl, config)
    if not ok then
        return fail("E_INTERNAL",
            "Unexpected internal failure; inspect locally.")
    end
    return result
end

function M.self_test()
    local config = {
        toolchain_name = "Synthetic toolchain",
        currency = "SYNTHETIC",
        installed_bytes = 1000,
        download_bytes = 200,
        staging_bytes = 300,
        scratch_bytes_per_session = 50,
        total_sessions = 4,
        concurrent_sessions = 2,
        cold_installs = 1,
        shared_installation = true,
        restart_each_cycle = false,
        cycles_per_session = 3,
        process_start_seconds = 2,
        kernel_seconds_per_cycle = 0.5,
        install_seconds_per_cold_install = 10,
        annual_license_cost = 100,
        annual_session_count = 100,
        engineering_hours_for_run = 2,
        engineering_cost_per_hour = 10
    }

    local ok, result = pcall(function()
        local first = M.evaluate(config)
        assert(first.ok, "baseline")
        assert(first.value.disk_peak_same_volume_conservative.bytes == 1600,
            "shared_peak")
        assert(first.value.cumulative_download.bytes == 200, "download")
        assert(first.value.process_starts == 4, "persistent_processes")
        assert(first.value.aggregate_process_work_seconds == 14, "work_time")
        assert(first.value.partial_accounted_cost == 24, "partial_cost")
        assert(config.installed_bytes == 1000, "nonmutation")

        local second = M.evaluate(config)
        assert(second.ok
            and second.value.aggregate_process_work_seconds
                == first.value.aggregate_process_work_seconds,
            "deterministic_work_time")

        config.shared_installation = false
        config.cold_installs = 4
        config.restart_each_cycle = true

        local restarted = M.evaluate(config)
        assert(restarted.ok, "unshared_success")
        assert(restarted.value.disk_peak_same_volume_conservative.bytes == 3100,
            "unshared_peak")
        assert(restarted.value.cumulative_download.bytes == 800,
            "repeated_download")
        assert(restarted.value.process_starts == 12, "restarted_processes")

        config.concurrent_sessions = 5
        local invalid = M.evaluate(config)
        assert(not invalid.ok and invalid.error.code == "E_CONCURRENCY",
            "error_code")

        return true
    end)

    if not ok or result ~= true then
        return fail("E_SELF_TEST", "Synthetic self-test failed.")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        field_validation = "not_performed",
        coverage = {
            "envelopes", "shared_peak", "unshared_peak",
            "cumulative_download", "persistent_startup",
            "restarted_startup", "partial_cost", "error_codes"
        }
    })
end

return M
