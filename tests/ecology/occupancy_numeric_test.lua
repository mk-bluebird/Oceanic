-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.occupancy_numeric")
local atol = tonumber(arg[1]) or 1e-12
local rtol = tonumber(arg[2]) or 1e-10
local failures = 0

local function valid_tolerance(x)
    return x == x and x >= 0 and x < math.huge
end
if not valid_tolerance(atol) or not valid_tolerance(rtol) then
    io.write("FAIL\tconfiguration\tinvalid_tolerance\n")
    os.exit(1)
end

io.write("CONFIG\tabsolute\t", tostring(atol),
    "\trelative\t", tostring(rtol), "\n")

local function close(a, b)
    if a == b then return end
    assert(a == a and b == b and math.abs(a) < math.huge
        and math.abs(b) < math.huge)
    assert(math.abs(a - b) <= atol + rtol * math.max(math.abs(a), math.abs(b)))
end

local function test(name, fn)
    local ok = pcall(fn)
    io.write((ok and "PASS\t" or "FAIL\t") .. name .. "\n")
    if not ok then failures = failures + 1 end
end

local function ll(psi, y, p)
    local value, code = m.log_likelihood(psi, y, p, 100)
    assert(value ~= nil, code)
    return value
end

local function rejects(psi, y, p, cap, code, path)
    local value, actual_code, actual_path =
        m.log_likelihood(psi, y, p, cap)
    assert(value == nil and actual_code == code and actual_path == path)
end

test("single_visit", function()
    close(math.exp(ll(0.4, {1}, {0.3})), 0.12)
    close(math.exp(ll(0.4, {0}, {0.3})), 0.88)
end)

test("exact_boundaries", function()
    assert(ll(0, {1}, {1}) == -math.huge)
    close(ll(0, {0}, {1}), 0)
    close(ll(1, {1}, {1}), 0)
    assert(ll(1, {0}, {1}) == -math.huge)
    close(ll(0.4, {0}, {0}), 0)
    assert(ll(0.4, {1}, {0}) == -math.huge)
end)

test("invalid_sequences", function()
    rejects(0.4, {}, {}, 10, "E_EMPTY", "input.history")
    rejects(0.4, {[1]=0,[3]=0}, {0.3,0.3}, 10,
        "E_SEQUENCE_GAP", "input.history")
    rejects(0.4, {[1.5]=0}, {0.3}, 10,
        "E_INDEX_INTEGER", "input.history")
    rejects(0.4, {extra=0}, {0.3}, 10,
        "E_INDEX_TYPE", "input.history")
    rejects(0.4, {[0]=0}, {0.3}, 10,
        "E_INDEX_POSITIVE", "input.history")
    rejects(0.4, {0,0}, {0.3,0.3}, 1,
        "E_DECLARED_CAPACITY", "input.history")
end)

test("invalid_probabilities_and_capacity", function()
    rejects(-0.1, {0}, {0.3}, 10, "E_PROBABILITY", "input.psi")
    rejects(0.4, {0}, {-0.1}, 10,
        "E_PROBABILITY", "input.detection[1]")
    rejects(0.4, {0}, {1.1}, 10,
        "E_PROBABILITY", "input.detection[1]")
    rejects(0/0, {0}, {0.3}, 10, "E_PROBABILITY", "input.psi")
    rejects(0.4, {0}, {math.huge}, 10,
        "E_PROBABILITY", "input.detection[1]")
    rejects(0.4, {0}, {0.3}, 1.5,
        "E_CAPACITY_CONFIG", "input.visit_capacity")
    rejects(0.4, {0}, {0.3}, 10001,
        "E_HARD_VISIT_LIMIT", "input.visit_capacity")
end)

test("visit_specific_normalization_generated", function()
    local state = 719
    local function uniform()
        state = (48271 * state) % 2147483647
        return (state + 0.5) / 2147483648
    end
    for k = 1, 4 do
        for trial = 1, 20 do
            local psi, p, sum = uniform(), {}, 0
            for j = 1, k do p[j] = uniform() end
            for mask = 0, 2^k - 1 do
                local y = {}
                for j = 1, k do
                    y[j] = math.floor(mask / 2^(j-1)) % 2
                end
                sum = sum + math.exp(ll(psi, y, p))
            end
            close(sum, 1)
        end
    end
end)

test("frozen_five_visit_regression", function()
    close(ll(0.4, {1,0,1,0,1}, {0.2,0.7,0.6,0.7,0.2}),
        math.log(0.000864))
end)

test("fifty_visit_small_probability", function()
    local y, p = {}, {}
    for i = 1, 50 do y[i], p[i] = 0, 1e-6 end
    local x = 1e-6
    local logq_reference = 50 * (-x - x*x/2 - x*x*x/3 - x^4/4)
    local reference = math.log(0.6 + 0.4 * math.exp(logq_reference))
    close(ll(0.4, y, p), reference)
end)

test("near_one_and_unequal_components", function()
    local p = 1 - 2^-52
    close(ll(1, {0}, {p}), math.log(2^-52))
    close(ll(0.5, {0}, {1 - 2^-40}),
        math.log(0.5 + 0.5 * 2^-40))
end)

test("permutation_and_nonmutation", function()
    local y, p = {1,0,1}, {0.2,0.7,0.6}
    local a = ll(0.4, y, p)
    close(a, ll(0.4, {1,1,0}, {0.6,0.2,0.7}))
    assert(y[1] == 1 and p[1] == 0.2 and #y == 3 and #p == 3)
end)

test("psi_monotonicity_and_derivative", function()
    assert(ll(0.8, {0,0}, {0.3,0.4})
        < ll(0.2, {0,0}, {0.3,0.4}))
    local psi, h = 0.4, 1e-5
    local derivative = (ll(psi+h, {1,0}, {0.3,0.4})
        - ll(psi-h, {1,0}, {0.3,0.4})) / (2*h)
    assert(math.abs(derivative - 1/psi) < 1e-8)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
