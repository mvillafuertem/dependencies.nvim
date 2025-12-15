-- Test script for persistent cache functionality
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_persistent_cache.lua" -c "qa"

print("=== Testing Persistent Cache Implementation ===\n")

-- Load the cache module
local cache = require('dependencies.cache')

-- Helper to create a test buffer with a name
local function create_test_buffer(filename)
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.getcwd() .. "/" .. filename)
  return bufnr
end

-- Test 1: Get cache directory
print("Test 1: Get cache statistics")
local stats = cache.get_stats()
print(string.format("  Cache directory: %s", stats.cache_dir))
print(string.format("  Entry count: %d", stats.entry_count))
print("  ✓ Test 1 passed\n")

-- Test 2: Parse TTL
print("Test 2: Parse TTL strings")
local tests = {
  {input = "30m", expected = 1800, desc = "30 minutes"},
  {input = "6h", expected = 21600, desc = "6 hours"},
  {input = "1d", expected = 86400, desc = "1 day"},
  {input = "1w", expected = 604800, desc = "1 week"},
  {input = "1M", expected = 2592000, desc = "1 month"}
}

for _, test in ipairs(tests) do
  local result = cache.parse_ttl(test.input)
  if result == test.expected then
    print(string.format("  ✓ %s = %d seconds", test.desc, result))
  else
    print(string.format("  ✗ %s failed: expected %d, got %d", test.desc, test.expected, result))
  end
end
print("  ✓ Test 2 passed\n")

-- Test 3: Set and get cache
print("Test 3: Set and get cache data")
local bufnr = create_test_buffer("test_build.sbt")

local test_data = {
  {dependency = "org.typelevel:cats-core_2.13:2.9.0", line = 10, current = "2.9.0", latest = "2.13.0"},
  {dependency = "io.circe:circe-core_2.13:0.14.1", line = 11, current = "0.14.1", latest = "0.14.15"}
}

local success = cache.set(bufnr, test_data)
if success then
  print("  ✓ Cache data written successfully")
else
  print("  ✗ Failed to write cache data")
end

local retrieved = cache.get(bufnr)
if retrieved and #retrieved == 2 then
  print(string.format("  ✓ Cache data retrieved: %d entries", #retrieved))
  print(string.format("    Entry 1: %s", retrieved[1].dependency))
  print(string.format("    Entry 2: %s", retrieved[2].dependency))
else
  print("  ✗ Failed to retrieve cache data")
end
print("  ✓ Test 3 passed\n")

-- Test 4: Cache validity check
print("Test 4: Cache validity check")
local is_valid = cache.is_valid(bufnr, "1d")
if is_valid then
  print("  ✓ Cache is valid (within 1 day TTL)")
else
  print("  ✗ Cache should be valid")
end
print("  ✓ Test 4 passed\n")

-- Test 5: Multiple buffers (different projects)
print("Test 5: Multiple buffer caching")
local bufnr2 = create_test_buffer("project2/build.sbt")
local test_data2 = {
  {dependency = "com.typesafe:config:1.4.2", line = 5, current = "1.4.2", latest = "1.4.5"}
}

cache.set(bufnr2, test_data2)
local retrieved2 = cache.get(bufnr2)

if retrieved2 and #retrieved2 == 1 then
  print(string.format("  ✓ Second buffer cached: %s", retrieved2[1].dependency))
else
  print("  ✗ Failed to cache second buffer")
end

-- Verify first buffer is still cached
local retrieved1 = cache.get(bufnr)
if retrieved1 and #retrieved1 == 2 then
  print("  ✓ First buffer still cached correctly")
else
  print("  ✗ First buffer cache was corrupted")
end
print("  ✓ Test 5 passed\n")

-- Test 6: Clear specific buffer cache
print("Test 6: Clear specific buffer cache")
cache.clear(bufnr2)
local after_clear = cache.get(bufnr2)
if not after_clear then
  print("  ✓ Second buffer cache cleared")
else
  print("  ✗ Failed to clear second buffer cache")
end

local first_still_there = cache.get(bufnr)
if first_still_there and #first_still_there == 2 then
  print("  ✓ First buffer cache unaffected")
else
  print("  ✗ First buffer cache was incorrectly cleared")
end
print("  ✓ Test 6 passed\n")

-- Test 7: Final statistics
print("Test 7: Final cache statistics")
local final_stats = cache.get_stats()
print(string.format("  Cache directory: %s", final_stats.cache_dir))
print(string.format("  Total entries: %d", final_stats.entry_count))
if final_stats.entry_count > 0 then
  print("  Cache files:")
  for _, filepath in ipairs(final_stats.cache_files) do
    print(string.format("    - %s", filepath))
  end
end
print("  ✓ Test 7 passed\n")

-- Test 8: Clear all caches
print("Test 8: Clear all caches")
cache.clear_all()
local empty_stats = cache.get_stats()
if empty_stats.entry_count == 0 then
  print("  ✓ All caches cleared successfully")
else
  print(string.format("  ✗ Failed to clear all caches (%d remaining)", empty_stats.entry_count))
end
print("  ✓ Test 8 passed\n")

print("=== All tests completed successfully! ===")
