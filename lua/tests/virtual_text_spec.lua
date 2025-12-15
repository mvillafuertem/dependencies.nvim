-- Integration Tests for Virtual Text
-- Run from command line: nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/integration_spec.lua" -c "qa"

local parser = require('dependencies.parser')
local maven = require('dependencies.maven')
local virtual_text = require('dependencies.virtual_text')
local helper = require('tests.test_helper')

-- Extract helper functions for convenience
local setup_buffer_with_content = helper.setup_buffer_with_content
local assert_equal = helper.assert_equal
local test = helper.test

-- Reset test counters at the start
helper.reset_counters()

io.write("=== Integration Tests - Virtual Text (TDD Order) ===\n")
io.flush()

-- ============================================================================
-- LEVEL 0: Basic structure - Simplest tests
-- ============================================================================

test("virtual_text.ns namespace exists", function()
  -- t h e n
  assert_equal(type(virtual_text.ns), "number", "Namespace should be a number")
end)

test("get_extmarks returns empty array for buffer without extmarks", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")

  -- w h e n
  local extmarks = virtual_text.get_extmarks(bufnr, false)

  -- t h e n
  assert_equal(#extmarks, 0, "Should return empty array for buffer without extmarks")
end)

-- ============================================================================
-- LEVEL 1: Apply virtual text - Single dependency (simplest apply)
-- ============================================================================

test("apply_virtual_text with single dependency creates one extmark", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create exactly one extmark")
end)

test("apply_virtual_text creates extmark with correct content", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 1, "Should have one extmark in buffer")

  local details = extmarks[1][4]
  local virt_text_content = details.virt_text[1][1]

  -- Verify EXACT content, not just pattern match
  assert_equal(virt_text_content, "  ← latest: 1.4.5", "Virtual text should have exact format '  ← latest: 1.4.5'")
end)

test("apply_virtual_text creates extmark with correct highlight group", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local details = extmarks[1][4]

  assert_equal(details.virt_text[1][2], "Comment", "Should use Comment highlight group")
end)

test("apply_virtual_text does NOT create extmark when current equals latest", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  virtual_text.clear(bufnr)  -- Ensure clean state

  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.5", version = "1.4.5", latest = "1.4.5" }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 0, "Should NOT create extmark when current version equals latest version")

  -- Verify no extmarks exist in buffer
  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 0, "Buffer should have zero extmarks when versions match")
end)

test("apply_virtual_text creates extmark at end of line", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local details = extmarks[1][4]

  assert_equal(details.virt_text_pos, "eol", "Virtual text should be positioned at end of line")
end)

test("apply_virtual_text places extmark on correct line", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3\nline4\nline5")
  local deps_with_versions = {
    { line = 5, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)

  -- Extmarks use 0-indexed lines, so line 5 becomes index 4
  assert_equal(extmarks[1][2], 4, "Extmark should be on line 5 (0-indexed: 4)")
end)

-- ============================================================================
-- LEVEL 2: Apply virtual text - Multiple dependencies
-- ============================================================================

test("apply_virtual_text with multiple dependencies creates multiple extmarks", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "org.scala-lang:scala-library:2.13.10", version = "2.13.10", latest = "2.13.12" },
    { line = 3, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 3, "Should create three extmarks")

  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 3, "Should have three extmarks in buffer")
end)

test("apply_virtual_text creates correct content for each dependency", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)

  -- Verify first extmark content
  local first_content = extmarks[1][4].virt_text[1][1]
  assert_equal(first_content, "  ← latest: 1.4.5", "First extmark should show '  ← latest: 1.4.5'")

  -- Verify second extmark content
  local second_content = extmarks[2][4].virt_text[1][1]
  assert_equal(second_content, "  ← latest: 0.14.15", "Second extmark should show '  ← latest: 0.14.15'")
end)

