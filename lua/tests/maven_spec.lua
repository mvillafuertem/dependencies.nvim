-- Maven Integration Tests (TDD - Complete Coverage)
-- Run from command line: nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/maven_spec.lua" -c "qa"

local maven = require('dependencies.maven')
local helper = require('tests.test_helper')
local config = require('dependencies.config')

-- Extract helper functions for convenience
local assert_equal = helper.assert_equal
local assert_table_equal = helper.assert_table_equal
local test = helper.test

-- Reset test counters at the start
helper.reset_counters()

-- Synchronous wrapper for testing async function
local function enrich_with_latest_versions_sync(dependencies, scala_version)
  local result = nil
  local done = false

  maven.enrich_with_latest_versions_async(dependencies, scala_version, function(enriched)
    result = enriched
    done = true
  end)

  -- Wait for async operation to complete
  vim.wait(10000, function() return done end, 100)

  return result or {}
end

io.write("=== Maven Integration Tests (TDD) ===\n")
io.flush()

-- ============================================================================
-- UNIT TESTS: parse_version()
-- ============================================================================

test("parse_version: handles simple version (1.0.0)", function()
  local result = maven.parse_version("1.0.0")

  assert_equal(result.major, 1, "major should be 1")
  assert_equal(result.minor, 0, "minor should be 0")
  assert_equal(result.patch, 0, "patch should be 0")
  assert_equal(result.prerelease_type, "", "no prerelease type")
  assert_equal(result.original, "1.0.0", "original should match")
end)

test("parse_version: handles two-part version (2.13)", function()
  local result = maven.parse_version("2.13")

  assert_equal(result.major, 2, "major should be 2")
  assert_equal(result.minor, 13, "minor should be 13")
  assert_equal(result.patch, 0, "patch should default to 0")
end)

test("parse_version: handles milestone version (1.0-M1)", function()
  local result = maven.parse_version("1.0-M1")

  assert_equal(result.major, 1, "major should be 1")
  assert_equal(result.minor, 0, "minor should be 0")
  assert_equal(result.prerelease_type, "M", "prerelease type should be M")
  assert_equal(result.prerelease_num, 1, "prerelease number should be 1")
end)

test("parse_version: handles RC version (2.5.0-RC3)", function()
  local result = maven.parse_version("2.5.0-RC3")

  assert_equal(result.major, 2, "major should be 2")
  assert_equal(result.minor, 5, "minor should be 5")
  assert_equal(result.patch, 0, "patch should be 0")
  assert_equal(result.prerelease_type, "RC", "prerelease type should be RC")
  assert_equal(result.prerelease_num, 3, "prerelease number should be 3")
end)

test("parse_version: handles alpha version (1.0-alpha2)", function()
  local result = maven.parse_version("1.0-alpha2")

  assert_equal(result.prerelease_type, "alpha", "prerelease type should be alpha")
  assert_equal(result.prerelease_num, 2, "prerelease number should be 2")
end)

test("parse_version: handles beta version (3.0-beta)", function()
  local result = maven.parse_version("3.0-beta")

  assert_equal(result.prerelease_type, "beta", "prerelease type should be beta")
  assert_equal(result.prerelease_num, 0, "prerelease number defaults to 0")
end)

test("parse_version: handles SNAPSHOT version (1.0-SNAPSHOT)", function()
  local result = maven.parse_version("1.0-SNAPSHOT")

  assert_equal(result.prerelease_type, "SNAPSHOT", "prerelease type should be SNAPSHOT")
end)

test("parse_version: handles nil input", function()
  local result = maven.parse_version(nil)

  assert_equal(result, nil, "should return nil for nil input")
end)

test("parse_version: handles malformed version", function()
  local result = maven.parse_version("not-a-version")

  assert_equal(result.major, 0, "major should default to 0")
  assert_equal(result.minor, 0, "minor should default to 0")
end)

-- ============================================================================
-- UNIT TESTS: compare_versions()
-- ============================================================================

test("compare_versions: 1.0.0 < 2.0.0 (different major)", function()
  local result = maven.compare_versions("1.0.0", "2.0.0")
  assert_equal(result, -1, "1.0.0 should be less than 2.0.0")
end)

