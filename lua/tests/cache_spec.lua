-- Cache Module Tests
-- Run from command line: nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/cache_spec.lua" -c "qa"

local cache = require('dependencies.cache')
local helper = require('tests.test_helper')

-- Extract helper functions for convenience
local assert_equal = helper.assert_equal
local assert_table_equal = helper.assert_table_equal
local test = helper.test

-- Reset test counters at the start
helper.reset_counters()

-- Counter for unique buffer names
local buffer_counter = 0

-- Setup a buffer with content and a unique filename for cache tests
local function setup_buffer_with_content(content)
  buffer_counter = buffer_counter + 1
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

  -- Set a unique buffer name so cache can work
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  local bufname = tmpdir .. "/test_build_" .. buffer_counter .. ".sbt"
  vim.api.nvim_buf_set_name(bufnr, bufname)

  vim.wait(100)
  return bufnr
end

io.write("=== Cache Module Tests ===\n")
io.flush()

-- ============================================================================
-- Basic tests: parse_ttl function (pure function, no I/O)
-- ============================================================================

test("parse_ttl converts minutes correctly", function()
  -- g i v e n
  local ttl_str = "30m"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 1800, "30 minutes should equal 1800 seconds")
end)

test("parse_ttl converts hours correctly", function()
  -- g i v e n
  local ttl_str = "6h"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 21600, "6 hours should equal 21600 seconds")
end)

test("parse_ttl converts days correctly", function()
  -- g i v e n
  local ttl_str = "1d"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 86400, "1 day should equal 86400 seconds")
end)

test("parse_ttl converts weeks correctly", function()
  -- g i v e n
  local ttl_str = "1w"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 604800, "1 week should equal 604800 seconds")
end)

test("parse_ttl converts months correctly", function()
  -- g i v e n
  local ttl_str = "1M"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 2592000, "1 month should equal 2592000 seconds (30 days)")
end)

test("parse_ttl handles invalid format and returns default", function()
  -- g i v e n
  local ttl_str = "invalid"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 86400, "Invalid format should return default (1 day = 86400 seconds)")
end)

test("parse_ttl handles non-string input and returns default", function()
  -- g i v e n
  local ttl_input = 123

  -- w h e n
  local seconds = cache.parse_ttl(ttl_input)

  -- t h e n
  assert_equal(seconds, 86400, "Non-string input should return default (1 day = 86400 seconds)")
end)

test("parse_ttl handles multiple digit values", function()
  -- g i v e n
  local ttl_str = "15d"

  -- w h e n
  local seconds = cache.parse_ttl(ttl_str)

  -- t h e n
  assert_equal(seconds, 1296000, "15 days should equal 1296000 seconds")
end)

-- ============================================================================
-- Intermediate tests: set and get operations
-- ============================================================================

test("set and get cache data successfully", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.4.2"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 2, latest = "1.4.5" }
  }

  -- w h e n
  local set_success = cache.set(bufnr, test_data)
  local retrieved_data = cache.get(bufnr)

  -- t h e n
  assert_equal(set_success, true, "Cache set should succeed")
  assert_equal(type(retrieved_data), "table", "Retrieved data should be a table")
  assert_equal(#retrieved_data, 1, "Should retrieve 1 dependency")
  assert_equal(retrieved_data[1].group, "com.typesafe", "Group should match")
  assert_equal(retrieved_data[1].artifact, "config", "Artifact should match")
  assert_equal(retrieved_data[1].version, "1.4.2", "Version should match")
  assert_equal(retrieved_data[1].latest, "1.4.5", "Latest version should match")

  -- Cleanup
  cache.clear(bufnr)
end)

