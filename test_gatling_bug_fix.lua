#!/usr/bin/env -S nvim -l

-- Test script to verify Gatling version bug fix
-- Bug: When user is on latest version, plugin showed stale Solr version
-- Fix: Return current version when no better versions exist (prevents Solr fallback)

package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local parser = require('dependencies.parser')
local maven = require('dependencies.maven')
local virtual_text = require('dependencies.virtual_text')

print("=== Gatling Version Bug Fix Test ===\n")

-- Create a test buffer with Gatling dependency
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test_build.sbt")

local content = [[
val gatlingVersion = "3.14.9"

libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion % "test,it",
)
]]

local lines = vim.split(content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

print("Test buffer created with content:")
print(content)
print("")

-- Extract dependencies
print("--- Step 1: Extract Dependencies ---")
local deps = parser.extract_dependencies(bufnr)
print(string.format("Found %d dependencies:", #deps))
for i, dep in ipairs(deps) do
  print(string.format("  %d) Line %d: %s:%s:%s",
    i, dep.line, dep.group, dep.artifact, dep.version))
end
print("")

if #deps == 0 then
  print("❌ ERROR: No dependencies extracted!")
  print("This test requires the parser to work correctly.")
  return
end

-- Test with async Maven API
print("--- Step 2: Fetch Latest Versions (Async) ---")
print("Querying Maven Central...")
print("")

local test_complete = false

maven.enrich_with_latest_versions_async(deps, nil, function(deps_with_versions)
  print("Maven query complete!")
  print("")

  for i, dep_info in ipairs(deps_with_versions) do
    print(string.format("Dependency %d:", i))
    print(string.format("  Group:    %s", dep_info.group))
    print(string.format("  Artifact: %s", dep_info.artifact))
    print(string.format("  Current:  %s", dep_info.version))

    if type(dep_info.latest) == "table" then
      print(string.format("  Latest:   %s (table)", table.concat(dep_info.latest, ", ")))
    else
      print(string.format("  Latest:   %s", dep_info.latest or "nil"))
    end
    print(string.format("  Line:     %d", dep_info.line))
    print("")
  end

  -- Analyze results
  print("--- Step 3: Analysis ---")
  local gatling_dep = deps_with_versions[1]

  if not gatling_dep then
    print("❌ ERROR: No dependency data returned")
    test_complete = true
    return
  end

  local current = gatling_dep.version
  local latest = type(gatling_dep.latest) == "table"
    and gatling_dep.latest[1]
    or gatling_dep.latest

  print(string.format("Current version: %s", current))
  print(string.format("Latest version:  %s", latest or "nil"))
  print("")

  -- Check for the bug
  if latest == "3.13.5" then
    print("❌ BUG STILL EXISTS!")
    print("   The plugin is showing stale Solr version (3.13.5)")
    print("   This means the fix didn't work or wasn't applied correctly")
    print("")
    print("   Root cause: process_metadata_xml() returned nil")
    print("   → Fell back to Solr Search API")
    print("   → Got stale version from Solr")
  elseif latest == "3.14.9" then
    print("✅ BUG FIXED!")
    print("   The plugin correctly shows current version as latest")
    print("   process_metadata_xml() returned current_version when no updates available")
    print("   → No fallback to Solr")
    print("   → Correct behavior")
  elseif latest == "unknown" or latest == nil then
    print("⚠️  UNEXPECTED: Latest version is unknown/nil")
    print("   This might indicate a network error or API change")
  elseif latest and latest > "3.14.9" then
    print("✅ CORRECT: Newer version available")
    print(string.format("   Latest version (%s) is newer than current (3.14.9)", latest))
  else
    print(string.format("⚠️  UNEXPECTED: Latest = %s", latest or "nil"))
  end
  print("")

  -- Test virtual text behavior
  print("--- Step 4: Virtual Text Behavior ---")
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  print(string.format("Extmarks created: %d", #extmarks))

  if current == latest then
    if #extmarks == 0 then
      print("✅ CORRECT: No virtual text shown (user is up to date)")
    else
      print("❌ ERROR: Virtual text shown even though current == latest")
      for _, mark in ipairs(extmarks) do
        print(string.format("   Line %d: %s", mark[2], mark[4].virt_text[1][1]))
      end
    end
  else
    if #extmarks > 0 then
      print("✅ CORRECT: Virtual text shown (update available)")
      for _, mark in ipairs(extmarks) do
        print(string.format("   Line %d: %s", mark[2], mark[4].virt_text[1][1]))
      end
    else
      print("❌ ERROR: No virtual text shown even though update is available")
    end
  end
  print("")

  print("=== Test Complete ===")
  test_complete = true
end)

-- Wait for async callback (max 10 seconds)
local wait_start = vim.loop.now()
while not test_complete do
  vim.wait(100)
  if vim.loop.now() - wait_start > 10000 then
    print("❌ TIMEOUT: Test did not complete within 10 seconds")
    break
  end
end

-- Cleanup
vim.api.nvim_buf_delete(bufnr, { force = true })

