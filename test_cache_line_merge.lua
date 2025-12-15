#!/usr/bin/env -S nvim --headless -c "set rtp+=." -c "luafile" -c "qa"

-- Test: Verify cache merge logic updates line numbers correctly

print("=== Testing Cache Line Number Merge Logic ===\n")

-- Setup test environment
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local parser = require('dependencies.parser')
local virtual_text = require('dependencies.virtual_text')

-- Test: Simulate cache merge when lines have changed
print("Test: Cache merge updates line numbers correctly\n")

-- Create initial buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test_merge.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'libraryDependencies ++= Seq(',
  '  "io.circe" %% "circe-core" % "0.14.1",',
  '  "org.typelevel" %% "cats-core" % "2.9.0",',
  ')'
})

-- Step 1: Parse initial state (simulates first parse before cache)
print("Step 1: Initial parse")
local initial_deps = parser.extract_dependencies(bufnr)
for _, dep in ipairs(initial_deps) do
  print(string.format("  Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
end

-- Step 2: Simulate cached data with enriched versions (old line numbers)
print("\nStep 2: Cached data with old line numbers")
local cached_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,
    latest = "0.14.15"
  },
  {
    group = "org.typelevel",
    artifact = "cats-core",
    version = "2.9.0",
    line = 3,
    latest = "2.13.0"
  }
}
for _, dep in ipairs(cached_data) do
  print(string.format("  Line %d: %s:%s:%s -> %s", dep.line, dep.group, dep.artifact, dep.version, dep.latest))
end

-- Step 3: User adds a blank line at the beginning
print("\nStep 3: User adds blank line at beginning")
vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {''})
local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
for i, line in ipairs(new_lines) do
  if line ~= '' then
    print(string.format("  Line %d: %s", i, line))
  end
end

-- Step 4: Re-parse to get current line numbers
print("\nStep 4: Re-parse to get current line numbers")
local current_deps = parser.extract_dependencies(bufnr)
for _, dep in ipairs(current_deps) do
  print(string.format("  Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
end

-- Step 5: Merge logic (simulates what init.lua does)
print("\nStep 5: Merge cache data with current line numbers")
local merged_data = {}
for _, current_dep in ipairs(current_deps) do
  local dep_key = string.format("%s:%s:%s", current_dep.group, current_dep.artifact, current_dep.version)

  -- Search in cache
  local found_in_cache = false
  for _, cached_dep in ipairs(cached_data) do
    local cached_key = string.format("%s:%s:%s", cached_dep.group, cached_dep.artifact, cached_dep.version)
    if dep_key == cached_key then
      -- Use CURRENT line but CACHED version
      table.insert(merged_data, {
        group = current_dep.group,
        artifact = current_dep.artifact,
        version = current_dep.version,
        line = current_dep.line,  -- UPDATED LINE
        latest = cached_dep.latest  -- CACHED VERSION
      })
      found_in_cache = true
      break
    end
  end

  if not found_in_cache then
    table.insert(merged_data, {
      group = current_dep.group,
      artifact = current_dep.artifact,
      version = current_dep.version,
      line = current_dep.line,
      latest = "unknown"
    })
  end
end

print("  Merged data:")
for _, dep in ipairs(merged_data) do
  print(string.format("  Line %d: %s:%s:%s -> %s", dep.line, dep.group, dep.artifact, dep.version, dep.latest))
end

-- Step 6: Apply virtual text with merged data
print("\nStep 6: Apply virtual text with corrected line numbers")
vim.api.nvim_set_current_buf(bufnr)
local count = virtual_text.apply_virtual_text(bufnr, merged_data)
print("  Extmarks created: " .. count)

-- Verify extmarks are at correct lines
local extmarks = virtual_text.get_extmarks(bufnr, true)
print("  Extmarks verification:")
for _, mark in ipairs(extmarks) do
  local id, row, col = mark[1], mark[2], mark[3]
  local line_num = row + 1
  local line_content = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  print(string.format("    Line %d: %s", line_num, line_content))
end

-- Validation
print("\n=== Validation ===")
local success = true

-- Check that we have 2 extmarks
if #extmarks ~= 2 then
  print("✗ FAIL: Expected 2 extmarks, got " .. #extmarks)
  success = false
else
  print("✓ PASS: Correct number of extmarks (2)")
end

-- Check that extmarks are at lines 3 and 4 (0-indexed: rows 2 and 3)
local expected_rows = {2, 3}  -- 0-indexed
for i, mark in ipairs(extmarks) do
  local row = mark[2]
  if row ~= expected_rows[i] then
    print(string.format("✗ FAIL: Extmark %d at row %d, expected %d", i, row, expected_rows[i]))
    success = false
  else
    print(string.format("✓ PASS: Extmark %d at correct row %d (line %d)", i, row, row + 1))
  end
end

if success then
  print("\n✓ ALL TESTS PASSED")
  print("Cache merge correctly updates line numbers!")
else
  print("\n✗ SOME TESTS FAILED")
end