test("apply_virtual_text places extmarks on correct lines for multiple dependencies", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10")
  local deps_with_versions = {
    { line = 5, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 10, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)

  assert_equal(extmarks[1][2], 4, "First extmark should be on line 5 (0-indexed: 4)")
  assert_equal(extmarks[2][2], 9, "Second extmark should be on line 10 (0-indexed: 9)")
end)

-- ============================================================================
-- LEVEL 3: Edge cases - nil and unknown versions
-- ============================================================================

test("apply_virtual_text skips dependencies with nil latest version", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "com.example:artifact:1.0.0", version = "1.0.0", latest = nil },
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create only one extmark (skipping nil)")

  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 1, "Should have one extmark in buffer")
end)

test("apply_virtual_text skips dependencies with 'unknown' version", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "com.nonexistent:artifact:1.0.0", version = "1.0.0", latest = "unknown" },
    { line = 3, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 2, "Should create only two extmarks (skipping unknown)")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 2, "Should have two extmarks in buffer")

  -- Verify correct versions were applied
  assert_equal(extmarks[1][4].virt_text[1][1], "  ← latest: 1.4.5", "First extmark should be for config")
  assert_equal(extmarks[2][4].virt_text[1][1], "  ← latest: 0.14.15", "Second extmark should be for circe-core")
end)

test("apply_virtual_text with empty array creates no extmarks", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {}

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 0, "Should create no extmarks for empty array")

  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 0, "Should have no extmarks in buffer")
end)

-- ============================================================================
-- LEVEL 4: Get extmarks - with and without details
-- ============================================================================

test("get_extmarks without details flag returns basic info", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- w h e n
  local extmarks = virtual_text.get_extmarks(bufnr, false)

  -- t h e n
  assert_equal(#extmarks, 1, "Should have one extmark")
  -- When details=false, nvim_buf_get_extmarks returns [id, row, col] without details table
  assert_equal(extmarks[1][4], nil, "Should NOT have details table when details=false")
end)

test("get_extmarks with details flag returns full details", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- w h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)

  -- t h e n
  assert_equal(#extmarks, 1, "Should have one extmark")

  local details = extmarks[1][4]
  assert_equal(type(details.virt_text), "table", "Should have virt_text in details")
  assert_equal(type(details.virt_text_pos), "string", "Should have virt_text_pos in details")
end)

-- ============================================================================
-- LEVEL 5: Clear operation - Destructive operation
-- ============================================================================

test("clear removes all extmarks from buffer", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  local extmarks_before = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks_before, 2, "Should have extmarks before clearing")

  -- w h e n
  virtual_text.clear(bufnr)

  -- t h e n
  local extmarks_after = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks_after, 0, "Should have no extmarks after clearing")
end)

test("clear on buffer without extmarks does not error", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")

  -- w h e n - Should not throw error
  virtual_text.clear(bufnr)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 0, "Should still have no extmarks")
end)

-- ============================================================================
-- LEVEL 6: Reapply - Clear and apply again
-- ============================================================================

test("clear and reapply creates same number of extmarks", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = "0.14.15" }
  }

  -- First application
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)
  local extmarks_first = virtual_text.get_extmarks(bufnr, false)

  -- w h e n - Clear and reapply
  virtual_text.clear(bufnr)
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks_second = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks_second, count, "Should have same number of extmarks after reapply")
  assert_equal(#extmarks_second, #extmarks_first, "Should have same count as first application")
end)

test("clear and reapply creates extmarks with same content", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- First application
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)
  local first_content = virtual_text.get_extmarks(bufnr, true)[1][4].virt_text[1][1]

  -- w h e n - Clear and reapply
  virtual_text.clear(bufnr)
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local second_content = virtual_text.get_extmarks(bufnr, true)[1][4].virt_text[1][1]
  assert_equal(second_content, first_content, "Content should be identical after reapply")
  assert_equal(second_content, "  ← latest: 1.4.5", "Content should be '  ← latest: 1.4.5'")
end)

-- ============================================================================
-- LEVEL 7: Full integration - Parser + Maven + Virtual Text
-- ============================================================================

