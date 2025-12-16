#!/usr/bin/env -S nvim -l

-- Unit tests for parse_version() and compare_versions() functions
-- This script validates semantic version comparison logic

vim.opt.runtimepath:append('.')

local maven = require('dependencies.maven')

-- Test counters
local tests_passed = 0
local tests_failed = 0

-- Helper function to run a test
local function test(name, fn)
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

-- Helper function for assertions
local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s",
      message or "Assertion failed",
      vim.inspect(expected),
      vim.inspect(actual)))
  end
end

print("=== Testing Version Parsing and Comparison ===\n")

-- Test parse_version function
test("parse_version: stable version 1.2.3", function()
  local parsed = maven.parse_version("1.2.3")
  assert_equal(parsed.major, 1, "Major should be 1")
  assert_equal(parsed.minor, 2, "Minor should be 2")
  assert_equal(parsed.patch, 3, "Patch should be 3")
  assert_equal(parsed.prerelease_type, "", "Should have empty prerelease type for stable")
end)

test("parse_version: milestone version 1.1-M1", function()
  local parsed = maven.parse_version("1.1-M1")
  assert_equal(parsed.major, 1, "Major should be 1")
  assert_equal(parsed.minor, 1, "Minor should be 1")
  assert_equal(parsed.patch, 0, "Patch should default to 0")
  assert_equal(parsed.prerelease_type, "M", "Should be milestone")
  assert_equal(parsed.prerelease_num, 1, "Milestone number should be 1")
end)

test("parse_version: RC version 2.0-RC3", function()
  local parsed = maven.parse_version("2.0-RC3")
  assert_equal(parsed.major, 2, "Major should be 2")
  assert_equal(parsed.minor, 0, "Minor should be 0")
  assert_equal(parsed.prerelease_type, "RC", "Should be release candidate")
  assert_equal(parsed.prerelease_num, 3, "RC number should be 3")
end)

test("parse_version: alpha version 1.0-alpha", function()
  local parsed = maven.parse_version("1.0-alpha")
  assert_equal(parsed.prerelease_type, "alpha", "Should be alpha")
  assert_equal(parsed.prerelease_num, 0, "Alpha should default to 0")
end)

test("parse_version: beta version 3.2.1-beta2", function()
  local parsed = maven.parse_version("3.2.1-beta2")
  assert_equal(parsed.major, 3, "Major should be 3")
  assert_equal(parsed.minor, 2, "Minor should be 2")
  assert_equal(parsed.patch, 1, "Patch should be 1")
  assert_equal(parsed.prerelease_type, "beta", "Should be beta")
  assert_equal(parsed.prerelease_num, 2, "Beta number should be 2")
end)

test("parse_version: SNAPSHOT version 1.0-SNAPSHOT", function()
  local parsed = maven.parse_version("1.0-SNAPSHOT")
  assert_equal(parsed.prerelease_type, "SNAPSHOT", "Should be SNAPSHOT")
end)

-- Test compare_versions function
test("compare_versions: 1.0 < 2.0", function()
  local result = maven.compare_versions("1.0", "2.0")
  assert_equal(result, -1, "1.0 should be less than 2.0")
end)

test("compare_versions: 2.0 > 1.0", function()
  local result = maven.compare_versions("2.0", "1.0")
  assert_equal(result, 1, "2.0 should be greater than 1.0")
end)

test("compare_versions: 1.1 = 1.1", function()
  local result = maven.compare_versions("1.1", "1.1")
  assert_equal(result, 0, "1.1 should equal 1.1")
end)

test("compare_versions: 1.1.0 = 1.1", function()
  local result = maven.compare_versions("1.1.0", "1.1")
  assert_equal(result, 0, "1.1.0 should equal 1.1")
end)

test("compare_versions: 1.1 > 1.1-M1 (stable > milestone)", function()
  local result = maven.compare_versions("1.1", "1.1-M1")
  assert_equal(result, 1, "Stable 1.1 should be greater than milestone 1.1-M1")
end)

test("compare_versions: 1.1-M1 < 1.1 (milestone < stable)", function()
  local result = maven.compare_versions("1.1-M1", "1.1")
  assert_equal(result, -1, "Milestone 1.1-M1 should be less than stable 1.1")
end)

test("compare_versions: 1.2 > 1.1 (minor version)", function()
  local result = maven.compare_versions("1.2", "1.1")
  assert_equal(result, 1, "1.2 should be greater than 1.1")
end)

test("compare_versions: 1.1.1 > 1.1.0 (patch version)", function()
  local result = maven.compare_versions("1.1.1", "1.1.0")
  assert_equal(result, 1, "1.1.1 should be greater than 1.1.0")
end)

test("compare_versions: 1.1-M2 > 1.1-M1 (milestone numbers)", function()
  local result = maven.compare_versions("1.1-M2", "1.1-M1")
  assert_equal(result, 1, "M2 should be greater than M1")
end)

test("compare_versions: 1.1-RC1 > 1.1-M1 (RC > milestone)", function()
  local result = maven.compare_versions("1.1-RC1", "1.1-M1")
  assert_equal(result, 1, "RC should be greater than milestone")
end)

test("compare_versions: 1.1-beta > 1.1-alpha (beta > alpha)", function()
  local result = maven.compare_versions("1.1-beta", "1.1-alpha")
  assert_equal(result, 1, "Beta should be greater than alpha")
end)

test("compare_versions: 1.1-alpha > 1.1-SNAPSHOT (alpha > SNAPSHOT)", function()
  local result = maven.compare_versions("1.1-alpha", "1.1-SNAPSHOT")
  assert_equal(result, 1, "Alpha should be greater than SNAPSHOT")
end)

test("compare_versions: 1.1-M1 > 1.1-alpha (milestone > alpha)", function()
  local result = maven.compare_versions("1.1-M1", "1.1-alpha")
  assert_equal(result, 1, "Milestone should be greater than alpha")
end)

test("compare_versions: 1.2-M1 > 1.1 (future milestone > older stable)", function()
  local result = maven.compare_versions("1.2-M1", "1.1")
  assert_equal(result, 1, "1.2-M1 should be greater than 1.1")
end)

test("compare_versions: 2.10.0 > 2.9.0", function()
  local result = maven.compare_versions("2.10.0", "2.9.0")
  assert_equal(result, 1, "2.10.0 should be greater than 2.9.0")
end)

-- Critical test case from user's example
test("compare_versions: 1.1-M1 < 1.1 (user's critical case)", function()
  local result = maven.compare_versions("1.1-M1", "1.1")
  assert_equal(result, -1, "1.1-M1 should be LESS than 1.1 (milestone of current version)")
end)

test("compare_versions: 2.9.0 < 2.13.0", function()
  local result = maven.compare_versions("2.9.0", "2.13.0")
  assert_equal(result, -1, "2.9.0 should be less than 2.13.0")
end)

test("compare_versions: 2.13.1-M1 > 2.13.0", function()
  local result = maven.compare_versions("2.13.1-M1", "2.13.0")
  assert_equal(result, 1, "2.13.1-M1 should be greater than 2.13.0")
end)

-- Print summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print(string.format("Total: %d", tests_passed + tests_failed))

if tests_failed == 0 then
  print("\n✓ All tests passed!")
else
  print(string.format("\n✗ %d test(s) failed", tests_failed))
  os.exit(1)
end

