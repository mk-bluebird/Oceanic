-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local ref = require("lua.ecology.shifted_variance_reference")
local failures = 0
local ABS_TOL, REL_TOL = 1e-12, 1e-10

local function close(a, b)
    assert(math.abs(a - b) <= ABS_TOL
        + REL_TOL * math.max(math.abs(a), math.abs(b)))
end

local function test(name, fn)
    local ok, detail = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then
        failures = failures + 1
        io.write("DETAIL\t", name, "\t",
            tostring(detail):gsub("[%z\1-\31\127]", " "):sub(1, 500), "\n")
    end
end

test("ordinary_fixture", function()
    local r = ref.compute({25, 10, -5, 20})
    assert(r.ok)
    close(r.value.mean, 12.5)
    close(r.value.sample_variance, 175)
end)

test("large_offset_small_spread", function()
    local r = ref.compute({1e16, 1e16 + 2, 1e16 + 4})
    assert(r.ok)
    close(r.value.sample_variance, 4)
end)

test("constant_and_permutation", function()
    close(ref.compute({7,7,7}).value.sample_variance, 0)
    local a = ref.compute({25,10,-5,20}).value
    local b = ref.compute({-5,20,25,10}).value
    close(a.mean, b.mean)
    close(a.sample_variance, b.sample_variance)
end)

test("scaling_and_nonmutation", function()
    local values = {1,2,3}
    local r = ref.compute(values)
    assert(r.ok)
    close(ref.compute({2,4,6}).value.sample_variance,
        4 * r.value.sample_variance)
    assert(values[1] == 1 and values[2] == 2 and values[3] == 3)
end)

test("invalid_inputs", function()
    assert(ref.compute({}).error.code == "E_SAMPLE_SIZE")
    assert(ref.compute({1}).error.code == "E_SAMPLE_SIZE")
    assert(ref.compute({1,0/0}).error.code == "E_FINITE")
    assert(ref.compute({[1]=1,[3]=2}).error.code == "E_SEQUENCE_GAP")
end)

io.write("SUMMARY\tfailures\t", tostring(failures),
    "\tabs_tol\t", tostring(ABS_TOL),
    "\trel_tol\t", tostring(REL_TOL), "\n")
os.exit(failures == 0 and 0 or 1)
