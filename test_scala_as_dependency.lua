-- Test: Scala version should be included as a dependency
-- Run: nvim --headless -c "set rtp+=." -c "luafile test_scala_as_dependency.lua" -c "qa"

local parser = require('dependencies.parser')

print("=== Test: Scala Version as Dependency ===\n")

-- Test 1: Scala 2.13 should be included as dependency
local content1 = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]

local bufnr1 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, vim.split(content1, "\n"))
vim.api.nvim_buf_set_option(bufnr1, 'filetype', 'scala')

local deps1 = parser.extract_dependencies(bufnr1)

print("Test 1: Scala 2.13 as dependency")
print("  Found " .. #deps1 .. " dependencies")
for i, dep in ipairs(deps1) do
  print(string.format("  [%d] %s:%s:%s (line %d)", i, dep.group, dep.artifact, dep.version, dep.line))
end

-- Verify Scala is included
local scala_found = false
for _, dep in ipairs(deps1) do
  if dep.group == "org.scala-lang" and dep.artifact == "scala-library" then
    scala_found = true
    print("✓ Scala 2.13 dependency found: " .. dep.version)
    assert(dep.version == "2.13.10", "Expected version 2.13.10, got " .. dep.version)
    assert(dep.line == 1, "Expected line 1, got " .. dep.line)
  end
end
assert(scala_found, "Scala dependency not found!")
print("")

-- Test 2: Scala 3 should use scala3-library_3
local content2 = [[
scalaVersion := "3.3.1"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]

local bufnr2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, vim.split(content2, "\n"))
vim.api.nvim_buf_set_option(bufnr2, 'filetype', 'scala')

local deps2 = parser.extract_dependencies(bufnr2)

print("Test 2: Scala 3 as dependency")
print("  Found " .. #deps2 .. " dependencies")
for i, dep in ipairs(deps2) do
  print(string.format("  [%d] %s:%s:%s (line %d)", i, dep.group, dep.artifact, dep.version, dep.line))
end

-- Verify Scala 3 is included
local scala3_found = false
for _, dep in ipairs(deps2) do
  if dep.group == "org.scala-lang" and dep.artifact == "scala3-library_3" then
    scala3_found = true
    print("✓ Scala 3 dependency found: " .. dep.version)
    assert(dep.version == "3.3.1", "Expected version 3.3.1, got " .. dep.version)
    assert(dep.line == 1, "Expected line 1, got " .. dep.line)
  end
end
assert(scala3_found, "Scala 3 dependency not found!")
print("")

-- Test 3: No scalaVersion means no Scala dependency
local content3 = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]

local bufnr3 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr3, 0, -1, false, vim.split(content3, "\n"))
vim.api.nvim_buf_set_option(bufnr3, 'filetype', 'scala')

local deps3 = parser.extract_dependencies(bufnr3)

print("Test 3: No scalaVersion defined")
print("  Found " .. #deps3 .. " dependencies")
for i, dep in ipairs(deps3) do
  print(string.format("  [%d] %s:%s:%s (line %d)", i, dep.group, dep.artifact, dep.version, dep.line))
end

-- Verify Scala is NOT included
local scala_found3 = false
for _, dep in ipairs(deps3) do
  if dep.group == "org.scala-lang" then
    scala_found3 = true
  end
end
assert(not scala_found3, "Scala dependency should not be present!")
print("✓ No Scala dependency added (correct behavior)")
print("")

print("=== All tests passed! ===")
