-- Test de uso real: abrir un archivo build.sbt y verificar múltiples versiones

-- Primero limpiamos todo
for k, _ in pairs(package.loaded) do
  if k:match("^dependencies") then
    package.loaded[k] = nil
  end
end

-- Configurar el plugin ANTES de cargar otros módulos
local config = require('dependencies.config')
config.setup({
  patterns = { "test_build.sbt" },
  include_prerelease = true,
  virtual_text_prefix = "  ← versiones: ",
})

print("=== Test Uso Real: build.sbt con include_prerelease = true ===\n")
print("1. Configuración:")
print(string.format("   include_prerelease: %s", tostring(config.get().include_prerelease)))
print(string.format("   virtual_text_prefix: '%s'\n", config.get().virtual_text_prefix))

-- Ahora cargar los otros módulos
local parser = require('dependencies.parser')
local maven = require('dependencies.maven')
local virtual_text = require('dependencies.virtual_text')

-- Leer el archivo test_build.sbt
local file = io.open("test_build.sbt", "r")
if not file then
  print("ERROR: No se pudo abrir test_build.sbt")
  os.exit(1)
end
local content = file:read("*all")
file:close()

print("2. Contenido de test_build.sbt:")
print(content)
print()

-- Crear un buffer con el contenido
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
local lines = vim.split(content, '\n')
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- Extraer dependencias
print("3. Extrayendo dependencias...")
local deps = parser.extract_dependencies(bufnr)
print(string.format("   ✓ Encontradas %d dependencias\n", #deps))

-- Obtener versión de Scala
local scala_version = parser.get_scala_version(bufnr)
print(string.format("4. Versión de Scala: %s\n", scala_version or "ninguna"))

-- Enriquecer con versiones de Maven
print("5. Consultando Maven Central...")
local enriched = maven.enrich_with_latest_versions(deps, scala_version)

print("\n" .. string.rep("=", 70))
print("RESULTADOS:")
print(string.rep("=", 70) .. "\n")

local success_count = 0
local fail_count = 0

for _, dep_info in ipairs(enriched) do
  print(string.format("Línea %d: %s", dep_info.line, dep_info.dependency))
  print(string.format("  Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("  ✓ Tipo: tabla (múltiples versiones)"))
    print(string.format("  ✓ Total: %d versiones", #dep_info.latest))
    print(string.format("  ✓ Versiones: %s", table.concat(dep_info.latest, ", ")))
    success_count = success_count + 1
  else
    print(string.format("  ✗ Tipo: string (versión única: %s)", dep_info.latest))
    fail_count = fail_count + 1
  end
  print()
end

print(string.rep("=", 70))
print(string.format("\nResultado: %d exitosas, %d fallidas", success_count, fail_count))

if success_count > 0 and fail_count == 0 then
  print("\n✓ TEST EXITOSO: Todas las dependencias retornaron múltiples versiones")
else
  print("\n✗ TEST FALLIDO: Algunas dependencias no retornaron múltiples versiones")
  os.exit(1)
end

