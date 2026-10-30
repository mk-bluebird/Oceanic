-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
-- Credit only; not verification, consent, or authorization.
--
-- Lua 5.4, standard library only.
--
-- API:
--   render(records)
--   self_test()
--
-- records: contiguous plain sequence of records with exactly:
--   source_path, language, kind, name, start_line, end_line
--
-- This is a metadata renderer, not a parser.
-- No files, networking, persistence, publication, or hardware action.
-- Returned Markdown contains no source hyperlinks or docstrings.

local M = {}
local SCHEMA_VERSION = "1.0.0"
local MODULE_VERSION = "1.0.0"
local MAX_RECORDS = 100000
local MAX_LINE = 9007199254740991

local function envelope(ok, value, code, path, message)
    return {
        ok = ok,
        schema_version = SCHEMA_VERSION,
        module_version = MODULE_VERSION,
        value = value,
        error = {
            present = not ok,
            code = code or "",
            path = path or "",
            message = message or ""
        }
    }
end

local function fail(code, path, message)
    return envelope(false, false, code, path, message)
end

local function plain_table(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value, maximum)
    return type(value) == "string"
        and #value > 0
        and #value <= maximum
        and value:find("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function line_number(value)
    return type(value) == "number"
        and value == value
        and value >= 1
        and value <= MAX_LINE
        and value % 1 == 0
end

local function valid_path(path)
    if not text(path, 1024) then return false end
    if path:sub(1, 1) == "/" or path:find("\\", 1, true)
        or path:find(":", 1, true) or path:find("//", 1, true)
        or path:sub(-1) == "/" then
        return false
    end
    for segment in path:gmatch("[^/]+") do
        if segment == "." or segment == ".." then return false end
    end
    return true
end

local function escape_markdown(value)
    value = value:gsub("&", "&amp;")
        :gsub("<", "&lt;"):gsub(">", "&gt;")
    return value:gsub("([\\`*_{}%[%]()#+.!|~])", "\\%1")
end

local function render_impl(records)
    if not plain_table(records) then
        return fail("E_RECORDS", "records", "Expected a plain sequence.")
    end

    local count = 0
    for key in next, records do
        if not line_number(key) or key > MAX_RECORDS then
            return fail("E_SEQUENCE", "records",
                "Use contiguous integer positions within the record limit.")
        end
        count = count + 1
    end
    for position = 1, count do
        if rawget(records, position) == nil then
            return fail("E_SEQUENCE", "records",
                "Sequence positions must be contiguous.")
        end
    end

    local required = {
        source_path = true, language = true, kind = true,
        name = true, start_line = true, end_line = true
    }
    local sortable = {}

    for position = 1, count do
        local record = rawget(records, position)
        if not plain_table(record) then
            return fail("E_RECORD", "records",
                "Each symbol record must be a plain table.")
        end

        for key in next, record do
            if not required[key] then
                return fail("E_FIELD", "records",
                    "Unexpected symbol-record field.")
            end
        end

        if not valid_path(record.source_path) then
            return fail("E_PATH", "source_path",
                "Supply a safe repository-relative path.")
        end
        if record.language ~= "matlab" and record.language ~= "lua" then
            return fail("E_LANGUAGE", "language",
                "Only explicitly declared MATLAB or Lua is supported.")
        end

        local extension = record.language == "matlab" and "%.m$" or "%.lua$"
        if not record.source_path:match(extension) then
            return fail("E_EXTENSION", "source_path",
                "Path extension and declared language disagree.")
        end

        local kinds = {
            ["function"] = true, ["class"] = true,
            ["method"] = true, ["property"] = true,
            ["enum_member"] = true
        }
        if type(record.kind) ~= "string" or not kinds[record.kind] then
            return fail("E_KIND", "kind", "Unsupported symbol kind.")
        end
        if not text(record.name, 512) then
            return fail("E_NAME", "name",
                "Supply a bounded nonempty symbol name without controls.")
        end
        if not line_number(record.start_line)
            or not line_number(record.end_line)
            or record.start_line > record.end_line then
            return fail("E_LINES", "start_line",
                "Line bounds must be finite ordered positive integers.")
        end

        sortable[#sortable + 1] = {
            record = record,
            original_position = position
        }
    end

    table.sort(sortable, function(a, b)
        local x, y = a.record, b.record
        if x.source_path ~= y.source_path then
            return x.source_path < y.source_path
        end
        if x.start_line ~= y.start_line then
            return x.start_line < y.start_line
        end
        if x.name ~= y.name then return x.name < y.name end
        if x.kind ~= y.kind then return x.kind < y.kind end
        if x.end_line ~= y.end_line then return x.end_line < y.end_line end
        return a.original_position < b.original_position
    end)

    local output = {
        "# Supplied symbol catalogue",
        "",
        "Metadata rendering only; extraction completeness is not verified.",
        "",
        "| Source | Language | Kind | Name | Lines |",
        "|---|---|---|---|---|"
    }

    for _, entry in ipairs(sortable) do
        local r = entry.record
        output[#output + 1] = "| "
            .. escape_markdown(r.source_path) .. " | "
            .. r.language .. " | " .. r.kind .. " | "
            .. escape_markdown(r.name) .. " | "
            .. string.format("%.0f-%.0f", r.start_line, r.end_line)
            .. " |"
    end

    return envelope(true, {
        status = "metadata_rendered_only",
        markdown = table.concat(output, "\n") .. "\n",
        record_count = count,
        parser_executed = false,
        source_locations_verified = false,
        publication_approved = false,
        external_actions = "none",
        attribution =
            "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
        interpretation_limits = {
            {
                code = "R_INPUT_PROVENANCE",
                message = "Records are supplied, not extracted or verified."
            },
            {
                code = "R_NO_COMPLETENESS",
                message = "Rendered records do not establish symbol coverage."
            },
            {
                code = "R_NO_AUTHORIZATION",
                message = "Rendering does not authorize storage or publication."
            }
        }
    })
end

function M.render(records)
    local ok, result = pcall(render_impl, records)
    if not ok then
        return fail("E_INTERNAL", "",
            "Unexpected internal failure; inspect locally.")
    end
    return result
end

function M.self_test()
    local records = {
        {
            source_path = "matlab/research/example.m",
            language = "matlab",
            kind = "function",
            name = "example",
            start_line = 1,
            end_line = 12
        }
    }

    local first = M.render(records)
    if not first.ok or first.value.record_count ~= 1 then
        return fail("E_SELF_TEST", "baseline", "Baseline rendering failed.")
    end

    local second = M.render(records)
    if not second.ok or second.value.markdown ~= first.value.markdown
        or records[1].start_line ~= 1 then
        return fail("E_SELF_TEST", "determinism",
            "Determinism or non-mutation test failed.")
    end

    local invalid = M.render({
        {
            source_path = "../private/example.m",
            language = "matlab",
            kind = "function",
            name = "example",
            start_line = 1,
            end_line = 2
        }
    })
    if invalid.ok or invalid.error.code ~= "E_PATH" then
        return fail("E_SELF_TEST", "path_rejection",
            "Unsafe path was not rejected.")
    end

    return envelope(true, {
        status = "synthetic_self_tests_passed",
        actual_source_indexing = "not_performed"
    })
end

return M
