-- Test script to verify dependency type detection
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_dependency_type_detection.lua" -c "qa"

local parser = require('dependencies.parser')

-- Create a test buffer with mixed dependency types
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local content = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",      // Scala dependency
  "com.typesafe" % "config" % "1.4.2",        // Java dependency
  "org.typelevel" %% "cats-core" % "2.9.0"    // Scala dependency
)

libraryDependencies += "ch.qos.logback" % "logback-classic" % "1.4.11"  // Single Java dep
]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n'))

-- Extract dependencies
print("Extracting dependencies with type detection...")
local deps = parser.extract_dependencies(bufnr)

-- Display results
print(string.format("\nFound %d dependencies:\n", #deps))

for i, dep in ipairs(deps) do
  local type_indicator = ""
  if dep.type == "scala" then
    type_indicator = "(%%) - Scala"
  elseif dep.type == "java" then
    type_indicator = "(%)  - Java"
  else
    type_indicator = "(??) - Unknown"
  end

  print(string.format("  %d. %s:%s:%s", i, dep.group, dep.artifact, dep.version))
  print(string.format("     Line: %d, Type: %s", dep.line, type_indicator))
end

-- Verify expectations
print("\n=== Type Detection Verification ===")

local expected = {
  {group = "io.circe", artifact = "circe-core", type = "scala"},
  {group = "com.typesafe", artifact = "config", type = "java"},
  {group = "org.typelevel", artifact = "cats-core", type = "scala"},
  {group = "ch.qos.logback", artifact = "logback-classic", type = "java"}
}

local all_passed = true

for i, exp in ipairs(expected) do
  local dep = deps[i]
  if not dep then
    print(string.format("❌ Missing dependency %d: %s:%s", i, exp.group, exp.artifact))
    all_passed = false
  elseif dep.group ~= exp.group or dep.artifact ~= exp.artifact then
    print(string.format("❌ Dependency %d mismatch: expected %s:%s, got %s:%s",
      i, exp.group, exp.artifact, dep.group, dep.artifact))
    all_passed = false
  elseif dep.type ~= exp.type then
    print(string.format("❌ Type mismatch for %s:%s - expected '%s', got '%s'",
      dep.group, dep.artifact, exp.type, dep.type))
    all_passed = false
  else
    print(string.format("✓ %s:%s correctly detected as '%s'", dep.group, dep.artifact, dep.type))
  end
end

if all_passed and #deps == #expected then
  print("\n✅ All type detections passed!")
else
  print("\n❌ Some type detections failed!")
end

