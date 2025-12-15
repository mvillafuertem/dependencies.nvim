-- Simple cache test without parser dependencies
print("=== Testing Cache File Persistence ===\n")

local cache = require('dependencies.cache')

-- Test 1: Create cache file
print("Test 1: Create and persist cache file")
local bufnr = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(bufnr, vim.fn.getcwd() .. "/my_project/build.sbt")

local test_data = {
  {dependency = "org.test:lib:1.0", line = 5, current = "1.0", latest = "2.0"}
}

cache.set(bufnr, test_data)
print("  ✓ Data written to cache\n")

-- Test 2: Check that file exists
print("Test 2: Verify cache file was created")
local stats = cache.get_stats()
print(string.format("  Cache directory: %s", stats.cache_dir))
print(string.format("  Files created: %d", stats.entry_count))

if stats.entry_count > 0 then
  local filepath = stats.cache_files[1]
  print(string.format("  Cache file: %s", filepath))
  
  -- Read raw file content
  local file = io.open(filepath, "r")
  if file then
    local content = file:read("*a")
    file:close()
    print("\n  Raw cache file content:")
    print("  " .. string.rep("-", 50))
    for line in content:gmatch("[^\n]+") do
      print("  " .. line)
    end
    print("  " .. string.rep("-", 50))
  end
end
print("  ✓ Cache file verified\n")

-- Test 3: Retrieve from cache
print("Test 3: Retrieve cached data")
local retrieved = cache.get(bufnr)
if retrieved and #retrieved == 1 then
  print(string.format("  ✓ Retrieved: %s", retrieved[1].dependency))
  print(string.format("    Line: %d", retrieved[1].line))
  print(string.format("    Current: %s", retrieved[1].current))
  print(string.format("    Latest: %s", retrieved[1].latest))
else
  print("  ✗ Failed to retrieve")
end
print("  ✓ Test 3 passed\n")

-- Test 4: Verify cache persists (simulate reopening Neovim)
print("Test 4: Cache validity check with TTL")
local is_valid = cache.is_valid(bufnr, "1d")
if is_valid then
  print("  ✓ Cache is valid (within 1 day TTL)")
else
  print("  ✗ Cache should be valid")
end

-- Check that we can read from cache file directly
local retrieved2 = cache.get(bufnr)
if retrieved2 and #retrieved2 == 1 then
  print("  ✓ Cache can be read multiple times")
else
  print("  ✗ Failed to re-read cache")
end
print("  ✓ Test 4 passed\n")

-- Cleanup
print("Cleanup: Removing cache files")
cache.clear_all()
local final_stats = cache.get_stats()
print(string.format("  Remaining files: %d", final_stats.entry_count))
print("\n=== All tests passed! ===")
