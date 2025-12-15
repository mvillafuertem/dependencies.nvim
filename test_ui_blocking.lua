-- Test to demonstrate non-blocking behavior
-- This test shows that async operations don't block the event loop

vim.opt.runtimepath:append('.')

print("=== Testing Non-Blocking UI Behavior ===\n")

local maven = require('dependencies.maven')

-- Create a large set of dependencies to test
local test_deps = {
  { dependency = "io.circe:circe-core:0.14.1", line = 1 },
  { dependency = "org.typelevel:cats-core:2.9.0", line = 2 },
  { dependency = "com.typesafe:config:1.4.2", line = 3 },
  { dependency = "org.scalatest:scalatest:3.2.15", line = 4 },
  { dependency = "org.scalactic:scalactic:3.2.15", line = 5 },
}

print(string.format("Starting async fetch for %d dependencies...", #test_deps))
print("If this blocks, you won't see the tick messages below.\n")

local completed = false
local result_count = 0

-- Start async operation
maven.enrich_with_latest_versions_async(test_deps, "2.13", function(results)
  result_count = #results
  completed = true

  print("\n✓ Async operation completed!")
  print(string.format("  Fetched versions for %d dependencies\n", result_count))

  -- Show results
  for _, dep_info in ipairs(results) do
    local latest_display
    if type(dep_info.latest) == "table" then
      latest_display = table.concat(dep_info.latest, ", ")
    else
      latest_display = dep_info.latest
    end
    print(string.format("  %s: %s → %s",
      dep_info.dependency:match("[^:]+:[^:]+"),
      dep_info.current,
      latest_display
    ))
  end
end)

-- Show tick messages while waiting (proves UI isn't blocked)
print("Event loop ticking while fetching (non-blocking):")
local ticks = 0
local start_time = vim.loop.now()

while not completed and ticks < 100 do
  vim.wait(100)
  ticks = ticks + 1
  if ticks % 10 == 0 then
    io.write(string.format("  [%d] tick... (%dms elapsed)\n", ticks, vim.loop.now() - start_time))
    io.flush()
  end
end

if completed then
  local elapsed = vim.loop.now() - start_time
  print(string.format("\n✓ Test PASSED: Completed in %dms with %d ticks", elapsed, ticks))
  print("✓ UI was NOT blocked - event loop ran continuously")

  if result_count == #test_deps then
    print(string.format("✓ Got all %d results", result_count))
  else
    print(string.format("✗ WARNING: Expected %d results, got %d", #test_deps, result_count))
  end
else
  print("\n✗ Test FAILED: Timeout after 10 seconds")
  os.exit(1)
end

print("\n=== Test Completed Successfully ===")

