-- Maven Integration Tests
-- Run from command line: nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/maven_spec.lua" -c "qa"

local maven = require('dependencies.maven')
local helper = require('tests.test_helper')

-- Extract helper functions for convenience
local assert_equal = helper.assert_equal
local assert_table_equal = helper.assert_table_equal
local test = helper.test

-- Reset test counters at the start
helper.reset_counters()

io.write("=== Maven Integration Tests ===\n")
io.flush()

-- ============================================================================
-- Test enrich_with_latest_versions function with mock data
-- ============================================================================

test("enrich_with_latest_versions returns correct format", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1" },
    { line = 2, dependency = "com.typesafe:config:1.4.2" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 2, "Should return same number of dependencies")

  -- Check structure of first result
  assert_equal(result[1].line, 1, "First dependency should have line 1")
  assert_equal(result[1].dependency, "io.circe:circe-core:0.14.1", "First dependency string should match")
  assert_equal(type(result[1].latest), "string", "First dependency should have latest as string")

  -- Check structure of second result
  assert_equal(result[2].line, 2, "Second dependency should have line 2")
  assert_equal(result[2].dependency, "com.typesafe:config:1.4.2", "Second dependency string should match")
  assert_equal(type(result[2].latest), "string", "Second dependency should have latest as string")
end)

test("enrich_with_latest_versions handles empty input", function()
  -- g i v e n
  local input_dependencies = {}

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 0, "Should return empty array for empty input")
end)

test("enrich_with_latest_versions handles single dependency", function()
  -- g i v e n
  local input_dependencies = {
    { line = 5, dependency = "org.scala-lang:scala-library:2.13.10" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 5, "Should preserve line number")
  assert_equal(result[1].dependency, "org.scala-lang:scala-library:2.13.10", "Should preserve dependency string")
  assert_equal(type(result[1].latest), "string", "Should have latest version as string")
end)

-- ============================================================================
-- Test with real Maven Central API (integration tests)
-- ============================================================================

test("fetch latest version for known Scala library", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.scala-lang:scala-library:2.13.10" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(result[1].dependency, "org.scala-lang:scala-library:2.13.10", "Should preserve original dependency")

  -- The latest version should not be "unknown" if Maven Central is accessible
  -- Note: This test might fail if Maven Central is down or network issues occur
  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version: %s\n", result[1].latest))
  else
    io.write("  ⚠️  Warning: Could not fetch version from Maven Central\n")
  end
end)

test("fetch latest version for Typesafe Config", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "com.typesafe:config:1.4.2" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(result[1].dependency, "com.typesafe:config:1.4.2", "Should preserve original dependency")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version: %s\n", result[1].latest))
  else
    io.write("  ⚠️  Warning: Could not fetch version from Maven Central\n")
  end
end)

test("fetch latest versions for multiple dependencies", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1" },
    { line = 2, dependency = "com.typesafe:config:1.4.2" },
    { line = 3, dependency = "org.scala-lang:scala-library:2.13.10" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 3, "Should return three dependencies")

  for i, dep in ipairs(result) do
    assert_equal(dep.line, i, string.format("Dependency %d should have correct line number", i))
    assert_equal(type(dep.dependency), "string", string.format("Dependency %d should have dependency string", i))
    assert_equal(type(dep.latest), "string", string.format("Dependency %d should have latest version", i))

    if dep.latest ~= "unknown" then
      io.write(string.format("  ℹ️  %s -> latest: %s\n", dep.dependency, dep.latest))
    end
  end
end)

-- ============================================================================
-- Test handling of malformed dependencies
-- ============================================================================

test("handles malformed dependency gracefully", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "invalid-dependency-format" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should still return one result")
  assert_equal(result[1].line, 1, "Should preserve line number")
  assert_equal(result[1].dependency, "invalid-dependency-format", "Should preserve original dependency")
  assert_equal(result[1].latest, "unknown", "Should return unknown for malformed dependency")
end)

test("handles dependency with double percent operator", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "com.github.jwt-scala:jwt-circe:9.4.5" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(result[1].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should preserve original dependency")
  assert_equal(type(result[1].latest), "string", "Should have latest version")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version: %s\n", result[1].latest))
  end
end)

test("handles non-existent artifact in Maven Central", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "com.nonexistent:fake-artifact:1.0.0" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one result")
  assert_equal(result[1].line, 1, "Should preserve line number")
  assert_equal(result[1].dependency, "com.nonexistent:fake-artifact:1.0.0", "Should preserve original dependency")
  assert_equal(result[1].latest, "unknown", "Should return unknown for non-existent artifact")
end)

-- ============================================================================
-- Test output format matches specification
-- ============================================================================

test("output format matches specification [{line, dependency, latest}]", function()
  -- g i v e n
  local input_dependencies = {
    { line = 10, dependency = "org.example:artifact:1.0.0" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 1, "Should return one element")

  local dep = result[1]

  -- Check all required fields exist
  assert_equal(type(dep.line), "number", "line should be a number")
  assert_equal(type(dep.dependency), "string", "dependency should be a string")
  assert_equal(type(dep.latest), "string", "latest should be a string")

  -- Check values
  assert_equal(dep.line, 10, "line should be 10")
  assert_equal(dep.dependency, "org.example:artifact:1.0.0", "dependency should match input")
  assert_equal(type(dep.latest), "string", "latest should be present")
end)

test("preserves all fields from input dependencies", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.example:artifact1:1.0.0" },
    { line = 5, dependency = "org.example:artifact2:2.0.0" },
    { line = 10, dependency = "org.example:artifact3:3.0.0" }
  }

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies)

  -- t h e n
  assert_equal(#result, 3, "Should return three dependencies")

  -- Check that line numbers are preserved
  assert_equal(result[1].line, 1, "First dependency line should be 1")
  assert_equal(result[2].line, 5, "Second dependency line should be 5")
  assert_equal(result[3].line, 10, "Third dependency line should be 10")

  -- Check that dependency strings are preserved
  assert_equal(result[1].dependency, "org.example:artifact1:1.0.0", "First dependency should be preserved")
  assert_equal(result[2].dependency, "org.example:artifact2:2.0.0", "Second dependency should be preserved")
  assert_equal(result[3].dependency, "org.example:artifact3:3.0.0", "Third dependency should be preserved")
end)

-- ============================================================================
-- Test Scala version support (new feature)
-- ============================================================================

test("enrich_with_latest_versions with scala_version for Scala library", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.typelevel:cats-core:2.9.0" }
  }
  local scala_version = "2.13"

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies, scala_version)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(result[1].dependency, "org.typelevel:cats-core:2.9.0", "Should preserve original dependency")
  assert_equal(type(result[1].latest), "string", "Should have latest version")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version for cats-core_2.13: %s\n", result[1].latest))
  else
    io.write("  ⚠️  Warning: Could not fetch version from Maven Central\n")
  end
end)

