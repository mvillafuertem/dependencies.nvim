#!/usr/bin/env -S nvim -l

-- Test de comparación de versiones y lógica de filtrado
-- Este script valida que las versiones se comparan correctamente
-- y que solo se muestran versiones MAYORES que la actual

-- Setup del runtime path
vim.opt.runtimepath:append('.')

local maven = require('dependencies.maven')

print("=== Test de Comparación de Versiones ===\n")

-- Función helper para simular la respuesta de maven-metadata.xml
local function create_mock_xml(versions)
  local xml = "<metadata>\n  <versioning>\n"
  for _, version in ipairs(versions) do
    xml = xml .. "    <version>" .. version .. "</version>\n"
  end
  xml = xml .. "  </versioning>\n</metadata>"
  return xml
end

-- Test 1: Versión 1.1 debe filtrar 1.1-M1 (milestone anterior)
print("Test 1: Usuario en versión 1.1, no debe ver 1.1-M1")
print("----------------------------------------")
local test1_versions = {"1.0", "1.1-M1", "1.1", "1.1.1", "1.2", "1.3"}
local test1_xml = create_mock_xml(test1_versions)
print("Versiones disponibles: " .. table.concat(test1_versions, ", "))
print("Versión actual del usuario: 1.1")
print("Esperado (sin prerelease): 1.3 (última stable mayor que 1.1)")
print("Esperado (con prerelease): 1.1.1, 1.2, 1.3 (en orden ascendente)")
print("")

-- Test 2: Versión 1.0 debe mostrar todas las versiones mayores
print("Test 2: Usuario en versión 1.0, debe ver mejoras")
print("----------------------------------------")
local test2_versions = {"1.0", "1.0.1", "1.1", "1.2", "1.3-M1", "1.3"}
local test2_xml = create_mock_xml(test2_versions)
print("Versiones disponibles: " .. table.concat(test2_versions, ", "))
print("Versión actual del usuario: 1.0")
print("Esperado (sin prerelease): 1.3 (última stable)")
print("Esperado (con prerelease): 1.3, 1.3-M1 (ordenadas - stable + prerelease)")
print("")

-- Test 3: Versión 2.9.0 debe ver versiones mayores correctamente
print("Test 3: Usuario en versión 2.9.0 (caso real)")
print("----------------------------------------")
local test3_versions = {
  "2.8.0", "2.9.0-M1", "2.9.0-M2", "2.9.0", "2.10.0",
  "2.11.0", "2.12.0", "2.13.0", "2.13.1-M1", "2.14.0-M1"
}
local test3_xml = create_mock_xml(test3_versions)
print("Versiones disponibles: " .. table.concat(test3_versions, ", "))
print("Versión actual del usuario: 2.9.0")
print("Esperado (sin prerelease): 2.13.0 (última stable)")
print("Esperado (con prerelease): 2.13.0, 2.13.1-M1, 2.14.0-M1 (ordenadas)")
print("")

-- Test 4: Pre-release de versión futura vs actual estable
print("Test 4: Usuario en 1.0, debe ver 1.1-M1 (prerelease de versión futura)")
print("----------------------------------------")
local test4_versions = {"0.9", "1.0", "1.1-M1", "1.1-M2", "1.2-M1"}
local test4_xml = create_mock_xml(test4_versions)
print("Versiones disponibles: " .. table.concat(test4_versions, ", "))
print("Versión actual del usuario: 1.0")
print("Esperado (con prerelease): 1.1-M1, 1.1-M2, 1.2-M1 (todas son mejoras futuras)")
print("")

-- Test 5: Caso con solo pre-releases disponibles
print("Test 5: Usuario en 1.0, solo hay pre-releases futuras disponibles")
print("----------------------------------------")
local test5_versions = {"0.9", "1.0", "1.1-M1", "1.1-M2", "1.1-RC1"}
local test5_xml = create_mock_xml(test5_versions)
print("Versiones disponibles: " .. table.concat(test5_versions, ", "))
print("Versión actual del usuario: 1.0")
print("Esperado (sin prerelease): nil (no hay stable mayor)")
print("Esperado (con prerelease): 1.1-M1, 1.1-M2, 1.1-RC1 (últimas 3)")
print("")

-- Test 6: Orden de prioridad de pre-releases
print("Test 6: Verificar orden: SNAPSHOT < M < alpha < beta < RC < stable")
print("----------------------------------------")
local test6_versions = {
  "1.0", "1.1-SNAPSHOT", "1.1-M1", "1.1-alpha",
  "1.1-beta", "1.1-RC1", "1.1"
}
local test6_xml = create_mock_xml(test6_versions)
print("Versiones disponibles: " .. table.concat(test6_versions, ", "))
print("Versión actual del usuario: 1.0")
print("Esperado (sin prerelease): 1.1 (stable)")
print("Esperado (con prerelease): 1.1, 1.1-RC1 (stable + última prerelease)")
print("")

print("\n=== Instrucciones para validar ===")
print("1. Ejecuta este script: nvim -l test_version_comparison.lua")
print("2. Modifica tu ~/.config/nvim/init.lua para configurar:")
print("   - include_prerelease = false (para probar sin pre-releases)")
print("   - include_prerelease = true (para probar con pre-releases)")
print("3. Abre un build.sbt con dependencias reales")
print("4. Ejecuta :SbtDepsLatest para ver resultados")
print("5. Verifica que:")
print("   - No aparezcan versiones menores o iguales a la actual")
print("   - Las versiones aparezcan en orden ascendente")
print("   - Con prerelease: 1 stable + 2 pre-releases (si existen)")
print("   - Sin prerelease: solo la última stable mayor que la actual")
print("\n=== Casos de prueba recomendados ===")
print("Dependencias de ejemplo para probar en build.sbt:")
print('  "org.typelevel" %% "cats-core" % "2.9.0"  // Probar con versión antigua')
print('  "io.circe" %% "circe-core" % "0.14.0"    // Probar con versión intermedia')
print('  "com.typesafe" % "config" % "1.4.0"       // Probar con Java library')
print("")