test("full integration: extract, fetch, and display virtual text", function()
  -- g i v e n
  local content = [[
scalaVersion := "2.13.12"

libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.4.0"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n - Complete flow using real modules
  local deps = parser.extract_dependencies(bufnr)
  assert_equal(#deps, 1, "Should extract one dependency")

  local scala_version = parser.get_scala_version(bufnr)
  assert_equal(scala_version, "2.13", "Should detect Scala version 2.13")

  local deps_with_versions = maven.enrich_with_latest_versions(deps, scala_version)
  assert_equal(#deps_with_versions, 1, "Should enrich one dependency")

  virtual_text.clear(bufnr)
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create exactly one extmark")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 1, "Extmark count should match")

  -- Verify the extmark has correct structure and content
  local details = extmarks[1][4]
  assert_equal(details.virt_text_pos, "eol", "Should be at end of line")
  assert_equal(details.virt_text[1][2], "Comment", "Should use Comment highlight")

  local content_text = details.virt_text[1][1]
  -- Verify exact format: "  ← latest: VERSION"
  assert_equal(content_text:match("^  ← latest: ") ~= nil, true, "Should start with '  ← latest: '")
  assert_equal(content_text:match("^  ← latest: %d+%.%d+") ~= nil, true, "Should have version format X.Y...")

  -- Verify it's on the correct line (line 4, 0-indexed: 3)
  assert_equal(extmarks[1][2], 3, "Should be on line 4 (0-indexed: 3)")

  io.write(string.format("  ℹ️  Virtual text created: '%s'\n", content_text))
end)

test("full integration with Scala dependencies using %%", function()
  -- g i v e n
  local content = [[
scalaVersion := "2.13.12"

val circeVersion = "0.14.1"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)
  local scala_version = parser.get_scala_version(bufnr)
  local deps_with_versions = maven.enrich_with_latest_versions(deps, scala_version)

  virtual_text.clear(bufnr)
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 3, "Should create three extmarks for three Scala dependencies")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 3, "Should have three extmarks")

  io.write(string.format("  ℹ️  Created %d extmarks for Scala dependencies\n", #extmarks))

  -- Verify all extmarks have correct format
  for i, extmark in ipairs(extmarks) do
    local details = extmark[4]
    local content_text = details.virt_text[1][1]

    assert_equal(content_text:match("^  ← latest: ") ~= nil, true,
                 string.format("Extmark %d should have correct format", i))

    io.write(string.format("  ℹ️  Extmark %d: '%s'\n", i, content_text))
  end
end)

test("full integration with real buffer content", function()
  -- g i v e n - Real-world example
  local content = [[
scalaVersion := "2.13.12"

libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.4.0"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n - Complete realistic flow
  local deps = parser.extract_dependencies(bufnr)
  local scala_version = parser.get_scala_version(bufnr)
  local deps_with_versions = maven.enrich_with_latest_versions(deps, scala_version)

  virtual_text.clear(bufnr)
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)

  if #extmarks > 0 then
    local details = extmarks[1][4]
    local virt_text = details.virt_text[1][1]

    -- The actual latest version from Maven Central
    assert_equal(virt_text:match("^  ← latest: %d+%.%d+") ~= nil, true,
                 "Should have valid version format X.Y...")

    -- Should be on line 4 (the dependency line, 0-indexed: 3)
    assert_equal(extmarks[1][2], 3, "Should be on line 4 (0-indexed: 3)")
  end
end)

-- ============================================================================
-- LEVEL 8: Multiple Versions Display (include_prerelease feature)
-- ============================================================================

test("apply_virtual_text with multiple versions (table) displays comma-separated list", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create exactly one extmark")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local virt_text_content = extmarks[1][4].virt_text[1][1]

  -- Verify comma-separated format
  assert_equal(virt_text_content, "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "Should display all versions separated by commas")
end)

test("apply_virtual_text with multiple versions creates extmark when at least one differs", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.1", "0.14.15", "0.15.0-M1"} }  -- First matches current, but others differ
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create extmark when at least one version differs from current")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local virt_text_content = extmarks[1][4].virt_text[1][1]
  assert_equal(virt_text_content, "  ← latest: 0.14.1, 0.14.15, 0.15.0-M1",
               "Should display all versions even if one matches current")
end)

test("apply_virtual_text with multiple versions does NOT create extmark when all equal current", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  virtual_text.clear(bufnr)  -- Ensure clean state

  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.15", version = "0.14.15",
      latest = {"0.14.15", "0.14.15", "0.14.15"} }  -- All versions match current
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 0, "Should NOT create extmark when all versions equal current")

  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 0, "Buffer should have zero extmarks")
end)

test("apply_virtual_text with empty version table does NOT create extmark", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  virtual_text.clear(bufnr)

  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1", latest = {} }
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 0, "Should NOT create extmark for empty version table")

  local extmarks = virtual_text.get_extmarks(bufnr, false)
  assert_equal(#extmarks, 0, "Buffer should have zero extmarks")
end)

test("apply_virtual_text with mixed single and multiple version formats", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },  -- Single version
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} },  -- Multiple versions
    { line = 3, dependency = "org.typelevel:cats-core:2.9.0", version = "2.9.0", latest = "2.13.0" }  -- Single version
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 3, "Should create three extmarks")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 3, "Should have three extmarks")

  -- Verify first extmark (single version)
  assert_equal(extmarks[1][4].virt_text[1][1], "  ← latest: 1.4.5",
               "First extmark should show single version")

  -- Verify second extmark (multiple versions)
  assert_equal(extmarks[2][4].virt_text[1][1], "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "Second extmark should show multiple versions")

  -- Verify third extmark (single version)
  assert_equal(extmarks[3][4].virt_text[1][1], "  ← latest: 2.13.0",
               "Third extmark should show single version")
end)

