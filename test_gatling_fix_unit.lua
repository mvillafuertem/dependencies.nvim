#!/usr/bin/env -S nvim -l

-- Unit test for Gatling version bug fix
-- Tests the process_metadata_xml function directly with mock XML data

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local maven = require('dependencies.maven')

print("=== Gatling Bug Fix - Unit Test ===\n")

-- Mock XML response from Maven Central for Gatling
-- This simulates what maven-metadata.xml returns for io.gatling.highcharts:gatling-charts-highcharts
local mock_xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <groupId>io.gatling.highcharts</groupId>
  <artifactId>gatling-charts-highcharts</artifactId>
  <versioning>
    <latest>3.14.9</latest>
    <release>3.14.9</release>
    <versions>
      <version>3.11.3</version>
      <version>3.11.4</version>
      <version>3.11.5</version>
      <version>3.12.0</version>
      <version>3.13.0</version>
      <version>3.13.1</version>
      <version>3.13.2</version>
      <version>3.13.3</version>
      <version>3.13.4</version>
      <version>3.13.5</version>
      <version>3.14.0</version>
      <version>3.14.1</version>
      <version>3.14.2</version>
      <version>3.14.3</version>
      <version>3.14.4</version>
      <version>3.14.5</version>
      <version>3.14.6</version>
      <version>3.14.7</version>
      <version>3.14.8</version>
      <version>3.14.9</version>
    </versions>
  </versioning>
</metadata>
]]

print("Test 1: User on LATEST version (3.14.9)")
print("==========================================")
print("Current version: 3.14.9")
print("Expected: Return 3.14.9 (prevents Solr fallback)")
print("")

local result1 = maven.process_metadata_xml(mock_xml, "3.14.9", false)
print(string.format("Result: %s", result1 or "nil"))

if result1 == "3.14.9" then
  print("✅ PASS: Correctly returned current version")
  print("   → No fallback to Solr will occur")
  print("   → Virtual text will NOT be shown (current == latest)")
elseif result1 == nil then
  print("❌ FAIL: Returned nil (BUG NOT FIXED!)")
  print("   → Will fall back to Solr Search API")
  print("   → Will show stale version 3.13.5")
else
  print(string.format("⚠️  UNEXPECTED: Returned %s", result1))
end
print("")

print("Test 2: User on OLD version (3.13.0)")
print("=====================================")
print("Current version: 3.13.0")
print("Expected: Return 3.14.9 (latest stable)")
print("")

local result2 = maven.process_metadata_xml(mock_xml, "3.13.0", false)
print(string.format("Result: %s", result2 or "nil"))

if result2 == "3.14.9" then
  print("✅ PASS: Correctly returned latest version")
  print("   → Virtual text will show: ← latest: 3.14.9")
elseif result2 == nil then
  print("❌ FAIL: Returned nil")
else
  print(string.format("⚠️  UNEXPECTED: Returned %s", result2))
end
print("")

print("Test 3: User on INTERMEDIATE version (3.14.5)")
print("==============================================")
print("Current version: 3.14.5")
print("Expected: Return 3.14.9 (latest stable, newer than current)")
print("")

local result3 = maven.process_metadata_xml(mock_xml, "3.14.5", false)
print(string.format("Result: %s", result3 or "nil"))

if result3 == "3.14.9" then
  print("✅ PASS: Correctly returned latest version")
  print("   → Virtual text will show: ← latest: 3.14.9")
elseif result3 == nil then
  print("❌ FAIL: Returned nil")
else
  print(string.format("⚠️  UNEXPECTED: Returned %s", result3))
end
print("")

print("Test 4: User on FUTURE version (4.0.0)")
print("========================================")
print("Current version: 4.0.0")
print("Expected: Return 4.0.0 (no better versions available)")
print("")

local result4 = maven.process_metadata_xml(mock_xml, "4.0.0", false)
print(string.format("Result: %s", result4 or "nil"))

if result4 == "4.0.0" then
  print("✅ PASS: Correctly returned current version")
  print("   → User has a newer version than Maven Central (local build?)")
  print("   → No virtual text shown")
elseif result4 == nil then
  print("❌ FAIL: Returned nil (should return current version)")
else
  print(string.format("⚠️  UNEXPECTED: Returned %s", result4))
end
print("")

-- Summary
print("=== Test Summary ===")
local passed = 0
local total = 4

if result1 == "3.14.9" then passed = passed + 1 end
if result2 == "3.14.9" then passed = passed + 1 end
if result3 == "3.14.9" then passed = passed + 1 end
if result4 == "4.0.0" then passed = passed + 1 end

print(string.format("Passed: %d/%d", passed, total))

if passed == total then
  print("✅ ALL TESTS PASSED - Bug is fixed!")
else
  print(string.format("❌ %d tests failed", total - passed))
end
print("")

-- Impact analysis
print("=== Impact Analysis ===")
if result1 == "3.14.9" then
  print("✅ Gatling 3.14.9 bug is FIXED")
  print("   Users on latest version will no longer see stale Solr suggestions")
else
  print("❌ Gatling 3.14.9 bug still EXISTS")
  print("   Users on latest version will still see stale Solr version (3.13.5)")
end
print("")

print("=== Test Complete ===")

