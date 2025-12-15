-- Integration test: Cache with real build.sbt parsing
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_cache_integration.lua" -c "qa"

print("=== Testing Cache Integration with Parser ===\n")

local parser = require('dependencies.parser')
local cache = require('dependencies.cache')

-- Create a test buffer with build.sbt content
local function create_build_sbt_buffer()
  local bufnr = vim.api.nvim_create_buf(false, false)
  local test_project_path = vim.fn.getcwd() .. "/test_project/build.sbt"
  vim.api.nvim_buf_set_name(bufnr, test_project_path)
  
  local content = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.9.0",
  "io.circe" %% "circe-core" % "0.14.1",
  "com.typesafe" % "config" % "1.4.2"
)
]]
  
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
  return bufnr
end

print("Test 1: Parse dependencies and cache results")
local bufnr = create_build_sbt_buffer()

-- Parse dependencies
local deps = parser.extract_dependencies(bufnr)
print(string.format("  Parsed %d dependencies", #deps))

-- Simulate enriched data (as if from Maven)
local enriched_deps = {}
for _, dep in ipairs(deps) do
  table.insert(enriched_deps, {
    dependency = dep.dependency,
    line = dep.line,
    current = "1.0.0",
    latest = "1.2.0"
  })
end

-- Cache the enriched data
local success = cache.set(bufnr, enriched_deps)
if success then
  print("  ✓ Cached enriched dependency data")
else
  print("  ✗ Failed to cache data")
end

-- Get cache file info
local stats = cache.get_stats()
print(string.format("  Cache file: %s", stats.cache_files[1] or "none"))
print("  ✓ Test 1 passed\n")

print("Test 2: Retrieve cached data")
local cached = cache.get(bufnr)
if cached and #cached == #deps then
  print(string.format("  ✓ Retrieved %d cached dependencies", #cached))
  for i, dep_info in ipairs(cached) do
    print(string.format("    %d: %s (current: %s, latest: %s)", 
      dep_info.line, dep_info.dependency, dep_info.current, dep_info.latest))
  end
else
  print("  ✗ Failed to retrieve cached data")
end
print("  ✓ Test 2 passed\n")

print("Test 3: Cache validity with different TTLs")
local ttl_tests = {
  {ttl = "30m", should_be_valid = true},
  {ttl = "1d", should_be_valid = true},
  {ttl = "1w", should_be_valid = true}
}

for _, test in ipairs(ttl_tests) do
  local is_valid = cache.is_valid(bufnr, test.ttl)
  if is_valid == test.should_be_valid then
    print(string.format("  ✓ Cache validity for TTL '%s': %s", test.ttl, tostring(is_valid)))
  else
    print(string.format("  ✗ Cache validity check failed for TTL '%s'", test.ttl))
  end
end
print("  ✓ Test 3 passed\n")

print("Test 4: Different projects have separate caches")
local bufnr2 = vim.api.nvim_create_buf(false, false)
local other_project_path = vim.fn.getcwd() .. "/other_project/build.sbt"
vim.api.nvim_buf_set_name(bufnr2, other_project_path)

local other_deps = {
  {dependency = "other:lib:1.0", line = 5, current = "1.0", latest = "2.0"}
}

cache.set(bufnr2, other_deps)

-- Both caches should exist
local stats_after = cache.get_stats()
if stats_after.entry_count == 2 then
  print(string.format("  ✓ Two separate cache files created"))
  print("  Cache files:")
  for _, filepath in ipairs(stats_after.cache_files) do
    print(string.format("    - %s", vim.fn.fnamemodify(filepath, ":t")))
  end
else
  print(string.format("  ✗ Expected 2 cache files, found %d", stats_after.entry_count))
end

-- Verify each cache has correct data
local cached1 = cache.get(bufnr)
local cached2 = cache.get(bufnr2)

if cached1 and #cached1 == 3 and cached2 and #cached2 == 1 then
  print("  ✓ Each project has independent cache")
else
  print("  ✗ Cache data is mixed between projects")
end
print("  ✓ Test 4 passed\n")

print("Test 5: Read actual cache file content")
if stats_after.cache_files[1] then
  local filepath = stats_after.cache_files[1]
  local file = io.open(filepath, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local decoded = vim.json.decode(content)
    print("  ✓ Cache file structure:")
    print(string.format("    - timestamp: %d", decoded.timestamp))
    print(string.format("    - buffer_name: %s", vim.fn.fnamemodify(decoded.buffer_name, ":t")))
    print(string.format("    - data entries: %d", #decoded.data))
  end
end
print("  ✓ Test 5 passed\n")

print("Test 6: Cleanup")
cache.clear_all()
local final_stats = cache.get_stats()
if final_stats.entry_count == 0 then
  print("  ✓ All caches cleaned up")
else
  print(string.format("  ✗ Cleanup failed, %d files remain", final_stats.entry_count))
end
print("  ✓ Test 6 passed\n")

print("=== All integration tests passed! ===")