test("get returns nil when cache does not exist", function()
  -- g i v e n
  local content = [[
// Empty build.sbt for testing
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local retrieved_data = cache.get(bufnr)

  -- t h e n
  assert_equal(retrieved_data, nil, "Should return nil when cache doesn't exist")
end)

test("set handles empty data array", function()
  -- g i v e n
  local content = [[
// Empty dependencies
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {}

  -- w h e n
  local set_success = cache.set(bufnr, test_data)
  local retrieved_data = cache.get(bufnr)

  -- t h e n
  assert_equal(set_success, true, "Cache set should succeed with empty array")
  assert_equal(type(retrieved_data), "table", "Retrieved data should be a table")
  assert_equal(#retrieved_data, 0, "Should retrieve empty array")

  -- Cleanup
  cache.clear(bufnr)
end)

test("set handles multiple dependencies", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.4.2",
  "io.circe" %% "circe-core" % "0.14.1"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 2, latest = "1.4.5" },
    { group = "io.circe", artifact = "circe-core", version = "0.14.1", line = 3, latest = "0.14.15" }
  }

  -- w h e n
  local set_success = cache.set(bufnr, test_data)
  local retrieved_data = cache.get(bufnr)

  -- t h e n
  assert_equal(set_success, true, "Cache set should succeed")
  assert_equal(#retrieved_data, 2, "Should retrieve 2 dependencies")
  assert_equal(retrieved_data[1].latest, "1.4.5", "First dependency latest version should match")
  assert_equal(retrieved_data[2].latest, "0.14.15", "Second dependency latest version should match")

  -- Cleanup
  cache.clear(bufnr)
end)

-- ============================================================================
-- Cache validity tests: is_valid function
-- ============================================================================

test("is_valid returns true for fresh cache within TTL", function()
  -- g i v e n
  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr, test_data)

  -- w h e n
  local is_valid = cache.is_valid(bufnr, "1d")

  -- t h e n
  assert_equal(is_valid, true, "Freshly cached data should be valid within 1 day TTL")

  -- Cleanup
  cache.clear(bufnr)
end)

test("is_valid returns false when cache does not exist", function()
  -- g i v e n
  local content = [[
// No cache file exists
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local is_valid = cache.is_valid(bufnr, "1d")

  -- t h e n
  assert_equal(is_valid, false, "Should return false when cache doesn't exist")
end)

test("is_valid works with different TTL formats", function()
  -- g i v e n
  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr, test_data)

  -- w h e n - test multiple TTL formats
  local is_valid_30m = cache.is_valid(bufnr, "30m")
  local is_valid_6h = cache.is_valid(bufnr, "6h")
  local is_valid_1w = cache.is_valid(bufnr, "1w")

  -- t h e n
  assert_equal(is_valid_30m, true, "Should be valid with 30 minutes TTL")
  assert_equal(is_valid_6h, true, "Should be valid with 6 hours TTL")
  assert_equal(is_valid_1w, true, "Should be valid with 1 week TTL")

  -- Cleanup
  cache.clear(bufnr)
end)

-- ============================================================================
-- Cache clearing tests
-- ============================================================================

test("clear removes cache for specific buffer", function()
  -- g i v e n
  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr, test_data)

  -- Verify cache exists before clearing
  local data_before = cache.get(bufnr)
  assert_equal(type(data_before), "table", "Cache should exist before clearing")

  -- w h e n
  local clear_success = cache.clear(bufnr)

  -- t h e n
  assert_equal(clear_success, true, "Clear should succeed")
  local data_after = cache.get(bufnr)
  assert_equal(data_after, nil, "Cache should be nil after clearing")
end)

test("clear_all removes all cached data", function()
  -- g i v e n - Create multiple cache entries
  local content1 = "// Buffer 1"
  local content2 = "// Buffer 2"
  local bufnr1 = setup_buffer_with_content(content1)
  local bufnr2 = setup_buffer_with_content(content2)

  local test_data1 = {{ group = "org.example", artifact = "dep1", version = "1.0", line = 1, latest = "1.1" }}
  local test_data2 = {{ group = "org.example", artifact = "dep2", version = "2.0", line = 1, latest = "2.1" }}

  cache.set(bufnr1, test_data1)
  cache.set(bufnr2, test_data2)

  -- Verify both caches exist
  assert_equal(type(cache.get(bufnr1)), "table", "Cache 1 should exist before clearing all")
  assert_equal(type(cache.get(bufnr2)), "table", "Cache 2 should exist before clearing all")

  -- w h e n
  local clear_all_success = cache.clear_all()

  -- t h e n
  assert_equal(clear_all_success, true, "Clear all should succeed")
  assert_equal(cache.get(bufnr1), nil, "Cache 1 should be nil after clearing all")
  assert_equal(cache.get(bufnr2), nil, "Cache 2 should be nil after clearing all")
end)

-- ============================================================================
-- Statistics and introspection tests
-- ============================================================================

test("get_stats returns cache statistics", function()
  -- g i v e n
  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr, test_data)

  -- w h e n
  local stats = cache.get_stats()

  -- t h e n
  assert_equal(type(stats), "table", "Stats should be a table")
  assert_equal(type(stats.entry_count), "number", "Should have entry_count field")
  assert_equal(type(stats.cache_dir), "string", "Should have cache_dir field")
  assert_equal(type(stats.cache_files), "table", "Should have cache_files field")

  -- The entry_count should be at least 1 (the one we just added)
  assert_equal(stats.entry_count >= 1, true, "Should have at least 1 cache entry")

  -- Cleanup
  cache.clear(bufnr)
end)

test("get_stats shows zero entries after clear_all", function()
  -- g i v e n
  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr, test_data)
  cache.clear_all()

  -- w h e n
  local stats = cache.get_stats()

  -- t h e n
  assert_equal(stats.entry_count, 0, "Should have 0 entries after clear_all")
end)

-- ============================================================================
-- Integration tests: Complex scenarios
-- ============================================================================

test("complete workflow: set → get → is_valid → clear", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.4.2",
  "io.circe" %% "circe-core" % "0.14.1"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 2, latest = "1.4.5" },
    { group = "io.circe", artifact = "circe-core", version = "0.14.1", line = 3, latest = "0.14.15" }
  }

  -- w h e n - Step 1: Set cache
  local set_success = cache.set(bufnr, test_data)

  -- t h e n
  assert_equal(set_success, true, "Step 1: Cache set should succeed")

  -- w h e n - Step 2: Get cache
  local retrieved_data = cache.get(bufnr)

  -- t h e n
  assert_equal(#retrieved_data, 2, "Step 2: Should retrieve 2 dependencies")
  assert_table_equal(retrieved_data, test_data, "Step 2: Retrieved data should match original")

  -- w h e n - Step 3: Check validity
  local is_valid = cache.is_valid(bufnr, "1d")

  -- t h e n
  assert_equal(is_valid, true, "Step 3: Cache should be valid")

  -- w h e n - Step 4: Clear cache
  local clear_success = cache.clear(bufnr)

  -- t h e n
  assert_equal(clear_success, true, "Step 4: Clear should succeed")
  assert_equal(cache.get(bufnr), nil, "Step 4: Cache should be nil after clearing")
  assert_equal(cache.is_valid(bufnr, "1d"), false, "Step 4: Cache should not be valid after clearing")
end)

