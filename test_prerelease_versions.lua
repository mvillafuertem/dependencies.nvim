#!/usr/bin/env nvim -l

-- Test directo de la función fetch_from_metadata_xml con include_prerelease = true

-- Agregar el directorio actual al runtime path
vim.opt.runtimepath:append('.')

print("=== Test: fetch_from_metadata_xml con include_prerelease ===\n")

-- Mock del módulo config para que retorne include_prerelease = true
package.loaded['dependencies.config'] = nil
local config_options = {
  patterns = { "build.sbt" },
  include_prerelease = true,
  virtual_text_prefix = "  ← versiones: ",
}
local config_mock = {
  options = config_options,
  setup = function(opts) end,
  get = function() return config_options end,
  get_patterns = function() return config_options.patterns end,
}
package.loaded['dependencies.config'] = config_mock

-- Cargar el módulo maven
package.loaded['dependencies.maven'] = nil
local maven = require('dependencies.maven')

print("1. Configuración:")
print(string.format("   include_prerelease: %s\n", tostring(config_mock.get().include_prerelease)))

-- Test con una dependencia conocida de Scala
print("2. Testeando con io.circe:circe-core_2.13")
print("   (Esto debería retornar 3 versiones incluyendo al menos una estable)\n")

local test_deps = {
  { line = 1, dependency = "io.circe:circe-core:0.14.1" }
}

local result = maven.enrich_with_latest_versions(test_deps, "2.13")

print("3. Resultado:")
for _, dep_info in ipairs(result) do
  print(string.format("   Dependencia: %s", dep_info.dependency))
  print(string.format("   Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("   ✓ Versiones retornadas: %s", table.concat(dep_info.latest, ", ")))
    print(string.format("   ✓ Total de versiones: %d", #dep_info.latest))

    -- Verificar que al menos una es estable
    local has_stable = false
    for _, version in ipairs(dep_info.latest) do
      -- Verificar si no es pre-release (no contiene -M, -RC, -alpha, -beta, etc.)
      if not version:match("%-M%d+") and
         not version:match("%-RC%d+") and
         not version:match("%-alpha") and
         not version:match("%-beta") and
         not version:match("%-SNAPSHOT") then
        has_stable = true
        print(string.format("   ✓ Versión estable encontrada: %s", version))
        break
      end
    end

    if not has_stable then
      print("   ⚠ ADVERTENCIA: No se encontró versión estable")
    end
  else
    print(string.format("   ✗ Versión única retornada: %s", dep_info.latest))
    print("   ✗ Se esperaban múltiples versiones (tabla)")
  end
end

print("\n4. Test con otra dependencia:")
print("   org.typelevel:cats-core_2.13\n")

local test_deps2 = {
  { line = 1, dependency = "org.typelevel:cats-core:2.9.0" }
}

local result2 = maven.enrich_with_latest_versions(test_deps2, "2.13")

for _, dep_info in ipairs(result2) do
  print(string.format("   Dependencia: %s", dep_info.dependency))
  print(string.format("   Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("   ✓ Versiones: %s", table.concat(dep_info.latest, ", ")))
    print(string.format("   ✓ Total: %d versiones", #dep_info.latest))
  else
    print(string.format("   ✗ Versión única: %s", dep_info.latest))
  end
end

print("\n✓ Test completado")

