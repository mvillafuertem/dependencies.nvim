#!/usr/bin/env -S nvim --headless -c "set rtp+=." -c "luafile" -c "qa"

-- Test: Verificar comportamiento cuando las líneas cambian pero se usa cache

print("=== Testing Cache with Changing Line Numbers ===\n")

-- Setup test environment
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local virtual_text = require('dependencies.virtual_text')
local parser = require('dependencies.parser')

-- Test 1: Parse buffer, then modify it, then apply cached virtual text
print("Test 1: Cached line numbers become stale after editing")

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test_stale_lines.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'libraryDependencies ++= Seq(',
  '  "io.circe" %% "circe-core" % "0.14.1",',
  '  "org.typelevel" %% "cats-core" % "2.9.0",',
  ')'
})

-- Parse dependencies (simulates initial cache creation)
local deps = parser.extract_dependencies(bufnr)
print("  Initial dependencies parsed:")
for _, dep in ipairs(deps) do
  print(string.format("    Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
end

-- Simulate enriched data (like what cache would store)
local cached_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,  -- Original line number
    latest = "0.14.15"
  },
  {
    group = "org.typelevel",
    artifact = "cats-core",
    version = "2.9.0",
    line = 3,  -- Original line number
    latest = "2.13.0"
  }
}

-- Apply virtual text with original line numbers
virtual_text.apply_virtual_text(bufnr, cached_data)
local extmarks_before = virtual_text.get_extmarks(bufnr, true)
print("\n  Virtual text applied at lines: 2, 3")
print("  Extmarks count: " .. #extmarks_before)

-- Now simulate user editing: add a blank line at the top
print("\n  User adds a blank line at the beginning...")
vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {''})

-- Show new buffer content
local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
print("\n  New buffer content:")
for i, line in ipairs(new_lines) do
  print(string.format("    %d: %s", i, line))
end

-- The cached data still has old line numbers (2, 3)
-- But now the dependencies are actually at lines 3, 4
print("\n  Cached line numbers: 2, 3")
print("  Actual dependency lines: 3, 4")

-- Check where extmarks are now
local extmarks_after = virtual_text.get_extmarks(bufnr, true)
print("\n  Extmarks after editing:")
for _, mark in ipairs(extmarks_after) do
  local id, row, col = mark[1], mark[2], mark[3]
  print(string.format("    Extmark at line %d (0-indexed row %d)", row + 1, row))
end

-- Parse again to see actual current lines
local deps_after = parser.extract_dependencies(bufnr)
print("\n  Re-parsed dependencies:")
for _, dep in ipairs(deps_after) do
  print(string.format("    Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
end

print("\n  ⚠️  PROBLEM IDENTIFIED:")
print("  - Cached data has stale line numbers (2, 3)")
print("  - Actual dependencies are now at lines (3, 4)")
print("  - Virtual text appears at wrong lines!")

-- Test 2: Demonstrate the fix - always re-parse before applying cache
print("\n\nTest 2: Solution - invalidate cache when buffer is modified")
print("  The cache should be invalidated when:")
print("  - User edits the file (buffer modified)")
print("  - BufWritePost saves changes")
print("  - Parser re-extracts dependencies with correct line numbers")
print("  - New cache is created with updated line numbers")

print("\n  Current behavior:")
print("  ✗ Cache is used even after editing (wrong line numbers)")
print("\n  Proposed fix:")
print("  ✓ Invalidate cache on buffer modification")
print("  ✓ Or: Always re-parse to get current line numbers")

print("\n=== Test Complete ===")

