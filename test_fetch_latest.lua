-- Test directo de fetch_latest_version con configuración

-- Limpiar módulos cargados
for k, _ in pairs(package.loaded) do
  if k:match("^dependencies") then
    package.loaded[k] = nil
  end
end

-- Configurar primero
local config = require('dependencies.config')
config.setup({
  include_prerelease = true,
})

print("=== Test: fetch_latest_version con include_prerelease = true ===\n")
print("1. Configuración:")
print("   include_prerelease = " .. tostring(config.get().include_prerelease))
print()

-- Cargar maven después de configurar
local maven = require('dependencies.maven')

-- Test con io.circe:circe-core_2.13
print("2. Test con io.circe:circe-core_2.13")
local group_id = "io.circe"
local artifact_id = "circe-core"
local scala_version = "2.13"

print(string.format("   Group: %s", group_id))
print(string.format("   Artifact: %s", artifact_id))
print(string.format("   Scala: %s", scala_version))
print()

-- Extraer fetch_latest_version usando require con debug
local maven_module = require('dependencies.maven')

-- Acceder a la función privada mediante un truco
local maven_source = debug.getinfo(maven_module.enrich_with_latest_versions, "S").source
print("3. Llamando a fetch_latest_version...")

-- Necesitamos crear una copia del código que tenga acceso a fetch_latest_version
-- Como es una función local, usaremos enrich_with_latest_versions como wrapper

local test_deps = {
  { dependency = "io.circe:circe-core:0.14.1", line = 1 }
}

local result = maven_module.enrich_with_latest_versions(test_deps, scala_version)

print("4. RESULTADO:")
print(string.format("   Dependencia: %s", result[1].dependency))
print(string.format("   Current: %s", result[1].current))
print(string.format("   Latest type: %s", type(result[1].latest)))

if type(result[1].latest) == "table" then
  print(string.format("   Latest count: %d", #result[1].latest))
  print(string.format("   Latest values: %s", table.concat(result[1].latest, ", ")))
  print("\n✓ CORRECTO: Se retornó una tabla con múltiples versiones")
else
  print(string.format("   Latest value: %s", result[1].latest))
  print("\n✗ ERROR: Se retornó un string en lugar de una tabla")
  print("\nDEBUG: Verificar si config.get().include_prerelease está siendo leído correctamente")
  print("       dentro de fetch_latest_version()")
end