test("enrich_with_latest_versions with scala_version for Java library", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "com.typesafe:config:1.4.2" }
  }
  local scala_version = "2.13"

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies, scala_version)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(result[1].dependency, "com.typesafe:config:1.4.2", "Should preserve original dependency")
  assert_equal(type(result[1].latest), "string", "Should have latest version")

  -- Java libraries don't have Scala version suffix, so it should fallback to plain artifact name
  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version for config (fallback): %s\n", result[1].latest))
  else
    io.write("  ⚠️  Warning: Could not fetch version from Maven Central\n")
  end
end)

test("enrich_with_latest_versions with different scala versions", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.scalactic:scalactic:3.2.15" }
  }

  -- w h e n - Test with Scala 2.13
  local result_2_13 = maven.enrich_with_latest_versions(input_dependencies, "2.13")

  -- w h e n - Test with Scala 2.12
  local result_2_12 = maven.enrich_with_latest_versions(input_dependencies, "2.12")

  -- t h e n
  assert_equal(#result_2_13, 1, "Should return one dependency for 2.13")
  assert_equal(#result_2_12, 1, "Should return one dependency for 2.12")

  if result_2_13[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version for scalactic_2.13: %s\n", result_2_13[1].latest))
  end

  if result_2_12[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version for scalactic_2.12: %s\n", result_2_12[1].latest))
  end
end)

test("enrich_with_latest_versions without scala_version still works", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.typelevel:cats-core:2.9.0" },
    { line = 2, dependency = "com.typesafe:config:1.4.2" }
  }

  -- w h e n - No scala_version provided (backward compatibility)
  local result = maven.enrich_with_latest_versions(input_dependencies, nil)

  -- t h e n
  assert_equal(#result, 2, "Should return two dependencies")
  assert_equal(result[1].line, 1, "First dependency should have line 1")
  assert_equal(result[2].line, 2, "Second dependency should have line 2")
  assert_equal(type(result[1].latest), "string", "First dependency should have latest version")
  assert_equal(type(result[2].latest), "string", "Second dependency should have latest version")

  io.write("  ℹ️  Backward compatibility: works without scala_version parameter\n")
end)

test("enrich_with_latest_versions with multiple Scala dependencies", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.typelevel:cats-core:2.9.0" },
    { line = 2, dependency = "org.scalactic:scalactic:3.2.15" },
    { line = 3, dependency = "com.typesafe:config:1.4.2" }
  }
  local scala_version = "2.13"

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies, scala_version)

  -- t h e n
  assert_equal(#result, 3, "Should return three dependencies")

  for i, dep in ipairs(result) do
    assert_equal(dep.line, i, string.format("Dependency %d should have correct line number", i))
    assert_equal(type(dep.dependency), "string", string.format("Dependency %d should have dependency string", i))
    assert_equal(type(dep.latest), "string", string.format("Dependency %d should have latest version", i))

    if dep.latest ~= "unknown" then
      io.write(string.format("  ℹ️  %s (Scala %s) -> latest: %s\n", dep.dependency, scala_version, dep.latest))
    end
  end
end)

test("enrich_with_latest_versions handles Scala 3 version suffix", function()
  -- g i v e n
  local input_dependencies = {
    { line = 1, dependency = "org.typelevel:cats-core:2.9.0" }
  }
  local scala_version = "3"

  -- w h e n
  local result = maven.enrich_with_latest_versions(input_dependencies, scala_version)

  -- t h e n
  assert_equal(#result, 1, "Should return one dependency")
  assert_equal(result[1].line, 1, "Should have line 1")
  assert_equal(type(result[1].latest), "string", "Should have latest version")

  -- Note: Scala 3 uses _3 suffix
  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version for cats-core_3: %s\n", result[1].latest))
  else
    io.write("  ℹ️  Scala 3 suffix (_3) or fallback used\n")
  end
end)

-- Print test summary
helper.print_summary()

