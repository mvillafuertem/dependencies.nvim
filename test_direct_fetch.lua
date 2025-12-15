#!/usr/bin/env nvim -l

-- Test directo de las versiones retornadas por maven-metadata.xml

vim.opt.runtimepath:append('.')

print("=== Test Directo: Verificación de maven-metadata.xml ===\n")

-- Test manual con curl directo
local group_id = "io.circe"
local artifact_id = "circe-core_2.13"
local group_path = group_id:gsub("%.", "/")
local url = string.format(
  "https://repo1.maven.org/maven2/%s/%s/maven-metadata.xml",
  group_path,
  artifact_id
)

print("1. URL a consultar:")
print("   " .. url .. "\n")

local curl_cmd = string.format('curl -s "%s"', url)
local response = vim.fn.system(curl_cmd)

-- Extraer todas las versiones
local all_versions = {}
for version in response:gmatch("<version>([^<]+)</version>") do
  table.insert(all_versions, version)
end

print("2. Total de versiones encontradas: " .. #all_versions .. "\n")

-- Función para detectar pre-release
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

-- Separar estables y pre-release
local stable_versions = {}
local prerelease_versions = {}

for _, version in ipairs(all_versions) do
  if is_prerelease(version) then
    table.insert(prerelease_versions, version)
  else
    table.insert(stable_versions, version)
  end
end

print("3. Versiones estables: " .. #stable_versions)
if #stable_versions > 0 then
  local last_5_stable = {}
  for i = math.max(1, #stable_versions - 4), #stable_versions do
    table.insert(last_5_stable, stable_versions[i])
  end
  print("   Últimas 5 estables: " .. table.concat(last_5_stable, ", ") .. "\n")
end

print("4. Versiones pre-release: " .. #prerelease_versions)
if #prerelease_versions > 0 then
  local last_5_pre = {}
  for i = math.max(1, #prerelease_versions - 4), #prerelease_versions do
    table.insert(last_5_pre, prerelease_versions[i])
  end
  print("   Últimas 5 pre-release: " .. table.concat(last_5_pre, ", ") .. "\n")
end

-- Construir resultado como lo haría fetch_from_metadata_xml con include_prerelease=true
print("5. Simulación de include_prerelease = true:")
local result_versions = {}

-- Agregar la última versión estable
if #stable_versions > 0 then
  table.insert(result_versions, stable_versions[#stable_versions])
  print("   ✓ Agregada última estable: " .. stable_versions[#stable_versions])
end

-- Agregar las últimas 2 versiones pre-release
local prerelease_count = math.min(2, #prerelease_versions)
for i = #prerelease_versions - prerelease_count + 1, #prerelease_versions do
  if i > 0 and #result_versions < 3 then
    table.insert(result_versions, prerelease_versions[i])
    print("   ✓ Agregada pre-release: " .. prerelease_versions[i])
  end
end

-- Si no tenemos 3 versiones, agregar más estables
if #result_versions < 3 and #stable_versions > 1 then
  local stable_start = math.max(1, #stable_versions - (3 - #result_versions))
  for i = stable_start, #stable_versions - 1 do
    if i > 0 then
      table.insert(result_versions, 1, stable_versions[i])
      print("   ✓ Agregada estable adicional: " .. stable_versions[i])
    end
  end
end

print("\n6. Resultado final (3 versiones esperadas):")
print("   Total: " .. #result_versions)
print("   Versiones: " .. table.concat(result_versions, ", "))

if #result_versions == 3 then
  print("\n✓ Test exitoso: Se retornaron 3 versiones")
else
  print("\n⚠ ADVERTENCIA: Se esperaban 3 versiones, se obtuvieron " .. #result_versions)
end

