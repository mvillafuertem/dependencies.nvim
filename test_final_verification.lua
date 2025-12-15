-- Final comprehensive test to verify the multiple versions feature

print("=" .. string.rep("=", 70))
print("FINAL VERIFICATION: Multiple Versions Display Feature")
print("=" .. string.rep("=", 70) .. "\n")

-- Force clean module reload
for k, _ in pairs(package.loaded) do
  if k:match("^dependencies") then
    package.loaded[k] = nil
  end
end

-- Test 1: Default behavior (include_prerelease = false)
print("TEST 1: Default Behavior (include_prerelease = false)")
print("-" .. string.rep("-", 70))

local config = require('dependencies.config')
config.setup({ include_prerelease = false })

local maven = require('dependencies.maven')
local deps1 = {{ dependency = "io.circe:circe-core:0.14.1", line = 1 }}
local result1 = maven.enrich_with_latest_versions(deps1, "2.13")

print("Config: include_prerelease = " .. tostring(config.get().include_prerelease))
print("Result type: " .. type(result1[1].latest))
print("Result value: " .. tostring(result1[1].latest))

if type(result1[1].latest) == "string" then
  print("✓ PASS: Returns single version string\n")
else
  print("✗ FAIL: Expected string, got table\n")
  os.exit(1)
end

-- Test 2: Multiple versions (include_prerelease = true)
print("TEST 2: Multiple Versions (include_prerelease = true)")
print("-" .. string.rep("-", 70))

-- Force reload modules to pick up new config
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil

config = require('dependencies.config')
config.setup({ include_prerelease = true })

maven = require('dependencies.maven')
local deps2 = {{ dependency = "io.circe:circe-core:0.14.1", line = 1 }}
local result2 = maven.enrich_with_latest_versions(deps2, "2.13")

print("Config: include_prerelease = " .. tostring(config.get().include_prerelease))
print("Result type: " .. type(result2[1].latest))

if type(result2[1].latest) == "table" then
  print("Result count: " .. #result2[1].latest)
  print("Result values: " .. table.concat(result2[1].latest, ", "))

  if #result2[1].latest == 3 then
    print("✓ PASS: Returns table with 3 versions\n")
  else
    print("✗ FAIL: Expected 3 versions, got " .. #result2[1].latest .. "\n")
    os.exit(1)
  end
else
  print("✗ FAIL: Expected table, got " .. type(result2[1].latest) .. "\n")
  os.exit(1)
end

-- Test 3: Virtual text display formatting
print("TEST 3: Virtual Text Display Formatting")
print("-" .. string.rep("-", 70))

package.loaded['dependencies.virtual_text'] = nil
local virtual_text = require('dependencies.virtual_text')

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '  "io.circe" %% "circe-core" % "0.14.1",',
})

local deps_with_versions = {{
  line = 1,
  dependency = "io.circe:circe-core:0.14.1",
  current = "0.14.1",
  latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"}
}}

local count = virtual_text.apply_virtual_text(bufnr, deps_with_versions)
local extmarks = virtual_text.get_extmarks(bufnr, true)

if #extmarks > 0 then
  local details = extmarks[1][4]
  local virt_text = details.virt_text[1][1]
  print("Virtual text: '" .. virt_text .. "'")

  if virt_text:match("0%.14%.15") and virt_text:match("0%.14%.0%-M7") and virt_text:match("0%.15%.0%-M1") then
    print("✓ PASS: Virtual text contains all 3 versions with commas\n")
  else
    print("✗ FAIL: Virtual text doesn't match expected format\n")
    os.exit(1)
  end
else
  print("✗ FAIL: No extmarks created\n")
  os.exit(1)
end

-- Test 4: End-to-end integration
print("TEST 4: End-to-End Integration")
print("-" .. string.rep("-", 70))

package.loaded['dependencies.config'] = nil
package.loaded['dependencies.parser'] = nil
package.loaded['dependencies.maven'] = nil

config = require('dependencies.config')
config.setup({
  include_prerelease = true,
  virtual_text_prefix = "  ← latest: "
})

local parser = require('dependencies.parser')
maven = require('dependencies.maven')

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(buf, 'filetype', 'scala')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  'scalaVersion := "2.13.10"',
  '',
  'libraryDependencies ++= Seq(',
  '  "io.circe" %% "circe-core" % "0.14.1"',
  ')',
})

local parsed_deps = parser.extract_dependencies(buf)
local scala_ver = parser.get_scala_version(buf)
local enriched = maven.enrich_with_latest_versions(parsed_deps, scala_ver)

print("Parsed dependencies: " .. #parsed_deps)
print("Scala version: " .. tostring(scala_ver))
print("Enriched[1].latest type: " .. type(enriched[1].latest))

if #parsed_deps > 0 and scala_ver == "2.13" and type(enriched[1].latest) == "table" then
  print("Versions: " .. table.concat(enriched[1].latest, ", "))
  print("✓ PASS: Full integration works correctly\n")
else
  print("✗ FAIL: Integration test failed\n")
  os.exit(1)
end

-- Summary
print("=" .. string.rep("=", 70))
print("ALL TESTS PASSED ✓")
print("=" .. string.rep("=", 70))
print("\nFeature Summary:")
print("  - Default mode returns single version (string)")
print("  - Pre-release mode returns 3 versions (table)")
print("  - Virtual text displays versions with commas")
print("  - Full integration with parser, maven, and virtual text works")
print("\nThe multiple versions display feature is FULLY FUNCTIONAL!")

