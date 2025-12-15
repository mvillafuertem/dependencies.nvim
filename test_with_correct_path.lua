-- Test with correct package.path setup

-- CRITICAL: Add current directory to package.path BEFORE requiring modules
local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path

print("=== Updated package.path to include: " .. cwd .. "/lua/")
print()

-- Force clean reload
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil

-- Setup config
local config = require('dependencies.config')
config.setup({ include_prerelease = true })

print("1. Config:")
print("   include_prerelease = " .. tostring(config.get().include_prerelease))
print()

-- Load maven (should now use local version with debug line)
local maven = require('dependencies.maven')

-- Verify it's loading from the right place
local info = debug.getinfo(maven.enrich_with_latest_versions, "S")
print("2. Maven loaded from:")
print("   " .. info.source)
print()

-- Test enrichment
local deps = {{ dependency = "io.circe:circe-core:0.14.1", line = 1 }}

print("3. Calling enrich_with_latest_versions...")
print("   (should see DEBUG output now)")
print()

local result = maven.enrich_with_latest_versions(deps, "2.13")

print("\n4. RESULT:")
print("   Type: " .. type(result[1].latest))

if type(result[1].latest) == "table" then
  print("   Count: " .. #result[1].latest)
  print("   Versions: " .. table.concat(result[1].latest, ", "))
  print("\n✓ SUCCESS: Multiple versions returned!")
else
  print("   Value: " .. tostring(result[1].latest))
  print("\n✗ FAILED: Still returning string")
end