test("cache persists across buffer operations", function()
  -- g i v e n - Create a shared project directory
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")

  local content = [[
libraryDependencies += "com.typesafe" % "config" % "1.4.2"
]]

  -- Create first buffer in shared directory
  local bufnr1 = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr1, 'filetype', 'scala')
  vim.api.nvim_buf_set_name(bufnr1, tmpdir .. "/build.sbt")

  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }
  cache.set(bufnr1, test_data)

  -- w h e n - Create a second buffer in the SAME directory (simulates reopening file)
  local bufnr2 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr2, 'filetype', 'scala')
  vim.api.nvim_buf_set_name(bufnr2, tmpdir .. "/other.sbt")

  local retrieved_data = cache.get(bufnr2)

  -- t h e n
  assert_equal(type(retrieved_data), "table", "Cache should persist across buffer instances in same directory")
  assert_equal(#retrieved_data, 1, "Should retrieve same dependency")
  assert_equal(retrieved_data[1].latest, "1.4.5", "Latest version should match")

  -- Cleanup
  cache.clear(bufnr1)
end)

test("cache handles buffer with no name gracefully", function()
  -- g i v e n - Create a buffer without setting a name
  local bufnr = vim.api.nvim_create_buf(false, true)
  local test_data = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1, latest = "1.4.5" }
  }

  -- w h e n
  local set_success = cache.set(bufnr, test_data)
  local get_result = cache.get(bufnr)
  local is_valid_result = cache.is_valid(bufnr, "1d")
  local clear_success = cache.clear(bufnr)

  -- t h e n
  assert_equal(set_success, false, "Set should fail for buffer without name")
  assert_equal(get_result, nil, "Get should return nil for buffer without name")
  assert_equal(is_valid_result, false, "is_valid should return false for buffer without name")
  assert_equal(clear_success, false, "Clear should return false for buffer without name")
end)

test("cache correctly handles same project with different files", function()
  -- g i v e n - Two buffers in same project directory
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")

  local content1 = "// File 1"
  local content2 = "// File 2"

  -- Create first buffer in shared directory
  local bufnr1 = vim.api.nvim_create_buf(false, true)
  local lines1 = vim.split(content1, "\n")
  vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, lines1)
  vim.api.nvim_buf_set_option(bufnr1, 'filetype', 'scala')
  vim.api.nvim_buf_set_name(bufnr1, tmpdir .. "/build.sbt")

  -- Create second buffer in SAME directory
  local bufnr2 = vim.api.nvim_create_buf(false, true)
  local lines2 = vim.split(content2, "\n")
  vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, lines2)
  vim.api.nvim_buf_set_option(bufnr2, 'filetype', 'scala')
  vim.api.nvim_buf_set_name(bufnr2, tmpdir .. "/other.sbt")

  -- Both should point to same cache file (same project directory)
  local test_data1 = {
    { group = "dep", artifact = "artifact", version = "1.0.0", line = 1, latest = "1.1.0" }
  }
  local test_data2 = {
    { group = "dep", artifact = "artifact", version = "2.0.0", line = 1, latest = "2.1.0" }
  }

  -- w h e n
  cache.set(bufnr1, test_data1)
  cache.set(bufnr2, test_data2) -- This should overwrite the first one (same cache file)

  local retrieved1 = cache.get(bufnr1)
  local retrieved2 = cache.get(bufnr2)

  -- t h e n
  -- Both should return the same data (last set wins, same cache file)
  assert_equal(#retrieved1, 1, "Buffer 1 should retrieve 1 dependency")
  assert_equal(#retrieved2, 1, "Buffer 2 should retrieve 1 dependency")
  assert_equal(retrieved1[1].version, "2.0.0", "Should have data from last set operation")
  assert_equal(retrieved2[1].version, "2.0.0", "Should have data from last set operation")

  -- Cleanup
  cache.clear(bufnr1)
end)

-- ============================================================================
-- Print test summary
-- ============================================================================

helper.print_summary()