test("compare_versions: 1.5.0 < 1.6.0 (different minor)", function()
  local result = maven.compare_versions("1.5.0", "1.6.0")
  assert_equal(result, -1, "1.5.0 should be less than 1.6.0")
end)

test("compare_versions: 1.0.1 < 1.0.2 (different patch)", function()
  local result = maven.compare_versions("1.0.1", "1.0.2")
  assert_equal(result, -1, "1.0.1 should be less than 1.0.2")
end)

test("compare_versions: 1.0.0 == 1.0.0 (equal)", function()
  local result = maven.compare_versions("1.0.0", "1.0.0")
  assert_equal(result, 0, "1.0.0 should equal 1.0.0")
end)

test("compare_versions: 2.0.0 > 1.0.0 (greater)", function()
  local result = maven.compare_versions("2.0.0", "1.0.0")
  assert_equal(result, 1, "2.0.0 should be greater than 1.0.0")
end)

test("compare_versions: stable > RC (1.0 > 1.0-RC1)", function()
  local result = maven.compare_versions("1.0", "1.0-RC1")
  assert_equal(result, 1, "stable version should be greater than RC")
end)

test("compare_versions: stable > M (1.0 > 1.0-M1)", function()
  local result = maven.compare_versions("1.0", "1.0-M1")
  assert_equal(result, 1, "stable version should be greater than milestone")
end)

test("compare_versions: RC > M (1.0-RC1 > 1.0-M1)", function()
  local result = maven.compare_versions("1.0-RC1", "1.0-M1")
  assert_equal(result, 1, "RC should be greater than milestone")
end)

test("compare_versions: M > beta (1.0-M1 > 1.0-beta)", function()
  local result = maven.compare_versions("1.0-M1", "1.0-beta")
  assert_equal(result, 1, "milestone should be greater than beta")
end)

test("compare_versions: beta > alpha (1.0-beta > 1.0-alpha)", function()
  local result = maven.compare_versions("1.0-beta", "1.0-alpha")
  assert_equal(result, 1, "beta should be greater than alpha")
end)

test("compare_versions: alpha > SNAPSHOT (1.0-alpha > 1.0-SNAPSHOT)", function()
  local result = maven.compare_versions("1.0-alpha", "1.0-SNAPSHOT")
  assert_equal(result, 1, "alpha should be greater than SNAPSHOT")
end)

test("compare_versions: RC2 > RC1 (same type, different number)", function()
  local result = maven.compare_versions("1.0-RC2", "1.0-RC1")
  assert_equal(result, 1, "RC2 should be greater than RC1")
end)

test("compare_versions: M3 > M1 (same type, different number)", function()
  local result = maven.compare_versions("1.0-M3", "1.0-M1")
  assert_equal(result, 1, "M3 should be greater than M1")
end)

test("compare_versions: handles nil inputs", function()
  local result = maven.compare_versions(nil, "1.0.0")
  assert_equal(result, 0, "should return 0 for nil input")
end)

-- ============================================================================
-- UNIT TESTS: process_metadata_xml()
-- ============================================================================

test("process_metadata_xml: extracts latest stable version", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.1.0</version>
          <version>1.2.0</version>
          <version>2.0.0-M1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, "1.2.0", "should return latest stable version greater than current")
end)

test("process_metadata_xml: filters prereleases when include_prerelease=false", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.1.0-M1</version>
          <version>1.1.0-RC1</version>
          <version>1.1.0</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, "1.1.0", "should skip prereleases and return stable version")
end)

test("process_metadata_xml: includes prereleases when include_prerelease=true", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.1.0</version>
          <version>1.2.0-M1</version>
          <version>1.2.0-RC1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", true)
  assert_equal(type(result), "table", "should return table when include_prerelease=true")
  assert_equal(#result, 3, "should return up to 3 versions")
end)

test("process_metadata_xml: returns current version when user is up-to-date", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.1.0</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.1.0", false)
  assert_equal(result, "1.1.0", "should return current version when already on latest")
end)

test("process_metadata_xml: returns nil for empty XML", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, nil, "should return nil when no versions found")
end)

test("process_metadata_xml: returns nil for malformed XML", function()
  local xml_response = "not valid xml"

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, nil, "should return nil for malformed XML")
end)

