-- Test to check if config is properly read in maven module

-- Force clean
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil

-- Setup config FIRST
local config = require('dependencies.config')
config.setup({ include_prerelease = true })

print("=== After config.setup() ===")
print("config.get().include_prerelease = " .. tostring(config.get().include_prerelease))
print()

-- NOW load maven (it will require config, but config is already loaded with our settings)
local maven = require('dependencies.maven')

-- Check config again
print("=== After loading maven ===")
print("config.get().include_prerelease = " .. tostring(config.get().include_prerelease))
print()

-- Let's manually inspect what maven sees
print("=== What maven's config module sees ===")
-- We can't directly access maven's local config variable, but we can reload config and check
local config2 = require('dependencies.config')
print("config via second require = " .. tostring(config2.get().include_prerelease))
print()

-- Test if they're the same table
print("config == config2: " .. tostring(config == config2))
print()

-- Now test enrichment
local deps = {{ dependency = "io.circe:circe-core:0.14.1", line = 1 }}
print("=== Calling enrich_with_latest_versions ===")
local result = maven.enrich_with_latest_versions(deps, "2.13")

print("\nResult type: " .. type(result[1].latest))
if type(result[1].latest) == "table" then
  print("✓ Got table with " .. #result[1].latest .. " versions")
  print("  Versions: " .. table.concat(result[1].latest, ", "))
else
  print("✗ Got string: " .. tostring(result[1].latest))
  print("\nPossible issue: config.get().include_prerelease not being read correctly in fetch_latest_version()")
end