test("apply_virtual_text with multiple versions handles pre-release versions correctly", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "org.typelevel:cats-core:2.9.0", version = "2.9.0",
      latest = {"2.13.0", "2.3.0-M1", "2.3.0-M2"} }  -- Stable + 2 pre-releases
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 1, "Should create one extmark")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local virt_text_content = extmarks[1][4].virt_text[1][1]

  -- Verify format includes all 3 versions
  assert_equal(virt_text_content, "  ← latest: 2.13.0, 2.3.0-M1, 2.3.0-M2",
               "Should display stable version first, then pre-releases")
end)

test("apply_virtual_text with multiple versions on different lines", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3\nline4\nline5")
  local deps_with_versions = {
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} },
    { line = 5, dependency = "org.typelevel:cats-core:2.9.0", version = "2.9.0",
      latest = {"2.13.0", "2.3.0-M1", "2.3.0-M2"} }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 2, "Should have two extmarks")

  -- Verify line numbers (0-indexed)
  assert_equal(extmarks[1][2], 1, "First extmark should be on line 2 (0-indexed: 1)")
  assert_equal(extmarks[2][2], 4, "Second extmark should be on line 5 (0-indexed: 4)")

  -- Verify content
  assert_equal(extmarks[1][4].virt_text[1][1], "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "First extmark should show circe versions")
  assert_equal(extmarks[2][4].virt_text[1][1], "  ← latest: 2.13.0, 2.3.0-M1, 2.3.0-M2",
               "Second extmark should show cats versions")
end)

test("clear and reapply with multiple versions preserves content", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} }
  }

  -- First application
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)
  local first_content = virtual_text.get_extmarks(bufnr, true)[1][4].virt_text[1][1]

  -- w h e n - Clear and reapply
  virtual_text.clear(bufnr)
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local second_content = virtual_text.get_extmarks(bufnr, true)[1][4].virt_text[1][1]
  assert_equal(second_content, first_content, "Content should be identical after reapply")
  assert_equal(second_content, "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "Content should show all three versions")
end)

