-- Integration test with real build.sbt file
vim.opt.runtimepath:append('.')

-- Clear module cache to ensure we load the latest version
package.loaded['dependencies'] = nil
package.loaded['dependencies.virtual_text'] = nil
package.loaded['dependencies.maven'] = nil
package.loaded['dependencies.parser'] = nil
package.loaded['dependencies.config'] = nil

print("=== Integration Test: Real build.sbt File ===\n")

-- Create a test buffer with build.sbt content
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "build.sbt")
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local content = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "io.circe" %% "circe-parser" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0",
  "com.typesafe" % "config" % "1.4.2",
)
]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

-- Now test the full plugin flow
local deps_plugin = require('dependencies')
local virtual_text = require('dependencies.virtual_text')

print("Step 1: Extracting dependencies from buffer...")
local deps = deps_plugin.extract_dependencies(bufnr)
print(string.format("  Found %d dependencies\n", #deps))

for _, dep in ipairs(deps) do
  print(string.format("  Line %d: %s", dep.line, dep.dependency))
end

print("\nStep 2: Detecting Scala version...")
local parser = require('dependencies.parser')
local scala_version = parser.get_scala_version(bufnr)
print(string.format("  Scala version: %s\n", scala_version or "not detected"))

print("Step 3: Showing 'checking...' indicators...")
virtual_text.clear(bufnr)
for _, dep_info in ipairs(deps) do
  virtual_text.show_checking_indicator(bufnr, dep_info.line)
end
print("  ✓ Indicators shown\n")

print("Step 4: Fetching latest versions asynchronously...")
local start_time = vim.loop.now()
local completed = false

local maven = require('dependencies.maven')
maven.enrich_with_latest_versions_async(deps, scala_version, function(deps_with_versions)
  local elapsed = vim.loop.now() - start_time
  completed = true

  print(string.format("  ✓ Completed in %dms\n", elapsed))

  print("Step 5: Applying virtual text with results...")
  virtual_text.clear(bufnr)
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  -- Get extmarks to verify they were applied
  local extmarks = virtual_text.get_extmarks(bufnr, true)
  print(string.format("  ✓ Applied %d virtual text markers\n", #extmarks))

  print("Results:")
  for _, dep_info in ipairs(deps_with_versions) do
    local latest_display
    if type(dep_info.latest) == "table" then
      latest_display = table.concat(dep_info.latest, ", ")
    else
      latest_display = dep_info.latest
    end

    local needs_update = ""
    if type(dep_info.latest) == "string" and dep_info.current ~= dep_info.latest and dep_info.latest ~= "unknown" then
      needs_update = " ⚠️  UPDATE AVAILABLE"
    elseif type(dep_info.latest) == "table" and dep_info.latest[1] ~= dep_info.current then
      needs_update = " ⚠️  UPDATE AVAILABLE"
    end

    print(string.format("  Line %d: %s", dep_info.line, dep_info.dependency:match("[^:]+:[^:]+") or dep_info.dependency))
    print(string.format("    Current: %s", dep_info.current))
    print(string.format("    Latest:  %s%s", latest_display, needs_update))
  end

  print("\n=== Integration Test PASSED ===")
end)

-- Wait for completion
print("  Waiting for async operations...\n")
while not completed and vim.loop.now() - start_time < 15000 do
  vim.wait(100)
end

if not completed then
  print("\n✗ Test FAILED: Timeout")
  os.exit(1)
end