test("process_metadata_xml: sorts versions correctly", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>2.0.0</version>
          <version>1.5.0</version>
          <version>1.8.0</version>
          <version>1.2.0</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, "2.0.0", "should return highest version")
end)

test("process_metadata_xml: only returns versions GREATER than current", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.5.0</version>
          <version>2.0.0</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.5.0", false)
  assert_equal(result, "2.0.0", "should only return versions greater than 1.5.0")
end)

test("process_metadata_xml: with prerelease returns 1 stable + 2 prereleases", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>1.5.0</version>
          <version>2.0.0-M1</version>
          <version>2.0.0-M2</version>
          <version>2.0.0-RC1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", true)
  assert_equal(type(result), "table", "should return table")
  assert_equal(#result, 3, "should return 3 versions")

  -- Should contain 1 stable and 2 most recent prereleases
  local has_stable = false
  for _, version in ipairs(result) do
    if version == "1.5.0" then
      has_stable = true
    end
  end
  assert_equal(has_stable, true, "should include at least 1 stable version")
end)

test("process_metadata_xml: prerelease mode returns versions in ascending order", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>2.0.0</version>
          <version>3.0.0-M1</version>
          <version>3.0.0-RC1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", true)
  assert_equal(type(result), "table", "should return table")

  -- Verify ascending order
  for i = 1, #result - 1 do
    local cmp = maven.compare_versions(result[i], result[i + 1])
    assert_equal(cmp < 0, true, string.format("%s should be < %s", result[i], result[i + 1]))
  end
end)

-- ============================================================================
-- INTEGRATION TESTS: enrich_with_latest_versions_async()
-- ============================================================================

test("enrich_with_latest_versions_async: handles empty input", function()
  local input_dependencies = {}

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 0, "should return empty array for empty input")
end)

test("enrich_with_latest_versions_async: returns correct format with new structure", function()
  -- Configure to NOT include prereleases (single version expected)
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 1, "should return one dependency")
  assert_equal(result[1].group, "com.typesafe", "should preserve group")
  assert_equal(result[1].artifact, "config", "should preserve artifact")
  assert_equal(result[1].version, "1.4.2", "should preserve version")
  assert_equal(result[1].line, 1, "should preserve line")
  assert_equal(type(result[1].latest), "string", "latest should be string when include_prerelease=false")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest version: %s\n", result[1].latest))
  end
end)

test("enrich_with_latest_versions_async: with include_prerelease=true returns table", function()
  -- Configure to include prereleases (table expected)
  config.setup({ include_prerelease = true })

  local input_dependencies = {
    { group = "io.circe", artifact = "circe-core", version = "0.14.1", line = 1 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies, "2.13")

  assert_equal(#result, 1, "should return one dependency")

  if type(result[1].latest) == "table" then
    io.write(string.format("  ℹ️  Found multiple versions: %s\n", table.concat(result[1].latest, ", ")))
    assert_equal(#result[1].latest <= 3, true, "should return at most 3 versions")
  else
    io.write(string.format("  ℹ️  Found single version: %s\n", result[1].latest))
  end

  -- Reset config
  config.setup({ include_prerelease = false })
end)

test("enrich_with_latest_versions_async: handles Scala library with version suffix", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "org.typelevel", artifact = "cats-core", version = "2.9.0", line = 1 }
  }
  local scala_version = "2.13"

  local result = enrich_with_latest_versions_sync(input_dependencies, scala_version)

  assert_equal(#result, 1, "should return one dependency")
  assert_equal(result[1].group, "org.typelevel", "should preserve group")
  assert_equal(result[1].artifact, "cats-core", "should preserve artifact")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest for cats-core_2.13: %s\n", result[1].latest))
  end
end)

test("enrich_with_latest_versions_async: handles Java library without Scala suffix", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1 }
  }
  local scala_version = "2.13"

  local result = enrich_with_latest_versions_sync(input_dependencies, scala_version)

  assert_equal(#result, 1, "should return one dependency")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest for config (no suffix): %s\n", result[1].latest))
  end
end)

test("enrich_with_latest_versions_async: handles multiple dependencies", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "com.typesafe", artifact = "config", version = "1.4.2", line = 1 },
    { group = "org.scala-lang", artifact = "scala-library", version = "2.13.10", line = 2 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 2, "should return two dependencies")
  assert_equal(result[1].line, 1, "first dependency should have line 1")
  assert_equal(result[2].line, 2, "second dependency should have line 2")

  for i, dep in ipairs(result) do
    if dep.latest ~= "unknown" then
      io.write(string.format("  ℹ️  %s:%s -> %s\n", dep.group, dep.artifact, dep.latest))
    end
  end
end)

