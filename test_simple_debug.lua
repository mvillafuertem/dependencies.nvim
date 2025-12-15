-- Simplest possible test to see debug output

-- Force clean module reload
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil

-- Setup config
local config = require('dependencies.config')
config.setup({ include_prerelease = true })

print("Config loaded: include_prerelease = " .. tostring(config.get().include_prerelease))

-- Load maven (should show debug prints)
local maven = require('dependencies.maven')

-- Test with one dependency
local deps = {
  { dependency = "io.circe:circe-core:0.14.1", line = 1 }
}

print("\nCalling enrich_with_latest_versions...")
local result = maven.enrich_with_latest_versions(deps, "2.13")

print("\nResult:")
print("  Type of latest: " .. type(result[1].latest))
if type(result[1].latest) == "table" then
  print("  Versions: " .. table.concat(result[1].latest, ", "))
else
  print("  Version: " .. tostring(result[1].latest))
end

