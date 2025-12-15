-- Test script to verify async implementation works correctly
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_async_implementation.lua" -c "qa"

-- Add current directory to runtimepath
vim.opt.runtimepath:append('.')

-- Wait for async operations to complete
local wait_time = 15000  -- 15 seconds timeout

print("=== Testing Async Maven Implementation ===\n")

-- Test 1: Test curl_async function
print("Test 1: Testing curl_async with maven-metadata.xml")
local maven = require('dependencies.maven')
local test_deps = {
  {
    dependency = "io.circe:circe-core:0.14.1",
    line = 5
  },
  {
    dependency = "org.typelevel:cats-core:2.9.0",
    line = 6
  }
}

local completed = false
local start_time = vim.loop.now()

maven.enrich_with_latest_versions_async(test_deps, "2.13", function(results)
  completed = true
  local elapsed = vim.loop.now() - start_time

  print(string.format("\n✓ Async operation completed in %d ms", elapsed))
  print("\nResults:")
  for _, dep_info in ipairs(results) do
    local latest_display
    if type(dep_info.latest) == "table" then
      latest_display = table.concat(dep_info.latest, ", ")
    else
      latest_display = dep_info.latest
    end
    print(string.format("  Line %d: %s", dep_info.line, dep_info.dependency))
    print(string.format("    Current: %s", dep_info.current))
    print(string.format("    Latest:  %s", latest_display))
  end

  -- Verify we got results
  if #results == 2 then
    print("\n✓ Test PASSED: Got expected number of results")
  else
    print(string.format("\n✗ Test FAILED: Expected 2 results, got %d", #results))
  end
end)

-- Wait for async operations to complete
print("\nWaiting for async operations to complete...")
local wait_start = vim.loop.now()
while not completed and (vim.loop.now() - wait_start) < wait_time do
  vim.wait(100)
end

if not completed then
  print("\n✗ Test FAILED: Timeout waiting for async operations")
  os.exit(1)
end

print("\n=== All Tests Completed ===")

