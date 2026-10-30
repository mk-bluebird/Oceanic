-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.replicate_contrast_summary")
local failures = 0

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500), "\n")
    end
end

local function run(values)
    return m.evaluate({
        schema_version = 1,
        independence_declaration = "independent_units_common_estimand",
        contrasts = values
    })
end

local function close(a, b)
    assert(math.abs(a - b) <= 1e-12 + 1e-10 * math.max(math.abs(a), math.abs(b)))
end

test("frozen_summary", function()
    local r = run({25, 10, -5, 20})
    assert(r.ok)
    close(r.value.mean, 12.5)
    close(r.value.sample_variance, 175)
    close(r.value.standard_error, math.sqrt(175 / 4))
end)

test("translation_and_scaling", function()
    local a = run({25, 10, -5, 20}).value
    local b = run({125, 110, 95, 120}).value
    local c = run({50, 20, -10, 40}).value
    close(b.mean, a.mean + 100)
    close(b.sample_variance, a.sample_variance)
    close(c.mean, 2 * a.mean)
    close(c.sample_variance, 4 * a.sample_variance)
end)

test("single_contrast_is_explicit", function()
    local r = run({25})
    assert(r.ok)
    assert(r.value.status == "screen_single_contrast_no_variance")
    assert(r.value.sample_variance == nil)
end)

test("invalid_and_nonmutating_inputs", function()
    assert(run({}).error.code == "E_EMPTY")
    assert(run({[1] = 1, [3] = 2}).error.code == "E_SEQUENCE_GAP")
    assert(run({1, 0/0}).error.code == "E_FINITE")
    local values = {1, 2, 3}
    local r = run(values)
    assert(r.ok)
    r.value.contrasts[1] = 99
    assert(values[1] == 1 and values[2] == 2 and values[3] == 3)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