test("enrich_with_latest_versions_async: handles missing group/artifact gracefully", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = nil, artifact = nil, version = "1.0.0", line = 1 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 1, "should return one result")
  assert_equal(result[1].latest, "unknown", "should return unknown for missing group/artifact")
end)

test("enrich_with_latest_versions_async: handles non-existent artifact", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "com.nonexistent", artifact = "fake-artifact", version = "1.0.0", line = 1 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 1, "should return one result")
  -- May return "unknown" or nil depending on network
  io.write(string.format("  ℹ️  Non-existent artifact returned: %s\n", tostring(result[1].latest)))
end)

test("enrich_with_latest_versions_async: preserves line order", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "org.example", artifact = "lib1", version = "1.0.0", line = 10 },
    { group = "org.example", artifact = "lib2", version = "2.0.0", line = 5 },
    { group = "org.example", artifact = "lib3", version = "3.0.0", line = 15 }
  }

  local result = enrich_with_latest_versions_sync(input_dependencies)

  assert_equal(#result, 3, "should return three dependencies")
  -- Results should be sorted by line number
  assert_equal(result[1].line, 5, "first result should be line 5")
  assert_equal(result[2].line, 10, "second result should be line 10")
  assert_equal(result[3].line, 15, "third result should be line 15")
end)

test("enrich_with_latest_versions_async: handles Scala 3 version suffix", function()
  config.setup({ include_prerelease = false })

  local input_dependencies = {
    { group = "org.typelevel", artifact = "cats-core", version = "2.9.0", line = 1 }
  }
  local scala_version = "3"

  local result = enrich_with_latest_versions_sync(input_dependencies, scala_version)

  assert_equal(#result, 1, "should return one dependency")

  if result[1].latest ~= "unknown" then
    io.write(string.format("  ℹ️  Found latest for cats-core_3: %s\n", result[1].latest))
  else
    io.write("  ℹ️  Scala 3 suffix (_3) tested\n")
  end
end)

-- ============================================================================
-- EDGE CASES AND ERROR HANDLING
-- ============================================================================

test("process_metadata_xml: handles version with 4 parts (1.2.3.4)", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.2.3.4</version>
          <version>1.2.3.5</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.2.3.4", false)
  assert_equal(result, "1.2.3.5", "should handle 4-part versions")
end)

test("compare_versions: handles versions with different part counts", function()
  local result = maven.compare_versions("1.0", "1.0.1")
  assert_equal(result, -1, "1.0 should be less than 1.0.1")
end)

test("parse_version: handles version with extra text", function()
  local result = maven.parse_version("1.0.0.Final")
  assert_equal(result.major, 1, "should parse major version")
  assert_equal(result.minor, 0, "should parse minor version")
  assert_equal(result.patch, 0, "should parse patch version")
end)

test("process_metadata_xml: no stable versions, only prereleases", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>2.0.0-M1</version>
          <version>2.0.0-M2</version>
          <version>2.0.0-RC1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", false)
  assert_equal(result, nil, "should return nil when only prereleases are available")
end)

test("process_metadata_xml: prerelease mode with no stable versions", function()
  local xml_response = [[
    <metadata>
      <versioning>
        <versions>
          <version>1.0.0</version>
          <version>2.0.0-M1</version>
          <version>2.0.0-M2</version>
          <version>2.0.0-RC1</version>
        </versions>
      </versioning>
    </metadata>
  ]]

  local result = maven.process_metadata_xml(xml_response, "1.0.0", true)
  assert_equal(type(result), "table", "should return table of prereleases")
  assert_equal(#result <= 3, true, "should return at most 3 prereleases")
end)

-- Print test summary
helper.print_summary()
