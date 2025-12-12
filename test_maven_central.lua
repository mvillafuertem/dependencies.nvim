#!/usr/bin/env lua

-- Script de prueba para verificar consultas a Maven Central
-- Uso: nvim --headless -c "luafile test_maven_central.lua" -c "qa"

print("=== Test de consultas a Maven Central ===\n")

local function test_maven_url(group_id, artifact_id, scala_version)
  local artifact_name = artifact_id
  if scala_version then
    artifact_name = artifact_id .. "_" .. scala_version
  end

  local url = string.format(
    "https://search.maven.org/solrsearch/select?q=g:%s+AND+a:%s&rows=1&wt=json",
    group_id,
    artifact_name
  )

  print(string.format("Probando: %s:%s (scala: %s)", group_id, artifact_id, scala_version or "ninguna"))
  print(string.format("  URL: %s", url))

  local curl_cmd = string.format('curl -s "%s"', url)
  local response = vim.fn.system(curl_cmd)
  local success, json = pcall(vim.fn.json_decode, response)

  if success and json.response and json.response.docs and #json.response.docs > 0 then
    local version = json.response.docs[1].latestVersion or json.response.docs[1].v
    print(string.format("  ✅ Encontrado: %s\n", version))
    return version
  else
    print("  ❌ No encontrado\n")
    return nil
  end
end

-- Test 1: circe-core sin Scala version (debería fallar)
print("Test 1: circe-core SIN versión de Scala")
test_maven_url("io.circe", "circe-core", nil)

-- Test 2: circe-core con Scala 2.13 (debería funcionar)
print("Test 2: circe-core CON Scala 2.13")
test_maven_url("io.circe", "circe-core", "2.13")

-- Test 3: jwt-circe sin Scala version (debería fallar)
print("Test 3: jwt-circe SIN versión de Scala")
test_maven_url("com.github.jwt-scala", "jwt-circe", nil)

-- Test 4: jwt-circe con Scala 2.13 (debería funcionar)
print("Test 4: jwt-circe CON Scala 2.13")
test_maven_url("com.github.jwt-scala", "jwt-circe", "2.13")

-- Test 5: typesafe config sin Scala version (librería Java, debería funcionar)
print("Test 5: typesafe config (librería Java)")
test_maven_url("com.typesafe", "config", nil)

-- Test 6: circe-generic con Scala 2.13
print("Test 6: circe-generic CON Scala 2.13")
test_maven_url("io.circe", "circe-generic", "2.13")

-- Test 7: circe-parser con Scala 2.13
print("Test 7: circe-parser CON Scala 2.13")
test_maven_url("io.circe", "circe-parser", "2.13")

print("\n=== Fin de tests ===")
print("\nConclusión:")
print("- Las librerías Scala NECESITAN el sufijo _2.13")
print("- Las librerías Java NO necesitan el sufijo")
print("- Si scala_version no se detecta, las librerías Scala fallarán")

