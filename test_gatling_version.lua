#!/usr/bin/env -S nvim -l

-- Test script to debug Gatling version issue
-- User reports: Plugin shows 3.13.5 when build.sbt has 3.14.9

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local maven = require('dependencies.maven')

print("=== Gatling Version Debug Test ===\n")

local group = "io.gatling.highcharts"
local artifact = "gatling-charts-highcharts"
local current_version = "3.14.9"

print(string.format("Testing: %s:%s", group, artifact))
print(string.format("Current version in build.sbt: %s", current_version))
print("")

-- Test 1: Use enrich_with_latest_versions (synchronous, default behavior)
print("--- Test 1: enrich_with_latest_versions (include_prerelease = false) ---")
local deps_default = {{
  group = group,
  artifact = artifact,
  version = current_version,
  line = 1
}}
maven.enrich_with_latest_versions(deps_default, nil, false)
print(string.format("Current: %s", deps_default[1].version))
print(string.format("Latest:  %s", deps_default[1].latest or "nil"))
print(string.format("Type:    %s", type(deps_default[1].latest)))
print("")

-- Test 2: With include_prerelease = true
print("--- Test 2: enrich_with_latest_versions (include_prerelease = true) ---")
local deps_with_prerelease = {{
  group = group,
  artifact = artifact,
  version = current_version,
  line = 1
}}
maven.enrich_with_latest_versions(deps_with_prerelease, nil, true)
print(string.format("Current: %s", deps_with_prerelease[1].version))
local latest = deps_with_prerelease[1].latest
if type(latest) == "table" then
  print(string.format("Latest:  %s", table.concat(latest, ", ")))
  print(string.format("Type:    table with %d versions", #latest))
else
  print(string.format("Latest:  %s", latest or "nil"))
  print(string.format("Type:    %s", type(latest)))
end
print("")

-- Test 3: Version comparison
print("--- Test 3: Version Comparison ---")
if maven.compare_versions then
  local cmp_result = maven.compare_versions("3.14.9", "3.13.5")
  print(string.format("compare_versions('3.14.9', '3.13.5') = %d", cmp_result))
  print(string.format("Expected: 1 (3.14.9 > 3.13.5)"))
  print(string.format("Result: %s", cmp_result == 1 and "CORRECT ✅" or "INCORRECT ❌"))
  print("")

  local cmp_result2 = maven.compare_versions("3.13.5", "3.14.9")
  print(string.format("compare_versions('3.13.5', '3.14.9') = %d", cmp_result2))
  print(string.format("Expected: -1 (3.13.5 < 3.14.9)"))
  print(string.format("Result: %s", cmp_result2 == -1 and "CORRECT ✅" or "INCORRECT ❌"))
  print("")

  -- Test with current version from user's build.sbt
  local cmp_current = maven.compare_versions(current_version, deps_default[1].latest)
  print(string.format("compare_versions('%s', '%s') = %d", current_version, deps_default[1].latest, cmp_current))
  if cmp_current == 1 then
    print("Result: Current version is NEWER than 'latest' ❌ (BUG!)")
  elseif cmp_current == -1 then
    print("Result: Current version is OLDER than 'latest' ✅ (correct)")
  else
    print("Result: Current version EQUALS 'latest' (up to date)")
  end
else
  print("compare_versions function not exported")
end
print("")

-- Test 4: Version parsing
print("--- Test 4: Version Parsing ---")
if maven.parse_version then
  local parsed_3149 = maven.parse_version("3.14.9")
  print("parse_version('3.14.9'):")
  print(vim.inspect(parsed_3149))
  print("")

  local parsed_3135 = maven.parse_version("3.13.5")
  print("parse_version('3.13.5'):")
  print(vim.inspect(parsed_3135))
  print("")

  if deps_default[1].latest and deps_default[1].latest ~= "unknown" then
    local parsed_latest = maven.parse_version(deps_default[1].latest)
    print(string.format("parse_version('%s'):", deps_default[1].latest))
    print(vim.inspect(parsed_latest))
  end
else
  print("parse_version function not exported")
end
print("")

print("=== Analysis ===")
if deps_default[1].latest == "3.13.5" then
  print("⚠️  ISSUE REPRODUCED: Maven Central returned 3.13.5 as latest")
  print("    This is likely a Maven Central API/indexing issue")
  print("    Similar to the netty-tcnative issue we fixed before")
elseif deps_default[1].latest == "unknown" then
  print("⚠️  Maven Central query failed (returned 'unknown')")
elseif maven.compare_versions and maven.compare_versions(current_version, deps_default[1].latest) == 1 then
  print(string.format("⚠️  Current version (%s) is NEWER than Maven's 'latest' (%s)",
    current_version, deps_default[1].latest))
  print("    This suggests Maven Central has stale data")
else
  print("✅ No issue detected - plugin returned correct latest version")
end

print("\n=== Debug Test Complete ===")

