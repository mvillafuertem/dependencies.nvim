-- Test con debugging para ver qué retorna fetch_from_metadata_xml

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

print("=== Debug: fetch_from_metadata_xml ===\n")
print("1. Configuración:")
print("   include_prerelease = " .. tostring(config.get().include_prerelease))
print()

-- Ahora cargar maven
local maven = require('dependencies.maven')

-- Acceder a la función interna mediante debug (hack)
local maven_env = getmetatable(maven) or {}
local fetch_func = nil

-- Cargar el archivo y extraer la función manualmente
local file_content = io.open("lua/dependencies/maven.lua", "r"):read("*all")

-- Ejecutar el código en un entorno controlado
local function test_fetch()
  -- Simular is_prerelease
  local function is_prerelease(version)
    if not version then return false end
    local patterns = {
      "%-M%d+", "%-RC%d+", "%-alpha", "%-beta", "%-SNAPSHOT",
      "%.Alpha", "%.Beta", "%.CR",
    }
    for _, pattern in ipairs(patterns) do
      if version:match(pattern) then return true end
    end
    return false
  end

  -- La función fetch_from_metadata_xml
  local group_id = "io.circe"
  local artifact_id = "circe-core_2.13"
  local include_prerelease = true  -- FORZADO A TRUE

  local group_path = group_id:gsub("%.", "/")
  local url = string.format(
    "https://repo1.maven.org/maven2/%s/%s/maven-metadata.xml",
    group_path,
    artifact_id
  )

  local curl_cmd = string.format('curl -s "%s"', url)
  local response = vim.fn.system(curl_cmd)

  local all_versions = {}
  for version in response:gmatch("<version>([^<]+)</version>") do
    table.insert(all_versions, version)
  end

  print("2. Versiones totales encontradas: " .. #all_versions)

  if #all_versions == 0 then
    return nil
  end

  print("3. include_prerelease = " .. tostring(include_prerelease))

  if not include_prerelease then
    print("   [RUTA: Retornar solo última estable]")
    return "NO DEBERÍA ESTAR AQUÍ"
  end

  print("   [RUTA: Retornar múltiples versiones]")

  local stable_versions = {}
  local prerelease_versions = {}

  for _, version in ipairs(all_versions) do
    if is_prerelease(version) then
      table.insert(prerelease_versions, version)
    else
      table.insert(stable_versions, version)
    end
  end

  print("4. Versiones estables: " .. #stable_versions)
  print("5. Versiones pre-release: " .. #prerelease_versions)

  local result_versions = {}

  if #stable_versions > 0 then
    table.insert(result_versions, stable_versions[#stable_versions])
    print("6. Agregada última estable: " .. stable_versions[#stable_versions])
  end

  local prerelease_count = math.min(2, #prerelease_versions)
  print("7. Pre-release a agregar: " .. prerelease_count)

  for i = #prerelease_versions - prerelease_count + 1, #prerelease_versions do
    if i > 0 and #result_versions < 3 then
      table.insert(result_versions, prerelease_versions[i])
      print("   Agregada pre-release: " .. prerelease_versions[i])
    end
  end

  if #result_versions < 3 then
    local stable_start = math.max(1, #stable_versions - (3 - #result_versions))
    for i = stable_start, #stable_versions - 1 do
      if i > 0 then
        table.insert(result_versions, 1, stable_versions[i])
        print("   Agregada estable adicional: " .. stable_versions[i])
      end
    end
  end

  print("8. Total de versiones en result_versions: " .. #result_versions)
  print("9. Tipo de result_versions: " .. type(result_versions))

  return result_versions
end

local result = test_fetch()

print("\n10. RESULTADO FINAL:")
print("    Tipo: " .. type(result))
if type(result) == "table" then
  print("    Total: " .. #result)
  print("    Versiones: " .. table.concat(result, ", "))
  print("\n✓ CORRECTO: Se retornó una tabla")
else
  print("    Valor: " .. tostring(result))
  print("\n✗ ERROR: Se retornó " .. type(result))
end

