-- Test: Virtual Text Refresh Bug Fix
-- Reproduces and validates the fix for the bug where virtual text
-- was not refreshing to correct line positions after buffer edits and save.
--
-- BUG: When user edits buffer (adds/removes lines) and saves,
--      virtual text positions were stale (using old cached line numbers)
--
-- ROOT CAUSE: Installed plugin was passing `cached_data` directly to
--             `apply_virtual_text()` instead of merging with re-parsed
--             line numbers.
--
-- FIX: Cache merge logic re-parses dependencies after cache hit to get
--      current line numbers, then merges with cached version data.

vim.opt.runtimepath:append('.')

-- Clear module cache to ensure we test the latest code
package.loaded['dependencies'] = nil
package.loaded['dependencies.init'] = nil
package.loaded['dependencies.virtual_text'] = nil
package.loaded['dependencies.cache'] = nil
package.loaded['dependencies.parser'] = nil
package.loaded['dependencies.maven'] = nil
package.loaded['dependencies.config'] = nil

local dependencies = require('dependencies')
local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

print("=== Test: Virtual Text Refresh Bug Fix ===\n")

-- Setup plugin
dependencies.setup({
  patterns = { "*.sbt" },
  cache_ttl = "1d",
  auto_check_on_open = false,
})

-- Create initial buffer
local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0",
)
]]

local lines = vim.split(content, "\n", { plain = true })
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test_refresh.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_set_current_buf(bufnr)

print("Initial buffer state:")
for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
  if i <= 5 then
    print(string.format("  Line %d: %s", i, line))
  end
end

-- Create mock cache (simulating previous Maven query results)
local mock_cache_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,  -- Original line position
    latest = "0.14.15"
  },
  {
    group = "org.typelevel",
    artifact = "cats-core",
    version = "2.9.0",
    line = 3,  -- Original line position
    latest = "2.13.0"
  }
}

cache.set(bufnr, mock_cache_data)
print("\nMock cache created:")
for _, dep in ipairs(mock_cache_data) do
  print(string.format("  Line %d: %s:%s:%s -> %s",
    dep.line, dep.group, dep.artifact, dep.version, dep.latest))
end

-- First call: Should use cache and create virtual text at original positions
print("\n--- STEP 1: Initial virtual text display (using cache) ---")
dependencies.list_dependencies_with_versions(false)
vim.wait(100)

local extmarks1 = virtual_text.get_extmarks(bufnr, true)
print(string.format("Extmarks created: %d", #extmarks1))

local test_passed = true

if #extmarks1 == 2 then
  print("✓ Correct number of extmarks")

  -- Verify original positions
  if extmarks1[1][2] == 1 and extmarks1[2][2] == 2 then
    print("✓ Extmarks at original positions (row 1 and 2)")
  else
    print(string.format("✗ FAIL: Extmarks at wrong positions: row %d and %d (expected 1 and 2)",
      extmarks1[1][2], extmarks1[2][2]))
    test_passed = false
  end
else
  print(string.format("✗ FAIL: Expected 2 extmarks, got %d", #extmarks1))
  test_passed = false
end

-- Edit buffer: Add blank line at top
print("\n--- STEP 2: Edit buffer (add blank line) ---")
vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {""})

print("Buffer after edit:")
for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
  if i <= 5 then
    print(string.format("  Line %d: %s", i, line))
  end
end

-- Dependencies are now at lines 3 and 4 (shifted down by 1)
local parser = require('dependencies.parser')
local current_deps = parser.extract_dependencies(bufnr)
print("\nParser detects dependencies at:")
for _, dep in ipairs(current_deps) do
  print(string.format("  Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
end

if current_deps[1].line == 3 and current_deps[2].line == 4 then
  print("✓ Parser correctly detects new line numbers (3 and 4)")
else
  print(string.format("✗ FAIL: Parser detected lines %d and %d (expected 3 and 4)",
    current_deps[1].line, current_deps[2].line))
  test_passed = false
end

-- Clear virtual text before refresh
virtual_text.clear(bufnr)

-- Simulate save: Should refresh virtual text with NEW line positions
print("\n--- STEP 3: Simulate save (BufWritePost) ---")
dependencies.list_dependencies_with_versions(false)
vim.wait(100)

local extmarks2 = virtual_text.get_extmarks(bufnr, true)
print(string.format("Extmarks after refresh: %d", #extmarks2))

-- Verify NEW positions (should be row 2 and 3, which are lines 3 and 4)
if #extmarks2 == 2 then
  print("✓ Correct number of extmarks")

  local row1 = extmarks2[1][2]
  local row2 = extmarks2[2][2]

  print(string.format("Extmark positions: row %d and %d", row1, row2))

  if row1 == 2 and row2 == 3 then
    print("✓ PASS: Extmarks at NEW positions (row 2 and 3)")
    print("✓ Virtual text correctly follows dependencies after buffer edit")

    -- Verify the content of the lines
    local line1 = vim.api.nvim_buf_get_lines(bufnr, row1, row1 + 1, false)[1]
    local line2 = vim.api.nvim_buf_get_lines(bufnr, row2, row2 + 1, false)[1]

    if line1:match("circe") and line2:match("cats") then
      print("✓ Extmarks are on correct dependency lines (not on blank line)")
    else
      print("✗ FAIL: Extmarks on wrong lines")
      test_passed = false
    end
  else
    print(string.format("✗ FAIL: Extmarks at WRONG positions: row %d and %d (expected 2 and 3)", row1, row2))
    print("✗ BUG: Virtual text NOT refreshed with new line numbers")
    test_passed = false
  end
else
  print(string.format("✗ FAIL: Expected 2 extmarks, got %d", #extmarks2))
  test_passed = false
end

print("\n=== Test Result ===")
if test_passed then
  print("✓ ALL TESTS PASSED")
  print("\nThe bug fix works correctly:")
  print("  1. Cache merge logic re-parses dependencies after cache hit")
  print("  2. Current line numbers are merged with cached version data")
  print("  3. Virtual text displays at correct positions after buffer edits")
else
  print("✗ SOME TESTS FAILED")
  print("\nThe bug may still exist:")
  print("  - Virtual text positions not updating after buffer edits")
  print("  - Cache merge logic may not be executing correctly")
end

print("\n=== Test Complete ===")
