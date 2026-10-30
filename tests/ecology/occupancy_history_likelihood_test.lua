-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.occupancy_history_likelihood")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.stderr:write(tostring(detail) .. "\n")
    end
end

local function close(a, b)
    assert(math.abs(a - b) < 1e-12)
end

local function input(history, detection)
    return {
        schema_version = 1, scope = "Synthetic two-visit fixture",
        psi = 0.4, history = history, detection = detection or {0.3, 0.3}
    }
end

local function likelihood(history, detection)
    local r = m.evaluate(input(history, detection))
    assert(r.ok)
    return math.exp(r.value.log_likelihood)
end

test("all-zero mixture", function()
    close(likelihood({0, 0}), 0.796)
end)

test("ordered detection history", function()
    close(likelihood({1, 0}), 0.084)
    close(likelihood({1, 1}), 0.036)
end)

test("probabilities sum to one", function()
    local sum = 0
    for a = 0, 1 do
        for b = 0, 1 do sum = sum + likelihood({a, b}) end
    end
    close(sum, 1)
end)

test("matched visit permutation", function()
    close(likelihood({1, 0}, {0.2, 0.7}),
        likelihood({0, 1}, {0.7, 0.2}))
end)

test("explicit boundaries and malformed inputs", function()
    local x = input({0, 0})
    x.psi = 1
    assert(m.evaluate(x).error.code == "E_OPEN_PROBABILITY")
    x = input({0, 0}, {0.3})
    assert(m.evaluate(x).error.code == "E_VISIT_COUNT")
    x = input({0, 2})
    assert(m.evaluate(x).error.code == "E_BINARY")
    x = input({0, 0}, {0.3, 0 / 0})
    assert(m.evaluate(x).error.code == "E_OPEN_PROBABILITY")
end)

test("output mutation does not modify input", function()
    local x = input({1, 0})
    local r = m.evaluate(x)
    assert(r.ok)
    r.value.history[1] = 0
    r.value.detection[1] = 0.9
    assert(x.history[1] == 1 and x.detection[1] == 0.3)
end)

os.exit(failures == 0 and 0 or 1)
