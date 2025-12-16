#!/usr/bin/env -S nvim -l

-- Test para verificar que el cache se invalida cuando cambia include_prerelease

-- Agregar el directorio actual al runtime path
vim.opt.runtimepath:prepend(".")

local cache = require('dependencies.cache')
local config = require('dependencies.config')

print("=== Test: Cache invalidation when include_prerelease changes ===\n")

-- Helper para crear un buffer temporal
local function create_test_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "/tmp/test_build.sbt")
  return bufnr
end

-- Test 1: Cache con include_prerelease = false
print("Test 1: Guardar cache con include_prerelease = false")
local bufnr = create_test_buffer()

local test_data_false = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 5,
    latest = "0.14.15"  -- Solo versión estable (string)
  }
}

cache.set(bufnr, test_data_false, false)
print("✅ Cache guardado con include_prerelease = false")
print("   latest = " .. test_data_false[1].latest .. " (string)\n")

-- Verificar que cache es válido con include_prerelease = false
local is_valid_false = cache.is_valid(bufnr, "1d", false)
print("Test 2: Verificar cache con include_prerelease = false")
if is_valid_false then
  print("✅ Cache válido con include_prerelease = false\n")
else
  print("❌ Cache inválido (INESPERADO!)\n")
end

-- Verificar que cache NO es válido cuando cambiamos a include_prerelease = true
print("Test 3: Verificar cache con include_prerelease = true (debería invalidarse)")
local is_valid_true = cache.is_valid(bufnr, "1d", true)
if not is_valid_true then
  print("✅ Cache invalidado correctamente al cambiar include_prerelease a true\n")
else
  print("❌ Cache todavía válido (ERROR!)\n")
end

-- Test 4: Guardar cache con include_prerelease = true
print("Test 4: Guardar cache con include_prerelease = true")
local test_data_true = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 5,
    latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"}  -- Múltiples versiones (tabla)
  }
}

cache.set(bufnr, test_data_true, true)
print("✅ Cache guardado con include_prerelease = true")
print("   latest = " .. vim.inspect(test_data_true[1].latest) .. " (tabla)\n")

-- Verificar que cache es válido con include_prerelease = true
local is_valid_true_2 = cache.is_valid(bufnr, "1d", true)
print("Test 5: Verificar cache con include_prerelease = true")
if is_valid_true_2 then
  print("✅ Cache válido con include_prerelease = true\n")
else
  print("❌ Cache inválido (INESPERADO!)\n")
end

-- Verificar que cache NO es válido cuando cambiamos a include_prerelease = false
print("Test 6: Verificar cache con include_prerelease = false (debería invalidarse)")
local is_valid_false_2 = cache.is_valid(bufnr, "1d", false)
if not is_valid_false_2 then
  print("✅ Cache invalidado correctamente al cambiar include_prerelease a false\n")
else
  print("❌ Cache todavía válido (ERROR!)\n")
end

-- Limpiar
cache.clear(bufnr)
print("🧹 Cache limpiado")

print("\n=== Resumen ===")
print("✅ Test 1: Guardar con include_prerelease = false")
print(is_valid_false and "✅" or "❌" .. " Test 2: Cache válido con mismo valor (false)")
print(not is_valid_true and "✅" or "❌" .. " Test 3: Cache invalidado al cambiar a true")
print("✅ Test 4: Guardar con include_prerelease = true")
print(is_valid_true_2 and "✅" or "❌" .. " Test 5: Cache válido con mismo valor (true)")
print(not is_valid_false_2 and "✅" or "❌" .. " Test 6: Cache invalidado al cambiar a false")

local all_passed = is_valid_false and not is_valid_true and is_valid_true_2 and not is_valid_false_2
if all_passed then
  print("\n✅ TODOS LOS TESTS PASARON")
else
  print("\n❌ ALGUNOS TESTS FALLARON")
end

