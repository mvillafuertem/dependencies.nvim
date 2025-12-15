#!/usr/bin/env nvim -l

-- Test con configuración real del plugin

vim.opt.runtimepath:append('.')

print("=== Test: Múltiples Versiones con include_prerelease = true ===\n")

-- Limpiar todos los módulos cargados
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil
package.loaded['dependencies.parser'] = nil
package.loaded['dependencies'] = nil

-- Cargar y configurar el plugin
local deps = require('dependencies')
deps.setup({
  patterns = { "build.sbt" },
  include_prerelease = true,
  virtual_text_prefix = "  ← versiones: ",
})

-- Verificar configuración
local config = require('dependencies.config')
print("1. Configuración actual:")
print(string.format("   include_prerelease: %s", tostring(config.get().include_prerelease)))
print(string.format("   virtual_text_prefix: '%s'\n", config.get().virtual_text_prefix))

-- Test directo con maven
print("2. Test con io.circe:circe-core_2.13")
print("   Consultando Maven Central...\n")

local maven = require('dependencies.maven')
local test_deps = {
  { line = 1, dependency = "io.circe:circe-core:0.14.1" }
}

local result = maven.enrich_with_latest_versions(test_deps, "2.13")

print("3. Resultado:")
for _, dep_info in ipairs(result) do
  print(string.format("   Dependencia: %s", dep_info.dependency))
  print(string.format("   Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("   ✓ Tipo: tabla (múltiples versiones)"))
    print(string.format("   ✓ Total: %d versiones", #dep_info.latest))
    print(string.format("   ✓ Versiones: %s", table.concat(dep_info.latest, ", ")))

    -- Verificar que al menos una es estable
    local has_stable = false
    local has_prerelease = false

    for _, version in ipairs(dep_info.latest) do
      if version:match("%-M%d+") or version:match("%-RC%d+") or
         version:match("%-alpha") or version:match("%-beta") then
        has_prerelease = true
      else
        has_stable = true
      end
    end

    if has_stable then
      print("   ✓ Contiene al menos una versión estable")
    end
    if has_prerelease then
      print("   ✓ Contiene versiones pre-release")
    end
  else
    print(string.format("   ✗ Tipo: string (versión única)"))
    print(string.format("   ✗ Valor: %s", dep_info.latest))
    print("   ✗ ERROR: Se esperaban múltiples versiones (tabla)")
  end
end

print("\n4. Test adicional con org.typelevel:cats-core")
local test_deps2 = {
  { line = 1, dependency = "org.typelevel:cats-core:2.9.0" }
}

local result2 = maven.enrich_with_latest_versions(test_deps2, "2.13")

for _, dep_info in ipairs(result2) do
  print(string.format("   Dependencia: %s", dep_info.dependency))
  print(string.format("   Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("   ✓ Versiones: %s", table.concat(dep_info.latest, ", ")))
  else
    print(string.format("   ✗ Versión única: %s", dep_info.latest))
  end
end

print("\n✓ Test completado")

