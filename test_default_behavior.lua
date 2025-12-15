-- Test default behavior (include_prerelease = false)

-- Force clean
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil

-- Setup config with default (false)
local config = require('dependencies.config')
config.setup({
  patterns = { "test_build.sbt" },
  include_prerelease = false,  -- DEFAULT: solo versiones estables
})

print("=== Test: Comportamiento por defecto (include_prerelease = false) ===\n")
print("1. Configuración:")
print(string.format("   include_prerelease: %s\n", tostring(config.get().include_prerelease)))

local parser = require('dependencies.parser')
local maven = require('dependencies.maven')

-- Crear un buffer de prueba
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
local content = [[scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0"
)]]
local lines = vim.split(content, '\n')
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- Extraer dependencias
local deps = parser.extract_dependencies(bufnr)
local scala_version = parser.get_scala_version(bufnr)

print("2. Dependencias encontradas: " .. #deps)
print("3. Versión de Scala: " .. scala_version)
print("\n4. Consultando Maven Central con include_prerelease = false...\n")

-- Enriquecer con versiones
local enriched = maven.enrich_with_latest_versions(deps, scala_version)

print("======================================================================")
print("RESULTADOS:")
print("======================================================================\n")

local success = true
for _, dep_info in ipairs(enriched) do
  print(string.format("Línea %d: %s", dep_info.line, dep_info.dependency))
  print(string.format("  Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "string" then
    print(string.format("  ✓ Tipo: string (versión única)"))
    print(string.format("  ✓ Versión: %s", dep_info.latest))
  else
    print(string.format("  ✗ Tipo: tabla (¡no debería ser tabla con include_prerelease = false!)"))
    print(string.format("  ✗ Versiones: %s", table.concat(dep_info.latest, ", ")))
    success = false
  end
  print()
end

print("======================================================================\n")

if success then
  print("✓ TEST EXITOSO: Todas las dependencias retornaron versión única (string)")
else
  print("✗ TEST FALLIDO: Algunas dependencias retornaron múltiples versiones")
  os.exit(1)
end

