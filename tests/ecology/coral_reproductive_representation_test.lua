-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Credit: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
local m = require("lua.ecology.coral_reproductive_representation")
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

local function run(counts)
    return m.evaluate({schema_version = 1, mature_colony_counts = counts})
end

test("balanced_and_dominated_samples", function()
    local a, b = run({2,2,2,2,2}).value, run({6,1,1,1,1}).value
    assert(a.genotype_to_colony_ratio == b.genotype_to_colony_ratio)
    assert(a.effective_sampled_genotypes == 5)
    assert(b.effective_sampled_genotypes == 2.5)
    assert(a.different_genotype_pairs == 40)
    assert(b.different_genotype_pairs == 30)
end)

test("empty_and_singleton_are_explicit", function()
    local a, b = run({}).value, run({1}).value
    assert(a.status == "screen_no_assessed_mature_colonies")
    assert(a.effective_sampled_genotypes == nil)
    assert(b.different_genotype_pair_fraction == nil)
end)

test("one_genotype_has_no_different_genotype_pairs", function()
    local r = run({10})
    assert(r.ok and r.value.different_genotype_pairs == 0)
    assert(not r.value.interpretation_limits.reproductive_failure_established)
end)

test("invalid_inputs", function()
    assert(run({0}).error.code == "E_COUNT")
    assert(run({1,0/0}).error.code == "E_COUNT")
    assert(run({[1]=1,[3]=2}).error.code == "E_SEQUENCE_GAP")
end)

test("permutation_and_nonmutation", function()
    local counts = {6,1,1,1,1}
    local a, b = run(counts), run({1,6,1,1,1})
    assert(a.ok and b.ok)
    assert(a.value.different_genotype_pairs == b.value.different_genotype_pairs)
    a.value.mature_colony_counts[1] = 99
    assert(counts[1] == 6)
end)

io.write("SUMMARY\tfailures\t", tostring(failures), "\n")
os.exit(failures == 0 and 0 or 1)