test("apply_virtual_text with multiple versions skips when mixed with unknown", function()
  -- g i v e n
  local bufnr = setup_buffer_with_content("line1\nline2\nline3")
  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} },  -- Multiple versions (valid)
    { line = 2, dependency = "com.example:unknown:1.0.0", version = "1.0.0", latest = "unknown" },  -- Unknown (skip)
    { line = 3, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }  -- Single version (valid)
  }

  -- w h e n
  local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  assert_equal(count, 2, "Should create two extmarks (skipping unknown)")

  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 2, "Should have two extmarks")

  -- Verify correct dependencies were displayed
  assert_equal(extmarks[1][4].virt_text[1][1], "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "First extmark should show multiple versions")
  assert_equal(extmarks[2][4].virt_text[1][1], "  ← latest: 1.4.5",
               "Second extmark should show single version")
end)

-- ============================================================================
-- LEVEL 9: Custom Configuration Tests
-- ============================================================================

test("apply_virtual_text respects custom virtual_text_prefix configuration", function()
  -- g i v e n
  local config = require('dependencies.config')

  -- Save original prefix
  local original_prefix = config.get().virtual_text_prefix

  -- Configure custom prefix
  config.setup({ virtual_text_prefix = "  🔄 new version: " })

  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 1, "Should create one extmark")

  local virt_text_content = extmarks[1][4].virt_text[1][1]
  assert_equal(virt_text_content, "  🔄 new version: 1.4.5",
               "Should use custom prefix from configuration")

  -- Restore original configuration
  config.setup({ virtual_text_prefix = original_prefix })
end)

test("apply_virtual_text with custom prefix and multiple versions", function()
  -- g i v e n
  local config = require('dependencies.config')
  local original_prefix = config.get().virtual_text_prefix

  -- Configure custom prefix with arrow
  config.setup({ virtual_text_prefix = " >> " })

  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local virt_text_content = extmarks[1][4].virt_text[1][1]

  assert_equal(virt_text_content, " >> 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "Should use custom prefix with multiple versions")

  -- Restore original configuration
  config.setup({ virtual_text_prefix = original_prefix })
end)

test("apply_virtual_text with empty prefix configuration", function()
  -- g i v e n
  local config = require('dependencies.config')
  local original_prefix = config.get().virtual_text_prefix

  -- Configure empty prefix
  config.setup({ virtual_text_prefix = "" })

  local bufnr = setup_buffer_with_content("")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  local virt_text_content = extmarks[1][4].virt_text[1][1]

  assert_equal(virt_text_content, "1.4.5",
               "Should display version without prefix when prefix is empty")

  -- Restore original configuration
  config.setup({ virtual_text_prefix = original_prefix })
end)

test("apply_virtual_text with multiple dependencies and custom prefix", function()
  -- g i v e n
  local config = require('dependencies.config')
  local original_prefix = config.get().virtual_text_prefix

  -- Configure custom prefix
  config.setup({ virtual_text_prefix = " ➜ " })

  local bufnr = setup_buffer_with_content("line1\nline2\nline3")
  local deps_with_versions = {
    { line = 1, dependency = "com.typesafe:config:1.4.0", version = "1.4.0", latest = "1.4.5" },
    { line = 2, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
      latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} },
    { line = 3, dependency = "org.typelevel:cats-core:2.9.0", version = "2.9.0", latest = "2.13.0" }
  }

  -- w h e n
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- t h e n
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  assert_equal(#extmarks, 3, "Should create three extmarks")

  -- Verify all use custom prefix
  assert_equal(extmarks[1][4].virt_text[1][1], " ➜ 1.4.5",
               "First extmark should use custom prefix")
  assert_equal(extmarks[2][4].virt_text[1][1], " ➜ 0.14.15, 0.14.0-M7, 0.15.0-M1",
               "Second extmark should use custom prefix with multiple versions")
  assert_equal(extmarks[3][4].virt_text[1][1], " ➜ 2.13.0",
               "Third extmark should use custom prefix")

  -- Restore original configuration
  config.setup({ virtual_text_prefix = original_prefix })
end)

-- Print test summary
helper.print_summary()

